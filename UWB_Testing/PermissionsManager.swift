//
//  PermissionsManager.swift
//  MyMultiPhoneApp
//
//  Requests and tracks all required iOS permissions for UWB/NI.
//

import Foundation
import CoreBluetooth
import NearbyInteraction
import Network
import CoreLocation

/// A singleton that manages and reports the status of required permissions.
/// Also spawns a single NISession to trigger the NI usage prompt if needed.
class PermissionsManager: NSObject, ObservableObject {
    /// Singleton instance for easy usage
    static let shared = PermissionsManager()
    
    // MARK: - Published states for UI
    /// Current location authorization status
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    /// Current Bluetooth state (e.g. poweredOn, unauthorized, etc.)
    @Published var bluetoothState: CBManagerState = .unknown
    /// Whether this device supports Nearby Interaction (UWB)
    @Published var isNearbyInteractionSupported: Bool = NISession.isSupported
    /// Whether local network permission is granted (detected via NWBrowser states)
    @Published var localNetworkPermissionGranted: Bool = false
    
    // MARK: - Private managers
    private var locationManager = CLLocationManager()
    private var bluetoothManager: CBCentralManager!
    private var niSession: NISession?
    private var localNetworkBrowser: NWBrowser?
    
    // Completion called after we attempt requests
    private var onPermissionsResolved: ((Bool) -> Void)?

    // MARK: - Init
    override init() {
        super.init()
        
        locationManager.delegate = self
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        
        // Create an NISession to trigger the NI permission prompt if needed
        niSession = NISession()
        isNearbyInteractionSupported = NISession.isSupported
    }
    
    // MARK: - Public: Request All
    /// Requests the needed permissions (location, bluetooth, local network, NI).
    /// The completion will be called after a short delay (for demonstration).
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        onPermissionsResolved = completion
        
        requestLocationPermission()
        requestBluetoothPermission()
        requestNearbyInteractionPermission()
        requestLocalNetworkPermission()
        
        // Very simplistic approach: call the callback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.onPermissionsResolved?(true)
        }
    }
    
    // MARK: - Individual Permission Requests
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func requestBluetoothPermission() {
        // Re-init to ensure the delegate is set, prompting as needed
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private func requestNearbyInteractionPermission() {
        // Already created niSession in init(). That triggers NI usage prompt if needed.
        Logger.log("Nearby Interaction session created for permission request.")
    }
    
    /// Uses NWBrowser to request local network permission
    private func requestLocalNetworkPermission() {
        // `_my-uwb-service._tcp` must match your MC service type
        localNetworkBrowser = NWBrowser(
            for: .bonjour(type: "_my-uwb-service._tcp", domain: nil),
            using: .udp
        )
        
        localNetworkBrowser?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready, .waiting(_):
                // Typically means user allowed local network
                DispatchQueue.main.async {
                    self?.localNetworkPermissionGranted = true
                }
            default:
                break
            }
        }
        
        localNetworkBrowser?.start(queue: .main)
        Logger.log("Local network permission requested.")
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionsManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Update published property
        locationAuthStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            Logger.log("Location permission granted.")
        default:
            Logger.log("Location permission denied or not determined.")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension PermissionsManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Update published property
        bluetoothState = central.state
        
        switch central.state {
        case .poweredOn:
            Logger.log("Bluetooth is ON.")
        default:
            Logger.log("Bluetooth permission not granted or unavailable.")
        }
    }
}
