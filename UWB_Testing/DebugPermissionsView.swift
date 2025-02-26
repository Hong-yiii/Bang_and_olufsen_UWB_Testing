//
//  DebugPermissionsView.swift
//  MyMultiPhoneApp
//
//  Shows a summary of permission states to help debugging.
//

import SwiftUI
import CoreBluetooth
import CoreLocation

struct DebugPermissionsView: View {
    @ObservedObject var perms = PermissionsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nearby Interaction Supported: \(perms.isNearbyInteractionSupported ? "Yes" : "No")")
            
            Text("Location Auth Status: \(stringForLocationStatus(perms.locationAuthStatus))")
            
            Text("Bluetooth State: \(stringForBluetoothState(perms.bluetoothState))")
            
            Text("Local Network Permission: \(perms.localNetworkPermissionGranted ? "Granted" : "Not Yet Granted")")
        }
        .padding()
        .navigationTitle("Permissions Debug")
    }
    
    // MARK: - Helpers
    private func stringForLocationStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .restricted:    return "Restricted"
        case .denied:        return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default:    return "Unknown"
        }
    }
    
    private func stringForBluetoothState(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:      return "Unknown"
        case .resetting:    return "Resetting"
        case .unsupported:  return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff:   return "Powered Off"
        case .poweredOn:    return "Powered On"
        @unknown default:   return "Unknown"
        }
    }
}
