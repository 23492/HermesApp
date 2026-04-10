import SwiftUI

// MARK: - Thinking Block
// Collapsible reasoning display similar to Claude Desktop

struct ThinkingBlock: View {
    let reasoning: String
    @Binding var isExpanded: Bool
    var isStreaming: Bool = false
    
    @State private var showCopyConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // Brain icon with streaming animation
                    ThinkingIcon(isStreaming: isStreaming)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thinking")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if isStreaming {
                            Text(" reasoning...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Copy button (visible on hover/expanded)
                    if isExpanded && !reasoning.isEmpty {
                        Button {
                            copyReasoning()
                        } label: {
                            Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(showCopyConfirmation ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                    
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(headerBackground)
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reasoning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        
                    if isStreaming {
                        StreamingIndicator()
                            .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(contentBackground)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    private var headerBackground: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.1),
                Color.yellow.opacity(colorScheme == .dark ? 0.1 : 0.05)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var contentBackground: some View {
        Color.orange.opacity(colorScheme == .dark ? 0.08 : 0.05)
    }
    
    private var backgroundColor: Color {
        Color.orange.opacity(colorScheme == .dark ? 0.1 : 0.05)
    }
    
    private var borderColor: Color {
        Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.2)
    }
    
    // MARK: - Actions
    
    private func copyReasoning() {
        #if os(iOS)
        UIPasteboard.general.string = reasoning
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reasoning, forType: .string)
        #endif
        
        withAnimation {
            showCopyConfirmation = true
        }
        
        // Reset after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                showCopyConfirmation = false
            }
        }
    }
}

// MARK: - Thinking Icon

struct ThinkingIcon: View {
    let isStreaming: Bool
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.orange)
            .symbolEffect(.pulse, isActive: isStreaming)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if isStreaming {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            }
            .onChange(of: isStreaming) { _, newValue in
                if !newValue {
                    rotation = 0
                }
            }
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var phase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Thinking")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .scaleEffect(phase == index ? 1.5 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: phase
                        )
                }
            }
        }
        .onAppear {
            phase = 1
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Collapsed state
        ThinkingBlock(
            reasoning: "Let me think about this step by step...\n\n1. First, I need to understand the problem\n2. Then break it down into smaller parts\n3. Finally, provide a comprehensive solution",
            isExpanded: .constant(false)
        )
        
        // Expanded state
        ThinkingBlock(
            reasoning: "Let me think about this step by step...\n\n1. First, I need to understand the problem\n2. Then break it down into smaller parts\n3. Finally, provide a comprehensive solution",
            isExpanded: .constant(true)
        )
        
        // Streaming state
        ThinkingBlock(
            reasoning: "Analyzing the request and formulating a response...",
            isExpanded: .constant(true),
            isStreaming: true
        )
    }
    .padding()
    .background(Color.systemBackground)
}
