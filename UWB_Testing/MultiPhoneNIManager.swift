//
//  MultiPhoneNIManager.swift
//  MyMultiPhoneApp
//
//  Manages MultipeerConnectivity and multiple NISessions (one per remote phone).
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI

/// Responsible for connecting with other iPhones, exchanging NI tokens,
/// and reporting distances/directions for each connected phone.
class MultiPhoneNIManager: NSObject, ObservableObject {
    
    // MARK: - Public Published Properties
    
    /// A list of remote phones currently connected
    @Published var connectedPhones: [PhoneDevice] = []
    
    /// A simple status message for the UI
    @Published var statusMessage: String = ""
    
    // MARK: - MC properties
    private let serviceType = "my-uwb-service"
    private var peerID: MCPeerID!
    private var mcSession: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    // MARK: - NI properties
    /// An NISession for us (so we have a local token to send out).
    private var localNISession: NISession?
    
    /// A dictionary storing a dedicated NISession for each remote phone by UUID.
    private var sessionsForPhones: [UUID: NISession] = [:]
    
    // MARK: - Init
    override init() {
        super.init()
        setupLocalPeerAndSession()
        setupNISession()
    }
    
    // MARK: - Setup
    private func setupLocalPeerAndSession() {
        // Our unique local peer ID (e.g. "John's iPhone")
        peerID = MCPeerID(displayName: UIDevice.current.name)
        
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        // Advertiser to let others find us
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        // Browser to find others
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        
        Logger.log("MCSession set up. Advertising and browsing started.")
    }
    
    private func setupNISession() {
        // This local session obtains our phone’s discovery token.
        localNISession = NISession()
        localNISession?.delegate = self
    }
    
    // MARK: - Token Exchange
    /// Called when we connect to a peer. We attempt to send them our local token.
    private func sendLocalDiscoveryToken(to peer: MCPeerID) {
        guard let token = localNISession?.discoveryToken else {
            Logger.log("Local discoveryToken is nil. Cannot send.")
            return
        }
        
        do {
            // Encode the token to Data
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            // Send reliably
            try mcSession.send(data, toPeers: [peer], with: .reliable)
            Logger.log("Sent local discovery token to \(peer.displayName).")
        } catch {
            Logger.log("Failed to send discovery token: \(error.localizedDescription)")
        }
    }
    
    // MARK: - NI Session per Remote Phone
    /// Create a new NISession for the given phone and run it with a peer configuration.
    private func startTrackingPhone(_ phone: PhoneDevice) {
        let session = NISession()
        session.delegate = self
        
        let config = NINearbyPeerConfiguration(peerToken: phone.discoveryToken)
        session.run(config)
        
        sessionsForPhones[phone.id] = session
        Logger.log("Started NI session for phone: \(phone.displayName).")
    }
    
    /// If a phone disconnects, we can invalidate that session.
    private func stopTrackingPhone(_ phone: PhoneDevice) {
        guard let session = sessionsForPhones[phone.id] else { return }
        session.invalidate()
        sessionsForPhones.removeValue(forKey: phone.id)
    }
}

// MARK: - MCSessionDelegate
extension MultiPhoneNIManager: MCSessionDelegate {
    /// Called whenever the peer's connection state changes (connected, connecting, notConnected).
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                Logger.log("Connected to \(peerID.displayName).")
                self.statusMessage = "Connected to \(peerID.displayName)."
                // Immediately attempt to send our token
                self.sendLocalDiscoveryToken(to: peerID)
                
            case .connecting:
                Logger.log("Connecting to \(peerID.displayName)...")
                self.statusMessage = "Connecting to \(peerID.displayName)..."
                
            case .notConnected:
                Logger.log("Disconnected from \(peerID.displayName).")
                self.statusMessage = "Disconnected from \(peerID.displayName)."
                // Remove from connectedPhones if present
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
    
    /// Called when we receive data (likely the remote phone’s discovery token).
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            // Attempt to unarchive a NIDiscoveryToken
            guard let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: data
            ) else {
                Logger.log("Error unarchiving token from \(peerID.displayName).")
                return
            }
            
            // Main-thread UI updates
            DispatchQueue.main.async {
                // Check if we already track this phone
                if let existingPhone = self.connectedPhones.first(where: { $0.displayName == peerID.displayName }) {
                    Logger.log("Already have phone device for \(peerID.displayName).")
                    // You could update its token if needed, though typically tokens don't change per run.
                } else {
                    // Create a new phone object and begin an NI session for it
                    let phone = PhoneDevice(displayName: peerID.displayName, token: token)
                    self.connectedPhones.append(phone)
                    self.startTrackingPhone(phone)
                }
            }
            
        } catch {
            Logger.log("Failed to decode discovery token from \(peerID.displayName): \(error.localizedDescription)")
        }
    }
    
    // We must implement these stubs, but they’re not used in this example:
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
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Logger.log("Advertiser failed: \(error.localizedDescription)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // For demonstration, auto-accept all invitations
        invitationHandler(true, self.mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultiPhoneNIManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Logger.log("Browser failed: \(error.localizedDescription)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Logger.log("Found peer: \(peerID.displayName). Inviting...")
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Logger.log("Lost peer: \(peerID.displayName).")
    }
}

// MARK: - NISessionDelegate
extension MultiPhoneNIManager: NISessionDelegate {
    
    /// Called when iOS generates this phone’s local discovery token.
    func session(_ session: NISession, didGenerateDiscoveryToken discoveryToken: NIDiscoveryToken) {
        Logger.log("Local iPhone discovery token generated.")
        // We keep it in localNISession, so we can send it when we connect to peers.
    }
    
    /// Called whenever a NISession updates distance/direction to a remote phone.
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for nearbyObject in nearbyObjects {
            guard let device = self.connectedPhones.first(where: { $0.discoveryToken == nearbyObject.discoveryToken }) else {
                continue
            }
            // Update device’s distance/direction
            DispatchQueue.main.async {
                device.distance = nearbyObject.distance
                device.direction = nearbyObject.direction
                Logger.log("Updated \(device.displayName) dist=\(device.distance ?? -1), dir=\(String(describing: device.direction))")
            }
        }
    }
    
    /// Called if the session fails or is no longer valid (e.g. permission revoked, device locked, etc.).
    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("NISession invalidated: \(error.localizedDescription)")
        // You might re-run or remove a phone from tracking, etc.
    }
}
