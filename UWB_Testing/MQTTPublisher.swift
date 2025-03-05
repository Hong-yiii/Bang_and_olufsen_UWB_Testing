import CocoaMQTT
import Foundation
import Dispatch
import simd

class MQTTPublisher: NSObject, ObservableObject {
    private var mqttClient: CocoaMQTT
    private var publishTimer: DispatchSourceTimer?
    private var phoneManager: MultiPhoneNIManager

    init(phoneManager: MultiPhoneNIManager) {
        self.phoneManager = phoneManager
        let clientID = "ios_client_\(UUID().uuidString.prefix(6))"
        
        self.mqttClient = CocoaMQTT(clientID: clientID, host: "BigBrain.localhost", port: 1883)
        self.mqttClient.username = nil // need if auth is enabled
        self.mqttClient.password = nil
        self.mqttClient.keepAlive = 120
        
        super.init()  // Ensure NSObject is initialized first
        configureMQTTHandlers()
        self.connect()
    }

    // MARK: - Configure MQTT Handlers Using Closures
    private func configureMQTTHandlers() {
        // When MQTT connects
        mqttClient.didConnectAck = { mqtt, ack in
            if ack == .accept {
                Logger.log("✅ MQTT Connected successfully", from: "MQTTPublisher")
                self.startPublishing()
            } else {
                Logger.log("❌ MQTT Connection failed with code \(ack)", from: "MQTTPublisher")
            }
        }

        // When MQTT disconnects
        mqttClient.didDisconnect = { mqtt, error in
            Logger.log("❌ MQTT Disconnected: \(error?.localizedDescription ?? "Unknown error")", from: "MQTTPublisher")
        }

        // When a message is received
        mqttClient.didReceiveMessage = { mqtt, message, id in
            Logger.log("📩 Received Message in topic \(message.topic) with payload \(message.string ?? "nil")", from: "MQTTPublisher")
        }

        // When a message is successfully published
        mqttClient.didPublishMessage = { mqtt, message, id in
            Logger.log("📡 Message Published: \(message.string ?? "nil")", from: "MQTTPublisher")
        }

        // When the MQTT client subscribes successfully
        mqttClient.didSubscribeTopics = { mqtt, success, failed in
            Logger.log("📡 Subscribed to topics successfully.", from: "MQTTPublisher")
        }

        // When the client pings the broker
        mqttClient.didPing = { mqtt in
            Logger.log("📡 Ping sent to MQTT broker", from: "MQTTPublisher")
        }

        // When the broker responds with PONG
        mqttClient.didReceivePong = { mqtt in
            Logger.log("📡 Pong received from MQTT broker", from: "MQTTPublisher")
        }

    }

    // MARK: - MQTT Connection Handling
    private func connect() {
        let attempt = mqttClient.connect()
        if !attempt {
            Logger.log("❌ Failed to connect to MQTT broker.", from: "MQTTPublisher")
        }
    }

    /// Gracefully disconnect from the MQTT broker
    func disconnectFromBroker() {
        mqttClient.disconnect()
        Logger.log("📴 Disconnected from MQTT broker.", from: "MQTTPublisher")
    }

    // MARK: - Publishing Logic
    func startPublishing(interval: TimeInterval = 2.0) {
        guard mqttClient.connState == .connected else {
            Logger.log("❌ MQTT not connected. Cannot start publishing.", from: "MQTTPublisher")
            return
        }

        publishTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        publishTimer?.schedule(deadline: .now(), repeating: interval)
        publishTimer?.setEventHandler { [weak self] in
            self?.publishData()
        }
        publishTimer?.resume()
    }

    func stopPublishing() {
        publishTimer?.cancel()
        publishTimer = nil
    }

    private func publishData() {
        guard let phone = phoneManager.connectedPhone else {
            Logger.log("📡 No connected phones. Skipping publish.", from: "MQTTPublisher")
            return
        }

        if let distance = phone.distance {
            mqttClient.publish("phone/distance", withString: "\(distance)", qos: .qos1)
            Logger.log("📡 Published Distance: \(distance)m", from: "MQTTPublisher")
        }

        if let direction = phone.direction {
            let directionString = "\(direction.x), \(direction.y), \(direction.z)"
            mqttClient.publish("phone/direction", withString: directionString, qos: .qos1)
            Logger.log("📡 Published Direction: \(directionString)", from: "MQTTPublisher")
        }
    }

    deinit {
        stopPublishing()
        disconnectFromBroker()
    }
}
