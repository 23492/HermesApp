import SwiftUI

// MARK: - Tool Result Display View

struct ToolResultView: View {
    let result: ToolResult
    var toolName: String?
    var style: ResultStyle = .full
    
    enum ResultStyle {
        case full
        case compact
        case inline
    }
    
    private var displayToolName: String {
        toolName ?? ToolRegistry.info(for: "unknown").displayName
    }
    
    var body: some View {
        switch style {
        case .full:
            fullView
        case .compact:
            compactView
        case .inline:
            inlineView
        }
    }
    
    // MARK: - Full View
    
    private var fullView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                statusIcon
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isError ? "Tool Execution Failed" : "Tool Execution Complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let completedAt = result.completedAt {
                        Text("Completed at \(formattedTime(completedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Output
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.isError ? "Error Output" : "Output")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        copyOutput()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                ScrollView {
                    Text(result.output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 200)
                .background(outputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: 10) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.isError ? "Failed" : "Success")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(truncatedOutput)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let completedAt = result.completedAt {
                Text(formattedTime(completedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Inline View
    
    private var inlineView: some View {
        HStack(spacing: 6) {
            statusIcon
                .font(.caption)
            
            Text(truncatedOutput)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // MARK: - Helper Views & Properties
    
    @ViewBuilder
    private var statusIcon: some View {
        if result.isError {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
    
    private var cardBackground: Color {
        result.isError ? Color.red.opacity(0.08) : Color.green.opacity(0.08)
    }
    
    private var outputBackground: Color {
        result.isError ? Color.red.opacity(0.05) : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        result.isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2)
    }
    
    private var truncatedOutput: String {
        let maxLength = 60
        if result.output.count > maxLength {
            return String(result.output.prefix(maxLength)) + "..."
        }
        return result.output
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyOutput() {
        #if os(iOS)
        UIPasteboard.general.string = result.output
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.output, forType: .string)
        #endif
    }
}

// MARK: - Tool Results Summary

struct ToolResultsSummary: View {
    let results: [ToolResult]
    
    private var successCount: Int {
        results.filter { !$0.isError }.count
    }
    
    private var errorCount: Int {
        results.filter { $0.isError }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(successCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(errorCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Text("\(results.count) tool calls")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Tool Error View

struct ToolErrorView: View {
    let error: String
    let toolName: String?
    var onRetry: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tool Error")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let toolName = toolName {
                        Text(toolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            if let onRetry = onRetry {
                HStack {
                    Spacer()
                    
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Tool Result Views") {
    ScrollView {
        VStack(spacing: 16) {
            Group {
                Text("Full Style")
                    .font(.headline)
                
                ToolResultView(
                    result: ToolResult(
                        toolCallId: "call_1",
                        output: "Successfully found 5 results for 'SwiftUI animations'",
                        isError: false
                    ),
                    toolName: "web_search",
                    style: .full
                )
                
                ToolResultView(
                    result: ToolResult(
                        toolCallId: "call_2",
                        output: "Error: File not found at path /invalid/path.txt",
                        isError: true
                    ),
                    toolName: "read_file",
                    style: .full
                )
            }
            
            Divider()
            
            Group {
                Text("Compact Style")
                    .font(.headline)
                
                ToolResultView(
                    result: ToolResult(
                        toolCallId: "call_1",
                        output: "Command executed successfully",
                        isError: false
                    ),
                    style: .compact
                )
                
                ToolResultView(
                    result: ToolResult(
                        toolCallId: "call_2",
                        output: "Permission denied",
                        isError: true
                    ),
                    style: .compact
                )
            }
            
            Divider()
            
            Group {
                Text("Inline Style")
                    .font(.headline)
                
                HStack {
                    ToolResultView(
                        result: ToolResult(
                            toolCallId: "call_1",
                            output: "Done",
                            isError: false
                        ),
                        style: .inline
                    )
                    
                    ToolResultView(
                        result: ToolResult(
                            toolCallId: "call_2",
                            output: "Failed",
                            isError: true
                        ),
                        style: .inline
                    )
                }
            }
            
            Divider()
            
            Group {
                Text("Summary & Error")
                    .font(.headline)
                
                ToolResultsSummary(results: [
                    ToolResult(toolCallId: "1", output: "Done", isError: false),
                    ToolResult(toolCallId: "2", output: "Done", isError: false),
                    ToolResult(toolCallId: "3", output: "Error", isError: true)
                ])
                
                ToolErrorView(
                    error: "Connection timeout while trying to reach the server. Please check your network connection and try again.",
                    toolName: "web_search"
                ) {
                    print("Retry tapped")
                }
            }
        }
        .padding()
    }
}
