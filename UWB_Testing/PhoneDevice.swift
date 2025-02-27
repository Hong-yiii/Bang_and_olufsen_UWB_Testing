//
//  PhoneDevice.swift
//  MyMultiPhoneApp
//
//  Represents a remote phone participating in UWB ranging.
//

import Foundation
import NearbyInteraction
import SwiftUI
import simd

/// A model representing another phone in our peer group,
/// along with its NI distance/direction data.
class PhoneDevice: Identifiable, ObservableObject {
    let id = UUID()
    
    /// The display name for the remote device (taken from MCPeerID).
    let displayName: String
    
    /// A color assigned randomly so we can differentiate each phone in the UI.
    let color: Color
    
    /// The phone's unique discovery token (received via Multipeer).
    private(set) var discoveryToken: NIDiscoveryToken
    
    /// The latest measured distance in meters (updated by NISession).
    @Published var distance: Float?
    
    /// The latest measured direction (x, y, z) from us to the remote phone.
    @Published var direction: simd_float3?
    
    init(displayName: String, token: NIDiscoveryToken) {
        self.displayName = displayName
        self.discoveryToken = token
        self.color = Color(
            hue: Double.random(in: 0..<1),
            saturation: 0.8,
            brightness: 0.8
        )
        
        // Log the token to verify it's valid
        Logger.log("📝 Created PhoneDevice with token: \(token)")
    }
    
    func updateToken(_ newToken: NIDiscoveryToken) {
        self.discoveryToken = newToken
        Logger.log("📝 Updated token for \(displayName)")
    }
}
