import SwiftUI

// MARK: - Tool Call Display View

struct ToolCallView: View {
    let toolCall: ToolCall
    var result: ToolResult? = nil
    @State private var isExpanded = false
    @State private var showCopiedFeedback = false
    
    private var toolInfo: ToolInfo {
        ToolRegistry.info(for: toolCall.name)
    }
    
    private var iconColor: Color {
        Color(hex: toolInfo.color) ?? .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always visible
            headerView
            
            // Expanded content
            if isExpanded {
                expandedContent
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
    
    // MARK: - Header View
    
    private var headerView: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                ToolIcon(toolName: toolCall.name, size: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolInfo.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(toolCall.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Result status indicator
                    if let result = result {
                        Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.isError ? .red : .green)
                    }
                    
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 12)
            
            // Arguments Section
            argumentsSection
            
            // Result Section (if available)
            if let result = result {
                resultSection(result)
            }
            
            // Copy button
            HStack {
                Spacer()
                
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(showCopiedFeedback ? "Copied!" : "Copy")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Arguments Section
    
    private var argumentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "curlybraces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Arguments")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            Text(toolCall.formattedArguments)
                .font(.caption)
                .fontDesign(.monospaced)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.systemGray5)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Result Section
    
    private func resultSection(_ result: ToolResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.isError ? "exclamationmark.triangle" : "return")
                    .font(.caption)
                    .foregroundStyle(result.isError ? .red : .green)
                
                Text(result.isError ? "Error" : "Result")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(result.isError ? .red : .green)
                
                Spacer()
                
                if let completedAt = result.completedAt {
                    Text(formattedTime(completedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(result.output)
                .font(.caption)
                .fontDesign(.monospaced)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((result.isError ? Color.red : Color.green).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Helper Methods
    
    private var backgroundColor: Color {
        if let result = result {
            return result.isError ? Color.red.opacity(0.05) : Color.green.opacity(0.05)
        }
        return iconColor.opacity(0.08)
    }
    
    private var borderColor: Color {
        if let result = result {
            return result.isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2)
        }
        return iconColor.opacity(0.2)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        var content = "Tool: \(toolCall.name)\n"
        content += "Arguments: \(toolCall.formattedArguments)\n"
        if let result = result {
            content += "\nResult: \(result.output)"
        }
        
        #if os(iOS)
        UIPasteboard.general.string = content
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
        
        withAnimation {
            showCopiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}

// MARK: - Tool Call List View

struct ToolCallListView: View {
    let toolCalls: [ToolCall]
    let toolResults: [ToolResult]?
    
    private func resultForCall(_ call: ToolCall) -> ToolResult? {
        toolResults?.first { $0.toolCallId == call.id }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(toolCalls) { call in
                ToolCallView(
                    toolCall: call,
                    result: resultForCall(call)
                )
            }
        }
    }
}

// MARK: - Compact Tool Call Badge

struct ToolCallBadge: View {
    let toolCall: ToolCall
    var result: ToolResult? = nil
    
    private var toolInfo: ToolInfo {
        ToolRegistry.info(for: toolCall.name)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: toolInfo.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: toolInfo.color) ?? .gray)
            
            Text(toolInfo.displayName)
                .font(.caption)
                .fontWeight(.medium)
            
            if let result = result {
                Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(result.isError ? .red : .green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.systemGray6)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Tool Call View") {
    ScrollView {
        VStack(spacing: 16) {
            // Without result
            ToolCallView(
                toolCall: ToolCall(
                    id: "call_1",
                    name: "terminal",
                    arguments: "{\"command\": \"ls -la\", \"timeout\": 30}"
                )
            )
            
            // With success result
            ToolCallView(
                toolCall: ToolCall(
                    id: "call_2",
                    name: "web_search",
                    arguments: "{\"query\": \"SwiftUI animation examples\"}"
                ),
                result: ToolResult(
                    toolCallId: "call_2",
                    output: "Found 5 results about SwiftUI animations...",
                    isError: false
                )
            )
            
            // With error result
            ToolCallView(
                toolCall: ToolCall(
                    id: "call_3",
                    name: "read_file",
                    arguments: "{\"path\": \"/nonexistent/file.txt\"}"
                ),
                result: ToolResult(
                    toolCallId: "call_3",
                    output: "Error: File not found at path /nonexistent/file.txt",
                    isError: true
                )
            )
            
            // List view
            ToolCallListView(
                toolCalls: [
                    ToolCall(id: "call_1", name: "web_search", arguments: "{}"),
                    ToolCall(id: "call_2", name: "read_file", arguments: "{}"),
                    ToolCall(id: "call_3", name: "terminal", arguments: "{}")
                ],
                toolResults: [
                    ToolResult(toolCallId: "call_1", output: "Done", isError: false),
                    ToolResult(toolCallId: "call_2", output: "Error", isError: true)
                ]
            )
            
            // Badge
            HStack {
                ToolCallBadge(
                    toolCall: ToolCall(id: "1", name: "terminal", arguments: "{}"),
                    result: ToolResult(toolCallId: "1", output: "Done", isError: false)
                )
                
                ToolCallBadge(
                    toolCall: ToolCall(id: "2", name: "web_search", arguments: "{}"),
                    result: ToolResult(toolCallId: "2", output: "Error", isError: true)
                )
            }
        }
        .padding()
    }
}
