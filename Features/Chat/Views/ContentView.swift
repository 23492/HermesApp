import SwiftUI

// MARK: - Content View (Main App View)

struct ContentView: View {
    @State private var appState = AppState()
    @State private var selectedConversationId: UUID?
    @State private var showingNewConversation = false
    
    var body: some View {
        NavigationSplitView {
            ConversationListView(
                selectedConversationId: $selectedConversationId
            )
        } detail: {
            if let conversationId = selectedConversationId {
                ConversationDetailView(conversationId: conversationId)
            } else {
                EmptyStateView()
            }
        }
        .environment(appState)
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Welcome to Hermes")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("Select a conversation or start a new one to begin chatting with your AI assistant.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button("New Conversation") {
                // Will trigger new conversation via environment or notification
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Conversation Detail View

struct ConversationDetailView: View {
    let conversationId: UUID
    
    @Environment(\.conversationRepository) private var conversationRepository
    @State private var viewModel: ChatViewModel?
    @State private var conversation: Conversation?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                ChatView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            await loadConversation()
        }
        .id(conversationId)
    }
    
    private func loadConversation() async {
        do {
            if let conv = try conversationRepository.fetchConversation(id: conversationId) {
                conversation = conv
                let apiClient = await DIContainer.shared.getAPIClient()
                viewModel = ChatViewModel(
                    conversation: conv,
                    apiClient: apiClient,
                    messageRepository: DIContainer.shared.messageRepository
                )
            }
        } catch {
            print("Failed to load conversation: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(SwiftDataStack.previewContainer)
}
