// PermissionsManager.swift
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
    
    func requestPermissions() {
        requestLocalNetworkPermission()
        requestNearbyInteractionPermission()
        requestBluetoothPermission()
        requestLocationPermission()
    }
    
    func requestLocalNetworkPermission() {
        let browser = NWBrowser(for: .bonjour(type: "_uwbtracking._tcp", domain: nil), using: .udp)
        browser.start(queue: .main)
    }
    
    func requestNearbyInteractionPermission() {
        let session = NISession()
        session.invalidate()
    }
    
    func requestBluetoothPermission() {
        _ = CBCentralManager(delegate: self, queue: nil)
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            Logger.log("Location permission granted")
        default:
            Logger.log("Location permission denied")
        }
    }
}

extension PermissionsManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            Logger.log("Bluetooth is ON")
        default:
            Logger.log("Bluetooth permission not granted or unavailable")
        }
    }
}
