import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
    case askUser
}

@Model
final class Message {
    // Thread-safe JSON encoder/decoder
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let lock = NSLock()
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var isStreaming: Bool
    var conversationId: UUID?
    
    // Thinking / Reasoning
    var reasoningContent: String?
    var isReasoningExpanded: Bool
    
    // For tool calls - stored as JSON strings since SwiftData doesn't support complex nested types directly
    var toolCallsData: Data?
    var toolResultsData: Data?
    var activeToolData: Data?
    
    // Ask User Question (for pending state)
    var pendingQuestion: String?
    var questionResponse: String?
    
    // Token usage (if available)
    var tokenCount: Int?
    
    // Canvas reference
    var canvasId: UUID?
    
    // Relationships
    @Relationship
    var conversation: Conversation?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String = "",
        conversation: Conversation? = nil,
        isStreaming: Bool = false,
        reasoningContent: String? = nil,
        isReasoningExpanded: Bool = false,
        pendingQuestion: String? = nil,
        questionResponse: String? = nil,
        tokenCount: Int? = nil,
        canvasId: UUID? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.conversation = conversation
        self.isStreaming = isStreaming
        self.reasoningContent = reasoningContent
        self.isReasoningExpanded = isReasoningExpanded
        self.pendingQuestion = pendingQuestion
        self.questionResponse = questionResponse
        self.tokenCount = tokenCount
        self.canvasId = canvasId
    }
    
    // MARK: - Computed Properties for Tool Data
    
    var toolCalls: [ToolCall]? {
        get {
            guard let data = toolCallsData else { return nil }
            Self.lock.lock()
            defer { Self.lock.unlock() }
            return try? Self.decoder.decode([ToolCall].self, from: data)
        }
        set {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            toolCallsData = newValue.map { try? Self.encoder.encode($0) }
        }
    }
    
    var toolResults: [ToolResult]? {
        get {
            guard let data = toolResultsData else { return nil }
            Self.lock.lock()
            defer { Self.lock.unlock() }
            return try? Self.decoder.decode([ToolResult].self, from: data)
        }
        set {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            toolResultsData = newValue.map { try? Self.encoder.encode($0) }
        }
    }
    
    var activeTool: ActiveTool? {
        get {
            guard let data = activeToolData else { return nil }
            Self.lock.lock()
            defer { Self.lock.unlock() }
            return try? Self.decoder.decode(ActiveTool.self, from: data)
        }
        set {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            activeToolData = newValue.map { try? Self.encoder.encode($0) }
        }
    }
    
    // MARK: - Helpers
    
    func appendContent(_ text: String) {
        self.content += text
    }
    
    func appendReasoning(_ text: String) {
        if self.reasoningContent == nil {
            self.reasoningContent = ""
        }
        self.reasoningContent! += text
    }
    
    func updateActiveTool(status: ToolStatus? = nil, preview: String? = nil, duration: Double? = nil) {
        var tool = activeTool ?? ActiveTool(
            name: "Unknown",
            status: .running,
            preview: "",
            startTime: Date()
        )
        
        if let status = status {
            tool.status = status
        }
        if let preview = preview {
            tool.preview = preview
        }
        if let duration = duration {
            tool.duration = duration
        }
        
        self.activeTool = tool
    }
    
    func addToolCall(_ toolCall: ToolCall) {
        var calls = toolCalls ?? []
        calls.append(toolCall)
        toolCalls = calls
    }
    
    func addToolResult(_ toolResult: ToolResult) {
        var results = toolResults ?? []
        results.append(toolResult)
        toolResults = results
    }
}

// MARK: - Query Extensions
extension Message {
    static func forConversation(_ conversationId: UUID) -> FetchDescriptor<Message> {
        var descriptor = FetchDescriptor<Message>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.predicate = #Predicate { message in
            message.conversationId == conversationId
        }
        return descriptor
    }
}
