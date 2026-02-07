import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var isRunning = false
    @Published var error: String?
    private var frameCount: Int = 0
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.output.queue")
    
    // Optimizations
    private let context = CIContext()
    private let frameSampleRate = 3 // Every 3rd frame ~10 FPS
    
    var onFrameCaptured: ((UIImage) -> Void)?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        
        // FIX 1: Begin configuration block
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = "No camera available"
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput?.setSampleBufferDelegate(self, queue: outputQueue)
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            
            if let output = videoOutput, session.canAddOutput(output) {
                session.addOutput(output)
                
                // FIX 3: Use videoOrientation instead of videoRotationAngle
                if let connection = output.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
        } catch {
            self.error = "Failed to setup camera: \(error.localizedDescription)"
        }
        
        // FIX 1: Commit configuration block
        session.commitConfiguration()
    }
    
    func start() {
        print("📷 CameraService.start() called")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 Camera authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("📷 Camera authorized, starting session")
            startSession()
        case .notDetermined:
            print("📷 Camera not determined, requesting access")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("📷 Camera access response: \(granted)")
                if granted {
                    self?.startSession()
                } else {
                    DispatchQueue.main.async {
                        self?.error = "Camera access denied. Please enable in Settings."
                    }
                }
            }
        case .denied, .restricted:
            print("📷 Camera denied/restricted")
            DispatchQueue.main.async { [weak self] in
                self?.error = "Camera access denied. Please enable in Settings."
            }
        @unknown default:
            print("📷 Unknown camera status")
            break
        }
    }
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.error = nil
                print("📷 Camera session is now running")
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession, session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    func captureCurrentFrame() -> Data? {
        guard let image = currentFrame else { return nil }
        return image.jpegData(compressionQuality: 0.7)
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // FIX 2: Increment frameCount once at the top, no race condition
        frameCount += 1
        
        guard frameCount % frameSampleRate == 0 else { return }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
            self?.onFrameCaptured?(image)
        }
    }
}
