//
//  AccessoryDevice.swift
//  SingleAccessorySample
//
//  Represents a single third-party UWB accessory, handling:
//   - Its own NISession.
//   - Parsing config data and running the session.
//   - Publishing distance, direction, and shareable config data via MQTTPublisher.
//

import Foundation
import NearbyInteraction
import SwiftUI
import simd

class AccessoryDevice: NSObject, ObservableObject {
    
    // MARK: - Identifiers & Metadata
    let id = UUID()
    let accessoryName: String
    
    // Optional fields you might populate after a handshake
    var firmwareVersion: String?
    var modelInfo: String?
    
    // MARK: - NI Session
    private var niSession: NISession?
    private var accessoryConfiguration: NINearbyAccessoryConfiguration?
    
    // Observed state for the UI
    @Published var sessionActive: Bool = false
    @Published var distance: Float?
    @Published var direction: simd_float3?
    
    // MARK: - MQTT Publisher
    /// We create one MQTTPublisher dedicated to this device
    private var mqttPublisher: MQTTPublisher?
    
    // MARK: - Init
    init(accessoryName: String,
         firmwareVersion: String? = nil,
         modelInfo: String? = nil)
    {
        self.accessoryName = accessoryName
        self.firmwareVersion = firmwareVersion
        self.modelInfo = modelInfo
        
        super.init()
        
        // Create an MQTT publisher that references this AccessoryDevice
        self.mqttPublisher = MQTTPublisher(forDevice: self)
        
        Logger.log("AccessoryDevice init: \(accessoryName)", from: "AccessoryDevice")
    }
    
    // MARK: - Configure & Run Session
    /// Called when we have new config data from the accessory or server
    func configureAndRunSession(configData: Data) throws {
        // 1) Parse config data into a NINearbyAccessoryConfiguration
        let config = try NINearbyAccessoryConfiguration(data: configData)
        accessoryConfiguration = config
        
        // 2) Invalidate any existing session
        niSession?.invalidate()
        
        // 3) Create a fresh session
        let session = NISession()
        session.delegate = self
        niSession = session
        
        // 4) Run with the new configuration
        session.run(config)
        sessionActive = true
        
        Logger.log("NISession started for \(accessoryName).", from: "AccessoryDevice")
    }
    
    // MARK: - Stop Session
    func stopSession() {
        Logger.log("Stopping NI session for \(accessoryName).", from: "AccessoryDevice")
        niSession?.invalidate()
        niSession = nil
        sessionActive = false
        
        // Optionally reset distance/direction
        distance = nil
        direction = nil
    }
    
    // MARK: - Publish Data
    /// Helper to publish new distance/direction whenever they update
    func publishUpdatesIfNeeded() {
        // If distance is known, publish it
        if let dist = distance {
            mqttPublisher?.publishDistance(dist)
        }
        // If direction is known, publish it
        if let dir = direction {
            mqttPublisher?.publishDirection(dir)
        }
    }
}

// MARK: - NISessionDelegate
extension AccessoryDevice: NISessionDelegate {
    
    /// Called whenever the system has a new set of NINearbyObjects for this session
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // For single-accessory usage, typically you only get one object
        guard let obj = nearbyObjects.first else { return }
        
        // Update distance/direction on the main thread (so the UI sees it)
        DispatchQueue.main.async {
            if let newDist = obj.distance {
                self.distance = newDist
                Logger.log("[\(self.accessoryName)] distance: \(newDist)", from: "AccessoryDevice")
            }
            if let newDir = obj.direction {
                self.direction = newDir
                Logger.log("[\(self.accessoryName)] direction: \(newDir)", from: "AccessoryDevice")
            }
            
            // Publish to MQTT
            self.publishUpdatesIfNeeded()
        }
    }
    
    /// Called after `session.run(config)`. The system generates data that you must send to the accessory
    func session(_ session: NISession, didGenerateShareableConfigurationData configData: Data, for object: NINearbyObject) {
        Logger.log("Shareable config data generated for \(accessoryName)", from: "AccessoryDevice")
        // Send it back to the accessory (via MQTT or your data channel)
        mqttPublisher?.publishConfigData(configData)
    }
    
    /// Called when the accessory is out of range or times out
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Logger.log("Accessory \(accessoryName) removed, reason: \(reason)", from: "AccessoryDevice")
        // You could choose to re-init or stop, depending on your needs
    }
    
    /// Called when the session becomes invalid for some reason (e.g. bad config, user permissions)
    func session(_ session: NISession, didInvalidateWith error: Error) {
        Logger.log("NISession invalidated for \(accessoryName): \(error.localizedDescription)", from: "AccessoryDevice")
        sessionActive = false
        // Possibly re-init or just remain stopped
    }
    
    func sessionWasSuspended(_ session: NISession) {
        Logger.log("Session suspended for \(accessoryName)", from: "AccessoryDevice")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        Logger.log("Session suspension ended for \(accessoryName)", from: "AccessoryDevice")
        
        // If we still have a valid config, re-run
        if let config = accessoryConfiguration {
            session.run(config)
        }
    }
}
