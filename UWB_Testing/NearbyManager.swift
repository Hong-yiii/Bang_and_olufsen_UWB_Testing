// NearbyManager.swift
import Foundation
import NearbyInteraction

class NearbyManager: NSObject, ObservableObject, NISessionDelegate {
    @Published var airTags: [AirTag] = []
    private var session: NISession?
    private var discoveredTokens: [NIDiscoveryToken: AirTag] = [:]
    
    override init() {
        super.init()
        initializeSession()
    }
    
    private func initializeSession() {
        Logger.log("Initializing NearbyManager and requesting permissions...")
        PermissionsManager.shared.requestPermissions()
        startSession()
    }
    
    private func startSession() {
        Logger.log("Entering startSession().")
        if session == nil {
            session = NISession()
            Logger.log("NISession instance created.")
        }
        
        guard let session = session else {
            Logger.log("Failed to initialize NISession.")
            return
        }
        
        session.delegate = self
        Logger.log("Nearby Interaction session started.")
    }
    
    func session(_ session: NISession, didGenerateDiscoveryToken discoveryToken: NIDiscoveryToken) {
        Logger.log("iPhone discovery token generated.")
        // This token would be used to interact with other Nearby Interaction devices
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        Logger.log("Nearby objects updated: \(nearbyObjects.count) found.")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startSession()
        }
    }
    
    func addAirTag(_ token: NIDiscoveryToken, name: String) {
        let airTag = AirTag(name: name, token: token)
        discoveredTokens[token] = airTag
        airTags.append(airTag)
    }
}
