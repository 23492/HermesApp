import Foundation

// MARK: - API Request Models

struct ChatRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?
    let tools: [ToolDefinition]?
    
    init(
        model: String = "hermes-agent",
        messages: [ChatMessage],
        stream: Bool = true,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        tools: [ToolDefinition]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tools = tools
    }
}

struct ChatMessage: Codable, Sendable {
    let role: String // "user", "assistant", "system", "tool"
    let content: String
    let name: String? // For tool messages
    let toolCalls: [APIToolCall]?
    let toolCallId: String?
    
    init(
        role: String,
        content: String,
        name: String? = nil,
        toolCalls: [APIToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

struct ToolDefinition: Codable, Sendable {
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable, Sendable {
    let name: String
    let description: String
    let parameters: [String: AnyCodable]?
}

struct APIToolCall: Codable, Sendable {
    let id: String
    let type: String
    var function: ToolFunctionCall
}

struct ToolFunctionCall: Codable, Sendable {
    let name: String
    var arguments: String
}

// MARK: - API Response Models

struct ChatCompletion: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: TokenUsage?
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessage?
    let delta: Delta?
    let finishReason: String?
}

struct Delta: Codable {
    let role: String?
    let content: String?
    let toolCalls: [APIToolCall]?
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

// MARK: - Chat Chunk (for streaming)

struct ChatChunk: Codable {
    let id: String
    let object: String
    let created: Int?
    let model: String?
    let choices: [Choice]
    
    // Reasoning content from extended thinking
    let reasoningContent: String?
    
    // Event type for special events (reasoning, askUserQuestion, etc.)
    let eventType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case reasoningContent = "reasoning_content"
        case eventType = "event_type"
    }
}

// MARK: - SSE Event Types

enum SSEEventType: String, Codable {
    case messageDelta = "message.delta"
    case messageComplete = "message.complete"
    case reasoningAvailable = "reasoning.available"
    case reasoningDelta = "reasoning.delta"
    case askUserQuestion = "ask_user.question"
    case toolStarted = "tool.started"
    case toolCompleted = "tool.completed"
    case toolError = "tool.error"
    case toolProgress = "tool.progress"
    case canvasUpdate = "canvas.update"
    case runCompleted = "run.completed"
    case runError = "run.error"
    case error
}

// MARK: - Models List

struct ModelsResponse: Codable {
    let object: String
    let data: [ModelInfo]
}

struct ModelInfo: Codable, Identifiable {
    let id: String
    let object: String
    let created: Int?
    let ownedBy: String?
    
    var displayName: String {
        id.split(separator: "/").last.map(String.init) ?? id
    }
}

// MARK: - Run Event Models (for /v1/runs API)

enum RunEvent: Codable {
    case messageDelta(String)
    case toolStarted(name: String, preview: String, toolCallId: String?)
    case toolCompleted(name: String, duration: Double, error: Bool, output: String?)
    case reasoningAvailable(text: String)
    case askUserQuestion(question: String, questionType: String?)
    case canvasUpdate(items: [CanvasItem])
    case completed
    case error(String)
    
    enum CodingKeys: String, CodingKey {
        case type, content, name, preview, duration, error, question, questionType
        case items, toolCallId, output
    }
    
    func encode(to encoder: Encoder) throws {
        // Implementation for encoding if needed
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Simplified encoding - full implementation would handle all cases
        switch self {
        case .messageDelta(let content):
            try container.encode("message.delta", forKey: .type)
            try container.encode(content, forKey: .content)
        default:
            break
        }
    }
    
    init(from decoder: Decoder) throws {
        // Simplified decoding - actual implementation would parse from server events
        self = .completed
    }
}

// MARK: - Canvas Models

struct CanvasItem: Codable, Identifiable, Equatable {
    var id: UUID
    var type: CanvasType
    var title: String
    var content: String
    var language: String? // For code blocks
    var isEditable: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        type: CanvasType,
        title: String,
        content: String,
        language: String? = nil,
        isEditable: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.language = language
        self.isEditable = isEditable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum CanvasType: String, Codable {
    case code
    case document
    case preview
    case diff
}

// MARK: - Helper Types

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}
