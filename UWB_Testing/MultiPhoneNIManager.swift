//
//  MultiPhoneNIManager.swift
//  MyMultiPhoneApp
//
//  Simplified implementation for basic 2-device UWB ranging
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI

class MultiPhoneNIManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// The remote phone we're connected to (only track one device for simplicity)
    @Published var connectedPhone: PhoneDevice?
    
    /// A simple status message for the UI
    @Published var statusMessage: String = "Ready"
    
    // MARK: - MC Properties
    private let serviceType = "my-uwb-service"
    private var peerID: MCPeerID!
    private var mcSession: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    // MARK: - NI Properties
    /// Our main NISession
    private var niSession: NISession?
    
    /// Our local discovery token
    private var localDiscoveryToken: NIDiscoveryToken?
    
    // MARK: - Init
    override init() {
        super.init()
        setupMultipeerConnectivity()
        setupNISession()
    }
    
    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        niSession?.invalidate()
    }
    
    // MARK: - Setup
    private func setupMultipeerConnectivity() {
        // Our unique local peer ID
        peerID = MCPeerID(displayName: UIDevice.current.name)
        
        // Setup session
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        // Setup advertiser
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        // Setup browser
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        
        // Start advertising and browsing
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        
        Logger.log("MCSession set up. Advertising and browsing started.")
    }
    
    private func setupNISession() {
        // Don't proceed if NI isn't supported
        guard NISession.isSupported else {
            Logger.log("ERROR: Nearby Interaction not supported on this device")
            statusMessage = "UWB not supported on this device"
            return
        }
        
        // Clean up any existing session
        niSession?.invalidate()
        
        // Create a new session
        niSession = NISession()
        niSession?.delegate = self
        Logger.log("Local NISession initialized")
    }
    
    // MARK: - Token Exchange
    private func sendMyDiscoveryToken(to peer: MCPeerID) {
        // Make sure we have a valid token
        guard let token = niSession?.discoveryToken else {
            Logger.log("❌ Cannot send token: Local discovery token is nil")
            // Try to force token generation if it's nil
            setupNISession()
            return
        }
        
        Logger.log("📝 Preparing to send token: \(token)")
        localDiscoveryToken = token
        
        do {
            // Encode token as data with secure coding
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            Logger.log("📦 Token encoded to \(data.count) bytes")
            
            // Send to peer
            try mcSession.send(data, toPeers: [peer], with: .reliable)
            Logger.log("📤 Successfully sent discovery token to \(peer.displayName)")
        } catch {
            Logger.log("❌ Failed to send token: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                Logger.log("❌ Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
            }
        }
    }
    
    // MARK: - Run NI Session
    private func runSession(with peerToken: NIDiscoveryToken) {
        guard let niSession = niSession else {
            Logger.log("❌ Cannot run session: NISession is nil")
            setupNISession()
            return
        }
        
        // Log warning if local token is nil, but continue with the function
        if localDiscoveryToken == nil {
            Logger.log("⚠️ Warning: localDiscoveryToken is nil when trying to run session")
            // We need a local token - force generation by restarting the session
            setupNISession()
            return
        }
        
        Logger.log("🔄 Preparing to run NISession with peer token")
        
        // Verify session is ready for configuration
        if niSession.discoveryToken == nil {
            Logger.log("⚠️ NI Session doesn't have a discovery token yet, waiting...")
            // Try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.runSession(with: peerToken)
            }
            return
        }
        
        // Create a configuration with the peer token
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        Logger.log("⚙️ Created peer configuration")
        
        // Run the session
        niSession.run(config)
        Logger.log("▶️ Successfully started NISession with peer token")
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
                
                // Send our token to the newly connected peer
                self.sendMyDiscoveryToken(to: peerID)
                
            case .connecting:
                Logger.log("Connecting to \(peerID.displayName)...")
                self.statusMessage = "Connecting to \(peerID.displayName)..."
                
            case .notConnected:
                Logger.log("Disconnected from \(peerID.displayName).")
                self.statusMessage = "Disconnected from \(peerID.displayName)."
                
                // Remove connected phone if it matches this peer
                if self.connectedPhone?.displayName == peerID.displayName {
                    self.connectedPhone = nil
                }
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Logger.log("📥 Received data (\(data.count) bytes) from \(peerID.displayName)")
        
        do {
            // Log the raw data for debugging
            let dataString = data.map { String(format: "%02x", $0) }.joined()
            Logger.log("📦 Raw data (first 64 bytes): \(String(dataString.prefix(64)))...")
            
            // Try to decode the data as an NIDiscoveryToken
            guard let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: data
            ) else {
                Logger.log("❌ Error unarchiving token from \(peerID.displayName) - nil result")
                return
            }
            
            Logger.log("📥 Successfully decoded token from \(peerID.displayName)")
            Logger.log("📝 Using token: \(token)")
            
            DispatchQueue.main.async {
                // Create a new PhoneDevice with this token
                let phone = PhoneDevice(displayName: peerID.displayName, token: token)
                self.connectedPhone = phone
                
                // Run the NISession with this peer token
                self.runSession(with: token)
            }
            
        } catch {
            Logger.log("❌ Failed to decode token: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                Logger.log("❌ Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    Logger.log("❌ Underlying error - Domain: \(underlyingError.domain), Code: \(underlyingError.code)")
                }
            }
        }
    }
    
    // Required stubs
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultiPhoneNIManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Logger.log("❌ Advertiser failed: \(error.localizedDescription)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Logger.log("📱 Received invitation from \(peerID.displayName)")
        // Auto-accept invitations
        invitationHandler(true, mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultiPhoneNIManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Logger.log("❌ Browser failed: \(error.localizedDescription)")
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
    func session(_ session: NISession, didGenerateDiscoveryToken discoveryToken: NIDiscoveryToken) {
        Logger.log("Discovery token generated successfully")
        localDiscoveryToken = discoveryToken
        
        // If we have connected peers, send them our token
        for peer in mcSession.connectedPeers {
            sendMyDiscoveryToken(to: peer)
        }
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            guard let phone = connectedPhone, phone.discoveryToken == object.discoveryToken else {
                continue
            }
            
            DispatchQueue.main.async {
                phone.distance = object.distance
                phone.direction = object.direction
                
                if let distance = phone.distance {
                    Logger.log("📏 \(phone.displayName): Distance = \(String(format: "%.2f", distance))m")
                }
            }
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let nsError = error as NSError
        Logger.log("❌ NISession invalidated. Code: \(nsError.code), Domain: \(nsError.domain)")
        Logger.log("❌ Error detail: \(nsError.localizedDescription)")
        
        // If we still have a connected phone, try to restart the session after a delay
        if connectedPhone != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.setupNISession()
                
                if let token = self.connectedPhone?.discoveryToken {
                    self.runSession(with: token)
                }
            }
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        Logger.log("⏸️ NISession was suspended")
        
        // Clear distance/direction when suspended
        connectedPhone?.distance = nil
        connectedPhone?.direction = nil
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        Logger.log("▶️ NISession suspension ended")
        
        // Try to restart with the peer token we have
        if let token = connectedPhone?.discoveryToken {
            runSession(with: token)
        }
    }
}

// MARK: - ConnectedPhones (for backward compatibility with UI)
extension MultiPhoneNIManager {
    var connectedPhones: [PhoneDevice] {
        if let phone = connectedPhone {
            return [phone]
        }
        return []
    }
}
