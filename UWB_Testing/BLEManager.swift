import CoreBluetooth

protocol BLEManagerDelegate: AnyObject {
    func bleManager(_ manager: BLEManager,
                    didReceiveInitResponseFrom device: CBPeripheral,
                    data: Data)
    func bleManager(_ manager: BLEManager,
                    didReceiveStartResponseFrom device: CBPeripheral,
                    config: Data)
}

/**
 A **singleton** that

 * constantly scans for any peripherals that advertise the Nordic-UART-style
   service (`6E400001…`)
 * maintains independent state (characteristics, pending config, etc.) for
   **every** connected peripheral
 * forwards decoded frames to `AccessoryNIManager`
 */
class BLEManager: NSObject,
                  CBCentralManagerDelegate,
                  CBPeripheralDelegate,
                  ObservableObject {

    // MARK: - Public

    static let shared = BLEManager()
    weak var delegate: BLEManagerDelegate?

    // MARK: - Private - state machines per peripheral

    private var centralManager: CBCentralManager!

    private var peripherals:          [UUID: CBPeripheral]       = [:]
    private var rxCharacteristics:    [UUID: CBCharacteristic]   = [:]
    private var txCharacteristics:    [UUID: CBCharacteristic]   = [:]
    private var configsToSend:        [UUID: Data]               = [:]

    // MARK: - BLE UUIDs

    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        // 🔎 Always keep scanning – even while connecting/connected
        centralManager.scanForPeripherals(withServices: [serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        Logger.log("🔍 BLE scan started", from: "BLEManager")
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        // Ignore if we already know this peripheral
        guard peripherals[peripheral.identifier] == nil else { return }

        peripherals[peripheral.identifier] = peripheral
        Logger.log("🔗 Connecting to BLE device: \(peripheral.name ?? "Unnamed")",
                   from: "BLEManager")
        central.connect(peripheral, options: nil)
        // ⬆️ **NO stopScan() here** – scan keeps running
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([txUUID, rxUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        for char in service.characteristics ?? [] {
            switch char.uuid {
            case rxUUID:
                rxCharacteristics[peripheral.identifier] = char
                Logger.log("✅ RX characteristic ready (\(short(peripheral)))",
                           from: "BLEManager")

            case txUUID:
                txCharacteristics[peripheral.identifier] = char
                peripheral.setNotifyValue(true, for: char)
                Logger.log("✅ Subscribed to TX notifications (\(short(peripheral)))",
                           from: "BLEManager")

            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == txUUID,
              characteristic.isNotifying
        else { return }

        Logger.log("📡 TX notifications enabled – sending Init (0x0A) → \(short(peripheral))",
                   from: "BLEManager")
        sendInitCommand(to: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        parseBLEResponse(data, from: peripheral)
    }

    // MARK: - Outgoing

    private func sendInitCommand(to peripheral: CBPeripheral) {
        guard let rx = rxCharacteristics[peripheral.identifier] else { return }
        peripheral.writeValue(Data([0x0A]), for: rx, type: .withResponse)
    }

    /// Called by `AccessoryDevice` (via `BLEManager.shared`) after generating
    /// shareable NI config data.
    func sendNIConfig(_ config: Data, to peripheral: CBPeripheral) {
        guard let rx = rxCharacteristics[peripheral.identifier] else {
            Logger.log("❌ Cannot send config – RX not ready for \(short(peripheral))",
                       from: "BLEManager")
            return
        }

        Logger.log("⏳ Sending NI config (0x0B + payload) → \(short(peripheral))",
                   from: "BLEManager")

        var message = Data([0x0B])
        message.append(config)

        configsToSend[peripheral.identifier] = config
        peripheral.writeValue(message, for: rx, type: .withResponse)
    }

    // MARK: - Incoming frame parser

    private func parseBLEResponse(_ data: Data, from peripheral: CBPeripheral) {
        guard let code = data.first else { return }
        let payload = data.dropFirst()

        switch code {
        case 0x01:
            Logger.log("📥 Init Response (0x01) ← \(short(peripheral))",
                       from: "BLEManager")
            delegate?.bleManager(self,
                                 didReceiveInitResponseFrom: peripheral,
                                 data: Data(payload))

        case 0x02:
            Logger.log("📥 Start Response (0x02) ← \(short(peripheral))",
                       from: "BLEManager")
            if let cfg = configsToSend[peripheral.identifier] {
                delegate?.bleManager(self,
                                     didReceiveStartResponseFrom: peripheral,
                                     config: cfg)
            }

        case 0x03:
            Logger.log("📥 Stop Response (0x03) ← \(short(peripheral))",
                       from: "BLEManager")

        default:
            Logger.log("❓ Unknown BLE response 0x\(String(format: "%02X", code))" +
                       " ← \(short(peripheral))",
                       from: "BLEManager")
        }
    }

    // MARK: - Helpers

    private func short(_ p: CBPeripheral) -> String {
        let name = p.name ?? "Unnamed"
        let id   = p.identifier.uuidString.prefix(4)
        return "\(name)-\(id)"
    }
}
