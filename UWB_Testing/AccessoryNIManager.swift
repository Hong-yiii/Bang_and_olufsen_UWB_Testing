import Foundation
import CoreBluetooth
import SwiftUI

/// A manager that coordinates multiple AccessoryDevice objects.
/// Receives new config data for an accessory and creates/updates the appropriate AccessoryDevice.
/// Also handles signals to stop or remove an accessory from the system.
// AccessoryNIManager.swift
//  1️⃣ iPhone sends:        0x0A
//  2️⃣ Accessory replies:   0x01 + UserAccessoryConfigData_t
//  3️⃣ iPhone sends:        0x0B + shareable_config_data
//  4️⃣ Accessory replies:   0x02 (session ready)
//  5️⃣ iPhone starts:       NISession.run(configData)


import Foundation
import CoreBluetooth
import NearbyInteraction
import SwiftUI

/// A manager that coordinates multiple AccessoryDevice objects and handles the BLE handshake flow.
class AccessoryNIManager: NSObject, ObservableObject, BLEManagerDelegate {

    @Published var accessories: [String: AccessoryDevice] = [:]

    override init() {
        super.init()
        BLEManager.shared.delegate = self
    }

    // MARK: - BLEManagerDelegate Handlers

    func bleManager(_ manager: BLEManager, didReceiveInitResponseFrom device: CBPeripheral, data: Data) {
        let name = device.name ?? "Unknown"
        Logger.log("🧠 Received accessory config for \(name)", from: "AccessoryNIManager")

        // Create or update the accessory object
        let accessory = accessories[name] ?? AccessoryDevice(accessoryName: name)
        accessories[name] = accessory

        // Step 5️⃣: Directly run the NI session using the received config
        do {
            try accessory.configureAndRunSession(configData: data)
        } catch {
            Logger.log("❌ Failed to configure accessory \(name): \(error)", from: "AccessoryNIManager")
        }
    }

    func bleManager(_ manager: BLEManager, didReceiveStartResponseFrom device: CBPeripheral, config: Data) {
        let name = device.name ?? "Unknown"
        Logger.log("🚀 Received start signal from accessory \(name)", from: "AccessoryNIManager")
        // You may choose to log or use this callback for additional logic.
    }
}
