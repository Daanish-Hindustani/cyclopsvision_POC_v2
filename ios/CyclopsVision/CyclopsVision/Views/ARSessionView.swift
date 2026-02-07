import SwiftUI
import AVFoundation
import Combine

struct ARSessionView: View {
    let lesson: Lesson
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkService: NetworkService
    
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var audioService = AudioService()
    
    @State private var currentOverlay: OverlayInstruction?
    @State private var showOverlay = false
    @State private var isPaused = false
    @State private var showControls = true
    
    // Ghost Mode
    @State private var ghostOpacity: Double = 0.3
    @State private var showGhostControls = false
    
    init(lesson: Lesson) {
        self.lesson = lesson
        print("🚀 ARSessionView.init() called for lesson: \(lesson.id)")
    }
    
    var body: some View {
        let _ = print("🎬 ARSessionView.body rendering")
        GeometryReader { geometry in
            ZStack {
                // Main split layout
                VStack(spacing: 0) {
                    // Top: Video Snippet (Looping)
                    if let config = lesson.aiTeacherConfig,
                       visionService.currentStepIndex < config.steps.count,
                       let clipUrl = config.steps[visionService.currentStepIndex].clipUrl,
                       let url = resolveURL(path: clipUrl) {
                        
                        VideoPlayerView(url: url, opacity: .constant(1.0))
                            .id(visionService.currentStepIndex) // Force refresh on step change
                            .frame(height: geometry.size.height * 0.35)
                            .overlay(alignment: .bottomTrailing) {

                                Button {
                                    showGhostControls.toggle()
                                } label: {
                                    Image(systemName: showGhostControls ? "eye.slash" : "eye")
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .foregroundColor(.white)
                                }
                                .padding(8)
                            }
                    } else if let config = lesson.aiTeacherConfig, visionService.currentStepIndex < config.steps.count {
                        // Fallback purely for layout when no video
                         Color.black
                            .frame(height: geometry.size.height * 0.35)
                            .overlay {
                                Text("No video snippet available")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    }
                    
                    // Bottom: Camera Feed + Local AI Overlay
                    ZStack {
                        CameraPreviewView(cameraService: cameraService)
                            .ignoresSafeArea(edges: .bottom)
                        
                        // Ghost Overlay (Video overlaid on camera)
                        if showGhostControls,
                           let config = lesson.aiTeacherConfig,
                           visionService.currentStepIndex < config.steps.count,
                           let clipUrl = config.steps[visionService.currentStepIndex].clipUrl,
                           let url = resolveURL(path: clipUrl) {
                            
                            VideoPlayerView(url: url, opacity: $ghostOpacity)
                                .allowsHitTesting(false)
                        }

                        
                        // Mistake Overlay (Cloud/Local)
                        if showOverlay, let overlay = currentOverlay {
                            DiagramOverlayView(overlay: overlay)
                                .transition(.opacity)
                        }
                        
                        // Verification State Overlay
                        VerificationStateOverlay(state: visionService.verificationState)
                        
                        // Local Vision Overlay (Skeleton)
                        if let bodyPose = visionService.currentBodyPose {
                             SkeletonView(bodyPose: bodyPose)
                                .allowsHitTesting(false)
                        }
                        
                        // Ghost Controls Slider
                        if showGhostControls {
                            VStack {
                                Spacer()
                                HStack {
                                    Text("Ghost:")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Slider(value: $ghostOpacity, in: 0...1)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding()
                                .padding(.bottom, 60) // clear bottom bar
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // UI Layer (Floating)
                VStack {
                    // Top bar
                    TopBarView(
                        lesson: lesson,
                        onDismiss: { dismiss() },
                        isPaused: isPaused,
                        onTogglePause: { isPaused.toggle() }
                    )
                    
                    Spacer()
                    
                    // Step progress
                    if let config = lesson.aiTeacherConfig {
                        StepProgressView(
                            config: config,
                            currentStep: visionService.currentStepIndex,
                            confidence: visionService.stepConfidence
                        )
                        .padding(.horizontal)
                    }
                    
                    // Bottom controls
                    if showControls {
                        BottomControlsView(
                            visionService: visionService,
                            audioService: audioService,
                            isPaused: isPaused,
                            showOverlay: showOverlay,
                            onTriggerMistake: triggerMistakeDemo,
                            onAdvanceStep: { visionService.manualAdvanceStep() },
                            onToggleOverlay: { showOverlay.toggle() },
                            onReplayAudio: replayAudio
                        )
                    }
                }
                
                // Camera error overlay
                if let cameraError = cameraService.error {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Camera Error")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(cameraError)
                            .foregroundColor(.white.opacity(0.8))
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.9))
                }
                
                // Pause overlay
                if isPaused {
                    PauseOverlayView(onResume: { isPaused = false })
                }
            }
        }
        .onAppear {
            setupSession()
        }
        .onDisappear {
            cameraService.stop()
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                cameraService.stop()
            } else {
                cameraService.start()
            }
        }
        .statusBarHidden()
    }
    
    private func setupSession() {
        print("📱 ARSessionView.setupSession() called")
        if let config = lesson.aiTeacherConfig {
            print("📱 Lesson has \(config.steps.count) steps")
            visionService.configure(with: config, networkService: networkService)
        } else {
            print("📱 Lesson has NO AI config")
        }
        
        // Handle step completion (for audio announcement)
        visionService.onStepCompleted = { stepIndex in
            handleStepCompleted(stepIndex: stepIndex)
        }
        
        // Handle mistake detected by VLM
        visionService.onMistakeDetected = { reason, suggestion in
            if let suggestion = suggestion {
                audioService.speak("Correction needed: \(reason). \(suggestion)")
            } else {
                audioService.speak("Correction needed: \(reason)")
            }
        }
        
        // Frame processing
        cameraService.onFrameCaptured = { image in
            if !isPaused {
                visionService.processFrame(image)
            }
        }
        
        cameraService.start()
    }
    
    private func handleMistakeDetected(mistakeType: String, confidence: Double) {
        // IMPROVEMENT: Instant Audio Feedback
        // Don't wait for backend. Speak immediately.
        let friendlyMistake = mistakeType.replacingOccurrences(of: "_", with: " ")
        audioService.speak("Mistake detected: \(friendlyMistake). Checking details...")
        
        print("☁️ Remote Model: Sending mistake '\(mistakeType)' to backend for analysis...")
        Task {
            do {
                let response = try await networkService.requestFeedback(
                    lessonId: lesson.id,
                    stepId: visionService.currentStepIndex + 1,
                    mistakeType: mistakeType,
                    confidence: confidence,
                    frameData: cameraService.captureCurrentFrame()
                )
                
                print("☁️ Remote Model: Received feedback response")
                
                if let overlay = response.overlay {
                    await MainActor.run {
                        currentOverlay = overlay
                        showOverlay = true
                        audioService.speak(overlay.audioText)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + overlay.durationSeconds) {
                            withAnimation {
                                showOverlay = false
                            }
                        }
                    }
                }
            } catch {
                // Feedback request failed
            }
        }
    }
    
    private func handleStepCompleted(stepIndex: Int) {
        guard let config = lesson.aiTeacherConfig else { return }
        
        // Announce the NEXT step (we just finished stepIndex, now moving to stepIndex+1)
        let nextStepIndex = stepIndex + 1
        
        if nextStepIndex < config.steps.count {
            let nextStep = config.steps[nextStepIndex]
            // Speak the next step's instructions
            audioService.speak("Step \(nextStepIndex + 1): \(nextStep.title). \(nextStep.description)")
        } else {
            // All steps done
            audioService.speak("Congratulations! You have completed all steps.")
        }
    }
    
    private func triggerMistakeDemo() {
        visionService.manualTriggerMistake()
    }
    
    private func replayAudio() {
        if let overlay = currentOverlay {
            audioService.speak(overlay.audioText)
        }
    }
    
    private func resolveURL(path: String) -> URL? {
        return networkService.resolveURL(path: path)
    }
}


// MARK: - Subviews

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraService: cameraService)
    }
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .black
        context.coordinator.imageView = imageView
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Use coordinator for updates
        context.coordinator.imageView = uiView
    }
    
    class Coordinator: NSObject {
        weak var imageView: UIImageView?
        private var cancellable: AnyCancellable?
        
        init(cameraService: CameraService) {
            super.init()
            cancellable = cameraService.$currentFrame
                .receive(on: DispatchQueue.main)
                .sink { [weak self] image in
                    self?.imageView?.image = image
                }
        }
    }
}

struct TopBarView: View {
    let lesson: Lesson
    let onDismiss: () -> Void
    let isPaused: Bool
    let onTogglePause: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            
            Spacer()
            
            Button(action: onTogglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }
}

struct StepProgressView: View {
    let config: TeacherConfig
    let currentStep: Int
    let confidence: Double
    
    var body: some View {
        VStack(spacing: 12) {
            // Current step info
            if currentStep < config.steps.count {
                let step = config.steps[currentStep]
                
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text("\(currentStep + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(step.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
            
            // Step dots
            HStack(spacing: 8) {
                ForEach(0..<config.totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index < currentStep ? Color.green :
                              index == currentStep ? Color.purple : Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            
            // Confidence bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * confidence, height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: confidence)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct BottomControlsView: View {
    @ObservedObject var visionService: VisionService
    @ObservedObject var audioService: AudioService
    let isPaused: Bool
    let showOverlay: Bool
    let onTriggerMistake: () -> Void
    let onAdvanceStep: () -> Void
    let onToggleOverlay: () -> Void
    let onReplayAudio: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Trigger mistake (for demo)
            Button(action: onTriggerMistake) {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                    Text("Mistake")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .frame(width: 60)
            }
            
            // Advance step (for demo)
            Button(action: onAdvanceStep) {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                    Text("Next")
                        .font(.caption2)
                }
                .foregroundColor(.green)
                .frame(width: 60)
            }
            
            // Toggle overlay
            Button(action: onToggleOverlay) {
                VStack(spacing: 4) {
                    Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                        .font(.title2)
                    Text("Overlay")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .frame(width: 60)
            }
            
            // Replay audio
            Button(action: onReplayAudio) {
                VStack(spacing: 4) {
                    Image(systemName: audioService.isSpeaking ? "speaker.wave.3.fill" : "speaker.fill")
                        .font(.title2)
                    Text("Audio")
                        .font(.caption2)
                }
                .foregroundColor(.purple)
                .frame(width: 60)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

struct PauseOverlayView: View {
    let onResume: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Paused")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tap anywhere to resume")
                    .foregroundColor(.white.opacity(0.7))
                
                Button("Resume") {
                    onResume()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .onTapGesture {
            onResume()
        }
    }
}

// MARK: - Verification State Overlay

struct VerificationStateOverlay: View {
    let state: VerificationState
    
    var body: some View {
        Group {
            switch state {
            case .observing:
                EmptyView()
                
            case .readyToVerify:
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Label("Hold still...", systemImage: "hand.raised.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    .padding(.bottom, 150)
                }
                
            case .verifying:
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Verifying...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.9))
                        .cornerRadius(20)
                        Spacer()
                    }
                    .padding(.bottom, 150)
                }
                
            case .verified:
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Label("Perfect!", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(25)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.bottom, 150)
                }
                .transition(.scale.combined(with: .opacity))
                
            case .needsCorrection(let reason):
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Try again")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.9))
                    .cornerRadius(16)
                    .padding(.bottom, 150)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

