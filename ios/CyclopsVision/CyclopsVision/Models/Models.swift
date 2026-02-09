import Foundation

// MARK: - Lesson Models

struct Lesson: Codable, Identifiable {
    let id: String
    let title: String
    let demoVideoUrl: String
    let aiTeacherConfig: TeacherConfig?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case demoVideoUrl = "demo_video_url"
        case aiTeacherConfig = "ai_teacher_config"
        case createdAt = "created_at"
    }
}

struct TeacherConfig: Codable {
    let lessonId: String
    let totalSteps: Int
    let steps: [Step]
    
    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case totalSteps = "total_steps"
        case steps
    }
}

struct Step: Codable, Identifiable {
    let stepId: Int
    let title: String
    let description: String
    let expectedObjects: [String]
    let expectedMotion: String
    let expectedDurationSeconds: Int
    let mistakePatterns: [MistakePattern]
    let correctionMode: String
    
    // New fields for Version 2 (local AI)
    var clipUrl: String?
    var localFeedbackRules: [String: String]?
    var requiredTools: [String]?
    
    // Audio/Voice Guidance
    var instruction: String?
    var audioUrl: String?
    
    var id: Int { stepId }
    
    enum CodingKeys: String, CodingKey {
        case stepId = "step_id"
        case title, description
        case expectedObjects = "expected_objects"
        case expectedMotion = "expected_motion"
        case expectedDurationSeconds = "expected_duration_seconds"
        case mistakePatterns = "mistake_patterns"
        case correctionMode = "correction_mode"
        case clipUrl = "clip_url"
        case localFeedbackRules = "local_feedback_rules"
        case requiredTools = "required_tools"
        case instruction
        case audioUrl = "audio_url"
    }
}

struct MistakePattern: Codable, Identifiable {
    let type: String
    let description: String
    
    var id: String { type }
}

// MARK: - Overlay Models

struct OverlayInstruction: Codable {
    let overlayType: String
    let audioText: String
    let elements: [OverlayElement]
    let durationSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case overlayType = "overlay_type"
        case audioText = "audio_text"
        case elements
        case durationSeconds = "duration_seconds"
    }
}

enum OverlayElement: Codable {
    case circle(CircleElement)
    case arrow(ArrowElement)
    case label(LabelElement)
    case rectangle(RectangleElement)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "circle":
            self = .circle(try CircleElement(from: decoder))
        case "arrow":
            self = .arrow(try ArrowElement(from: decoder))
        case "label":
            self = .label(try LabelElement(from: decoder))
        case "rectangle":
            self = .rectangle(try RectangleElement(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown overlay element type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .circle(let element):
            try element.encode(to: encoder)
        case .arrow(let element):
            try element.encode(to: encoder)
        case .label(let element):
            try element.encode(to: encoder)
        case .rectangle(let element):
            try element.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct CircleElement: Codable {
    let type: String
    let center: [Double]
    let radius: Double
    let color: String
    let strokeWidth: Double?
    let style: String?
    let fill: String?
    
    enum CodingKeys: String, CodingKey {
        case type, center, radius, color
        case strokeWidth = "stroke_width"
        case style, fill
    }
}

struct ArrowElement: Codable {
    let type: String
    let from: [Double]
    let to: [Double]
    let color: String
    let strokeWidth: Double?
    let style: String?
    let headStyle: String?
    
    enum CodingKeys: String, CodingKey {
        case type, from, to, color
        case strokeWidth = "stroke_width"
        case style
        case headStyle = "head_style"
    }
}

struct LabelElement: Codable {
    let type: String
    let position: [Double]
    let text: String
    let fontSize: Int?
    let color: String?
    let background: String?
    
    enum CodingKeys: String, CodingKey {
        case type, position, text
        case fontSize = "font_size"
        case color, background
    }
}

struct RectangleElement: Codable {
    let type: String
    let origin: [Double]
    let size: [Double]
    let color: String
    let strokeWidth: Double?
    let cornerRadius: Double?
    
    enum CodingKeys: String, CodingKey {
        case type, origin, size, color
        case strokeWidth = "stroke_width"
        case cornerRadius = "corner_radius"
    }
}

// MARK: - API Request/Response

struct FeedbackRequest: Codable {
    let lessonId: String
    let stepId: Int
    let mistakeType: String
    let confidence: Double
    let frameBase64: String?
    
    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case stepId = "step_id"
        case mistakeType = "mistake_type"
        case confidence
        case frameBase64 = "frame_base64"
    }
}

struct FeedbackResponse: Codable {
    let success: Bool
    let overlay: OverlayInstruction?
    let message: String?
}
