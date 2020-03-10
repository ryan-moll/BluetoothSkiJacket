//Service UUID:
//0000ffe0-0000-1000-8000-00805f9b34fb

//Characteristic UUID (Readable, Writable, Notifications):
//0000ffe1-0000-1000-8000-00805f9b34fb

#include <SoftwareSerial.h>
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_LIS3DH.h>
#include <Adafruit_Sensor.h>

// PIN 7 = BT TX; PIN 2 = BT RX
SoftwareSerial BT(7,2);

Adafruit_LIS3DH lis = Adafruit_LIS3DH();

float previousAngle;

void setup(void) {
    delay(1000);
    Serial.println("Setting up Arduino...");
    Serial.begin(9600);
    while (!Serial) delay(10);     // will pause Zero, Leonardo, etc until serial console opens
    Serial.println("Serial started.");
    BT.begin(9600);
    Serial.println("Bluetooth started.");
  
    if (! lis.begin(0x18)) {   // change this to 0x19 for alternative i2c address
        Serial.println("Couldn't find LISD3H (accelerometer). Quitting...");
        while (1) yield();
    }
    Serial.println("LIS3DH (accelerometer) found.");
  
    lis.setRange(LIS3DH_RANGE_4_G);   // 2, 4, 8 or 16 G
    Serial.print("Set range: "); 
    Serial.print(2 << lis.getRange());  
    Serial.println("G");
    previousAngle = 0.0;
    Serial.println("Setup complete.");
}

void loop() {
    lis.read();      // get X Y and Z data at once

    /* Print out the raw data
    Serial.print("X:  "); Serial.print(lis.x); 
    Serial.print("  \tY:  "); Serial.print(lis.y); 
    Serial.print("  \tZ:  "); Serial.print(lis.z); */

    // Get a new sensor event, normalized
    sensors_event_t event; 
    lis.getEvent(&event);
    float xTilt = event.acceleration.x;
    float deg = abs(xTilt * 9.0);
    float change = deg - previousAngle;

    /* Display the results (acceleration is measured in m/s^2)
    Serial.print("\t\tX: "); Serial.print(event.acceleration.x);
    Serial.print(" \tY: "); Serial.print(event.acceleration.y); 
    Serial.print(" \tZ: "); Serial.print(event.acceleration.z); 
    Serial.println(" m/s^2 "); */

    String data = String(change);
    data += ",";
    data += deg;
    Serial.println(data);
    BT.print(data);
    previousAngle = deg;
    
    //delay(10);
    delay(200);
}
