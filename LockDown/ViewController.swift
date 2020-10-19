//
//  ViewController.swift
//  LockDown
//
//  Created by Ty Janik on 10/7/20.
//  Copyright © 2020 Locksmiths. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreLocation
import MapKit
import CoreData

let firstServiceUUID = CBUUID(string: "1d4103b8-0fe9-11eb-adc1-0242ac120002")

let LOCKDOWN_SERVICE_UUID = CBUUID(string: "a495ff20-c5b1-4b44-b512-1370f02d74de")

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate, MKMapViewDelegate {
    @IBOutlet weak var luButton: UIButton!
    @IBOutlet weak var isConnectedLabel: UILabel!
    
    @IBOutlet weak var mapView: MKMapView!
    
    var centralMan: CBCentralManager!
    var peripheralMan: CBPeripheral!
    var _characteristics: [CBCharacteristic]?
    var isLocked = false
    
    let locationMan = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralMan = CBCentralManager(delegate: self, queue: nil)
        locationMan.delegate = self
        locationMan.desiredAccuracy = kCLLocationAccuracyBest
        locationMan.requestAlwaysAuthorization()
        }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("MEMORY WARNING")
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
            //print(pname)
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
        print("Connected")
        isConnectedLabel.text = "Connected"
        self.peripheralMan.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnectedLabel.text = "Disconnected"
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
        let hey = characteristic.value!
        let str = String(decoding: hey, as: UTF8.self)
        print(str + "\n")
        
        if str == "0" {
            isLocked = false
        } else if str == "1" {
            isLocked = true
        } else {
            print("not really sure if its locked or unlocked")
        }
        var newButtonText = "Lock"
        if isLocked {
            newButtonText = "Unlock"
        }
        
        luButton.setTitle(newButtonText, for: .normal)
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let chars = service.characteristics {
            _characteristics = service.characteristics
            peripheral.setNotifyValue(true, for: _characteristics![0])
            print("notify value has been set")
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
            }
        } else {
            print("Unable to unwrap descriptors optional")
        }
    }
        
    @IBAction func toggleLockState(_ sender: Any) {
        var strToSend = "0"
        if isLocked == false {
            strToSend = "1"
            // save a new location to CoreData
            locationMan.startUpdatingLocation()
        }
        let strToSendAsData: Data = strToSend.data(using: String.Encoding.utf8)!
        if let characteristic = _characteristics?[0] {
            peripheralMan.writeValue(strToSendAsData, for: characteristic, type: .withResponse)
            
            peripheralMan.readValue(for: characteristic)
        } else {
            print("No connection to peripheral so no data was written")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("location manager authorization status changed")

        switch status {
        case .authorizedAlways:
            print("user allow app to get location data when app is active or in background")
        case .authorizedWhenInUse:
            print("user allow app to get location data only when app is active")
        case .denied:
            print("user tap 'disallow' on the permission dialog, cant get location data")
        case .restricted:
            print("parental control setting disallow location data")
        case .notDetermined:
            print("the location permission dialog has not been shown or they have not made a selection yet")
        @unknown default:
            print("Unkown location permission status")
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        //print(location)
        let lat: Double = location.coordinate.latitude
        let lon: Double = location.coordinate.longitude
        saveNewLocation(lat: lat, lon: lon)
        
        let span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) // indicates zoom level of map
        let currLocation: CLLocationCoordinate2D = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
        let region: MKCoordinateRegion = MKCoordinateRegion(center: currLocation, span: span)
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        mapView.setRegion(region, animated: true)
        self.mapView.addAnnotation(annotation)
        locationMan.stopUpdatingLocation()
    }

    
    @IBAction func getCurrentLocation(_ sender: Any) {
        let resp = getSavedLocation()
        print(resp[0])
        }
    
    func getSavedLocation() -> [NSManagedObject] {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
        var resp: [NSManagedObject]
        fetchRequest.returnsObjectsAsFaults = false
        do {
        resp = try managedContext.fetch(fetchRequest)
            return resp
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        resp = [NSManagedObject()]
        print("there was an issue")
        return resp
    }
    
    func saveNewLocation(lat: Double, lon: Double) {
      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        return
      }
      
        let managedContext = appDelegate.persistentContainer.viewContext
      
        let entity = NSEntityDescription.entity(forEntityName: "Location", in: managedContext)!
              
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
        fetchRequest.returnsObjectsAsFaults = false
      
      do {
        var resp = try managedContext.fetch(fetchRequest)
        if resp.count != 0 {
            print(resp.count)
            deleteAllData()
            print("...data deleted")
        }
        let location = NSManagedObject(entity: entity, insertInto: managedContext)
        location.setValue(lat, forKeyPath: "lat")
        location.setValue(lon, forKey: "lon")
        location.setValue("lastLocation", forKey: "name")
        print(location)
        try managedContext.save()
        print("current data in CoreData:")
        resp = try managedContext.fetch(fetchRequest)
        print(resp[0])
        print("end current data (has length of " + String(resp.count) + ")")
      } catch let error as NSError {
        print("Could not save. \(error), \(error.userInfo)")
      }
    }
    
    func deleteAllData()
    {
        let entity = "Location"
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false

        do
        {
            let results = try managedContext.fetch(fetchRequest)
            for managedObject in results
            {
                let managedObjectData:NSManagedObject = managedObject as! NSManagedObject
                managedContext.delete(managedObjectData)
            }
        } catch let error as NSError {
            print("Detele all data in \(entity) error : \(error) \(error.userInfo)")
        }
    }
}
