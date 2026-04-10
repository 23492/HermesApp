import Foundation
import SwiftUI

// MARK: - Conversation List View Model

@Observable
@MainActor
final class ConversationListViewModel {
    // MARK: - Properties
    
    private let repository: ConversationRepositoryProtocol
    
    var conversations: [Conversation] = []
    var searchQuery: String = ""
    var isLoading: Bool = false
    var error: String?
    
    var filteredConversations: [Conversation] {
        if searchQuery.isEmpty {
            return conversations
        }
        let lowerQuery = searchQuery.lowercased()
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowerQuery)
        }
    }
    
    // MARK: - Initialization
    
    init(repository: ConversationRepositoryProtocol) {
        self.repository = repository
        
        Task {
            await loadConversations()
        }
    }
    
    // MARK: - Loading
    
    func loadConversations() async {
        isLoading = true
        error = nil
        
        do {
            conversations = try repository.fetchConversations()
        } catch {
            self.error = "Failed to load conversations: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func search() async {
        guard !searchQuery.isEmpty else {
            await loadConversations()
            return
        }
        
        do {
            conversations = try repository.searchConversations(query: searchQuery)
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CRUD Operations
    
    func createConversation(title: String = "New Conversation", model: String = "hermes-agent") -> Conversation {
        let conversation = Conversation(
            title: title,
            model: model
        )
        
        do {
            try repository.saveConversation(conversation)
            conversations.insert(conversation, at: 0)
            return conversation
        } catch {
            self.error = "Failed to create conversation: \(error.localizedDescription)"
            return conversation
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        do {
            try repository.deleteConversation(conversation)
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations.remove(at: index)
            }
        } catch {
            self.error = "Failed to delete conversation: \(error.localizedDescription)"
        }
    }
    
    func archiveConversation(_ conversation: Conversation) {
        conversation.isArchived = true
        do {
            try repository.saveConversation(conversation)
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations.remove(at: index)
            }
        } catch {
            self.error = "Failed to archive conversation: \(error.localizedDescription)"
        }
    }
    
    func updateConversation(_ conversation: Conversation) {
        do {
            conversation.updateTimestamp()
            try repository.saveConversation(conversation)
            
            // Re-sort conversations
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            self.error = "Failed to update conversation: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helpers
    
    func getConversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }
}
