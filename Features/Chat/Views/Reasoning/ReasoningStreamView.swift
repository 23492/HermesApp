import SwiftUI

// MARK: - Reasoning Stream View
// Real-time thinking streaming with word-by-word animation

struct ReasoningStreamView: View {
    let reasoning: String
    let isActive: Bool
    
    @State private var displayedText: String = ""
    @State private var wordQueue: [String] = []
    @State private var isAnimating = false
    
    private let wordDelay: TimeInterval = 0.03 // 30ms between words
    
    var body: some View {
        ThinkingBlock(
            reasoning: displayedText,
            isExpanded: .constant(true),
            isStreaming: isActive
        )
        .onAppear {
            displayedText = reasoning
        }
        .onChange(of: reasoning) { oldValue, newValue in
            handleTextUpdate(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                // Ensure all text is shown when streaming stops
                displayedText = reasoning
                wordQueue.removeAll()
                isAnimating = false
            }
        }
    }
    
    private func handleTextUpdate(oldValue: String, newValue: String) {
        // Find the new content added
        guard newValue.count > oldValue.count else {
            displayedText = newValue
            return
        }
        
        let startIndex = oldValue.endIndex
        let newContent = String(newValue[startIndex...])
        
        // Split new content into words/tokens
        let words = tokenize(newContent)
        wordQueue.append(contentsOf: words)
        
        // Start animation if not already running
        if !isAnimating && isActive {
            animateWords()
        }
    }
    
    private func tokenize(_ text: String) -> [String] {
        // Split by whitespace but keep the delimiters for natural typing effect
        var tokens: [String] = []
        var current = ""
        
        for char in text {
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            tokens.append(current)
        }
        
        return tokens
    }
    
    private func animateWords() {
        guard isActive && !wordQueue.isEmpty else {
            isAnimating = false
            return
        }
        
        isAnimating = true
        
        Task {
            while isActive && !wordQueue.isEmpty {
                let word = wordQueue.removeFirst()
                
                await MainActor.run {
                    displayedText.append(word)
                }
                
                // Small delay between words for streaming effect
                let delay = UInt64(wordDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            
            await MainActor.run {
                isAnimating = false
            }
        }
    }
}

// MARK: - Reasoning Container View

struct ReasoningContainer: View {
    @Bindable var message: Message
    let isStreaming: Bool
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                if isStreaming && message.isStreaming {
                    // Show streaming view during active streaming
                    ReasoningStreamView(
                        reasoning: reasoning,
                        isActive: true
                    )
                } else {
                    // Show static block after streaming completes
                    ThinkingBlock(
                        reasoning: reasoning,
                        isExpanded: $message.isReasoningExpanded,
                        isStreaming: false
                    )
                }
            }
        }
    }
}

// MARK: - Reasoning Toggle Button

struct ReasoningToggleButton: View {
    @Binding var isExpanded: Bool
    let hasReasoning: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text(isExpanded ? "Hide thinking" : "Show thinking")
                    .font(.caption)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(hasReasoning ? .orange : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(hasReasoning ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasReasoning)
        .opacity(hasReasoning ? 1.0 : 0.5)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Static reasoning
        ReasoningContainer(
            message: createPreviewMessage(reasoning: "This is a completed reasoning process."),
            isStreaming: false
        )
        
        // Toggle button
        ReasoningToggleButton(
            isExpanded: .constant(false),
            hasReasoning: true
        )
    }
    .padding()
    .environment(AppState())
}

private func createPreviewMessage(reasoning: String) -> Message {
    let message = Message(role: .assistant, content: "Here's my response.")
    message.reasoningContent = reasoning
    message.isReasoningExpanded = true
    return message
}
