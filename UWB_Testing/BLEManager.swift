import CoreBluetooth

protocol BLEManagerDelegate: AnyObject {
    func bleManager(_ manager: BLEManager, didReceiveInitResponseFrom device: CBPeripheral, data: Data)
    func bleManager(_ manager: BLEManager, didReceiveStartResponseFrom device: CBPeripheral, config: Data)
}

class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    static let shared = BLEManager()
    weak var delegate: BLEManagerDelegate?

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?

    private var configToSend: Data?
    private var pendingPeripheral: CBPeripheral?

    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID])
            Logger.log("🔍 BLE scan started", from: "BLEManager")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.pendingPeripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
        Logger.log("🔗 Connecting to BLE device: \(peripheral.name ?? "Unnamed")", from: "BLEManager")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([txUUID, rxUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            switch char.uuid {
            case rxUUID:
                rxCharacteristic = char
                Logger.log("✅ RX characteristic ready", from: "BLEManager")
                sendInitCommand()
            case txUUID:
                txCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
                Logger.log("✅ Subscribed to TX notifications", from: "BLEManager")
            default:
                break
            }
        }
    }

    func sendInitCommand() {
        guard let peripheral = peripheral, let rx = rxCharacteristic else { return }
        let initCommand = Data([0x0A])
        peripheral.writeValue(initCommand, for: rx, type: .withResponse)
        Logger.log("📤 Sent Init command (0x0A)", from: "BLEManager")
    }

    func sendNIConfig(_ config: Data) {
        guard let peripheral = peripheral, let rx = rxCharacteristic else {
            Logger.log("❌ Cannot send config – peripheral or RX not ready", from: "BLEManager")
            return
        }
        Logger.log("⏳ Sending config to accessory", from: "BLEManager")
        var message = Data([0x0B])
        message.append(config)
        configToSend = config
        pendingPeripheral = peripheral
        peripheral.writeValue(message, for: rx, type: .withResponse)
        Logger.log("📤 Sent NI config with 0x0B prefix", from: "BLEManager")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        parseBLEResponse(data)
    }

    func parseBLEResponse(_ data: Data) {
        guard let responseCode = data.first else { return }
        let payload = data.dropFirst()
        switch responseCode {
        case 0x01:
            Logger.log("📥 Init Response Received (0x01)", from: "BLEManager")
            if let device = pendingPeripheral {
                delegate?.bleManager(self, didReceiveInitResponseFrom: device, data: Data(payload))
            }
        case 0x02:
            Logger.log("📥 Start Response Received (0x02)", from: "BLEManager")
            if let config = configToSend, let device = pendingPeripheral {
                delegate?.bleManager(self, didReceiveStartResponseFrom: device, config: config)
            }
        case 0x03:
            Logger.log("📥 Stop Response Received (0x03)", from: "BLEManager")
        default:
            Logger.log("❓ Unknown BLE response: 0x\(String(format: "%02X", responseCode))", from: "BLEManager")
        }
    }
}
