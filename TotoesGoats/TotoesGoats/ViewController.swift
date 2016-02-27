//
//  ViewController.swift
//  TotoesGoats
//
//  Created by Daniel Hauagge on 2/20/16.
//  Copyright © 2016 Daniel Hauagge. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    var captureDevice : AVCaptureDevice?

    // switch front and back camera
    var isSwitchProcessing = false
    @IBAction func switchCameraButton(sender: UIButton) {
        print("switch cam pressed")
        isSwitchProcessing = !isSwitchProcessing
        reloadCamera()

    }
    
    
    @IBOutlet weak var switchCamOutlet: UIButton!
    
    
    // switch face detection and filter
    var isFaceOrFilter = false
    @IBOutlet weak var faceFilterSwitch: UIButton!
    @IBAction func faceFilterSwitchButton(sender: UIButton) {
        // Filter
        isFaceOrFilter = !isFaceOrFilter
        // Face 
        
        // Do i need to call the output function here???
    }
    
    
    @IBOutlet weak var button: UIButton!
    @IBAction func buttonClicked(sender: AnyObject) {
        isProcessing = !isProcessing
        
        if isProcessing {
            processedLayer.hidden = false
            processedLayer.backgroundColor = nil // sets layer to be transparent, so we can see the video feed being shown in the preview layer
            previewLayer.hidden = false
            button.backgroundColor = UIColor.greenColor()
        } else {
            processedLayer.hidden = true
            previewLayer.hidden = false
            button.backgroundColor = UIColor.redColor()
        }
    }
    
    var session = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer!
    var processedLayer : CALayer!
    
    var isProcessing = false
    var frameNo = 0
    
    var faceDetector = CIDetector(ofType: CIDetectorTypeFace,
        context: nil, options: [
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            CIDetectorTracking: true
        ])
    
    lazy var goatFace : UIImage! = {
        var path = NSBundle.mainBundle().pathForResource("goat2", ofType: "png")!
        return UIImage(contentsOfFile: path)
    }()
    
    override func viewDidLoad() { //WHAT IS NIB???
        super.viewDidLoad()
        
        // Test on camera
        reloadCamera()
        
        // Get all devices on my phone
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        
        let device = devices.first!
        //        let device = devices.filter({ (dev) -> Bool in
        //            dev.position == .Front
        //        }).first!
        
        // Selecting the front facing camera
        // let x = devices.filter { (dev) -> Bool in
        //    dev.position == .Front
        // }
        // let device = devices.filter({ $0.position == .Front }).first!
        
        let input = try! AVCaptureDeviceInput(device: device)
        //        do {
        //            input =AVCaptureDeviceInput(device: device)
        //        } catch {
        //            assert(false)
        //        }
        
        assert(session.canAddInput(input))
        session.addInput(input)
        
        // Create preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = self.view.bounds
        self.view.layer.addSublayer(previewLayer)
        
        // Create processed video layer
        processedLayer = CALayer()
        processedLayer.frame = self.view.bounds
        processedLayer.hidden = true
        processedLayer.backgroundColor = UIColor.redColor().CGColor // <- Just for debugging
        self.view.layer.addSublayer(processedLayer)
        
        // Create data output
        let frameProcessingQueue = dispatch_queue_create("goatface.frameprocessing", DISPATCH_QUEUE_SERIAL);
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) ]
        output.setSampleBufferDelegate(self, queue: frameProcessingQueue)
        assert(session.canAddOutput(output))
        session.addOutput(output)
        
        // Button
        self.view.bringSubviewToFront(button)
        self.view.bringSubviewToFront(switchCamOutlet)
        self.view.bringSubviewToFront(faceFilterSwitch)
        button.layer.cornerRadius = button.frame.width / 2.0
        
        // Start actually capturing
        session.startRunning()
    }

    func hackFixOrientation(img: UIImage) -> CGImageRef {
        let debug = CIImage(CGImage: img.CGImage!).imageByApplyingOrientation(6)
        let context = CIContext()
        let fixedImg = context.createCGImage(debug, fromRect: debug.extent)
        return fixedImg
    }
    
    func detectFaces(imageBuffer : CVImageBufferRef) {
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let ciImage = CIImage(CVImageBuffer: imageBuffer)
        let faces = faceDetector.featuresInImage(ciImage,
            options:[CIDetectorImageOrientation: 6]) as! [CIFaceFeature]

        print("\(faces.count) faces detected")

        // Draw rectangles on detected faces
        UIGraphicsBeginImageContext(ciImage.extent.size)
        let context = UIGraphicsGetCurrentContext()
        
        // Set line properties color and width
        CGContextSetLineWidth(context, 30)
        CGContextSetStrokeColorWithColor(context, UIColor.redColor().CGColor)
        
        // Transform that flips the Y axis
        var T = CGAffineTransformIdentity
        T = CGAffineTransformScale(T, 1, -1)
        T = CGAffineTransformTranslate(T, 0, -CGFloat(height))
        
        for face in faces {
            let faceLoc = CGRectApplyAffineTransform(face.bounds, T)
            CGContextAddEllipseInRect(context, faceLoc)
            
            CGContextDrawImage(context, faceLoc, goatFace.CGImage)
        }
        
        CGContextStrokePath(context)
        
        let drawnFaces = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
        
        // Send to main queue to update UI
        dispatch_async(dispatch_get_main_queue()) {
            self.processedLayer.contents = self.hackFixOrientation(drawnFaces)
        }

    }
    
    func colorFilter(imageBuffer : CVImageBufferRef) {
        CVPixelBufferLockBaseAddress(imageBuffer, 0)

        var pixels = UnsafeMutablePointer<UInt8>(CVPixelBufferGetBaseAddress(imageBuffer))
        // pixels are stored as (blue, green, red, alpha), one byte per channel
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        let blueValue = UInt8((1.0 + sin(Double(frameNo) / 10.0)) * 0.5 * 255)
        
        for _ in 0 ..< height {
            var idx = 0
            for _ in 0 ..< width {
                pixels[idx    ] = blueValue  // Blue
                //pixels[idx + 1] = 0  // Green
                //pixels[idx + 2] = 0  // Red
                //pixels[idx + 3] = 0  // Alpha
                idx += 4
            }
            pixels += bytesPerRow
        }
        
        // Create an image with this buffer
        let context = CIContext()
        let ciImage = CIImage(CVImageBuffer: imageBuffer).imageByApplyingOrientation(6)
        let cgImage = context.createCGImage(ciImage, fromRect: ciImage.extent)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
        
        // Send to main queue to update UI
        dispatch_async(dispatch_get_main_queue()) {
            self.processedLayer.contents = cgImage
        }
    }
    
    // Method that receives the frame buffers
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if(isProcessing) {
            guard let frameBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            // let frameBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            // if frameBuffer == nil {
            //     return
            // }
            
            // To face
            if isFaceOrFilter {
                faceFilterSwitch.setTitle("Filter", forState: .Normal)
                detectFaces(frameBuffer)
            }
                // To filter
            else {
                faceFilterSwitch.setTitle("Face Detection", forState: .Normal)
                colorFilter(frameBuffer)
            }
            
            frameNo += 1
        }
    }
    
    // switch front and back camera
    func reloadCamera() {
        let devices = AVCaptureDevice.devices()
        
        if isSwitchProcessing {
            
            
            
            for device in devices {
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    if (device.position == AVCaptureDevicePosition.Front) {
                        captureDevice = device as? AVCaptureDevice
                        print("captureDevice = \(captureDevice)")
                        
                    }
                }
            }
            
            switchCamOutlet.setTitle("Front", forState: .Normal)
            switchCamOutlet.backgroundColor = UIColor.greenColor()
        } else {
            
            for device in devices {
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    if (device.position == AVCaptureDevicePosition.Back) {
                        captureDevice = device as? AVCaptureDevice
                        print("captureDevice = \(captureDevice)")
                        
                    }
                }
            }
            
            switchCamOutlet.setTitle("Back", forState: .Normal)
            switchCamOutlet.backgroundColor = UIColor.redColor()
        }
    }
    

}

