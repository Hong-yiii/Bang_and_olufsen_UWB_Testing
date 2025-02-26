// multipeer connectivity handling, one NI session per phone
// updates each PhoneDevice as new stuff comes in

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI

/// Manages the local phone's NISession for each remote peer,
/// plus a MultipeerConnectivity session for token exchange.
class MultiPhoneNIManager: NSObject, ObservableObject {
    
    // MARK: - Public Published Properties
    @Published var connectedPhones: [PhoneDevice] = []
    @Published var statusMessage: String = ""
    
    // MARK: - MC properties
    private let serviceType = "my-uwb-service"
    private var peerID: MCPeerID!
    private var mcSession: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    // MARK: - NI properties
    private var localNISession: NISession?
    
    /// We store a separate NISession for each peer to track that phone.
    /// Keyed by the phone’s ID so we can update each session’s delegate properly.
    private var sessionsForPhones: [UUID: NISession] = [:]
    
    override init() {
        super.init()
        setupLocalPeerAndSession()
        setupNISession()
    }
    
    // MARK: - Setup
    private func setupLocalPeerAndSession() {
        // Use device name or some other name. Must be unique across devices for debugging.
        peerID = MCPeerID(displayName: UIDevice.current.name)
        
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        // Create an advertiser (will broadcast to others that we’re available)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        // Create a browser (will look for others advertising the same service type)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        
        Logger.log("MCSession set up. Advertising and browsing started.")
    }
    
    private func setupNISession() {
        // We create one "localNISession" primarily to get our local phone’s discovery token.
        // But for *tracking*, we’ll create dedicated sessions as we learn about remote tokens.
        localNISession = NISession()
        localNISession?.delegate = self
    }
    
    // MARK: - Peer Handling
    
    /// Called whenever we connect to a new peer.
    /// We should send that peer *our* local discovery token if we have it.
    private func sendLocalDiscoveryToken(to peer: MCPeerID) {
        guard let token = localNISession?.discoveryToken else {
            Logger.log("Local discoveryToken is nil. Cannot send.")
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try mcSession.send(data, toPeers: [peer], with: .reliable)
            Logger.log("Sent local discovery token to \(peer.displayName).")
        } catch {
            Logger.log("Failed to send discovery token: \(error.localizedDescription)")
        }
    }
    
    // MARK: - NI for a new Phone
    
    /// Create a new NISession for the given phone and run it with a NINearbyPeerConfiguration.
    private func startTrackingPhone(_ phone: PhoneDevice) {
        let session = NISession()
        session.delegate = self
        
        let config = NINearbyPeerConfiguration(peerToken: phone.discoveryToken)
        
        session.run(config)
        
        sessionsForPhones[phone.id] = session
        Logger.log("Started NI session for phone: \(phone.displayName).")
    }
    
    /// If we lose a phone, we can invalidate that session.
    private func stopTrackingPhone(_ phone: PhoneDevice) {
        guard let session = sessionsForPhones[phone.id] else { return }
        session.invalidate()
        sessionsForPhones.removeValue(forKey: phone.id)
    }
}

// MARK: - MCSessionDelegate
extension MultiPhoneNIManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                Logger.log("Connected to \(peerID.displayName).")
                self.statusMessage = "Connected to \(peerID.displayName)."
                // Send our local token to the newly connected peer
                self.sendLocalDiscoveryToken(to: peerID)
                
            case .connecting:
                Logger.log("Connecting to \(peerID.displayName)...")
                self.statusMessage = "Connecting to \(peerID.displayName)..."
                
            case .notConnected:
                Logger.log("Disconnected from \(peerID.displayName).")
                self.statusMessage = "Disconnected from \(peerID.displayName)."
                // If we stored a phone for this peer, remove it & stop tracking
                if let phone = self.connectedPhones.first(where: { $0.displayName == peerID.displayName }) {
                    self.stopTrackingPhone(phone)
                    DispatchQueue.main.async {
                        self.connectedPhones.removeAll { $0.id == phone.id }
                    }
                }
            @unknown default:
                break
            }
        }
    }
    
    // Receiving data from a peer (likely their discovery token)
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: data
            ) else {
                Logger.log("Error unarchiving token from \(peerID.displayName).")
                return
            }
            
            DispatchQueue.main.async {
                // Check if we already track this phone
                if let existingPhone = self.connectedPhones.first(where: { $0.displayName == peerID.displayName }) {
                    Logger.log("Already have phone device for \(peerID.displayName).")
                    // Potentially update its token if needed
                    // ...
                } else {
                    // Create a new phone object, start NI tracking
                    let phone = PhoneDevice(displayName: peerID.displayName, token: token)
                    self.connectedPhones.append(phone)
                    self.startTrackingPhone(phone)
                }
            }
            
        } catch {
            Logger.log("Failed to decode discovery token from \(peerID.displayName): \(error.localizedDescription)")
        }
    }
    
    // Required stubs (not used here)
    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) { }
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) { }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) { }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultiPhoneNIManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        Logger.log("Advertiser failed: \(error.localizedDescription)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept all invitations for demonstration.
        invitationHandler(true, self.mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultiPhoneNIManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        Logger.log("Browser failed: \(error.localizedDescription)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        Logger.log("Found peer: \(peerID.displayName). Inviting...")
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser,
                 lostPeer peerID: MCPeerID) {
        Logger.log("Lost peer: \(peerID.displayName).")
    }
}

// MARK: - NISessionDelegate
extension MultiPhoneNIManager: NISessionDelegate {
    
    /// Called once iOS creates this phone’s local discovery token.
    func session(_ session: NISession, didGenerateDiscoveryToken discoveryToken: NIDiscoveryToken) {
        Logger.log("Local iPhone discovery token generated.")
        // Typically, we store this to send to peers once connected.
        // Because we store it in localNISession, see .discoveryToken property.
    }
    
    /// Called whenever a NISession with a remote phone updates distance/direction.
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for nearbyObject in nearbyObjects {
            guard let device = self.connectedPhones.first(where: { $0.discoveryToken == nearbyObject.discoveryToken }) else {
                continue
            }
            // Update the device’s distance/direction
            DispatchQueue.main.async {
                device.distance = nearbyObject.distance
                device.direction = nearbyObject.direction
                Logger.log("Updated \(device.displayName). Dist=\(device.distance ?? -1), Dir=\(String(describing: device.direction))")
            }
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("NISession invalidated: \(error.localizedDescription)")
        // Possibly re-run or remove a phone from tracking, etc.
    }
}
