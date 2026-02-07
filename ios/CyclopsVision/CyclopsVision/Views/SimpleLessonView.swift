import SwiftUI
import AVFoundation

struct SimpleLessonView: View {
    let lesson: Lesson
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkService: NetworkService
    
    @State private var currentStepIndex: Int = 0
    @State private var videoOpacity: Double = 1.0
    // Ghost Mode
    @State private var showGhostMode: Bool = false
    @State private var ghostOpacity: Double = 0.3
    
    // TTS
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Camera Service for Ghost Mode background (optional, but requested "video overlay")
    // If we just want video playback without camera, we can remove this.
    // However, "Ghost Mode" implies overlaying on *something* (usually reality).
    // The prompt said: "just read the text ... and desplay the video".
    // I will stick to PURE VIDEO for the main view, and maybe Ghost Mode as an extra if needed.
    // Actually, "redirect the video and feed back service to this new POC" implies removing the complex feedback,
    // but maybe keeping the camera?
    // Let's implement PURE VIDEO + TEXT first as per "The user sould just see the step and here the predeified teacher."
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(lesson.title)
                            .foregroundColor(.white)
                            .font(.headline)
                        Spacer()
                        // Placeholder for symmetry
                        Image(systemName: "circle")
                            .font(.title)
                            .foregroundColor(.clear)
                    }
                    .padding()
                    
                    // Main Video Area
                    if let config = lesson.aiTeacherConfig,
                       currentStepIndex < config.steps.count,
                       let clipUrl = config.steps[currentStepIndex].clipUrl,
                       let url = networkService.resolveURL(path: clipUrl) {
                        
                        VideoPlayerView(url: url, opacity: $videoOpacity)
                            .frame(height: geometry.size.height * 0.5)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .id(currentStepIndex) // Force refresh on step change
                        
                    } else {
                        // Fallback UI
                        ZStack {
                            Color.gray.opacity(0.2)
                            Text("No Video Available")
                                .foregroundColor(.white)
                        }
                        .frame(height: geometry.size.height * 0.5)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Instruction & Controls Area
                    if let config = lesson.aiTeacherConfig, currentStepIndex < config.steps.count {
                        let step = config.steps[currentStepIndex]
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Step Info
                            HStack {
                                Text("Step \(currentStepIndex + 1)/\(config.steps.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(8)
                                    
                                Spacer()
                                
                                Button(action: { speakDescription(for: step) }) {
                                    Label("Replay Audio", systemImage: "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Title & Description
                            Text(step.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            ScrollView {
                                Text(step.description)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(nil)
                            }
                            
                            // Navigation Buttons
                            HStack(spacing: 20) {
                                Button(action: previousStep) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Previous")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(10)
                                    .foregroundColor(currentStepIndex > 0 ? .white : .gray)
                                }
                                .disabled(currentStepIndex == 0)
                                
                                Button(action: nextStep) {
                                    HStack {
                                        Text(currentStepIndex < config.steps.count - 1 ? "Next Step" : "Finish")
                                        Image(systemName: "chevron.right")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground).opacity(0.1))
                        .cornerRadius(20)
                        .padding()
                    }
                }
            }
        }
        .onAppear {
             // Start correct audio session category for playback
             try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
             try? AVAudioSession.sharedInstance().setActive(true)
             
            if let config = lesson.aiTeacherConfig, !config.steps.isEmpty {
                 speakDescription(for: config.steps[0])
            }
        }
    }
    
    // MARK: - Actions
    
    private func nextStep() {
        guard let config = lesson.aiTeacherConfig else { return }
        if currentStepIndex < config.steps.count - 1 {
            currentStepIndex += 1
            speakDescription(for: config.steps[currentStepIndex])
        } else {
            // Finished
            dismiss()
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            if let config = lesson.aiTeacherConfig {
                speakDescription(for: config.steps[currentStepIndex])
            }
        }
    }
    
    private func speakDescription(for step: Step) {
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: step.description)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        speechSynthesizer.speak(utterance)
    }
}
