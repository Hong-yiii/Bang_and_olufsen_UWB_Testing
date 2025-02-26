// AirTag.swift
import Foundation
import NearbyInteraction

class AirTag: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let token: NIDiscoveryToken
    @Published var distance: Float?
    @Published var direction: simd_float3?
    
    init(name: String, token: NIDiscoveryToken) {
        self.name = name
        self.token = token
    }
}
