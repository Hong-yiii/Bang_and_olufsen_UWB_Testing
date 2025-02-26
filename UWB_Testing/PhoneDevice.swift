// A Object to represent and store information representing another phone

import Foundation
import NearbyInteraction
import SwiftUI  // for Color, if you want random color assignment
import simd

class PhoneDevice: Identifiable, ObservableObject {
    let id = UUID()
    
    // A user-friendly name for the remote device
    let displayName: String
    
    // A random color so we can visually differentiate
    let color: Color
    
    // This is the remote phone’s NIDiscoveryToken (obtained via MC).
    let discoveryToken: NIDiscoveryToken
    
    // Updated when the session receives new data
    @Published var distance: Float?
    @Published var direction: simd_float3?
    
    init(displayName: String, token: NIDiscoveryToken) {
        self.displayName = displayName
        self.discoveryToken = token
        self.color = Color(
            hue: Double.random(in: 0..<1),
            saturation: 0.8,
            brightness: 0.8
        )
    }
}
