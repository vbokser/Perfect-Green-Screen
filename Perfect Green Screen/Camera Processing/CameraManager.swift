import UIKit
import AVFoundation

// Protocol for camera manager delegates to receive camera events
protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didReceiveFrame image: UIImage?)
    func cameraManager(_ manager: CameraManager, didUpdatePixelBuffer buffer: CVPixelBuffer)
}

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Public properties
    weak var delegate: CameraManagerDelegate?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Camera state
    private var captureSession: AVCaptureSession!
    private var cameraDevice: AVCaptureDevice?
    
    // Camera settings
    private(set) var isFocusLocked: Bool = false
    private(set) var isExposureLocked: Bool = false
    
    // Available camera properties
    var availableCameras: [AVCaptureDevice] {
        let videoDeviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video,
            position: .unspecified
        )
        return videoDeviceDiscovery.devices
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        captureSession = AVCaptureSession()
    }
    
    // MARK: - Camera Setup
    
    func setupCamera(with resolution: AVCaptureSession.Preset = .vga640x480, position: AVCaptureDevice.Position = .back) {
        // Stop any existing session
        if captureSession.isRunning {
            stopCamera()
        }
        
        captureSession.sessionPreset = resolution
        
        // Select camera device
        let videoDeviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        
        for camera in videoDeviceDiscovery.devices {
            if camera.position == position {
                cameraDevice = camera
                break
            }
        }
        
        guard cameraDevice != nil else {
            print("Error: Could not find camera")
            return
        }
        
        // Connect camera to session
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            }
        } catch {
            print("Error: Could not add camera as input: \(error)")
            return
        }
        
        // Configure video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoOutputQueue = DispatchQueue(label: "VideoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Error: Could not add video data as output")
        }
    }
    
    // MARK: - Preview Layer
    
    func createPreviewLayer(for view: UIView) -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = view.bounds
        
        if (previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
        
        self.previewLayer = previewLayer
        return previewLayer
    }
    
    // MARK: - Camera Control
    
    func startCamera() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    func stopCamera() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func toggleFocusLock() -> Bool {
        guard let device = cameraDevice else { return false }
        
        do {
            try device.lockForConfiguration()
            
            isFocusLocked = !isFocusLocked
            
            if isFocusLocked {
                device.focusMode = .locked
            } else {
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }
            
            device.unlockForConfiguration()
            return true
            
        } catch {
            print("Error: Could not lock camera for configuration: \(error)")
            return false
        }
    }
    
    func toggleExposureLock() -> Bool {
        guard let device = cameraDevice else { return false }
        
        do {
            try device.lockForConfiguration()
            
            isExposureLocked = !isExposureLocked
            
            if isExposureLocked {
                device.exposureMode = .locked
            } else {
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
            
            device.unlockForConfiguration()
            return true
            
        } catch {
            print("Error: Could not lock camera for configuration: \(error)")
            return false
        }
    }
    
    // MARK: - Camera Info
    
    func printCameraDetails() {
        print("Available cameras:")
        
        for camera in availableCameras {
            print("- \(camera.localizedName) (\(camera.position == .back ? "Back" : "Front"))")
            print("  • Supports: Focus \(camera.isFocusModeSupported(.continuousAutoFocus) ? "✓" : "✗")")
            print("  • Supports: Exposure \(camera.isExposureModeSupported(.continuousAutoExposure) ? "✓" : "✗")")
            print("  • Supports: Flash \(camera.hasFlash ? "✓" : "✗")")
            print("  • Supports: Torch \(camera.hasTorch ? "✓" : "✗")")
            print("  • Min/Max Zoom: \(camera.minAvailableVideoZoomFactor)/\(camera.maxAvailableVideoZoomFactor)")
            
            if camera.formats.count > 0 {
                print("  • Supported resolutions:")
                for format in camera.formats {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    print("    - \(dimensions.width)×\(dimensions.height)")
                }
            }
        }
        
        print("\nSupported session presets:")
        let presets: [AVCaptureSession.Preset] = [.photo, .high, .medium, .low, .vga640x480, .hd1280x720, .hd1920x1080, .hd4K3840x2160]
        for preset in presets {
            print("- \(preset.rawValue): \(captureSession.canSetSessionPreset(preset) ? "✓" : "✗")")
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Notify delegate about the new frame
        delegate?.cameraManager(self, didUpdatePixelBuffer: imageBuffer)
        
        // Create a simple UIImage from the buffer (unprocessed)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let image = UIImage(cgImage: cgImage)
            delegate?.cameraManager(self, didReceiveFrame: image)
        }
    }
} 