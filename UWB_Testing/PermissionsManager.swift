import Foundation
import CoreBluetooth
import NearbyInteraction
import Network
import CoreLocation

class PermissionsManager: NSObject, ObservableObject {
    static let shared = PermissionsManager()
    
    private var locationManager = CLLocationManager()
    private var bluetoothManager: CBCentralManager!
    private var niSession: NISession?
    
    // Simple callback to notify when permissions are done (granted or not)
    private var onPermissionsResolved: ((Bool) -> Void)?
    
    override init() {
        super.init()
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        locationManager.delegate = self
        niSession = NISession()
    }
    
    /// Request all needed permissions; call completion once user has responded.
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        onPermissionsResolved = completion
        
        requestLocationPermission()
        requestBluetoothPermission()
        requestNearbyInteractionPermission()
        requestLocalNetworkPermission()
        
        // Wait a bit for user to respond, then call completion.
        // A real app should check each permission more thoroughly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.onPermissionsResolved?(true)
        }
    }
    
    private func requestLocalNetworkPermission() {
        let browser = NWBrowser(for: .bonjour(type: "_uwbtracking._tcp", domain: nil), using: .udp)
        browser.start(queue: .main)
        Logger.log("Local network permission requested.")
    }
    
    private func requestNearbyInteractionPermission() {
        // Creating an NISession can trigger the NI usage prompt if not shown yet
        let _ = NISession()
        Logger.log("Nearby Interaction session created for permission request.")
    }
    
    private func requestBluetoothPermission() {
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionsManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
        switch central.state {
        case .poweredOn:
            Logger.log("Bluetooth is ON")
        default:
            Logger.log("Bluetooth permission not granted or unavailable")
        }
    }
}

