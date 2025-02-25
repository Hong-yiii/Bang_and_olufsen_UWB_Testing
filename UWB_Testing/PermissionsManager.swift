//
//  PermissionsManager.swift
//  UWB_Testing
//
//  Created by Hong Yi Lin on 25/2/25.
//

import Foundation
import CoreBluetooth
import NearbyInteraction
import Network
import CoreLocation

class PermissionsManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = PermissionsManager()
    
    private var locationManager = CLLocationManager()
    private var bluetoothManager: CBCentralManager!
    
    override init() {
        super.init()
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        locationManager.delegate = self
    }
    
    // Request Local Network Access (iOS handles the prompt automatically)
    func requestLocalNetworkPermission() {
        let browser = NWBrowser(for: .bonjour(type: "_uwbtracking._tcp", domain: nil), using: .udp)
        browser.start(queue: .main) // This will trigger the local network prompt
    }
    
    // Request Nearby Interaction (UWB) permission
    func requestNearbyInteractionPermission() {
        // Just initializing the NISession triggers the permission prompt
        let session = NISession()
        session.invalidate() // We don’t need the session, just the prompt
    }
    
    // Request Bluetooth permission
    func requestBluetoothPermission() {
        // The CBCentralManager initialization will automatically request Bluetooth permission
        _ = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Request Location permission
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission granted")
        default:
            print("Location permission denied")
        }
    }
}

extension PermissionsManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is ON")
        default:
            print("Bluetooth permission not granted or unavailable")
        }
    }
}
