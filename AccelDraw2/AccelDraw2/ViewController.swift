//
//  ViewController.swift
//  AccelDraw2
//
//  Created by Daniel Hauagge on 2/6/16.
//  Copyright © 2016 Daniel Hauagge. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    var session = CMMotionManager()
    
    var currPoint = CGPointMake(0, 0)
    
    var red = CGFloat(1)
    var green = CGFloat(0)
    var blue = CGFloat(0)
    var brushSize = CGFloat(5.0) // brush size
    
    var shouldClearDrawing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Device motion is a processed version of the data that the accelerometer
        // give us, it separatest the device acceleration into userAcceleration
        // and gravity.
        
        // session.deviceMotionUpdateInterval = 1
        // session.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue()) { (motion: CMDeviceMotion?, error: NSError?) -> Void in
        // print(motion?.userAcceleration)
        // }
        
        session.accelerometerUpdateInterval = 1.0/60.0 // seconds
        session.startAccelerometerUpdatesToQueue(
            NSOperationQueue.mainQueue()) {
                (data: CMAccelerometerData?, error: NSError?) in
                print(data?.acceleration)
                
                let accel = CGPoint(
                    x: data!.acceleration.x,
                    y: data!.acceleration.y
                )
                let s = CGFloat(5.0)
                let nextPoint = CGPointMake(
                    self.currPoint.x + s * accel.x,
                    self.currPoint.y + s * accel.y
                )
                
                // * * Prevent the cursor from going out of the screen
                if self.currPoint.x >= 0 && self.currPoint.x <= self.view.frame.size.width && self.currPoint.y >= 0 && self.currPoint.y <= self.view.frame.size.height {
                    
                    self.drawLine(
                        fromPoint: self.currPoint,
                        toPoint: nextPoint
                    )
                    
                    self.currPoint = nextPoint
                    
                }
                
                
        }
    }
    
    func drawLine(fromPoint a: CGPoint, toPoint b:CGPoint) {
        UIGraphicsBeginImageContext(self.imageView.frame.size)
        
        let context = UIGraphicsGetCurrentContext()
        
        // if true {
        //    // without bug
        //    self.imageView.image?.drawInRect(CGRectMake(0, 0,
        //        self.view.frame.size.width,
        //        self.view.frame.size.height))
        // } else {
        //    // with bug
        //    self.imageView.image?.drawInRect(self.imageView.frame)
        // }

        print(self.imageView.frame)
        if !shouldClearDrawing {
            self.imageView.image?.drawInRect(
                CGRectMake(0, 0,
                    self.imageView.frame.size.width,
                    self.imageView.frame.size.height))
        }
        shouldClearDrawing = false

        let origin = CGPointMake(
            self.imageView.frame.origin.x + self.imageView.frame.size.width/2.0,
            self.imageView.frame.origin.y + self.imageView.frame.size.height/2.0
        )
        
        // Draw line
        CGContextMoveToPoint(context, a.x + origin.x, a.y + origin.y)
        CGContextAddLineToPoint(context, b.x + origin.x, b.y + origin.y)
        
        // Set line params
        CGContextSetLineWidth(context, brushSize)
        CGContextSetRGBStrokeColor(context, red, green, blue, 1.0)
        CGContextSetLineCap(context, .Round)
        
        // Render the drawing
        CGContextStrokePath(context)
        
        // Put the newly rendered image into the image view
        self.imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        
        // End the graphics context
        UIGraphicsEndImageContext()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let settingsView = segue.destinationViewController as! SettingsViewController
        
        // Let the settings view know of the current brush color
        settingsView.red = red
        settingsView.green = green
        settingsView.blue = blue
        settingsView.brushSize = brushSize
        
        // Give the settings view a reference to this view, so that it can
        // inform this view of the final color chosen by the user.
        settingsView.delegate = self
    }
    
    @IBAction func clearButtonPressed(sender: UIButton) {
        shouldClearDrawing = true
        currPoint = CGPointMake(0, 0)
    }
}

extension ViewController : SettingsViewControllerDelegate {
    func finalChosenSettings(red : CGFloat, green : CGFloat, blue : CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

