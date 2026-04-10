import SwiftUI

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    let onModelChange: ((String) -> Void)?
    
    @State private var textEditorHeight: CGFloat = 40
    @State private var showingModelPicker = false
    @State private var showingImagePicker = false
    @State private var mentionQuery: String?
    @FocusState private var isFocused: Bool
    
    private let minHeight: CGFloat = 40
    private let maxHeight: CGFloat = 200
    
    init(
        text: Binding<String>,
        isStreaming: Bool,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onModelChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onCancel = onCancel
        self.onModelChange = onModelChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Model mention suggestions
            if let query = mentionQuery {
                ModelMentionSuggestions(query: query) { model in
                    insertModelMention(model)
                }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                AttachmentButton {
                    showingImagePicker = true
                }
                
                // Text input area
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if text.isEmpty {
                        Text("Message...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    
                    // Auto-resizing text editor
                    AutoResizingTextEditor(
                        text: $text,
                        minHeight: minHeight,
                        maxHeight: maxHeight,
                        currentHeight: $textEditorHeight,
                        onMentionDetected: { query in
                            mentionQuery = query
                        }
                    )
                    .focused($isFocused)
                }
                .frame(height: textEditorHeight)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // Action buttons
                if isStreaming {
                    CancelButton(action: onCancel)
                } else {
                    SendButton(action: onSend, isEnabled: canSend)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Input hints
            if !text.isEmpty {
                InputHints()
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerPlaceholder()
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
    
    private func insertModelMention(_ model: String) {
        // Replace the @query with @model
        if let query = mentionQuery,
           let range = text.range(of: "@\(query)", options: .backwards) {
            text.replaceSubrange(range, with: "@\(model) ")
        }
        mentionQuery = nil
        onModelChange?(model)
    }
}

// MARK: - Auto-Resizing Text Editor

struct AutoResizingTextEditor: View {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @Binding var currentHeight: CGFloat
    var onMentionDetected: ((String) -> Void)?
    
    @State private var isCheckingForMention = false
    
    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(
                GeometryReader { geometry in
                    Color.clear.onChange(of: text) { _ in
                        calculateHeight(from: geometry)
                        checkForMention()
                    }
                }
            )
            .onSubmit {
                // Handle Option+Enter for new line
            }
    }
    
    private func calculateHeight(from geometry: GeometryProxy) {
        // Calculate height based on content
        let textHeight = text.boundingRect(
            with: CGSize(width: geometry.size.width - 16, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)],
            context: nil
        ).height + 20
        
        let newHeight = min(max(textHeight, minHeight), maxHeight)
        if abs(newHeight - currentHeight) > 5 {
            withAnimation(.easeInOut(duration: 0.1)) {
                currentHeight = newHeight
            }
        }
    }
    
    private func checkForMention() {
        // Check for @ mention
        if let lastAt = text.lastIndex(of: "@") {
            let afterAt = text.index(after: lastAt)
            let query = String(text[afterAt...])
            
            // Only trigger if no space in query and not too long
            if !query.contains(" ") && query.count < 20 {
                onMentionDetected?(query)
            } else {
                onMentionDetected?(nil)
            }
        } else {
            onMentionDetected?(nil)
        }
    }
}

// MARK: - Attachment Button

struct AttachmentButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Send Button

struct SendButton: View {
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(width: 44, height: 44)
                .background(isEnabled ? Color.accentColor : Color(.systemGray4))
                .foregroundStyle(isEnabled ? .white : .secondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .keyboardShortcut(.return, modifiers: .command)
    }
}

// MARK: - Cancel Button

struct CancelButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "stop.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Mention Suggestions

struct ModelMentionSuggestions: View {
    let query: String
    let onSelect: (String) -> Void
    
    private let availableModels = [
        "hermes-agent",
        "gpt-4",
        "gpt-4-turbo",
        "claude-3-opus",
        "claude-3-sonnet",
        "gemini-pro"
    ]
    
    private var filteredModels: [String] {
        if query.isEmpty {
            return availableModels
        }
        return availableModels.filter { $0.lowercased().contains(query.lowercased()) }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredModels, id: \.self) { model in
                    Button {
                        onSelect(model)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.caption)
                            Text(model)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Input Hints

struct InputHints: View {
    var body: some View {
        HStack(spacing: 16) {
            Label("⌘↵ Send", systemImage: "return")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Label("⌥↵ New Line", systemImage: "arrow.turn.down.left")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Label("@ Model", systemImage: "at")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Image Picker Placeholder

struct ImagePickerPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Image Support")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Image upload functionality will be implemented in a future update.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
            .navigationTitle("Attach Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Alternative Simple Input

struct SimpleMessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Attachments button
            Button {
                // Show attachment options
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            // Text field
            TextField("Message...", text: $text, axis: .vertical)
                .font(.body)
                .focused($isFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            // Send/Cancel button
            if isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 36)
                        .background(canSend ? Color.accentColor : Color(.systemGray4))
                        .foregroundStyle(canSend ? .white : .secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
}

// MARK: - macOS Optimized Input

#if os(macOS)
struct MacMessageInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    let onModelChange: ((String) -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var showingModelPicker = false
    @State private var mentionQuery: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Model mention suggestions
            if let query = mentionQuery {
                ModelMentionSuggestions(query: query) { model in
                    insertModelMention(model)
                }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Text editor with proper sizing for macOS
                TextEditor(text: $text)
                    .font(.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 40, maxHeight: 200)
                    .background(Color(.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.separator, lineWidth: 1)
                    )
                    .onChange(of: text) { _ in
                        checkForMention()
                    }
                
                VStack(spacing: 8) {
                    // Model selector
                    ModelSelectorButton { model in
                        onModelChange?(model)
                    }
                    
                    Spacer()
                    
                    // Send/Cancel button
                    if isStreaming {
                        Button(action: onCancel) {
                            Image(systemName: "stop.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSend)
                        .keyboardShortcut(.return, modifiers: [.command])
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }
    
    private func checkForMention() {
        if let lastAt = text.lastIndex(of: "@") {
            let afterAt = text.index(after: lastAt)
            let query = String(text[afterAt...])
            
            if !query.contains(" ") && query.count < 20 {
                mentionQuery = query
            } else {
                mentionQuery = nil
            }
        } else {
            mentionQuery = nil
        }
    }
    
    private func insertModelMention(_ model: String) {
        if let query = mentionQuery,
           let range = text.range(of: "@\(query)", options: .backwards) {
            text.replaceSubrange(range, with: "@\(model) ")
        }
        mentionQuery = nil
        onModelChange?(model)
    }
}

// MARK: - Model Selector Button

struct ModelSelectorButton: View {
    let onSelect: (String) -> Void
    
    private let models = [
        "hermes-agent",
        "gpt-4",
        "gpt-4-turbo",
        "claude-3-opus",
        "claude-3-sonnet"
    ]
    
    var body: some View {
        Menu {
            ForEach(models, id: \.self) { model in
                Button(model) {
                    onSelect(model)
                }
            }
        } label: {
            Image(systemName: "cpu")
                .foregroundStyle(.secondary)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    VStack {
        MessageInputView(
            text: .constant("Hello world"),
            isStreaming: false,
            onSend: {},
            onCancel: {},
            onModelChange: { model in
                print("Selected model: \(model)")
            }
        )
        
        MessageInputView(
            text: .constant(""),
            isStreaming: true,
            onSend: {},
            onCancel: {},
            onModelChange: nil
        )
    }
}
