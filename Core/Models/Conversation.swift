import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var model: String
    var sessionId: String?
    var runId: String?
    
    // Metadata
    var totalTokens: Int?
    var isArchived: Bool
    var tags: [String]
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]?
    
    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        model: String = "hermes-agent",
        sessionId: String? = nil,
        runId: String? = nil,
        totalTokens: Int? = nil,
        isArchived: Bool = false,
        tags: [String] = [],
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.model = model
        self.sessionId = sessionId
        self.runId = runId
        self.totalTokens = totalTokens
        self.isArchived = isArchived
        self.tags = tags
        self.messages = messages
    }
    
    func updateTimestamp() {
        self.updatedAt = Date()
    }
    
    func generateTitle(from content: String) {
        // Use first line or first 50 characters as title
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = trimmed.split(separator: "\n").first {
            let line = String(firstLine)
            if line.count > 50 {
                self.title = String(line.prefix(50)) + "..."
            } else {
                self.title = line
            }
        } else {
            self.title = "Conversation"
        }
    }
}

// MARK: - Query Extensions
extension Conversation {
    static var all: FetchDescriptor<Conversation> {
        var descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate { $0.isArchived == false }
        return descriptor
    }
    
    static var archived: FetchDescriptor<Conversation> {
        var descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate { $0.isArchived == true }
        return descriptor
    }
}
