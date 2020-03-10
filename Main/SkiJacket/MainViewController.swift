//
//  MainViewController.swift
//  CompassCompanion
//
//  Created by Rick Smith on 04/07/2016.
//  Copyright © 2016 Rick Smith. All rights reserved.
//  Modified by Ryan Moll 2020
//

import UIKit
import CoreBluetooth

class MainViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    
    let BLEService = "FFE0" // Transmission key = 254
    let BLECharacteristic = "FFE1"
    var orientation = 0.0
    var setup = false
    var recording = false
    var readingsSum = 0.0
    var numReadings = 0
    
    @IBOutlet weak var visualizer: UIImageView!
    @IBOutlet weak var recievedMessageText: UILabel!
    @IBOutlet weak var avgAngle: UILabel!
    
    // Upon the main screen loading
    override func viewDidLoad() {
        // Called in case a superclass also overrides this method
        super.viewDidLoad()
        
        // Initialize the bluetooth manager
        manager = CBCentralManager(delegate: self, queue: nil);
        
        customiseNavigationBar()
        let image:UIImage = UIImage(named: "Torso.png")!
        let templateImage = image.withRenderingMode(.alwaysTemplate)
        visualizer.image = templateImage
        visualizer.tintColor = UIColor.red
    }
    
    func customiseNavigationBar () {
        // Declare a button to go in the nav bar (scan/disconnect)
        self.navigationItem.rightBarButtonItem = nil
        let rightButton = UIButton()
        
        // Initialize the button
        // If there is no connected bluetooth device
        if (mainPeripheral == nil) {
            // Make the button say "Scan"
            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else { // There is a connected bluetooth device
            // Make the button say "Disconnect"
            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        // Declare the UI element for the button
        let rightBarButton = UIBarButtonItem()
        // Initialize it with the button just created
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController
            
            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    @objc func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    @objc func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        setup = false
        rotate(degrees: CGFloat(truncating: NSNumber(value: 0.0)))
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }
    
    @objc func recordButton(_ sender: UIButton) {
        if(!recording){
            recording = true
            sender.tintColor = UIColor.red
            avgAngle.text = "..."
        }else{
            recording = false
            sender.tintColor = UIColor.darkGray
            var avgTilt = 0.0
            if(numReadings != 0){
                avgTilt = readingsSum/Double(numReadings)
            }
            avgAngle.text = String(avgTilt)
            print(String(avgTilt))
        }
    }
    
    // MARK: - CBCentralManagerDelegate Methods    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected" + peripheral.name!)
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    // MARK: CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            print("Service found with UUID: " + service.uuid.uuidString)
            
            //device information service
            if (service.uuid.uuidString == "180A") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            //GAP (Generic Access Profile) for Device Name
            // This replaces the deprecated CBUUIDGenericAccessProfileString
            if (service.uuid.uuidString == "1800") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            //Jank Arduino bluetooth device Service
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        //get device name
        if (service.uuid.uuidString == "1800") {
            
            for characteristic in service.characteristics! {
                
                if (characteristic.uuid.uuidString == "2A00") {
                    peripheral.readValue(for: characteristic)
                    print("Found Device Name Characteristic")
                }
                
            }
            
        }
        
        if (service.uuid.uuidString == "180A") {
            
            for characteristic in service.characteristics! {
                
                if (characteristic.uuid.uuidString == "2A29") {
                    peripheral.readValue(for: characteristic)
                    print("Found a Device Manufacturer Name Characteristic")
                } else if (characteristic.uuid.uuidString == "2A23") {
                    peripheral.readValue(for: characteristic)
                    print("Found System ID")
                }
                
            }
            
        }
        
        if (service.uuid.uuidString == BLEService) {
            
            for characteristic in service.characteristics! {
                
                if (characteristic.uuid.uuidString == BLECharacteristic) {
                    //we'll save the reference, we need it to write data
                    mainCharacteristic = characteristic
                    
                    //Set Notify is useful to read incoming data async
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Found Arduino Data Characteristic")
                }
                
            }
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        
        if (characteristic.uuid.uuidString == "2A00") {
            //value for device name recieved
            let deviceName = characteristic.value
            print(deviceName ?? "No Device Name")
        } else if (characteristic.uuid.uuidString == "2A29") {
            //value for manufacturer name recieved
            let manufacturerName = characteristic.value
            print(manufacturerName ?? "No Manufacturer Name")
        } else if (characteristic.uuid.uuidString == "2A23") {
            //value for system ID recieved
            let systemID = characteristic.value
            print(systemID ?? "No System ID")
        } else if (characteristic.uuid.uuidString == BLECharacteristic) {
            //data recieved
            if(characteristic.value != nil) {
                let tempVal = characteristic.value!
                let stringValue = String(data: tempVal, encoding: String.Encoding.utf8)!
                
                let dataArr = stringValue.components(separatedBy: [","]).filter({!$0.isEmpty})
                let changeString: String = dataArr[0]
                let degString: String = dataArr[1]
                
                recievedMessageText.text = degString
                guard let change = NumberFormatter().number(from: changeString) else { return }
                guard let deg = NumberFormatter().number(from: degString) else { return }
                let rad = CGFloat(truncating: change) * CGFloat.pi / 180
                
                if(!setup){
                    rotate(degrees: CGFloat(truncating: deg))
                    setup = true
                }else{
                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveLinear, animations: { () -> Void in
                        self.visualizer.transform = self.visualizer.transform.rotated(by: rad)
                    })
                }
                
                if(recording){
                    readingsSum += Double(truncating: deg)
                    numReadings += 1
                }
                
                if(Double(truncating: deg) > 60 && Double(truncating: deg) < 70){
                    visualizer.tintColor = UIColor.green
                } else {
                    visualizer.tintColor = UIColor.red
                }
                orientation = Double(truncating: deg)
            }
        }
        
        
    }
    
    func rotate(degrees: CGFloat){
        // https://stackoverflow.com/a/58046326/
        let degreesToRadians: (CGFloat) -> CGFloat = { (degrees: CGFloat) in
            return degrees / 180.0 * CGFloat.pi
        }
        visualizer.transform =  CGAffineTransform(rotationAngle: degreesToRadians(degrees))
    }
    
}

