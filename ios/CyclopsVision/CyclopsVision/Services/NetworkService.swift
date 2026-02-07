import Foundation
import Combine

@MainActor
class NetworkService: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://192.168.0.156:8000") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // VLM can be slow
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
        
        Task {
            await checkHealth()
        }
    }
    
    func updateBaseURL(_ url: String) {
        baseURL = url
        Task {
            await checkHealth()
        }
    }
    
    // MARK: - Health Check
    
    func checkHealth() async {
        guard let url = URL(string: "\(baseURL)/health") else {
            isConnected = false
            return
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                isConnected = httpResponse.statusCode == 200
            }
        } catch {
            isConnected = false
            print("Health check failed: \(error)")
        }
    }
    
    // MARK: - Lessons
    
    func fetchLessons() async throws -> [Lesson] {
        guard let url = URL(string: "\(baseURL)/lessons") else {
            throw NetworkError.invalidURL
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Lesson].self, from: data)
    }
    
    func fetchLesson(id: String) async throws -> Lesson {
        guard let url = URL(string: "\(baseURL)/lessons/\(id)") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Lesson.self, from: data)
    }
    
    // MARK: - AI Feedback
    
    func requestFeedback(
        lessonId: String,
        stepId: Int,
        mistakeType: String,
        confidence: Double,
        frameData: Data? = nil
    ) async throws -> FeedbackResponse {
        let feedbackRequest = FeedbackRequest(
            lessonId: lessonId,
            stepId: stepId,
            mistakeType: mistakeType,
            confidence: confidence,
            frameBase64: frameData?.base64EncodedString()
        )
        
        return try await performRequest(endpoint: "/api/ai/feedback", body: feedbackRequest, responseType: FeedbackResponse.self)
    }
    
    // MARK: - Verification
    
    struct VerificationRequest: Codable {
        let lesson_id: String
        let step_id: Int
        let step_title: String
        let step_description: String
        let frames_base64: [String]
    }
    
    struct VerificationResponse: Codable {
        let status: String  // "in_progress", "complete", "mistake"
        let reason: String
        let confidence: Double
        let suggestion: String?
    }
    
    func verifyStep(
        lessonId: String,
        stepId: Int,
        stepTitle: String,
        stepDescription: String,
        frames: [Data]
    ) async throws -> VerificationResponse {
        guard !frames.isEmpty else {
            throw NetworkError.invalidData
        }
        
        let framesBase64 = frames.map { $0.base64EncodedString() }
        
        let request = VerificationRequest(
            lesson_id: lessonId,
            step_id: stepId,
            step_title: stepTitle,
            step_description: stepDescription,
            frames_base64: framesBase64
        )
        
        return try await performRequest(endpoint: "/api/verify_step", body: request, responseType: VerificationResponse.self)
    }

    
    // MARK: - Private Helpers
    
    private func performRequest<T: Codable, U: Codable>(endpoint: String, body: T, responseType: U.Type) async throws -> U {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(U.self, from: data)
    }
    // MARK: - Helper
    
    func resolveURL(path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(baseURL)\(cleanPath)")
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed"
        case .decodingFailed:
            return "Failed to decode response"
        case .invalidData:
            return "Invalid data"
        }
    }
}
