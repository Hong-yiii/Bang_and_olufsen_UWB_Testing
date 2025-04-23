import Foundation
import CoreBluetooth
import SwiftUI

/// A manager that coordinates multiple AccessoryDevice objects.
/// Receives new config data for an accessory and creates/updates the appropriate AccessoryDevice.
/// Also handles signals to stop or remove an accessory from the system.
// AccessoryNIManager.swift
//    [ App launches ]
//    ↓
//    BLEManager connects + discovers
//    ↓
//    AccessoryNIManager → sends 0x0A (init)
//    ↓
//    BLEManager gets 0x01 → passes back to AccessoryNIManager
//    ↓
//    AccessoryNIManager → calls session.generateShareableConfig(...)
//    ↓
//    BLEManager sends 0x0B + configData
//    ↓
//    BLEManager gets 0x02 → passes to AccessoryNIManager
//    ↓
//    AccessoryNIManager → calls session.run(config)
//    ↓
//    UWB Ranging begins


import Foundation
import CoreBluetooth
import NearbyInteraction

/// A manager that coordinates multiple AccessoryDevice objects and handles the BLE handshake flow.
class AccessoryNIManager: NSObject, ObservableObject, BLEManagerDelegate {

    @Published var accessories: [String: AccessoryDevice] = [:]
    private var pendingConfigRequest: [String: CBPeripheral] = [:]

    override init() {
        super.init()
        BLEManager.shared.delegate = self
    }

    // MARK: - BLEManagerDelegate Handlers

    func bleManager(_ manager: BLEManager, didReceiveInitResponseFrom device: CBPeripheral, data: Data) {
        let name = device.name ?? "Unknown"
        Logger.log("🧠 Received accessory config for \(name)", from: "AccessoryNIManager")

        // Create placeholder device if needed
        let accessory = accessories[name] ?? AccessoryDevice(accessoryName: name)
        accessories[name] = accessory

        // Save peripheral for later use
        pendingConfigRequest[name] = device

        // Ask the device to begin NI config generation
        accessory.beginShareableConfigurationGeneration(delegate: self)
    }

    func bleManager(_ manager: BLEManager, didReceiveStartResponseFrom device: CBPeripheral, config: Data) {
        let name = device.name ?? "Unknown"
        Logger.log("🚀 Ready to start NI for \(name)", from: "AccessoryNIManager")

        do {
            let accessory = accessories[name] ?? AccessoryDevice(accessoryName: name)
            accessories[name] = accessory
            try accessory.configureAndRunSession(configData: config)
        } catch {
            Logger.log("❌ Failed to configure accessory \(name): \(error)", from: "AccessoryNIManager")
        }
    }
}

// MARK: - NI Session Delegate Extension

extension AccessoryNIManager: NISessionDelegate {
    func session(_ session: NISession, didGenerateShareableConfigurationData configData: Data, for object: NINearbyObject) {
        guard let deviceName = accessories.first(where: { $0.value.niSession === session })?.key else { return }
        Logger.log("📤 Generated NI config for \(deviceName)", from: "AccessoryNIManager")
        BLEManager.shared.sendNIConfig(configData)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("⚠️ Session invalidated: \(error.localizedDescription)", from: "AccessoryNIManager")
    }
}
