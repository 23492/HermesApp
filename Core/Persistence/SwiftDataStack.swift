import Foundation
import SwiftData

// MARK: - Model Container Setup

enum SwiftDataStack {
    static let shared: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            Message.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Local only for now
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    /// Creates a new background context for thread-safe operations
    /// Use this for background operations instead of shared.mainContext
    static func newBackgroundContext() -> ModelContext {
        ModelContext(shared)
    }
}

// MARK: - Preview Support

extension SwiftDataStack {
    @MainActor
    static var previewContainer: ModelContainer {
        let schema = Schema([
            Conversation.self,
            Message.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            // Add sample data
            let context = container.mainContext
            
            let conversation = Conversation(
                title: "Sample Conversation",
                model: "hermes-agent"
            )
            context.insert(conversation)
            
            let userMessage = Message(
                role: .user,
                content: "Hello! Can you help me with SwiftUI?",
                conversation: conversation
            )
            context.insert(userMessage)
            
            let assistantMessage = Message(
                role: .assistant,
                content: "I'd be happy to help you with SwiftUI! What would you like to know? I can help with views, state management, animations, and more.",
                conversation: conversation
            )
            context.insert(assistantMessage)
            
            let toolMessage = Message(
                role: .assistant,
                content: "Let me search for relevant information about SwiftUI.",
                conversation: conversation
            )
            toolMessage.toolCalls = [
                ToolCall(
                    id: "call_123",
                    name: "web_search",
                    arguments: "{\"query\": \"SwiftUI best practices 2024\"}"
                )
            ]
            toolMessage.activeTool = ActiveTool(
                name: "web_search",
                status: .running,
                preview: "Searching for SwiftUI best practices...",
                startTime: Date()
            )
            context.insert(toolMessage)
            
            try? context.save()
            
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }
}

// MARK: - Repository Pattern

@MainActor
protocol ConversationRepositoryProtocol {
    func fetchConversations() throws -> [Conversation]
    func fetchConversation(id: UUID) throws -> Conversation?
    func saveConversation(_ conversation: Conversation) throws
    func deleteConversation(_ conversation: Conversation) throws
    func searchConversations(query: String) throws -> [Conversation]
}

@MainActor
class ConversationRepository: ConversationRepositoryProtocol {
    private let context: ModelContext
    
    init(context: ModelContext? = nil) {
        self.context = context ?? SwiftDataStack.shared.mainContext
    }
    
    func fetchConversations() throws -> [Conversation] {
        let descriptor = Conversation.all
        return try context.fetch(descriptor)
    }
    
    func fetchConversation(id: UUID) throws -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    func saveConversation(_ conversation: Conversation) throws {
        context.insert(conversation)
        try context.save()
    }
    
    func deleteConversation(_ conversation: Conversation) throws {
        context.delete(conversation)
        try context.save()
    }
    
    func searchConversations(query: String) throws -> [Conversation] {
        let lowerQuery = query.lowercased()
        let descriptor = Conversation.all
        let conversations = try context.fetch(descriptor)
        
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowerQuery) ||
            conversation.messages?.contains(where: { message in
                message.content.lowercased().contains(lowerQuery)
            }) ?? false
        }
    }
}

@MainActor
protocol MessageRepositoryProtocol {
    func fetchMessages(for conversationId: UUID) throws -> [Message]
    func saveMessage(_ message: Message) throws
    func deleteMessage(_ message: Message) throws
    func updateMessage(_ message: Message) throws
}

@MainActor
class MessageRepository: MessageRepositoryProtocol {
    private let context: ModelContext
    
    init(context: ModelContext? = nil) {
        self.context = context ?? SwiftDataStack.shared.mainContext
    }
    
    func fetchMessages(for conversationId: UUID) throws -> [Message] {
        let descriptor = Message.forConversation(conversationId)
        return try context.fetch(descriptor)
    }
    
    func saveMessage(_ message: Message) throws {
        context.insert(message)
        try context.save()
        
        // Update conversation timestamp
        if let conversation = message.conversation {
            conversation.updateTimestamp()
            try context.save()
        }
    }
    
    func deleteMessage(_ message: Message) throws {
        context.delete(message)
        try context.save()
    }
    
    func updateMessage(_ message: Message) throws {
        try context.save()
    }
}
