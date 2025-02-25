//
//  BluetoothManager.swift
//  UWB_Testing
//
//  Created by Hong Yi Lin on 22/2/25.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager!
    private var homepodPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        default:
            print("Bluetooth is not available.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("HomePod") == true {
            homepodPeripheral = peripheral
            centralManager.connect(peripheral, options: nil)
            centralManager.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to HomePod: \(peripheral.name ?? "Unknown")")
    }
    
    func disconnectHomePod() {
        if let homepod = homepodPeripheral {
            centralManager.cancelPeripheralConnection(homepod)
        }
    }
}
