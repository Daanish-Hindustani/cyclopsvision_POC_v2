import Foundation
import UIKit
import Vision
import CoreML

/// VisionService handles on-device AI processing for step tracking and mistake detection
class VisionService: ObservableObject {
    @Published var currentStepIndex: Int = 0
    @Published var stepConfidence: Double = 0.0
    @Published var detectedMistake: String?
    @Published var mistakeConfidence: Double = 0.0
    @Published var isProcessing = false
    
    private var teacherConfig: TeacherConfig?
    private var frameBuffer: [UIImage] = []
    private let maxBufferSize = 5
    
    // Callbacks
    var onMistakeDetected: ((String, Double) -> Void)?
    var onStepCompleted: ((Int) -> Void)?
    
    // Confidence thresholds
    private let stepCompleteThreshold = 0.85
    private let mistakeThreshold = 0.7
    private let backendThreshold = 0.8
    
    func configure(with config: TeacherConfig) {
        self.teacherConfig = config
        self.currentStepIndex = 0
        self.stepConfidence = 0.0
        self.detectedMistake = nil
    }
    
    func processFrame(_ image: UIImage) {
        guard let config = teacherConfig,
              currentStepIndex < config.steps.count else { return }
        
        // Add to buffer
        frameBuffer.append(image)
        if frameBuffer.count > maxBufferSize {
            frameBuffer.removeFirst()
        }
        
        isProcessing = true
        
        // Get current step
        let currentStep = config.steps[currentStepIndex]
        
        // Perform vision analysis
        analyzeFrame(image, for: currentStep)
    }
    
    private func analyzeFrame(_ image: UIImage, for step: Step) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        // Use Vision framework for object detection
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error, step: step)
        }
        request.recognitionLevel = .accurate
        
        // Also run object detection
        let objectRequest = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleObjectDetection(request: request, error: error, step: step)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try handler.perform([request, objectRequest])
            } catch {
                print("Vision request failed: \(error)")
            }
            
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
        }
    }
    
    private func handleTextRecognition(request: VNRequest, error: Error?, step: Step) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        
        // Check for step-related text
        let recognizedTexts = observations.compactMap { observation in
            observation.topCandidates(1).first?.string.lowercased()
        }
        
        // Simple heuristic: check if expected objects are mentioned
        var matchCount = 0
        for expectedObject in step.expectedObjects {
            if recognizedTexts.contains(where: { $0.contains(expectedObject.lowercased()) }) {
                matchCount += 1
            }
        }
        
        if !step.expectedObjects.isEmpty {
            let objectConfidence = Double(matchCount) / Double(step.expectedObjects.count)
            
            DispatchQueue.main.async { [weak self] in
                self?.updateConfidence(objectConfidence, for: step)
            }
        }
    }
    
    private func handleObjectDetection(request: VNRequest, error: Error?, step: Step) {
        guard let observations = request.results as? [VNRectangleObservation] else { return }
        
        // Use rectangle detection as a proxy for object positioning
        // In a real implementation, you'd use a custom CoreML model here
        
        let hasObjects = !observations.isEmpty
        
        DispatchQueue.main.async { [weak self] in
            if hasObjects {
                // Increment confidence slightly when objects are detected
                self?.stepConfidence = min(1.0, (self?.stepConfidence ?? 0) + 0.1)
            }
        }
    }
    
    private func updateConfidence(_ additionalConfidence: Double, for step: Step) {
        // Blend new confidence with existing
        stepConfidence = stepConfidence * 0.7 + additionalConfidence * 0.3
        
        // Check for step completion
        if stepConfidence >= stepCompleteThreshold {
            advanceToNextStep()
        }
        
        // Simulate mistake detection based on low confidence + time
        // In a real implementation, you'd analyze motion patterns, object positions, etc.
        if stepConfidence < 0.3 && frameBuffer.count >= maxBufferSize {
            simulateMistakeDetection(for: step)
        }
    }
    
    private func simulateMistakeDetection(for step: Step) {
        guard !step.mistakePatterns.isEmpty else { return }
        
        // For POC: randomly select a mistake pattern
        if let mistake = step.mistakePatterns.randomElement() {
            detectedMistake = mistake.type
            mistakeConfidence = Double.random(in: 0.7...0.95)
            
            if mistakeConfidence >= backendThreshold {
                onMistakeDetected?(mistake.type, mistakeConfidence)
            }
        }
    }
    
    private func advanceToNextStep() {
        guard let config = teacherConfig else { return }
        
        onStepCompleted?(currentStepIndex)
        
        if currentStepIndex < config.steps.count - 1 {
            currentStepIndex += 1
            stepConfidence = 0.0
            detectedMistake = nil
            mistakeConfidence = 0.0
            frameBuffer.removeAll()
        }
    }
    
    func reset() {
        currentStepIndex = 0
        stepConfidence = 0.0
        detectedMistake = nil
        mistakeConfidence = 0.0
        frameBuffer.removeAll()
    }
    
    // Manual step control for demo purposes
    func manualAdvanceStep() {
        advanceToNextStep()
    }
    
    func manualTriggerMistake() {
        guard let config = teacherConfig,
              currentStepIndex < config.steps.count else { return }
        
        let step = config.steps[currentStepIndex]
        if let mistake = step.mistakePatterns.first {
            detectedMistake = mistake.type
            mistakeConfidence = 0.85
            onMistakeDetected?(mistake.type, mistakeConfidence)
        } else {
            // Default mistake if none defined
            detectedMistake = "generic_error"
            mistakeConfidence = 0.85
            onMistakeDetected?("generic_error", mistakeConfidence)
        }
    }
}
