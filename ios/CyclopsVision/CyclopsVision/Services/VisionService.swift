import Foundation
import UIKit
import Vision

/// Monitoring status from VLM
enum MonitoringStatus: Equatable {
    case idle               // Not started
    case monitoring         // Actively watching user
    case checking           // VLM call in progress
    case complete           // Step verified complete
    case mistake(String)    // Error detected, show feedback
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .monitoring:
            return "Watching..."
        case .checking:
            return "Checking..."
        case .complete:
            return "Perfect! ✓"
        case .mistake(let reason):
            return reason
        }
    }
}

/// VisionService - Continuous VLM-based step monitoring
/// Polls VLM every few seconds to check step status
@MainActor
class VisionService: ObservableObject {
    // MARK: - Published State
    @Published var currentStepIndex: Int = 0
    @Published var monitoringStatus: MonitoringStatus = .idle
    @Published var isProcessing = false
    
    // For UI: show body pose overlay
    @Published var currentBodyPose: VNHumanBodyPoseObservation?
    
    // Legacy compatibility
    @Published var stepConfidence: Double = 0.0
    @Published var detectedMistake: String?
    @Published var verificationState: VerificationState = .observing
    
    // MARK: - Configuration
    private var teacherConfig: TeacherConfig?
    private var lessonId: String = ""
    
    // MARK: - Frame Buffer
    private var frameBuffer: [UIImage] = []
    private let maxFrameBufferSize = 5
    private var lastFrameCaptureTime: Date = .distantPast
    private let frameCaptureInterval: TimeInterval = 0.4  // Capture every 0.4s
    
    // MARK: - Polling Timer
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 3.0  // Check VLM every 3 seconds
    private var lastVLMCallTime: Date = .distantPast
    private var isVLMCallInProgress = false
    
    // MARK: - Presence Detection
    private var handsVisible = false
    private var presenceStartTime: Date?
    private let minPresenceBeforeCheck: TimeInterval = 1.5  // Wait 1.5s before first check
    
    // MARK: - Callbacks
    var onStepCompleted: ((Int) -> Void)?
    var onMistakeDetected: ((String, String?) -> Void)?  // (reason, suggestion)
    
    // MARK: - Network
    private var networkService: NetworkService?
    
    // MARK: - Setup
    
    func configure(with config: TeacherConfig, networkService: NetworkService? = nil) {
        self.teacherConfig = config
        self.lessonId = config.lessonId
        self.networkService = networkService
        self.currentStepIndex = 0
        self.monitoringStatus = .monitoring
        self.verificationState = .observing
        self.stepConfidence = 0.0
        self.frameBuffer.removeAll()
        
        // Start polling timer
        startPolling()
        
        print("🧠 VisionService: Configured with \(config.steps.count) steps, continuous monitoring enabled")
    }
    
    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollVLM()
            }
        }
        // Ensure timer runs on main run loop
        RunLoop.current.add(pollingTimer!, forMode: .common)
        print("⏰ VLM Polling timer started (every \(pollingInterval)s)")
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Frame Processing
    
    func processFrame(_ image: UIImage) {
        guard let config = teacherConfig,
              currentStepIndex < config.steps.count else { return }
        
        // Always buffer frames
        bufferFrame(image)
        
        // Skip if already processing pose detection
        guard !isProcessing else { return }
        isProcessing = true
        
        // Detect hands/body for presence indication
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.detectPresence(image)
        }
    }
    
    private func bufferFrame(_ image: UIImage) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameCaptureTime) >= frameCaptureInterval else { return }
        lastFrameCaptureTime = now
        
        if frameBuffer.count >= maxFrameBufferSize {
            frameBuffer.removeFirst()
        }
        frameBuffer.append(image)
    }
    
    // MARK: - Presence Detection
    
    nonisolated private func detectPresence(_ image: UIImage) async {
        guard let cgImage = image.cgImage else {
            await MainActor.run { isProcessing = false }
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let bodyRequest = VNDetectHumanBodyPoseRequest()
        
        do {
            try handler.perform([handRequest, bodyRequest])
            
            let handsFound = !(handRequest.results?.isEmpty ?? true)
            let bodyFound = !(bodyRequest.results?.isEmpty ?? true)
            
            await MainActor.run {
                // Update body pose for skeleton overlay
                if let pose = bodyRequest.results?.first {
                    currentBodyPose = pose
                }
                
                handlePresenceUpdate(handsVisible: handsFound, bodyVisible: bodyFound)
                isProcessing = false
            }
        } catch {
            await MainActor.run { isProcessing = false }
        }
    }
    
    private func handlePresenceUpdate(handsVisible: Bool, bodyVisible: Bool) {
        let wasPresent = self.handsVisible
        self.handsVisible = handsVisible || bodyVisible
        
        if self.handsVisible {
            if presenceStartTime == nil {
                presenceStartTime = Date()
                print("👤 User present, starting observation")
            }
            
            // Update confidence as visual feedback
            if let start = presenceStartTime {
                let duration = Date().timeIntervalSince(start)
                stepConfidence = min(0.5, duration / (minPresenceBeforeCheck * 2))
            }
        } else {
            if wasPresent {
                print("👤 User left frame")
            }
            presenceStartTime = nil
            stepConfidence = 0.0
        }
    }
    
    // MARK: - VLM Polling
    
    private func pollVLM() {
        print("⏰ pollVLM: status=\(monitoringStatus), frames=\(frameBuffer.count), presence=\(presenceStartTime != nil)")
        
        // Don't poll if not in monitoring state
        guard case .monitoring = monitoringStatus else { 
            print("  ↳ Skipped: not monitoring")
            return 
        }
        
        // Don't poll if already calling
        guard !isVLMCallInProgress else { 
            print("  ↳ Skipped: call in progress")
            return 
        }
        
        // Don't poll if user not present long enough
        guard let start = presenceStartTime,
              Date().timeIntervalSince(start) >= minPresenceBeforeCheck else {
            print("  ↳ Skipped: presence=\(presenceStartTime != nil), need \(minPresenceBeforeCheck)s")
            return
        }
        
        // Need enough frames
        guard frameBuffer.count >= 3 else { 
            print("  ↳ Skipped: only \(frameBuffer.count) frames")
            return 
        }
        
        print("  ↳ ✅ All checks passed, calling VLM!")
        callVLM()
    }
    
    private func callVLM() {
        guard let config = teacherConfig,
              currentStepIndex < config.steps.count,
              let network = networkService else { return }
        
        let step = config.steps[currentStepIndex]
        
        isVLMCallInProgress = true
        monitoringStatus = .checking
        verificationState = .verifying
        lastVLMCallTime = Date()
        
        // Convert frames to JPEG - use fewer, smaller images for speed
        let framesToSend = Array(frameBuffer.suffix(3))  // Only 3 frames
        let frameData = framesToSend.compactMap { image -> Data? in
            let size = CGSize(width: 384, height: 384)  // Smaller for speed
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            image.draw(in: CGRect(origin: .zero, size: size))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resized?.jpegData(compressionQuality: 0.5)  // Lower quality
        }
        
        print("📤 Polling VLM: Step \(step.stepId) - \(step.title)")
        
        Task {
            do {
                let response = try await network.verifyStep(
                    lessonId: lessonId,
                    stepId: step.stepId,
                    stepTitle: step.title,
                    stepDescription: step.description,
                    frames: frameData
                )
                
                handleVLMResponse(response)
                
            } catch {
                print("❌ VLM call failed: \(error)")
                isVLMCallInProgress = false
                monitoringStatus = .monitoring
                verificationState = .observing
            }
        }
    }
    
    private func handleVLMResponse(_ response: NetworkService.VerificationResponse) {
        isVLMCallInProgress = false
        
        print("📥 VLM: status=\(response.status), reason=\(response.reason)")
        
        switch response.status {
        case "complete":
            monitoringStatus = .complete
            verificationState = .verified
            stepConfidence = 1.0
            
            // Auto-advance after brief delay
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                advanceToNextStep()
            }
            
        case "mistake":
            monitoringStatus = .mistake(response.reason)
            verificationState = .needsCorrection(response.reason)
            detectedMistake = response.reason
            stepConfidence = 0.0
            
            // Notify for audio feedback
            onMistakeDetected?(response.reason, response.suggestion)
            
            // Resume monitoring after delay
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if case .mistake = monitoringStatus {
                    monitoringStatus = .monitoring
                    verificationState = .observing
                    detectedMistake = nil
                }
            }
            
        default:  // "in_progress"
            monitoringStatus = .monitoring
            verificationState = .observing
            
            // Slight confidence bump to show we're checking
            stepConfidence = min(0.6, stepConfidence + 0.1)
        }
    }
    
    // MARK: - Step Navigation
    
    private func advanceToNextStep() {
        guard let config = teacherConfig else { return }
        
        onStepCompleted?(currentStepIndex)
        
        if currentStepIndex < config.steps.count - 1 {
            currentStepIndex += 1
            resetForNewStep()
            print("➡️ Advanced to step \(currentStepIndex + 1)")
        } else {
            print("🎉 All steps completed!")
            monitoringStatus = .complete
            stopPolling()
        }
    }
    
    private func resetForNewStep() {
        monitoringStatus = .monitoring
        verificationState = .observing
        stepConfidence = 0.0
        detectedMistake = nil
        presenceStartTime = nil
        frameBuffer.removeAll()
        currentBodyPose = nil
        isVLMCallInProgress = false
    }
    
    func reset() {
        stopPolling()
        currentStepIndex = 0
        resetForNewStep()
        startPolling()
    }
    
    // MARK: - Manual Controls
    
    func manualAdvanceStep() {
        advanceToNextStep()
    }
    
    func manualTriggerMistake() {
        monitoringStatus = .mistake("Manual test")
        verificationState = .needsCorrection("Manual test")
        onMistakeDetected?("Manual test mistake", "This is a test")
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
}

// MARK: - Legacy VerificationState (for UI compatibility)

enum VerificationState: Equatable {
    case observing
    case readyToVerify
    case verifying
    case verified
    case needsCorrection(String)
    
    var displayText: String {
        switch self {
        case .observing: return "Watching..."
        case .readyToVerify: return "Hold still..."
        case .verifying: return "Verifying..."
        case .verified: return "Perfect! ✓"
        case .needsCorrection(let r): return r
        }
    }
    
    var isBlocking: Bool {
        switch self {
        case .verifying: return true
        default: return false
        }
    }
}
