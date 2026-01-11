import Foundation
import Combine

@MainActor
class NetworkService: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://192.168.0.149:8000") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
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
        guard let url = URL(string: "\(baseURL)/ai/feedback") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let feedbackRequest = FeedbackRequest(
            lessonId: lessonId,
            stepId: stepId,
            mistakeType: mistakeType,
            confidence: confidence,
            frameBase64: frameData?.base64EncodedString()
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(feedbackRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FeedbackResponse.self, from: data)
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed"
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}
