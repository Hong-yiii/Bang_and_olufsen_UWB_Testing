import Foundation
import NearbyInteraction
import CoreBluetooth
import Combine
import MultipeerConnectivity

class ProximityManager: NSObject, ObservableObject, NISessionDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {
    @Published var isTracking: Bool = false
    @Published var distanceToAirtag: Double? = nil
    @Published var distanceToHomepod: Double? = nil

    private var session: NISession?
    private var peerSession: MCSession?
    private var peerID: MCPeerID!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var browser: MCBrowserViewController?
    
    private var airtagToken: NIDiscoveryToken?
    private var homepodToken: NIDiscoveryToken?
    
    override init() {
        super.init()
        peerID = MCPeerID(displayName: UIDevice.current.name)
        peerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        peerSession?.delegate = self
        setupNearbyInteraction()
        advertiseService()
    }
    
    private func setupNearbyInteraction() {
        session = NISession()
        session?.delegate = self
    }
    
    private func advertiseService() {
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: "uwb-tracking"
        )
        serviceAdvertiser?.startAdvertisingPeer()
    }
    
    func startTracking() {
        if let discoveryToken = session?.discoveryToken {
            sendDiscoveryToken(token: discoveryToken)
        }
    }

    private func sendDiscoveryToken(token: NIDiscoveryToken) {
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try peerSession?.send(tokenData, toPeers: peerSession!.connectedPeers, with: .reliable)
        } catch {
            print("Failed to send token: \(error)")
        }
    }

    // MARK: - NISessionDelegate
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            guard let distance = object.distance else { continue }
            
            if object.discoveryToken == airtagToken {
                distanceToAirtag = Double(distance)
                print("Distance to AirTag: \(distance) meters")
                if distance < 1.0 {
                    AudioManager.shared.switchToIphone()
                }
            } else if object.discoveryToken == homepodToken {
                distanceToHomepod = Double(distance)
                print("Distance to HomePod: \(distance) meters")
                if distance < 1.0 {
                    AudioManager.shared.switchToHomePod()
                }
            }
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("Session suspended, restarting...")
        if let token = airtagToken {
            session.run(NINearbyPeerConfiguration(peerToken: token))
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("Session invalidated: \(error.localizedDescription)")
        setupNearbyInteraction()
        isTracking = false
    }

    // MARK: - MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to \(peerID.displayName)")
        case .notConnected:
            print("Disconnected from \(peerID.displayName)")
        case .connecting:
            print("Connecting to \(peerID.displayName)")
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let receivedToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                DispatchQueue.main.async {
                    self.airtagToken = receivedToken
                    let config = NINearbyPeerConfiguration(peerToken: receivedToken)
                    self.session?.run(config)
                    self.isTracking = true
                }
            }
        } catch {
            print("Failed to receive token: \(error)")
        }
    }

    // Unused but required MCSessionDelegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - MCBrowserViewControllerDelegate
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }

    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
}

