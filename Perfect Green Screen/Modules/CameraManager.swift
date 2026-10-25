import UIKit
import AVFoundation

// Use the view's backing layer so UIKit resizes the preview with the pane itself.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didUpdatePixelBuffer buffer: CVPixelBuffer)
}

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CameraError: LocalizedError {
        case permissionDenied
        case unavailable
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Allow camera access in Settings to analyze your green screen."
            case .unavailable:
                return "A rear camera is required. Run the app on an iPhone or iPad to see the live preview."
            case .configurationFailed:
                return "The camera could not be configured. Close other apps using the camera and try again."
            }
        }
    }

    weak var delegate: CameraManagerDelegate?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isFocusLocked = false
    private(set) var isExposureLocked = false

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.indiefilmgear.perfectgreenscreen.camera")
    private let videoQueue = DispatchQueue(label: "com.indiefilmgear.perfectgreenscreen.frames")
    private var cameraDevice: AVCaptureDevice?
    private var isConfigured = false
    private var shouldRun = false

    func createPreviewLayer(for view: CameraPreviewView) -> AVCaptureVideoPreviewLayer {
        if let previewLayer = previewLayer { return previewLayer }
        let layer = view.previewLayer
        layer.session = captureSession
        layer.videoGravity = .resizeAspect
        previewLayer = layer
        return layer
    }

    func updatePreviewOrientation() {
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0 // The app supports landscape right.
        }
    }

    func startCamera(completion: @escaping (Result<Void, CameraError>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.shouldRun = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureAndStart(completion: completion)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self = self else { return }
                    self.sessionQueue.async {
                        guard self.shouldRun else { return }
                        if granted {
                            self.configureAndStart(completion: completion)
                        } else {
                            DispatchQueue.main.async { completion(.failure(.permissionDenied)) }
                        }
                    }
                }
            default:
                DispatchQueue.main.async { completion(.failure(.permissionDenied)) }
            }
        }
    }

    private func configureAndStart(completion: @escaping (Result<Void, CameraError>) -> Void) {
        do {
            if !isConfigured { try configureSession() }
            if shouldRun && !captureSession.isRunning { captureSession.startRunning() }
            DispatchQueue.main.async { completion(.success(())) }
        } catch {
            let cameraError = error as? CameraError ?? .configurationFailed
            DispatchQueue.main.async { completion(.failure(cameraError)) }
        }
    }

    private func configureSession() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        if captureSession.canSetSessionPreset(.vga640x480) { captureSession.sessionPreset = .vga640x480 }
        guard captureSession.canAddInput(input) else { throw CameraError.configurationFailed }
        captureSession.addInput(input)
        guard captureSession.canAddOutput(output) else {
            captureSession.removeInput(input)
            throw CameraError.configurationFailed
        }
        captureSession.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }
        cameraDevice = device
        isConfigured = true
    }

    func stopCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.shouldRun = false
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
        }
    }

    func toggleFocusLock(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.cameraDevice else { return }
            let mode: AVCaptureDevice.FocusMode = device.focusMode == .locked ? .continuousAutoFocus : .locked
            guard device.isFocusModeSupported(mode) else { return }
            do {
                try device.lockForConfiguration()
                device.focusMode = mode
                device.unlockForConfiguration()
                let locked = mode == .locked
                DispatchQueue.main.async {
                    self.isFocusLocked = locked
                    completion()
                }
            } catch {
                print("Could not change focus: \(error.localizedDescription)")
            }
        }
    }

    func toggleExposureLock(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.cameraDevice else { return }
            let mode: AVCaptureDevice.ExposureMode = device.exposureMode == .locked ? .continuousAutoExposure : .locked
            guard device.isExposureModeSupported(mode) else { return }
            do {
                try device.lockForConfiguration()
                device.exposureMode = mode
                device.unlockForConfiguration()
                let locked = mode == .locked
                DispatchQueue.main.async {
                    self.isExposureLocked = locked
                    completion()
                }
            } catch {
                print("Could not change exposure: \(error.localizedDescription)")
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.cameraManager(self, didUpdatePixelBuffer: buffer)
    }
}
