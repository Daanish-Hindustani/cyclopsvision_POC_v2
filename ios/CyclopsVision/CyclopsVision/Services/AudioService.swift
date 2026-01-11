import AVFoundation

/// AudioService handles text-to-speech for voice guidance
class AudioService: ObservableObject {
    @Published var isSpeaking = false
    
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: AudioServiceDelegate?
    
    init() {
        delegate = AudioServiceDelegate(service: self)
        synthesizer.delegate = delegate
    }
    
    func speak(_ text: String, rate: Float = 0.5) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use a natural voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    fileprivate func didFinishSpeaking() {
        isSpeaking = false
    }
}

private class AudioServiceDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var service: AudioService?
    
    init(service: AudioService) {
        self.service = service
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.service?.didFinishSpeaking()
        }
    }
}
