//
//  ViewController.swift
//  LockDown
//
//  Created by Ty Janik on 10/7/20.
//  Copyright © 2020 Locksmiths. All rights reserved.
//

import UIKit
import CoreBluetooth

let firstServiceUUID = CBUUID(string: "1d4103b8-0fe9-11eb-adc1-0242ac120002")

let LOCKDOWN_SERVICE_UUID = CBUUID(string: "a495ff20-c5b1-4b44-b512-1370f02d74de")  // CHANGE THIS

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralMan: CBCentralManager!
    var peripheralMan: CBPeripheral!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    centralMan = CBCentralManager(delegate: self, queue: nil)
        //centralMan = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }

    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
          print("central.state is .unknown")
        case .resetting:
          print("central.state is .resetting")
        case .unsupported:
          print("central.state is .unsupported")
        case .unauthorized:
          print("central.state is .unauthorized")
        case .poweredOff:
          print("central.state is .poweredOff")
        case .poweredOn:
          print("central.state is .poweredOn")
          central.scanForPeripherals(withServices: nil, options: nil)
        @unknown default:
            print("Error: Bluetooth in unknown state")
        }
    }
    func centralManager( // connect to a device
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber) {
        if let pname = peripheral.name {
            print(pname)
            if pname == "kath" {
                print("kathleen has been located")
                
                self.centralMan.stopScan()
                
                self.peripheralMan = peripheral
                self.peripheralMan.delegate = self
                self.centralMan.connect(peripheral, options: nil)
            }
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("this boi connected")
        self.peripheralMan.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnected")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Services:")
        print(peripheral)
        if let servs = peripheral.services {
            for service in servs {
                print(service)
                self.peripheralMan.discoverCharacteristics(nil, for: service)
            }
        } else {
            print("unable to unwrap services optional")
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //peripheral.readValue(for: characteristic)
        let hey = characteristic.value!
        let str = String(decoding: hey, as: UTF8.self)
        print(str + "\n")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let chars = service.characteristics {
            for characteristic in chars {
                print(characteristic)
                self.peripheralMan.discoverDescriptors(for: characteristic)
            }
        } else {
            print("Unable to unwrap characteristics optional")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let desc = characteristic.descriptors {
            for descriptor in desc {
                print(descriptor)
                let isLocked: Data = "1".data(using: String.Encoding.utf8)!
                peripheral.writeValue(isLocked, for: characteristic, type: .withResponse)
                peripheral.readValue(for: characteristic)

            }
        } else {
            print("Unable to unwrap descriptors optional")
        }
    }
}
