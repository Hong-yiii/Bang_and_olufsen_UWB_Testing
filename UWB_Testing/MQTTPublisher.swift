//
//  MQTTPublisher.swift
//  SingleAccessorySample
//
//  A publisher that ties to a *single* AccessoryDevice.
//  Called by the device to send distance, direction, or config data over MQTT.
//

import CocoaMQTT
import Foundation
import simd

class MQTTPublisher: NSObject, ObservableObject {
    
    // MARK: - Stored Properties
    
    /// Weak reference to the device that owns this publisher
    private weak var device: AccessoryDevice?
    
    /// The underlying MQTT client
    private var mqttClient: CocoaMQTT
    
    // MARK: - Init
    
    init(forDevice: AccessoryDevice) {
        self.device = forDevice
        
        // Build a unique clientID
        let clientID = "ios_client_\(UUID().uuidString.prefix(6))"
        self.mqttClient = CocoaMQTT(clientID: clientID, host: "BigBrain.local", port: 1883)
        
        // Example configuration: no username/pw, 120s keepAlive
        self.mqttClient.username = nil
        self.mqttClient.password = nil
        self.mqttClient.keepAlive = 120
        
        super.init()
        
        configureMQTTHandlers()
        connect()
    }
    
    // MARK: - MQTT Setup
    
    private func configureMQTTHandlers() {
        mqttClient.didConnectAck = { mqtt, ack in
            if ack == .accept {
                Logger.log("✅ MQTT Connected successfully", from: "MQTTPublisher")
            } else {
                Logger.log("❌ MQTT Connection failed with code \(ack)", from: "MQTTPublisher")
            }
        }
        
        mqttClient.didDisconnect = { mqtt, error in
            Logger.log("❌ MQTT Disconnected: \(error?.localizedDescription ?? "Unknown error")", from: "MQTTPublisher")
        }
        
        mqttClient.didReceiveMessage = { mqtt, message, id in
            Logger.log("📩 Received Message in topic \(message.topic) with payload \(message.string ?? "nil")", from: "MQTTPublisher")
        }
        
        mqttClient.didPublishMessage = { mqtt, message, id in
            Logger.log("📡 Message Published: \(message.string ?? "nil")", from: "MQTTPublisher")
        }
        
        mqttClient.didSubscribeTopics = { mqtt, success, failed in
            Logger.log("📡 Subscribed to topics successfully.", from: "MQTTPublisher")
        }
        
        mqttClient.didPing = { mqtt in
            Logger.log("📡 Ping sent to MQTT broker", from: "MQTTPublisher")
        }
        
        mqttClient.didReceivePong = { mqtt in
            Logger.log("📡 Pong received from MQTT broker", from: "MQTTPublisher")
        }
    }
    
    private func connect() {
        let attempt = mqttClient.connect()
        if !attempt {
            Logger.log("❌ Failed to connect to MQTT broker.", from: "MQTTPublisher")
        }
    }
    
    func disconnectFromBroker() {
        mqttClient.disconnect()
        Logger.log("📴 Disconnected from MQTT broker.", from: "MQTTPublisher")
    }
    
    // MARK: - Publish Methods
    
    /// Publish distance data
    func publishDistance(_ distance: Float) {
        guard let device = device else { return }
        
        let topic = "accessory/\(device.accessoryName)/distance"
        let message = "\(distance)"
        
        mqttClient.publish(topic, withString: message, qos: .qos1)
        Logger.log("📡 Published Distance: \(distance)m to \(topic)", from: "MQTTPublisher")
    }
    
    /// Publish direction data
    func publishDirection(_ direction: simd_float3) {
        guard let device = device else { return }
        
        let directionStr = "\(direction.x),\(direction.y),\(direction.z)"
        let topic = "accessory/\(device.accessoryName)/direction"
        
        mqttClient.publish(topic, withString: directionStr, qos: .qos1)
        Logger.log("📡 Published Direction: \(directionStr) to \(topic)", from: "MQTTPublisher")
    }
    
    /// Publish shareable NI config data that we must send back to the accessory
    func publishConfigData(_ configData: Data) {
        guard let device = device else { return }
        
        // Convert to Base64 or hex
        let base64String = configData.base64EncodedString()
        let topic = "accessory/\(device.accessoryName)/shareableConfig"
        
        mqttClient.publish(topic, withString: base64String, qos: .qos1)
        Logger.log("📡 Published shareable config (base64) to \(topic)", from: "MQTTPublisher")
    }
    
    // MARK: - Cleanup
    deinit {
        disconnectFromBroker()
    }
}
