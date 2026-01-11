import SwiftUI

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
    
    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // Overlay layer
            if showOverlay, let overlay = currentOverlay {
                DiagramOverlayView(overlay: overlay)
                    .transition(.opacity)
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
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
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
            
            // UI Layer
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
            
            // Pause overlay
            if isPaused {
                PauseOverlayView(onResume: { isPaused = false })
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
        // Configure vision service with lesson
        if let config = lesson.aiTeacherConfig {
            visionService.configure(with: config)
        }
        
        // Set up callbacks
        visionService.onMistakeDetected = { mistakeType, confidence in
            handleMistakeDetected(mistakeType: mistakeType, confidence: confidence)
        }
        
        visionService.onStepCompleted = { stepIndex in
            handleStepCompleted(stepIndex: stepIndex)
        }
        
        // Connect camera to vision service
        cameraService.onFrameCaptured = { image in
            if !isPaused {
                visionService.processFrame(image)
            }
        }
        
        // Start camera
        cameraService.start()
    }
    
    private func handleMistakeDetected(mistakeType: String, confidence: Double) {
        Task {
            do {
                let response = try await networkService.requestFeedback(
                    lessonId: lesson.id,
                    stepId: visionService.currentStepIndex + 1,
                    mistakeType: mistakeType,
                    confidence: confidence,
                    frameData: cameraService.captureCurrentFrame()
                )
                
                if let overlay = response.overlay {
                    await MainActor.run {
                        currentOverlay = overlay
                        showOverlay = true
                        
                        // Speak the correction
                        audioService.speak(overlay.audioText)
                        
                        // Auto-hide overlay after duration
                        DispatchQueue.main.asyncAfter(deadline: .now() + overlay.durationSeconds) {
                            withAnimation {
                                showOverlay = false
                            }
                        }
                    }
                }
            } catch {
                print("Failed to get feedback: \(error)")
            }
        }
    }
    
    private func handleStepCompleted(stepIndex: Int) {
        // Announce step completion
        guard let config = lesson.aiTeacherConfig,
              stepIndex < config.steps.count else { return }
        
        let completedStep = config.steps[stepIndex]
        audioService.speak("Step \(stepIndex + 1) complete: \(completedStep.title)")
        
        // Check if lesson is complete
        if stepIndex == config.steps.count - 1 {
            audioService.speak("Congratulations! You have completed the lesson.")
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
}

// MARK: - Subviews

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .black
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = cameraService.currentFrame
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
                            .lineLimit(2)
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

#Preview {
    ARSessionView(lesson: Lesson(
        id: "test",
        title: "Test Lesson",
        demoVideoUrl: "",
        aiTeacherConfig: TeacherConfig(
            lessonId: "test",
            totalSteps: 3,
            steps: [
                Step(
                    stepId: 1,
                    title: "Insert wire",
                    description: "Insert the wire into the terminal",
                    expectedObjects: ["wire", "terminal"],
                    expectedMotion: "forward_insertion",
                    expectedDurationSeconds: 10,
                    mistakePatterns: [
                        MistakePattern(type: "misaligned", description: "Wire is not aligned")
                    ],
                    correctionMode: "diagram_overlay_audio"
                ),
                Step(
                    stepId: 2,
                    title: "Tighten screw",
                    description: "Use screwdriver to tighten",
                    expectedObjects: ["screwdriver"],
                    expectedMotion: "rotation_clockwise",
                    expectedDurationSeconds: 15,
                    mistakePatterns: [],
                    correctionMode: "diagram_overlay_audio"
                ),
                Step(
                    stepId: 3,
                    title: "Test connection",
                    description: "Verify the connection is secure",
                    expectedObjects: [],
                    expectedMotion: "pulling",
                    expectedDurationSeconds: 5,
                    mistakePatterns: [],
                    correctionMode: "diagram_overlay_audio"
                )
            ]
        ),
        createdAt: "2026-01-11T10:00:00Z"
    ))
    .environmentObject(NetworkService())
}
