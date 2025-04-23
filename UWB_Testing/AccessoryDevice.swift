// AccessoryDevice.swift
// SingleAccessorySample
// Represents a single third-party UWB accessory, handling:
// - Its own NISession.
// - Parsing config data and running the session.
// - Generating and sending shareable NI config data over BLE.

import Foundation
import NearbyInteraction
import SwiftUI
import simd

class AccessoryDevice: NSObject, ObservableObject {

    let id = UUID()
    let accessoryName: String
    var firmwareVersion: String?
    var modelInfo: String?

    // MARK: - NI Session
    var niSession: NISession?
    private var accessoryConfiguration: NINearbyAccessoryConfiguration?

    @Published var sessionActive: Bool = false
    @Published var distance: Float?
    @Published var direction: simd_float3?

    // private var mqttPublisher: MQTTPublisher?

    init(accessoryName: String,
         firmwareVersion: String? = nil,
         modelInfo: String? = nil) {
        self.accessoryName = accessoryName
        self.firmwareVersion = firmwareVersion
        self.modelInfo = modelInfo
        super.init()
        // self.mqttPublisher = MQTTPublisher(forDevice: self)
        Logger.log("AccessoryDevice init: \(accessoryName)", from: "AccessoryDevice")
    }

    // MARK: - Configure & Run Session
    func configureAndRunSession(configData: Data) throws {
        let config = try NINearbyAccessoryConfiguration(data: configData)
        accessoryConfiguration = config

        if niSession == nil {
            niSession = NISession()
        }

        guard let session = niSession else {
            throw NSError(
                domain: "AccessoryDevice",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "NISession was not initialized prior to running config"]
            )
        }

        session.delegate = self
        session.run(config)
        sessionActive = true

        Logger.log("NISession started for \(accessoryName).", from: "AccessoryDevice")
    }

    func stopSession() {
        Logger.log("Stopping NI session for \(accessoryName)", from: "AccessoryDevice")
        niSession?.invalidate()
        niSession = nil
        sessionActive = false
        distance = nil
        direction = nil
    }

    func publishUpdatesIfNeeded() {
        if let dist = distance {
            Logger.log("📏 Distance updated: \(dist)m", from: "AccessoryDevice")
            // mqttPublisher?.publishDistance(dist)
        }
        if let dir = direction {
            Logger.log("🧭 Direction updated: \(dir.x), \(dir.y), \(dir.z)", from: "AccessoryDevice")
            // mqttPublisher?.publishDirection(dir)
        }
    }
}

// MARK: - NISessionDelegate

extension AccessoryDevice: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let obj = nearbyObjects.first else { return }
        DispatchQueue.main.async {
            if let newDist = obj.distance {
                self.distance = newDist
                Logger.log("[\(self.accessoryName)] distance: \(newDist)", from: "AccessoryDevice")
            }
            if let newDir = obj.direction {
                self.direction = newDir
                Logger.log("[\(self.accessoryName)] direction: \(newDir)", from: "AccessoryDevice")
            }
            self.publishUpdatesIfNeeded()
        }
    }

    func session(_ session: NISession, didGenerateShareableConfigurationData configData: Data, for object: NINearbyObject) {
        Logger.log("Shareable config data generated for \(accessoryName)", from: "AccessoryDevice")
        BLEManager.shared.sendNIConfig(configData)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Logger.log("Accessory \(accessoryName) removed, reason: \(reason)", from: "AccessoryDevice")
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("NISession invalidated for \(accessoryName): \(error.localizedDescription)", from: "AccessoryDevice")
        sessionActive = false
    }

    func sessionWasSuspended(_ session: NISession) {
        Logger.log("Session suspended for \(accessoryName)", from: "AccessoryDevice")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        Logger.log("Session suspension ended for \(accessoryName)", from: "AccessoryDevice")
        if let config = accessoryConfiguration {
            session.run(config)
        }
    }
}
