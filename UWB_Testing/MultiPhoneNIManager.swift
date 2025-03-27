import Foundation
import SwiftUI

/// A manager that coordinates multiple AccessoryDevice objects.
/// Receives new config data for an accessory and creates/updates the appropriate AccessoryDevice.
/// Also handles signals to stop or remove an accessory from the system.
class AccessoryNIManager: ObservableObject {
    
    // Keep track of multiple AccessoryDevice objects, e.g. keyed by name:
    @Published var accessories: [String: AccessoryDevice] = [:]
    
    // MARK: - Handling Config Data
    /// Called whenever your system receives "Accessory Configuration Data" for a specific device
    /// (e.g., from MQTT or a data channel).
    func handleAccessoryConfigData(_ configData: Data, accessoryName: String) {
        do {
            // If we already have this device, reuse it; otherwise, create a new one
            let device: AccessoryDevice
            if let existing = accessories[accessoryName] {
                device = existing
                Logger.log("Updating existing device \(accessoryName).", from: "AccessoryNIManager")
            } else {
                device = AccessoryDevice(accessoryName: accessoryName)
                accessories[accessoryName] = device
                Logger.log("Created new device \(accessoryName).", from: "AccessoryNIManager")
            }
            
            // Instruct the device to parse the config and run its new NISession
            try device.configureAndRunSession(configData: configData)
            
        } catch {
            Logger.log("Error configuring accessory \(accessoryName): \(error)", from: "AccessoryNIManager")
        }
    }
    
    // MARK: - Handling Stop/Removal
    /// Called if the accessory is out of range or we receive a "stop" message from it
    func stopAccessorySession(accessoryName: String) {
        guard let device = accessories[accessoryName] else { return }
        device.stopSession()
        Logger.log("\(accessoryName) session stopped.", from: "AccessoryNIManager")
    }
    
    /// Optionally remove the device entirely from the dictionary
    func removeAccessory(accessoryName: String) {
        guard let device = accessories[accessoryName] else { return }
        device.stopSession()
        accessories.removeValue(forKey: accessoryName)
        Logger.log("Removed accessory \(accessoryName) from manager.", from: "AccessoryNIManager")
    }
}
