import SwiftUI
import MarkdownUI

// Make Log available if not already imported
private struct Log {
    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}

// MARK: - Message Bubble View

struct MessageBubble: View {
    let message: Message
    var canvasViewModel: CanvasViewModel?
    @Environment(AppState.self) private var appState
    @State private var showActions = false
    @State private var isEditing = false
    @State private var editedContent: String = ""
    
    private var hasCodeBlocks: Bool {
        message.content.contains("```")
    }
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Reasoning content (if present and enabled)
                if let reasoning = message.reasoningContent,
                   !reasoning.isEmpty,
                   appState.showThinking {
                    ThinkingBlock(
                        reasoning: reasoning,
                        isExpanded: $message.isReasoningExpanded,
                        isStreaming: message.isStreaming
                    )
                }
                
                // Tool execution indicator (for active/running tools)
                if let activeTool = message.activeTool, message.isStreaming {
                    ToolExecutionView(tool: activeTool, style: .compact)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                
                // Tool calls list with results
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ToolCallListView(
                        toolCalls: toolCalls,
                        toolResults: message.toolResults
                    )
                }
                
                // Tool results summary (if completed)
                if let toolResults = message.toolResults, !toolResults.isEmpty && !message.isStreaming {
                    ToolResultsSummary(results: toolResults)
                }
                
                // Message content
                if !message.content.isEmpty {
                    if isEditing && message.role == .user {
                        // Edit mode for user messages
                        MessageEditView(
                            content: $editedContent,
                            onSave: saveEdit,
                            onCancel: { isEditing = false }
                        )
                    } else {
                        MessageContent(
                            text: message.content,
                            role: message.role,
                            showActions: $showActions
                        )
                        .padding(12)
                        .background(backgroundColor)
                        .foregroundColor(foregroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(borderColor, lineWidth: showActions ? 2 : 0)
                                .animation(.easeInOut(duration: 0.2), value: showActions)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                showActions.toggle()
                            }
                        }
                        .onLongPressGesture {
                            withAnimation {
                                showActions = true
                            }
                        }
                    }
                }
                
                // Message actions
                if showActions && !isEditing {
                    MessageActionsBar(
                        message: message,
                        onCopy: copyMessage,
                        onRegenerate: regenerateMessage,
                        onEdit: startEditing,
                        onCopyCodeToCanvas: hasCodeBlocks ? copyCodeToCanvas : nil,
                        onDismiss: { showActions = false }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Streaming indicator
                if message.isStreaming && message.content.isEmpty {
                    TypingIndicator()
                        .padding(12)
                        .background(backgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Pending question
                if let question = message.pendingQuestion, !question.isEmpty {
                    InlineQuestionView(
                        question: AskUserQuestion(
                            question: question,
                            questionType: .text
                        ),
                        onSubmit: { response in
                            // Post notification for view model to handle
                            NotificationCenter.default.post(
                                name: .submitQuestionResponse,
                                object: nil,
                                userInfo: ["response": response]
                            )
                        }
                    )
                }
                
                // Timestamp and status
                HStack(spacing: 6) {
                    Text(formattedTime(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if message.isStreaming {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.pulse)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.85, 700), alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant || message.role == .system {
                Spacer()
            }
        }
        .onAppear {
            editedContent = message.content
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(.systemGray6)
        case .system:
            return Color.yellow.opacity(0.2)
        case .tool:
            return Color.purple.opacity(0.1)
        case .askUser:
            return Color.orange.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system, .tool, .askUser:
            return .primary
        }
    }
    
    private var borderColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.5)
        case .assistant:
            return Color.secondary.opacity(0.3)
        default:
            return Color.clear
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyMessage() {
        #if os(iOS)
        UIPasteboard.general.string = message.content
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
        
        withAnimation {
            showActions = false
        }
    }
    
    private func regenerateMessage() {
        // Post notification for view model to handle
        NotificationCenter.default.post(
            name: .regenerateMessage,
            object: nil,
            userInfo: ["messageId": message.id]
        )
        
        withAnimation {
            showActions = false
        }
    }
    
    private func startEditing() {
        guard message.role == .user else { return }
        editedContent = message.content
        withAnimation {
            isEditing = true
            showActions = false
        }
    }
    
    private func saveEdit() {
        // Post notification for view model to handle
        NotificationCenter.default.post(
            name: .editMessage,
            object: nil,
            userInfo: ["messageId": message.id, "newContent": editedContent]
        )
        
        withAnimation {
            isEditing = false
        }
    }
    
    private func copyCodeToCanvas() {
        // Extract code blocks and add to canvas
        let codeBlocks = extractCodeBlocks(from: message.content)
        
        for (index, block) in codeBlocks.enumerated() {
            let canvasItem = CanvasItem(
                type: .code,
                title: block.language?.isEmpty == false ? "Code.\(block.language!)" : "Snippet \(index + 1)",
                content: block.code,
                language: block.language
            )
            canvasViewModel?.addItem(canvasItem)
        }
        
        // Show the canvas
        canvasViewModel?.showCanvas()
        
        withAnimation {
            showActions = false
        }
    }
    
    private func extractCodeBlocks(from content: String) -> [(language: String?, code: String)] {
        var blocks: [(language: String?, code: String)] = []
        let pattern = "```(\\w+)?\\n(.*?)```"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let nsRange = NSRange(content.startIndex..., in: content)
            
            for match in regex.matches(in: content, options: [], range: nsRange) {
                let languageRange = Range(match.range(at: 1), in: content)
                let codeRange = Range(match.range(at: 2), in: content)
                
                let language = languageRange.map { String(content[$0]) }
                let code = codeRange.map { String(content[$0]) } ?? ""
                
                blocks.append((language, code))
            }
        } catch {
            Log.error("Failed to parse code blocks: \(error)")
        }
        
        return blocks
    }
}

// MARK: - Message Content

struct MessageContent: View {
    let text: String
    let role: MessageRole
    @Binding var showActions: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if role == .user {
            // User messages render as plain text
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        } else {
            // Assistant messages render with Markdown
            MarkdownContentRenderer(content: text)
        }
    }
}

// MARK: - Markdown Content Renderer

struct MarkdownContentRenderer: View {
    let content: String
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Markdown(content)
            .markdownTheme(markdownTheme)
            .markdownCodeSyntaxHighlighter(
                SplashCodeSyntaxHighlighter(theme: colorScheme == .dark ? .wwdc17(withFont: .init(size: 14)) : .sunset(withFont: .init(size: 14)))
            )
    }
    
    private var markdownTheme: Theme {
        let textColor = Color.primary
        let secondaryColor = Color.secondary
        let codeBackground = Color(.systemGray5)
        
        return Theme()
            .text {
                ForegroundColor(textColor)
                FontSize(16)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(14)
                BackgroundColor(codeBackground)
                ForegroundColor(textColor)
            }
            .codeBlock { configuration in
                CodeBlockView(
                    code: configuration.content,
                    language: configuration.language
                )
            }
            .strong {
                FontWeight(.bold)
            }
            .emphasis {
                FontStyle(.italic)
            }
            .strikethrough {
                StrikethroughStyle(.single)
            }
            .heading1 {
                FontWeight(.bold)
                FontSize(24)
                Padding(.bottom, 8)
            }
            .heading2 {
                FontWeight(.bold)
                FontSize(20)
                Padding(.bottom, 6)
            }
            .heading3 {
                FontWeight(.semibold)
                FontSize(18)
                Padding(.bottom, 4)
            }
            .heading4 {
                FontWeight(.semibold)
                FontSize(16)
            }
            .heading5 {
                FontWeight(.medium)
                FontSize(15)
            }
            .heading6 {
                FontWeight(.medium)
                FontSize(14)
                ForegroundColor(secondaryColor)
            }
            .paragraph {
                Padding(.vertical, 4)
            }
            .unorderedList {
                Margin(.bottom, 8)
            }
            .orderedList {
                Margin(.bottom, 8)
            }
            .listItem {
                MarkerStyle {
                    ForegroundColor(textColor)
                }
            }
            .blockquote {
                Padding(.horizontal, 16)
                Padding(.vertical, 8)
                Margin(.vertical, 8)
                Border(.leading, width: 4, color: secondaryColor.opacity(0.5))
                BackgroundColor(codeBackground.opacity(0.5))
            }
            .link {
                ForegroundColor(.accentColor)
            }
            .table {
                Margin(.vertical, 8)
            }
            .tableCell {
                Padding(.horizontal, 8)
                Padding(.vertical, 4)
                Border(.bottom, width: 0.5, color: secondaryColor.opacity(0.3))
            }
            .tableHeader {
                FontWeight(.bold)
                Border(.bottom, width: 1, color: textColor.opacity(0.5))
            }
            .thematicBreak {
                Margin(.vertical, 16)
                Border(.top, width: 1, color: secondaryColor.opacity(0.3))
            }
    }
}

// MARK: - Message Actions Bar

struct MessageActionsBar: View {
    let message: Message
    let onCopy: () -> Void
    let onRegenerate: () -> Void
    let onEdit: () -> Void
    let onCopyCodeToCanvas: (() -> Void)?
    let onDismiss: () -> Void
    
    @Environment(AppState.self) private var appState
    
    init(
        message: Message,
        onCopy: @escaping () -> Void,
        onRegenerate: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onCopyCodeToCanvas: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
        self.onEdit = onEdit
        self.onCopyCodeToCanvas = onCopyCodeToCanvas
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Copy button
                ActionButton(icon: "doc.on.doc", label: "Copy", action: onCopy)
                
                // Regenerate button (assistant only)
                if message.role == .assistant {
                    ActionButton(icon: "arrow.clockwise", label: "Regenerate", action: onRegenerate)
                }
                
                // Edit button (user only)
                if message.role == .user {
                    ActionButton(icon: "pencil", label: "Edit", action: onEdit)
                }
                
                // Copy code to canvas (if code blocks detected)
                if let copyCodeAction = onCopyCodeToCanvas, message.content.contains("```") {
                    ActionButton(icon: "square.on.square", label: "To Canvas", action: copyCodeAction)
                }
                
                Spacer()
                
                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Additional actions row
            HStack(spacing: 12) {
                // Show/Hide thinking button
                if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                    ThinkingToggleButton(
                        isExpanded: Binding(
                            get: { message.isReasoningExpanded },
                            set: { newValue in
                                message.isReasoningExpanded = newValue
                            }
                        ),
                        hasReasoning: true
                    )
                }
                
                // Global show thinking toggle (for app setting)
                Button {
                    appState.showThinking.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.showThinking ? "eye" : "eye.slash")
                            .font(.caption)
                        Text(appState.showThinking ? "Hide all thinking" : "Show all thinking")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Edit View

struct MessageEditView: View {
    @Binding var content: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $content)
                .font(.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 60, maxHeight: 200)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let regenerateMessage = Notification.Name("regenerateMessage")
    static let editMessage = Notification.Name("editMessage")
    static let submitQuestionResponse = Notification.Name("submitQuestionResponse")
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .offset(y: phase == index ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear {
            phase = 1
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            MessageBubble(message: Message(role: .user, content: "Hello, can you help me with SwiftUI?"))
            
            MessageBubble(message: Message(role: .assistant, content: """
            I'd be happy to help! Here's a code example:
            
            ```swift
            struct ContentView: View {
                var body: some View {
                    Text("Hello, World!")
                }
            }
            ```
            
            This creates a simple view that displays text.
            """))
            
            let toolMessage = Message(role: .assistant, content: "Let me search for that information.")
            toolMessage.activeTool = ActiveTool(name: "web_search", status: .running, preview: "Searching...", startTime: Date())
            MessageBubble(message: toolMessage)
        }
        .padding()
    }
    .environment(AppState())
}
