import AVFoundation

/// AudioService handles text-to-speech using OpenAI TTS for natural voices
class AudioService: ObservableObject {
    @Published var isSpeaking = false
    
    private var player: AVAudioPlayer?
    private let session = URLSession.shared
    private let baseURL: String
    
    // Fallback synthesizer for offline use
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: AudioServiceDelegate?
    
    init(baseURL: String = "http://192.168.0.156:8000") {
        self.baseURL = baseURL
        delegate = AudioServiceDelegate(service: self)
        synthesizer.delegate = delegate
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Stop any current speech
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        
        isSpeaking = true
        
        // Use OpenAI TTS via backend
        Task {
            do {
                try await speakWithOpenAI(text)
            } catch {
                print("OpenAI TTS failed, falling back to local: \(error)")
                await MainActor.run {
                    speakLocally(text)
                }
            }
        }
    }
    
    private func speakWithOpenAI(_ text: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/tts/speak") else {
            throw NSError(domain: "AudioService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["text": text, "voice": "nova"] // nova is a friendly female voice
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AudioService", code: 2, userInfo: [NSLocalizedDescriptionKey: "TTS request failed"])
        }
        
        // Play the MP3 audio
        await MainActor.run {
            do {
                self.player = try AVAudioPlayer(data: data)
                self.player?.delegate = self.delegate
                self.player?.play()
            } catch {
                print("Audio playback error: \(error)")
                self.isSpeaking = false
            }
        }
    }
    
    private func speakLocally(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    fileprivate func didFinishPlaying() {
        isSpeaking = false
    }
}

private class AudioServiceDelegate: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    weak var service: AudioService?
    
    init(service: AudioService) {
        self.service = service
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.service?.didFinishPlaying()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.service?.didFinishPlaying()
        }
    }
}
