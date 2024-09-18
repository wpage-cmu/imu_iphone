//
//  ViewController.swift
//  test
//
//  Created by Justin Kwok Lam CHAN on 4/4/21.
//

import DGCharts
import UIKit
import CoreMotion

class ViewController: UIViewController, ChartViewDelegate {
    
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var label: UILabel!
    
    var ts: Double = 0
    var magnitudeBuffer: [Double] = []
    let bufferSize = 10
    //var dcBias: Double = 0.0
    
    var previousMagnitude: Double = 0.0
    var filteredMagnitude: Double = 0.0
    let alpha: Double = 0.5  // Low-pass filter constant (can be tuned)
    
    var stepCount = 0
    var threshold: Double = 1.1  // Set this based on your testing
    var previousMovingAverage: Double = 0.0
    var lastStepTimestamp: TimeInterval = 0.0
    let stepDebounce: TimeInterval = 0.3  // 400 ms debounce

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.lineChartView.delegate = self
        
        let set_a: LineChartDataSet = LineChartDataSet(entries: [ChartDataEntry](), label: "x")
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.blue)
        
        let set_b: LineChartDataSet = LineChartDataSet(entries: [ChartDataEntry](), label: "y")
        set_b.drawCirclesEnabled = false
        set_b.setColor(UIColor.red)
        
        let set_c: LineChartDataSet = LineChartDataSet(entries: [ChartDataEntry](), label: "z")
        set_c.drawCirclesEnabled = false
        set_c.setColor(UIColor.green)
        self.lineChartView.data = LineChartData(dataSets: [set_a,set_b,set_c])
    }
    
    @IBAction func startSensors(_ sender: Any) {
        ts=NSDate().timeIntervalSince1970
        label.text=String(format: "%f", ts)
        startAccelerometers()
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }
    
    @IBAction func stopSensors(_ sender: Any) {
        stopAccels()
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    let motion = CMMotionManager()
    var counter:Double = 0
    
    var timer_accel:Timer?
    var accel_file_url:URL?
    var accel_fileHandle:FileHandle?
    
    let xrange:Double = 500
    
    func startAccelerometers() {
       // Make sure the accelerometer hardware is available.
       if self.motion.isAccelerometerAvailable {
        // sampling rate can usually go up to at least 100 hz
        // if you set it beyond hardware capabilities, phone will use max rate
          self.motion.accelerometerUpdateInterval = 1.0 / 60.0  // 60 Hz
          self.motion.startAccelerometerUpdates()
        
        // create the data file we want to write to
        // initialize file with header line
        do {
            // get timestamp in epoch time
            let file = "accel_file_\(ts).txt"
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                accel_file_url = dir.appendingPathComponent(file)
            }
            
            // write first line of file
            try "ts,x,y,z\n".write(to: accel_file_url!, atomically: true, encoding: String.Encoding.utf8)

            accel_fileHandle = try FileHandle(forWritingTo: accel_file_url!)
            accel_fileHandle!.seekToEndOfFile()
        } catch {
            print("Error writing to file \(error)")
        }
        
          // Configure a timer to fetch the data.
          self.timer_accel = Timer(fire: Date(), interval: (1.0/60.0),
                                   repeats: true, block: { [self] (timer) in
             // Get the accelerometer data.
             if let data = self.motion.accelerometerData {
                let x = data.acceleration.x
                let y = data.acceleration.y
                let z = data.acceleration.z
                
                let timestamp = NSDate().timeIntervalSince1970
                let text = "\(timestamp), \(x), \(y), \(z)\n"
                print ("A: \(text)")
                
                 
                 // Calculate magnitude
                 let magnitude = sqrt(x * x + y * y + z * z)
                 
                 // Apply low-pass filter
                 filteredMagnitude = magnitude * (1 - alpha) + previousMagnitude * alpha
                 previousMagnitude = filteredMagnitude
                 
                 // Update buffer
                 if magnitudeBuffer.count >= bufferSize {
                     magnitudeBuffer.removeFirst()  // Remove the oldest value
                 }
                 magnitudeBuffer.append(filteredMagnitude)  // Use filtered magnitude for moving average
                 
                 // Calculate moving average
                 var movingAverage: Double = 0.0
                 if magnitudeBuffer.count == bufferSize {
                     movingAverage = magnitudeBuffer.reduce(0, +) / Double(bufferSize)
                 } else {
                     movingAverage = magnitudeBuffer.reduce(0, +) / Double(magnitudeBuffer.count)
                 }
                 
                 DispatchQueue.main.async {
                     self.label.text = "Steps: \(self.stepCount)"
                 }
                 
                 // Step detection
                 let currentTime = NSDate().timeIntervalSince1970
                 //let adaptiveThreshold = max(threshold, movingAverage * 1)  // Increase threshold dynamically
                 
                 
                 print("Moving Average: \(movingAverage), Threshold: \(threshold)")

                 if movingAverage > threshold {
                     print("Moving average exceeded threshold.")
                     
                     if previousMovingAverage < movingAverage {
                         print("Previous moving average was lower.")
                         
                         if currentTime - lastStepTimestamp > stepDebounce {
                             print("Debounce condition met.")
                             stepCount += 1
                             lastStepTimestamp = currentTime
                             print("Step detected: \(stepCount)")
                         } else {
                             print("Debounce condition NOT met.")
                         }
                     } else {
                         print("Previous moving average was not lower.")
                     }
                 } else {
                     print("Moving average did not exceed threshold.")
                 }
                 if movingAverage > threshold && previousMovingAverage < movingAverage {
                     if currentTime - lastStepTimestamp > stepDebounce {
                         
                         
                         stepCount += 1
                         lastStepTimestamp = currentTime
                         
                         DispatchQueue.main.async {
                             self.label.text = "Steps: \(self.stepCount)"
                         }
                         
                         print("Step detected: \(stepCount)")
                     }
                 }
                 previousMovingAverage = movingAverage
        
                self.accel_fileHandle!.write(text.data(using: .utf8)!)
                 
                  self.lineChartView.data?.appendEntry(ChartDataEntry(x: Double(counter), y: x), toDataSet: ChartData.Index(0))
                 self.lineChartView.data?.appendEntry(ChartDataEntry(x: Double(counter), y: y), toDataSet: ChartData.Index(1))
                 self.lineChartView.data?.appendEntry(ChartDataEntry(x: Double(counter), y: z), toDataSet: ChartData.Index(2))
                
                // refreshes the data in the graph
                self.lineChartView.notifyDataSetChanged()
                  
                self.counter = self.counter+1
                
                // needs to come up after notifyDataSetChanged()
                if counter < xrange {
                    self.lineChartView.setVisibleXRange(minXRange: 0, maxXRange: xrange)
                }
                else {
                    self.lineChartView.setVisibleXRange(minXRange: counter, maxXRange: counter+xrange)
                }
             }
          })

          // Add the timer to the current run loop.
        RunLoop.current.add(self.timer_accel!, forMode: RunLoop.Mode.default)
       }
    }
    
    func stopAccels() {
       if self.timer_accel != nil {
          self.timer_accel?.invalidate()
          self.timer_accel = nil

          self.motion.stopAccelerometerUpdates()
        
           accel_fileHandle!.closeFile()
       }
    }
}

