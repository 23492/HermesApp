import SwiftUI

// MARK: - Chat View

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(AppState.self) private var appState
    @StateObject private var canvasViewModel = CanvasViewModel()
    @State private var scrollToBottom = false
    @State private var showingError = false
    @State private var showingTypingIndicator = false
    @State private var showingCanvas = false
    @State private var notificationObservers: [NSObjectProtocol] = []
    
    var body: some View {
        CanvasContainer(viewModel: canvasViewModel) {
            chatContent
        }
        .onAppear {
            setupNotificationHandlers()
            setupCanvasBindings()
        }
        .onDisappear {
            removeNotificationHandlers()
        }
        .onChange(of: viewModel.canvasItems) { _, newItems in
            canvasViewModel.updateItems(newItems)
            if !newItems.isEmpty && !canvasViewModel.isVisible {
                canvasViewModel.showCanvas()
            }
        }
    }
    
    // MARK: - Chat Content
    
    private var chatContent: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesList
            
            // Error banner
            if let error = viewModel.error {
                ErrorBanner(message: error) {
                    viewModel.error = nil
                }
            }
            
            // Action status bar for active tools
            if !viewModel.activeTools.isEmpty {
                ActionStatusBar(
                    activeTools: viewModel.activeTools,
                    onCancel: {
                        viewModel.cancelStreaming()
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Canvas indicator bar
            if canvasViewModel.hasItems && !canvasViewModel.isVisible {
                canvasIndicatorBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Message input
            MessageInputView(
                text: $viewModel.inputText,
                isStreaming: viewModel.isStreaming,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                onCancel: {
                    viewModel.cancelStreaming()
                },
                onModelChange: { model in
                    viewModel.changeModel(to: model)
                }
            )
        }
        .navigationTitle(viewModel.conversation.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ChatToolbarMenu(viewModel: viewModel, canvasViewModel: canvasViewModel)
            }
        }
        .sheet(item: $viewModel.pendingQuestion) { question in
            AskUserQuestionView(
                question: question,
                onSubmit: { response in
                    Task {
                        await viewModel.submitQuestionResponse(response)
                    }
                },
                onDismiss: {
                    viewModel.dismissQuestion()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.activeTools.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: canvasViewModel.hasItems)
    }
    
    // MARK: - Canvas Indicator Bar
    
    private var canvasIndicatorBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "square.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                
                Text("\(canvasViewModel.items.count) canvas item\(canvasViewModel.items.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Button {
                canvasViewModel.showCanvas()
            } label: {
                Text("Show Canvas")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondarySystemBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.secondary.opacity(0.2)),
            alignment: .top
        )
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageBubble(message: message, canvasViewModel: canvasViewModel)
                            .id(message.id)
                            .contextMenu {
                                MessageContextMenu(message: message, viewModel: viewModel)
                            }
                    }
                    
                    // Streaming message
                    if let streamingMessage = viewModel.streamingMessage {
                        MessageBubble(message: streamingMessage, canvasViewModel: canvasViewModel)
                            .id("streaming")
                    }
                    
                    // Typing indicator during streaming
                    if viewModel.isStreaming && viewModel.streamingMessage == nil {
                        TypingIndicatorBubble()
                            .id("typing")
                    }
                    
                    // Bottom spacer for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingMessage?.content) { _, _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    // MARK: - Notification Handlers
    
    private func setupNotificationHandlers() {
        // Handle regenerate message notification
        let regenerateObserver = NotificationCenter.default.addObserver(
            forName: .regenerateMessage,
            object: nil,
            queue: .main
        ) { notification in
            Task {
                await viewModel.regenerateLastMessage()
            }
        }
        notificationObservers.append(regenerateObserver)
        
        // Handle edit message notification
        let editObserver = NotificationCenter.default.addObserver(
            forName: .editMessage,
            object: nil,
            queue: .main
        ) { notification in
            guard let messageId = notification.userInfo?["messageId"] as? UUID,
                  let newContent = notification.userInfo?["newContent"] as? String else { return }
            
            Task {
                await viewModel.editMessage(id: messageId, newContent: newContent)
            }
        }
        notificationObservers.append(editObserver)
    }
    
    private func removeNotificationHandlers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    // MARK: - Canvas Bindings
    
    private func setupCanvasBindings() {
        // Forward canvas apply changes back to conversation
        // This allows the user to apply canvas edits back to the chat
    }
}

// MARK: - Typing Indicator Bubble

struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 4) {
                TypingIndicator()
            }
            .padding(12)
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Spacer()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Chat Toolbar Menu

struct ChatToolbarMenu: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var canvasViewModel: CanvasViewModel
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        Menu {
            // Canvas toggle
            Button {
                canvasViewModel.toggleVisibility()
            } label: {
                Label(
                    canvasViewModel.isVisible ? "Hide Canvas" : "Show Canvas",
                    systemImage: canvasViewModel.isVisible ? "square.fill" : "square"
                )
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            // Canvas layout submenu
            if canvasViewModel.isVisible {
                Menu {
                    ForEach(CanvasLayout.allCases, id: \.self) { layout in
                        Button {
                            canvasViewModel.setLayout(layout)
                        } label: {
                            Label(
                                layout.displayName,
                                systemImage: layout.icon
                            )
                            if canvasViewModel.layout == layout {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Label("Canvas Layout", systemImage: "square.split.2x1")
                }
            }
            
            Divider()
            
            // Regenerate option
            Button {
                Task {
                    await viewModel.regenerateLastMessage()
                }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isStreaming || viewModel.messages.isEmpty || viewModel.messages.last?.role != .assistant)
            
            // Copy conversation
            Button {
                viewModel.copyConversation()
            } label: {
                Label("Copy Conversation", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.messages.isEmpty)
            
            Divider()
            
            // Clear conversation
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear Messages", systemImage: "trash")
            }
            .disabled(viewModel.messages.isEmpty)
            
            Divider()
            
            // Settings
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .confirmationDialog(
            "Clear all messages?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Messages", role: .destructive) {
                Task {
                    await viewModel.clearMessages()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingSettings) {
            ChatSettingsSheet(viewModel: viewModel, canvasViewModel: canvasViewModel)
        }
    }
}

// MARK: - Message Context Menu

struct MessageContextMenu: View {
    let message: Message
    let viewModel: ChatViewModel
    
    var body: some View {
        // Copy
        Button {
            viewModel.copyMessageContent(message)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        // Copy to canvas (if code detected)
        if detectCodeBlocks(in: message.content) {
            Button {
                // Would copy code blocks to canvas
            } label: {
                Label("Copy Code to Canvas", systemImage: "curlybraces")
            }
        }
        
        // Edit (user only)
        if message.role == .user {
            Button {
                NotificationCenter.default.post(
                    name: .editMessage,
                    object: nil,
                    userInfo: ["messageId": message.id, "newContent": message.content]
                )
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        
        // Regenerate (assistant only)
        if message.role == .assistant {
            Button {
                Task {
                    await viewModel.regenerateLastMessage()
                }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }
        
        Divider()
        
        // Delete
        Button(role: .destructive) {
            Task {
                await viewModel.deleteMessage(message)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func detectCodeBlocks(in content: String) -> Bool {
        content.contains("```")
    }
}

// MARK: - Chat Settings Sheet

struct ChatSettingsSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var canvasViewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Picker("Model", selection: .constant(viewModel.conversation.model)) {
                        Text("Hermes Agent").tag("hermes-agent")
                        Text("GPT-4").tag("gpt-4")
                        Text("GPT-4 Turbo").tag("gpt-4-turbo")
                        Text("Claude 3 Opus").tag("claude-3-opus")
                        Text("Claude 3 Sonnet").tag("claude-3-sonnet")
                    }
                }
                
                Section("Canvas") {
                    Toggle("Show Canvas", isOn: .init(
                        get: { canvasViewModel.isVisible },
                        set: { _ in canvasViewModel.toggleVisibility() }
                    ))
                    
                    if canvasViewModel.isVisible {
                        Picker("Layout", selection: $canvasViewModel.layout) {
                            ForEach(CanvasLayout.allCases, id: \.self) { layout in
                                Label(
                                    layout.displayName,
                                    systemImage: layout.icon
                                )
                                .tag(layout)
                            }
                        }
                    }
                    
                    if canvasViewModel.hasItems {
                        Button(role: .destructive) {
                            canvasViewModel.clearItems()
                        } label: {
                            Label("Clear Canvas Items", systemImage: "trash")
                        }
                    }
                }
                
                Section("Information") {
                    LabeledContent("Title", value: viewModel.conversation.title)
                    LabeledContent("Messages", value: "\(viewModel.messages.count)")
                    LabeledContent("Created", value: formattedDate(viewModel.conversation.createdAt))
                }
                
                Section("Actions") {
                    Button {
                        Task {
                            await viewModel.regenerateLastMessage()
                            dismiss()
                        }
                    } label: {
                        Label("Regenerate Last Response", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.messages.isEmpty || viewModel.isStreaming)
                    
                    Button(role: .destructive) {
                        Task {
                            await viewModel.clearMessages()
                            dismiss()
                        }
                    } label: {
                        Label("Clear All Messages", systemImage: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .navigationTitle("Chat Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color.red)
    }
}

// MARK: - Preview

#Preview {
    let conversation = Conversation(title: "Test Conversation", model: "hermes-agent")
    
    ChatView(viewModel: ChatViewModel(
        conversation: conversation,
        apiClient: HermesAPIClient(),
        messageRepository: DIContainer.shared.messageRepository
    ))
    .environment(AppState())
}
