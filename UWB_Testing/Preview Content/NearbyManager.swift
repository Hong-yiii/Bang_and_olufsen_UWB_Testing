// NearbyManager.swift
import Foundation
import NearbyInteraction

class NearbyManager: NSObject, ObservableObject, NISessionDelegate {
    @Published var airTags: [AirTag] = []
    private var session: NISession?
    private var discoveredTokens: [NIDiscoveryToken: AirTag] = [:]
    
    override init() {
        super.init()
        PermissionsManager.shared.requestNearbyInteractionPermission()
        PermissionsManager.shared.requestLocationPermission()
        startSession()
    }
    
    private func startSession() {
        session = NISession()
        session?.delegate = self
        Logger.log("Nearby Interaction session started.")
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for nearbyObject in nearbyObjects {
            if let airTag = discoveredTokens[nearbyObject.discoveryToken] {
                airTag.distance = nearbyObject.distance
                airTag.direction = nearbyObject.direction
                Logger.log("Updated \(airTag.name): Distance = \(String(describing: airTag.distance)), Direction = \(String(describing: airTag.direction))")
            }
        }
        objectWillChange.send()
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("Session invalidated: \(error.localizedDescription)")
        startSession()  // Restart session on error
    }
    
    func addAirTag(_ token: NIDiscoveryToken, name: String) {
        let airTag = AirTag(name: name, token: token)
        discoveredTokens[token] = airTag
        airTags.append(airTag)
    }
}
