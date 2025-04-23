// AccessoryDevice.swift
// Handles NI for **one** UWB accessory.

import Foundation
import NearbyInteraction
import SwiftUI
import CoreBluetooth        // ⬅️ needed for peripheral reference
import simd

class AccessoryDevice: NSObject, ObservableObject {

    let id = UUID()
    let accessoryName: String

    // Optional metadata
    var firmwareVersion: String?
    var modelInfo:      String?

    // Reference to its BLE peripheral so we can reply with config later
    weak var peripheral: CBPeripheral?

    // MARK: - NI
    private var accessoryConfiguration: NINearbyAccessoryConfiguration?
    var         niSession:              NISession?

    @Published var sessionActive = false
    @Published var distance: Float?
    @Published var direction: simd_float3?

    // MARK: - Init

    init(accessoryName: String) {
        self.accessoryName = accessoryName
        super.init()
        Logger.log("AccessoryDevice created: \(accessoryName)",
                   from: "AccessoryDevice")
    }

    // MARK: - NI lifecycle

    func configureAndRunSession(configData: Data) throws {
        let config = try NINearbyAccessoryConfiguration(data: configData)
        accessoryConfiguration = config

        if niSession == nil { niSession = NISession() }
        guard let session = niSession else {
            throw NSError(domain: "AccessoryDevice",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "Failed to create NISession"])
        }

        session.delegate = self
        session.run(config)
        sessionActive = true

        Logger.log("NISession started for \(accessoryName).",
                   from: "AccessoryDevice")
    }

    func stopSession() {
        Logger.log("Stopping NI session for \(accessoryName)",
                   from: "AccessoryDevice")
        niSession?.invalidate()
        niSession      = nil
        sessionActive  = false
        distance       = nil
        direction      = nil
    }
}

// MARK: - NISessionDelegate

extension AccessoryDevice: NISessionDelegate {

    func session(_ session: NISession,
                 didUpdate nearbyObjects: [NINearbyObject]) {

        guard let obj = nearbyObjects.first else { return }

        DispatchQueue.main.async {
            if let d = obj.distance    { self.distance  = d }
            if let v = obj.direction   { self.direction = v }
        }
    }

    func session(_ session: NISession,
                 didGenerateShareableConfigurationData configData: Data,
                 for object: NINearbyObject) {

        Logger.log("Shareable config generated for \(accessoryName)",
                   from: "AccessoryDevice")

        // Send back over BLE to *this* peripheral
        if let p = peripheral {
            BLEManager.shared.sendNIConfig(configData, to: p)
        } else {
            Logger.log("⚠️  Missing peripheral reference – can't send config",
                       from: "AccessoryDevice")
        }
    }

    func session(_ session: NISession,
                 didRemove nearbyObjects: [NINearbyObject],
                 reason: NINearbyObject.RemovalReason) {
        Logger.log("Accessory \(accessoryName) removed – \(reason)",
                   from: "AccessoryDevice")
    }

    func session(_ session: NISession,
                 didInvalidateWith error: Error) {
        Logger.log("NISession invalidated for \(accessoryName): \(error.localizedDescription)",
                   from: "AccessoryDevice")
        sessionActive = false
    }

    func sessionWasSuspended(_ session: NISession) { }
    func sessionSuspensionEnded(_ session: NISession) {
        if let cfg = accessoryConfiguration { session.run(cfg) }
    }
}
