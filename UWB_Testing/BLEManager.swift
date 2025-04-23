import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?

    private let qppServiceUUID = CBUUID(string: "6E400001-B5A3-F3E0-A9E5-0E24DCCA9E")
    private let qppsRXCharUUID = CBUUID(string: "6E400002-B5A3-F3E0-A9E5-0E24DCCA9E")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [qppServiceUUID], options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([qppServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([qppsRXCharUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics where char.uuid == qppsRXCharUUID {
            txCharacteristic = char
            Logger.log("✅ BLE TX characteristic ready", from: "BLEManager")
        }
    }

    func sendNIConfig(_ configData: Data) {
        guard let txCharacteristic = txCharacteristic, let peripheral = peripheral else { return }
        var message = Data([0x01])  // kMsg_ConfigureAndStart
        message.append(configData)
        peripheral.writeValue(message, for: txCharacteristic, type: .withResponse)
        Logger.log("📡 Sent NI config over BLE", from: "BLEManager")
    }
}
