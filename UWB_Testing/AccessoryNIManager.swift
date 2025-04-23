import Foundation
import CoreBluetooth
import NearbyInteraction
import SwiftUI

/**
 Orchestrates **many** `AccessoryDevice` instances – keyed by each
 peripheral’s UUID so identical accessory names no longer collide.
 */
class AccessoryNIManager: NSObject,
                           ObservableObject,
                           BLEManagerDelegate {

    /// All active accessories, indexed by the peripheral UUID string
    @Published var accessories: [String: AccessoryDevice] = [:]

    override init() {
        super.init()
        BLEManager.shared.delegate = self
    }

    // MARK: - BLEManagerDelegate

    func bleManager(_ manager: BLEManager,
                    didReceiveInitResponseFrom device: CBPeripheral,
                    data: Data) {

        let uuidKey   = device.identifier.uuidString
        let baseName  = device.name ?? "Unknown"
        let unique    = "\(baseName)-\(uuidKey.prefix(4))"

        // Create (or fetch) an AccessoryDevice for this specific peripheral
        let accessory = accessories[uuidKey] ??
                        AccessoryDevice(accessoryName: unique)

        accessory.peripheral = device          // give it the reference
        accessories[uuidKey] = accessory       // store for UI binding

        Logger.log("🧠 Received accessory config for \(unique)",
                   from: "AccessoryNIManager")

        do {
            try accessory.configureAndRunSession(configData: data)
        } catch {
            Logger.log("❌ Failed to configure \(unique): \(error)",
                       from: "AccessoryNIManager")
        }
    }

    func bleManager(_ manager: BLEManager,
                    didReceiveStartResponseFrom device: CBPeripheral,
                    config: Data) {
        let shortId = device.identifier.uuidString.prefix(4)
        Logger.log("🚀 Start signal from accessory \(device.name ?? "Unknown")-\(shortId)",
                   from: "AccessoryNIManager")
        // Extra logic could live here if needed.
    }
}
