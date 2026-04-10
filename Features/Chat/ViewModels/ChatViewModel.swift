import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Chat View Model

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Properties
    
    let conversation: Conversation
    private let apiClient: HermesAPIClient
    private let messageRepository: MessageRepositoryProtocol
    
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isStreaming: Bool = false
    @Published var streamingMessage: Message?
    @Published var error: String?
    
    // Tool tracking
    @Published var activeTools: [ActiveTool] = []
    @Published var toolResults: [ToolResult] = []
    
    // Reasoning tracking
    @Published var currentReasoning: String = ""
    @Published var isReasoning: Bool = false
    
    // Ask User Question tracking
    @Published var pendingQuestion: AskUserQuestion?
    @Published var questionHistory: [AskUserQuestion] = []
    
    // Canvas tracking
    @Published var canvasItems: [CanvasItem] = []
    @Published var currentCanvasId: UUID?
    
    private var streamingTask: Task<Void, Never>?
    private var cancellationToken = CancellationToken()
    private var currentToolCalls: [String: ToolCall] = [:] // Track by ID
    private var currentRunId: String?
    
    // MARK: - Initialization
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        conversation: Conversation,
        apiClient: HermesAPIClient,
        messageRepository: MessageRepositoryProtocol
    ) {
        self.conversation = conversation
        self.apiClient = apiClient
        self.messageRepository = messageRepository
        
        // Load existing messages
        Task {
            await loadMessages()
        }
        
        // Set up notification observers
        setupNotificationObservers()
    }
    
    deinit {
        streamingTask?.cancel()
        Task {
            await cancellationToken.cancel()
        }
        cancellables.removeAll()
    }
    
    private func setupNotificationObservers() {
        // Observe question response notifications
        NotificationCenter.default
            .publisher(for: .submitQuestionResponse)
            .compactMap { $0.userInfo?["response"] as? String }
            .sink { [weak self] response in
                Task { @MainActor in
                    await self?.submitQuestionResponse(response)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Message Loading
    
    func loadMessages() async {
        do {
            messages = try messageRepository.fetchMessages(for: conversation.id)
        } catch {
            self.error = "Failed to load messages: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userContent = inputText
        inputText = ""
        
        // Create and save user message
        let userMessage = Message(
            role: .user,
            content: userContent,
            conversation: conversation
        )
        
        do {
            try messageRepository.saveMessage(userMessage)
            messages.append(userMessage)
            
            // Update conversation title if first message
            if messages.count == 1 {
                conversation.generateTitle(from: userContent)
            }
            
            // Start streaming response
            await startStreaming(userContent: userContent)
            
        } catch {
            self.error = "Failed to send message: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Streaming
    
    private func startStreaming(userContent: String) async {
        isStreaming = true
        error = nil
        activeTools.removeAll()
        toolResults.removeAll()
        currentToolCalls.removeAll()
        
        // Create streaming message
        let assistantMessage = Message(
            role: .assistant,
            content: "",
            conversation: conversation,
            isStreaming: true
        )
        
        self.streamingMessage = assistantMessage
        
        // Build chat messages from history
        let chatMessages = buildChatMessages(userContent: userContent)
        
        let request = ChatRequest(
            model: conversation.model,
            messages: chatMessages,
            stream: true
        )
        
        streamingTask = Task {
            do {
                let stream = try await apiClient.sendMessage(
                    request,
                    sessionId: conversation.sessionId,
                    cancellationToken: cancellationToken
                )
                
                var fullContent = ""
                var toolCalls: [ToolCall] = []
                var reasoningContent = ""
                
                for await chunk in stream {
                    guard !Task.isCancelled else { break }
                    
                    // Handle reasoning content
                    if let reasoning = chunk.reasoningContent {
                        reasoningContent += reasoning
                        currentReasoning = reasoningContent
                        isReasoning = true
                        assistantMessage.reasoningContent = reasoningContent
                        assistantMessage.isReasoningExpanded = true
                    }
                    
                    // Handle event type for special events
                    if let eventType = chunk.eventType {
                        handleSpecialEvent(eventType, chunk: chunk, message: assistantMessage)
                    }
                    
                    // Process chunk
                    if let delta = chunk.choices.first?.delta {
                        // Handle content
                        if let content = delta.content {
                            // Check for embedded question data
                            if content.hasPrefix("__ASK_USER_QUESTION__:") {
                                parseAndHandleQuestion(from: content, message: assistantMessage)
                            } else {
                                fullContent += content
                                assistantMessage.content = fullContent
                            }
                        }
                        
                        // Handle tool calls from delta
                        if let apiToolCalls = delta.toolCalls {
                            for apiCall in apiToolCalls {
                                await processAPIToolCall(apiCall, toolCalls: &toolCalls, message: assistantMessage)
                            }
                        }
                    }
                    
                    // Check for finish reason
                    if chunk.choices.first?.finishReason != nil {
                        break
                    }
                }
                
                // Save any remaining tool calls
                for (_, toolCall) in currentToolCalls {
                    if !toolCalls.contains(where: { $0.id == toolCall.id }) {
                        toolCalls.append(toolCall)
                    }
                }
                
                assistantMessage.toolCalls = toolCalls.isEmpty ? nil : toolCalls
                assistantMessage.toolResults = toolResults.isEmpty ? nil : toolResults
                
                // Mark streaming complete
                assistantMessage.isStreaming = false
                isReasoning = false
                
                // Mark all active tools as completed
                for index in activeTools.indices where activeTools[index].status == .running {
                    activeTools[index].complete(success: true)
                }
                
                // Save message
                try? messageRepository.saveMessage(assistantMessage)
                messages.append(assistantMessage)
                
            } catch {
                if let apiError = error as? APIError, apiError == .cancelled {
                    // User cancelled, don't show error
                } else {
                    self.error = error.localizedDescription
                }
                
                // Clean up streaming message
                assistantMessage.isStreaming = false
                isReasoning = false
            }
            
            isStreaming = false
            streamingMessage = nil
            activeTools.removeAll()
            currentReasoning = ""
        }
    }
    
    // MARK: - Tool Call Processing
    
    private func processAPIToolCall(
        _ apiCall: APIToolCall,
        toolCalls: inout [ToolCall],
        message: Message
    ) async {
        let toolCallId = apiCall.id
        
        if var existing = currentToolCalls[toolCallId] {
            // Accumulate arguments for existing tool call
            existing.arguments += apiCall.function.arguments
            currentToolCalls[toolCallId] = existing
        } else {
            // New tool call
            let newToolCall = ToolCall(
                id: toolCallId,
                name: apiCall.function.name,
                arguments: apiCall.function.arguments
            )
            currentToolCalls[toolCallId] = newToolCall
            toolCalls.append(newToolCall)
            
            // Create active tool for UI
            let activeTool = ActiveTool(
                name: apiCall.function.name,
                status: .running,
                preview: "Running \(apiCall.function.name)...",
                startTime: Date()
            )
            activeTools.append(activeTool)
            message.activeTool = activeTool
            
            Log.debug("Tool started: \(apiCall.function.name) [\(toolCallId)]")
        }
    }
    
    // MARK: - Tool Event Handlers
    
    func handleToolStarted(name: String, preview: String?, toolCallId: String?) {
        let activeTool = ActiveTool(
            name: name,
            status: .running,
            preview: preview ?? "Running \(name)...",
            startTime: Date()
        )
        
        activeTools.append(activeTool)
        
        if let message = streamingMessage {
            message.activeTool = activeTool
        }
        
        Log.debug("Tool started event: \(name)")
    }
    
    func handleToolCompleted(name: String, output: String?, duration: Double?, toolCallId: String?) {
        // Update active tool status
        if let index = activeTools.firstIndex(where: { $0.name == name && $0.status == .running }) {
            activeTools[index].complete(success: true)
            if let duration = duration {
                activeTools[index].duration = duration
            }
        }
        
        // Create tool result
        if let toolCallId = toolCallId {
            let result = ToolResult(
                toolCallId: toolCallId,
                output: output ?? "Completed successfully",
                isError: false
            )
            toolResults.append(result)
            
            if let message = streamingMessage {
                message.addToolResult(result)
            }
        }
        
        Log.debug("Tool completed: \(name), duration: \(duration ?? 0)s")
    }
    
    func handleToolError(name: String, error: String, toolCallId: String?) {
        // Update active tool status
        if let index = activeTools.firstIndex(where: { $0.name == name && $0.status == .running }) {
            activeTools[index].complete(success: false)
        }
        
        // Create error result
        if let toolCallId = toolCallId {
            let result = ToolResult(
                toolCallId: toolCallId,
                output: error,
                isError: true
            )
            toolResults.append(result)
            
            if let message = streamingMessage {
                message.addToolResult(result)
            }
        }
        
        Log.error("Tool error: \(name) - \(error)")
    }
    
    // MARK: - Special Event Handlers
    
    private func handleSpecialEvent(_ eventType: String, chunk: ChatChunk, message: Message) {
        switch eventType {
        case "reasoning.available", "reasoning.delta":
            if let reasoning = chunk.reasoningContent {
                message.appendReasoning(reasoning)
                currentReasoning = message.reasoningContent ?? ""
                isReasoning = true
                message.isReasoningExpanded = true
            }
            
        case "ask_user.question":
            // Question is handled through delta content parsing
            break
            
        case "tool.started":
            // Handle tool started event from SSE
            if let metadata = extractMetadata(from: chunk) {
                handleToolStarted(
                    name: metadata["tool_name"] ?? "Tool",
                    preview: metadata["tool_preview"],
                    toolCallId: metadata["tool_call_id"]
                )
            }
            
        case "tool.completed":
            if let metadata = extractMetadata(from: chunk) {
                let duration = metadata["tool_duration"].flatMap { Double($0) }
                handleToolCompleted(
                    name: metadata["tool_name"] ?? "Tool",
                    output: metadata["tool_output"],
                    duration: duration,
                    toolCallId: metadata["tool_call_id"]
                )
            }
            
        case "tool.error":
            if let metadata = extractMetadata(from: chunk) {
                handleToolError(
                    name: metadata["tool_name"] ?? "Tool",
                    error: metadata["tool_error"] ?? "Unknown error",
                    toolCallId: metadata["tool_call_id"]
                )
            }
            
        case "canvas.update":
            // Handle canvas update event from SSE
            if let items = extractCanvasItems(from: chunk) {
                handleCanvasUpdate(items)
            }
            
        default:
            break
        }
    }
    
    private func extractCanvasItems(from chunk: ChatChunk) -> [CanvasItem]? {
        // Canvas items would be passed in the chunk's metadata or content
        // This is a placeholder for the actual extraction logic
        return nil
    }
    
    func handleCanvasUpdate(_ items: [CanvasItem]) {
        // Merge new items with existing ones
        for item in items {
            if let index = canvasItems.firstIndex(where: { $0.id == item.id }) {
                canvasItems[index] = item
            } else {
                canvasItems.append(item)
            }
        }
        
        // Update the streaming message's canvas reference
        if let message = streamingMessage {
            message.canvasId = items.first?.id
        }
        
        Log.debug("Canvas updated with \(items.count) items, total: \(canvasItems.count)")
    }
    
    func handleCanvasEvent(_ event: RunEvent) {
        switch event {
        case .canvasUpdate(let items):
            handleCanvasUpdate(items)
        default:
            break
        }
    }
    
    func applyCanvasChanges(_ item: CanvasItem) {
        // Apply canvas changes back to the conversation
        // This could create a new message or update existing content
        let updateMessage = Message(
            role: .system,
            content: "[Canvas Update] Applied changes to \(item.title)",
            conversation: conversation
        )
        
        do {
            try messageRepository.saveMessage(updateMessage)
            messages.append(updateMessage)
        } catch {
            Log.error("Failed to save canvas update message: \(error.localizedDescription)")
        }
    }
    
    private func extractMetadata(from chunk: ChatChunk) -> [String: String]? {
        // Extract metadata from chunk if available
        // This is a placeholder - actual implementation depends on how metadata is passed
        return nil
    }
    
    private func parseAndHandleQuestion(from content: String, message: Message) {
        // Parse question from embedded content
        // Format: __ASK_USER_QUESTION__:{json_data}
        guard let jsonStart = content.firstIndex(of: ":"),
              jsonStart < content.endIndex else { return }
        
        let jsonString = String(content[content.index(after: jsonStart)...])
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questionText = json["question"] as? String else { return }
        
        let questionType = json["question_type"] as? String ?? "text"
        let options = json["options"] as? [String]
        let context = json["context"] as? String
        
        let question = AskUserQuestion(
            question: questionText,
            questionType: QuestionType(rawValue: questionType) ?? .text,
            options: options,
            context: context
        )
        
        pendingQuestion = question
        message.pendingQuestion = questionText
        
        Log.debug("Received question from AI: \(questionText)")
    }
    
    // MARK: - User Response Submission
    
    func submitQuestionResponse(_ response: String) async {
        guard let question = pendingQuestion else { return }
        
        // Update question state
        var answeredQuestion = question
        answeredQuestion.submitResponse(response)
        questionHistory.append(answeredQuestion)
        
        // Find the message with pending question and update it
        if let message = messages.last(where: { $0.pendingQuestion != nil }) {
            message.pendingQuestion = nil
            message.questionResponse = response
        }
        
        // Clear pending question
        pendingQuestion = nil
        
        // Submit to API if using run-based API
        if let runId = currentRunId {
            do {
                try await apiClient.submitUserResponse(runId: runId, response: response)
                Log.debug("Submitted user response for run \(runId)")
            } catch {
                Log.error("Failed to submit user response: \(error.localizedDescription)")
                self.error = "Failed to submit response: \(error.localizedDescription)"
            }
        }
        
        // Create user message for the response
        let responseMessage = Message(
            role: .user,
            content: response,
            conversation: conversation
        )
        
        do {
            try messageRepository.saveMessage(responseMessage)
            messages.append(responseMessage)
        } catch {
            Log.error("Failed to save response message: \(error.localizedDescription)")
        }
    }
    
    func dismissQuestion() {
        pendingQuestion = nil
        
        // Clear pending question from message
        if let message = messages.last(where: { $0.pendingQuestion != nil }) {
            message.pendingQuestion = nil
        }
    }
    
    private func buildChatMessages(userContent: String) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []
        
        // Add system message if needed
        chatMessages.append(ChatMessage(
            role: "system",
            content: "You are a helpful AI assistant."
        ))
        
        // Add conversation history
        for message in messages where !message.isStreaming {
            let role: String
            switch message.role {
            case .user: role = "user"
            case .assistant: role = "assistant"
            case .system: role = "system"
            case .tool: role = "tool"
            case .askUser: role = "user" // Treat ask user as user role
            }
            
            var chatMessage = ChatMessage(
                role: role,
                content: message.content
            )
            
            // Add tool calls if present
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                chatMessage = ChatMessage(
                    role: role,
                    content: message.content,
                    toolCalls: toolCalls.map { toolCall in
                        APIToolCall(
                            id: toolCall.id,
                            type: "function",
                            function: ToolFunctionCall(
                                name: toolCall.name,
                                arguments: toolCall.arguments
                            )
                        )
                    }
                )
            }
            
            // Add tool results if present
            if let toolResults = message.toolResults {
                for result in toolResults {
                    chatMessages.append(ChatMessage(
                        role: "tool",
                        content: result.output,
                        toolCallId: result.toolCallId
                    ))
                }
            }
            
            chatMessages.append(chatMessage)
        }
        
        // Add current user message
        chatMessages.append(ChatMessage(
            role: "user",
            content: userContent
        ))
        
        return chatMessages
    }
    
    // MARK: - Actions
    
    func cancelStreaming() {
        Task {
            await cancellationToken.cancel()
            streamingTask?.cancel()
            
            // Clean up streaming message
            if let streamingMessage = streamingMessage {
                streamingMessage.isStreaming = false
                if !streamingMessage.content.isEmpty {
                    try? messageRepository.saveMessage(streamingMessage)
                    messages.append(streamingMessage)
                }
            }
            
            isStreaming = false
            self.streamingMessage = nil
        }
    }
    
    func regenerateLastMessage() async {
        guard let lastMessage = messages.last,
              lastMessage.role == .assistant else { return }
        
        // Find the user message before this
        guard messages.count >= 2 else { return }
        let userMessage = messages[messages.count - 2]
        
        // Remove last message
        do {
            try messageRepository.deleteMessage(lastMessage)
            messages.removeLast()
            
            // Resend the user content
            inputText = userMessage.content
            await sendMessage()
        } catch {
            self.error = "Failed to regenerate: \(error.localizedDescription)"
        }
    }
    
    func deleteMessage(_ message: Message) async {
        do {
            try messageRepository.deleteMessage(message)
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages.remove(at: index)
            }
        } catch {
            self.error = "Failed to delete message: \(error.localizedDescription)"
        }
    }
    
    func copyMessageContent(_ message: Message) {
        #if os(iOS)
        UIPasteboard.general.string = message.content
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
    }
    
    // MARK: - Edit Message
    
    func editMessage(id: UUID, newContent: String) async {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              messages[index].role == .user else { return }
        
        // Update the message content
        messages[index].content = newContent
        
        do {
            try messageRepository.saveMessage(messages[index])
            
            // Remove all messages after this one (they're now invalid)
            let messagesToDelete = messages.suffix(from: index + 1)
            for message in messagesToDelete {
                try? messageRepository.deleteMessage(message)
            }
            messages.removeSubrange(index + 1..<messages.count)
            
            // Resend with new content
            inputText = newContent
            await sendMessage()
        } catch {
            self.error = "Failed to edit message: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Change Model
    
    func changeModel(to model: String) {
        conversation.model = model
        // The conversation model is saved via SwiftData automatically
    }
    
    // MARK: - Copy Conversation
    
    func copyConversation() {
        let conversationText = messages.map { message in
            let role = message.role == .user ? "User" : "Assistant"
            return "**\(role)**: \(message.content)"
        }.joined(separator: "\n\n")
        
        #if os(iOS)
        UIPasteboard.general.string = conversationText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversationText, forType: .string)
        #endif
    }
    
    // MARK: - Clear Messages
    
    func clearMessages() async {
        do {
            for message in messages {
                try messageRepository.deleteMessage(message)
            }
            messages.removeAll()
            canvasItems.removeAll()
        } catch {
            self.error = "Failed to clear messages: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Canvas Management
    
    func clearCanvas() {
        canvasItems.removeAll()
        currentCanvasId = nil
    }
}

// MARK: - Streaming Service

@MainActor
final class StreamingService: ObservableObject {
    private let apiClient: HermesAPIClient
    private var activeTask: Task<Void, Never>?
    
    init(apiClient: HermesAPIClient) {
        self.apiClient = apiClient
    }
    
    deinit {
        activeTask?.cancel()
    }
    
    func streamResponse(
        messages: [ChatMessage],
        model: String,
        sessionId: String? = nil,
        onChunk: @escaping @Sendable (String) -> Void,
        onToolCall: @escaping @Sendable (ToolCall) -> Void,
        onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> Task<Void, Never> {
        let task = Task {
            do {
                let request = ChatRequest(
                    model: model,
                    messages: messages,
                    stream: true
                )
                
                let cancellationToken = CancellationToken()
                let stream = try await apiClient.sendMessage(
                    request,
                    sessionId: sessionId,
                    cancellationToken: cancellationToken
                )
                
                for await chunk in stream {
                    if Task.isCancelled { break }
                    
                    if let content = chunk.choices.first?.delta?.content {
                        onChunk(content)
                    }
                    
                    if let apiToolCalls = chunk.choices.first?.delta?.toolCalls {
                        for apiCall in apiToolCalls {
                            let toolCall = ToolCall(
                                id: apiCall.id,
                                name: apiCall.function.name,
                                arguments: apiCall.function.arguments
                            )
                            onToolCall(toolCall)
                        }
                    }
                }
                
                onComplete(.success(()))
            } catch {
                onComplete(.failure(error))
            }
        }
        activeTask = task
        return task
    }
}
