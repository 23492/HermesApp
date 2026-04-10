import SwiftUI

// MARK: - Conversation List View

struct ConversationListView: View {
    @Binding var selectedConversationId: UUID?
    @Environment(\.conversationRepository) private var conversationRepository
    @State private var viewModel: ConversationListViewModel?
    @State private var showingDeleteConfirmation = false
    @State private var conversationToDelete: Conversation?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                conversationListContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            viewModel = ConversationListViewModel(
                repository: conversationRepository
            )
        }
    }
    
    @ViewBuilder
    private func conversationListContent(viewModel: ConversationListViewModel) -> some View {
        List(selection: $selectedConversationId) {
            ForEach(viewModel.filteredConversations, id: \.id) { conversation in
                ConversationRow(conversation: conversation)
                    .tag(conversation.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            conversationToDelete = conversation
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            viewModel.archiveConversation(conversation)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        
                        Button(role: .destructive) {
                            conversationToDelete = conversation
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: .init(
            get: { viewModel.searchQuery },
            set: { viewModel.searchQuery = $0 }
        ), placement: .sidebar, prompt: "Search conversations")
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let newConversation = viewModel.createConversation()
                    selectedConversationId = newConversation.id
                } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
            }
        }
        .confirmationDialog(
            "Delete Conversation?",
            isPresented: $showingDeleteConfirmation,
            presenting: conversationToDelete
        ) { conversation in
            Button("Delete", role: .destructive) {
                viewModel.deleteConversation(conversation)
                if selectedConversationId == conversation.id {
                    selectedConversationId = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { conversation in
            Text("This will permanently delete '\(conversation.title)' and all its messages.")
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)
            
            HStack {
                Text(relativeDateString(for: conversation.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(conversation.model)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ConversationListView(selectedConversationId: .constant(nil))
        .modelContainer(SwiftDataStack.previewContainer)
}
