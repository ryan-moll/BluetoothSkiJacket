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
    // UIColors from https://www.ralfebert.de/ios-examples/uikit/swift-uicolor-picker/
    let redColor = UIColor(hue: 0.025, saturation: 0.73, brightness: 0.98, alpha: 1.0) /* #fc6042 */
    let greenColor = UIColor(hue: 0.3333, saturation: 0.59, brightness: 0.89, alpha: 1.0) /* #5de25d */
    let min = 60.0 // Change to adjust ideal skier lean angle
    let max = 70.0
    var setup = false // For initial model rotation
    var shrunk = false // For angle text animation after recording
    var recording = false
    var readingsSum = 0.0 // Sum of angles read in current recording session
    var numReadings = 0 // Number of angles read in current recording session
    var successfulReadings = 0 // Number of angles read in current recording session within the ideal range
    
    
    @IBOutlet weak var torsoArms: UIImageView!
    @IBOutlet weak var visualizer: UIImageView!
    @IBOutlet weak var currentAngle: UILabel!
    @IBOutlet weak var currentAngleLabel: UILabel!
    @IBOutlet weak var avgAngle: UILabel!
    @IBOutlet weak var avgAngleLabel: UILabel!
    @IBOutlet weak var timeGreen: UILabel!
    @IBOutlet weak var timeGreenLabel: UILabel!
    
    @IBOutlet weak var recordButtonObject: UIButton!
    
    // Upon the main screen loading
    override func viewDidLoad() {
        // Called in case a superclass also overrides this method
        super.viewDidLoad()
        
        // Prevent phone from sleeping while app view is loaded
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Initialize the bluetooth manager
        manager = CBCentralManager(delegate: self, queue: nil);
        
        customiseNavigationBar()
        // Add torso to UI in rendering mode so it can change color
        let image:UIImage = UIImage(named: "Torso.png")!
        let templateImage = image.withRenderingMode(.alwaysTemplate)
        visualizer.image = templateImage
        // Make the torso grey until connected to jacket via bluetooth
        visualizer.tintColor = UIColor(hue: 0, saturation: 0, brightness: 0.33, alpha: 1.0) /* #434343 */
        // Set the default rotation of the torso to whatever the minimum ideal range value is
        rotate(degrees: CGFloat(truncating: NSNumber(value: min)))
        // Hide the record button and readouts until connected to jacket via bluetooth
        recordButtonObject.isHidden = true
        avgAngle.isHidden = true
        avgAngleLabel.isHidden = true
        timeGreen.isHidden = true
        timeGreenLabel.isHidden = true
        // Adjust the size of the currentAngle label on the UI to avoid blurriness
        var t1 = CGAffineTransform.identity
        t1 = t1.translatedBy(x: 0.0, y: 20.0)
        var t2 = CGAffineTransform.identity
        t2 = t2.translatedBy(x: 0.0, y: 40.0)
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
            self.currentAngleLabel.transform = t1
        })
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
            self.currentAngle.transform = t2
        })
    }
    
    func customiseNavigationBar () {
        // Declare a button to go in the nav bar (scan/disconnect)
        self.navigationItem.rightBarButtonItem = nil
        // Initialize the button
        let rightButton = UIButton()
        // If there is no connected bluetooth device
        if (mainPeripheral == nil) {
            // Make the button say "Scan"
            rightButton.setTitle("SCAN", for: [])
            rightButton.setTitleColor(UIColor.darkGray, for: [])
            rightButton.titleLabel?.font =  UIFont(name: "Futura-Bold", size: 16)
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else { // There is a connected bluetooth device
            // Make the button say "Disconnect"
            rightButton.setTitle("DISCONNECT", for: [])
            rightButton.setTitleColor(UIColor.darkGray, for: [])
            rightButton.titleLabel?.font =  UIFont(name: "Futura-Bold", size: 16)
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        // Declare the UI element for the button
        let rightBarButton = UIBarButtonItem()
        // Initialize it with the button just created
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        // Add the logo to the nav bar
        let imageView = UIImageView(image: UIImage(named: "LogoVectorLarge"))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 38, height: 38))
        imageView.frame = titleView.bounds
        titleView.addSubview(imageView)

        self.navigationItem.titleView = titleView
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Setup for transition to the bluetooth scan screen
        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController
            
            // Set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    @objc func scanButtonPressed() {
        // Switch views to the bluetooth scan screen
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    @objc func disconnectButtonPressed() {
        // Reset setup so default back angle will be reset on next connection
        setup = false
        // Reset torso angle to min degrees with smooth rotation
        let resetRad = CGFloat(min) / 180.0 * CGFloat.pi
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: { () -> Void in
            self.visualizer.transform = CGAffineTransform(rotationAngle: resetRad)
        })
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: { () -> Void in
            self.torsoArms.transform = CGAffineTransform(rotationAngle: resetRad)
        })
        // Reset torso to grey while not connected
        visualizer.tintColor = UIColor(hue: 0, saturation: 0, brightness: 0.33, alpha: 1.0) /* #434343 */
        // Hide record button while not connected
        recordButtonObject.isHidden = true // TODO: try 'recordButtonObject.tintColor = UIColor.lightGray' instead of hiding
        // Reset angle to "..."
        currentAngle.text = "..."
        // Reset and hide avgAngle and timeGreen on disconnect
        avgAngle.text = "..."
        timeGreen.text = "..."
        avgAngle.isHidden = true
        avgAngleLabel.isHidden = true
        timeGreen.isHidden = true
        timeGreenLabel.isHidden = true
        // Reset all record values (in case of disconnect while recording)
        self.numReadings = 0
        self.readingsSum = 0.0
        self.successfulReadings = 0
        recording = false
        // Reset currentAngle label to take up more screen space
        if(shrunk){
            var t1 = CGAffineTransform.identity
            t1 = t1.scaledBy(x: 1.0, y: 1.0)
            t1 = t1.translatedBy(x: 0.0, y: 20.0)
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                self.currentAngleLabel.transform = t1
            })
            var t2 = CGAffineTransform.identity
            t2 = t2.scaledBy(x: 1.0, y: 1.0)
            t2 = t2.translatedBy(x: 0.0, y: 40.0)
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                self.currentAngle.transform = t2
            })
            shrunk = false
        }
        
        // This will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }
    
    @objc func recordButton(_ sender: UIButton) {
        if(!recording){ // User pressed button to start recording
            recording = true
            // Make the record button red
            sender.tintColor = redColor
            // Reset the data readout labels
            avgAngle.text = "..."
            timeGreen.text = "..."
            // Hide the data readout labels if they're visible
            avgAngle.isHidden = true
            avgAngleLabel.isHidden = true
            timeGreen.isHidden = true
            timeGreenLabel.isHidden = true
            // Make the currentAngle label take up more screen
            if(shrunk){
                var t1 = CGAffineTransform.identity
                t1 = t1.scaledBy(x: 1.0, y: 1.0)
                t1 = t1.translatedBy(x: 0.0, y: 20.0)
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                    self.currentAngleLabel.transform = t1
                })
                var t2 = CGAffineTransform.identity
                t2 = t2.scaledBy(x: 1.0, y: 1.0)
                t2 = t2.translatedBy(x: 0.0, y: 40.0)
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                    self.currentAngle.transform = t2
                })
                shrunk = false
            }
        }else{ // User pressed button to stop recording
            recording = false
            // Make the currentAngle label take up less screen to make space for the data readout labels
            var t1 = CGAffineTransform.identity
            t1 = t1.scaledBy(x: 0.4, y: 0.4)
            t1 = t1.translatedBy(x: 0.0, y: -20.0)
            var t2 = CGAffineTransform.identity
            t2 = t2.scaledBy(x: 0.4, y: 0.4)
            t2 = t2.translatedBy(x: 0.0, y: -30.0)
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                self.currentAngleLabel.transform = t1
            })
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { () -> Void in
                self.currentAngle.transform = t2
            })
            shrunk = true
            // Make the data readout labels visible
            avgAngle.isHidden = false
            avgAngleLabel.isHidden = false
            timeGreen.isHidden = false
            timeGreenLabel.isHidden = false
            // Change the record button back to grey
            sender.tintColor = UIColor.darkGray
            // Calculate average tilt for that record session
            var avgTilt = 0.0
            if(numReadings != 0){
                avgTilt = readingsSum/Double(numReadings)
            }
            avgTilt = Double(round(100*avgTilt)/100)
            let avgTiltText = String(avgTilt) + "°"
            // Update the average tilt data readout
            self.avgAngle.text = avgTiltText
            // Calculate the percentage of successful readings
            var avgSuccess = 0.0
            if(numReadings != 0){
                avgSuccess = Double(successfulReadings)/Double(numReadings)
            }
            avgSuccess = Double(round(100*avgSuccess))
            let avgSuccessText = String(avgSuccess) + "%"
            // Update the average successes data readout
            self.timeGreen.text = avgSuccessText
            // Reset recording data for next recording session
            self.numReadings = 0
            self.readingsSum = 0.0
            self.successfulReadings = 0
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
            
            // Device information service
            if (service.uuid.uuidString == "180A") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            // GAP (Generic Access Profile) for Device Name
            // This replaces the deprecated CBUUIDGenericAccessProfileString
            if (service.uuid.uuidString == "1800") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            // Arduino bluetooth device Service
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Get device name
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
                    // We'll save the reference, we need it to write data
                    mainCharacteristic = characteristic
                    // Set Notify is useful to read incoming data async
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Found Arduino Data Characteristic")
                    // Make the graphic red
                    visualizer.tintColor = redColor
                    // Make the record button visible
                    recordButtonObject.isHidden = false
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
                // Read value from bluetooth and convert it to string
                let tempVal = characteristic.value!
                let stringValue = String(data: tempVal, encoding: String.Encoding.utf8)!
                // Split it into change in degrees and current degree measurements
                let dataArr = stringValue.components(separatedBy: [","]).filter({!$0.isEmpty})
                let changeString: String = dataArr[0]
                let degString: String = dataArr[1]
                // Update currentAngle label on app main view
                currentAngle.text = degString
                guard let change = NumberFormatter().number(from: changeString) else { return }
                guard let deg = NumberFormatter().number(from: degString) else { return }
                
                /* Code to limit forward lean to 30 deg so model doesn't lean off the screen
                if(Int(truncating: deg) < 30){
                    deg = 30
                }*/
                
                // Convert change to radians.
                let rad = CGFloat(truncating: change) * CGFloat.pi / 180
                // If this is the first reading from the accelerometer
                if(!setup){
                    // Adjust the model to start at whatever angle the accelerometer is currently at
                    let setRad = CGFloat(truncating: deg) / 180.0 * CGFloat.pi
                    UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: { () -> Void in
                        self.visualizer.transform = CGAffineTransform(rotationAngle: setRad)
                    })
                    UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: { () -> Void in
                        self.torsoArms.transform = CGAffineTransform(rotationAngle: setRad)
                    })
                    setup = true
                }else{
                    // Animate the model rotating by however many degrees the accelerometer has changed since its last reading
                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveLinear, animations: { () -> Void in
                        self.visualizer.transform = self.visualizer.transform.rotated(by: rad)
                    })
                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveLinear, animations: { () -> Void in
                        self.torsoArms.transform = self.torsoArms.transform.rotated(by: rad)
                    })
                }
                
                // Count this data as part of the current recording session if the user has hit record
                if(recording){
                    readingsSum += Double(truncating: deg)
                    numReadings += 1
                }
                
                // Update the torso color to either green or red based on whether or not the user is within the ideal leaning range
                if(Double(truncating: deg) > min && Double(truncating: deg) < max){
                    visualizer.tintColor = greenColor
                    if(recording){
                        successfulReadings += 1
                    }
                } else {
                    visualizer.tintColor = redColor
                }
            }
        }
        
        
    }
    
    func rotate(degrees: CGFloat){
        // https://stackoverflow.com/a/58046326/
        let degreesToRadians: (CGFloat) -> CGFloat = { (degrees: CGFloat) in
            return degrees / 180.0 * CGFloat.pi
        }
        visualizer.transform =  CGAffineTransform(rotationAngle: degreesToRadians(degrees))
        torsoArms.transform =  CGAffineTransform(rotationAngle: degreesToRadians(degrees))
    }
    
}

