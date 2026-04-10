import SwiftUI

// MARK: - Live Tool Execution Indicator

struct ToolExecutionView: View {
    let tool: ActiveTool
    var showDuration: Bool = true
    var style: ExecutionStyle = .compact
    
    enum ExecutionStyle {
        case compact
        case expanded
        case minimal
    }
    
    private var toolInfo: ToolInfo {
        ToolRegistry.info(for: tool.name)
    }
    
    private var iconColor: Color {
        Color(hex: toolInfo.color) ?? .gray
    }
    
    var body: some View {
        switch style {
        case .compact:
            compactView
        case .expanded:
            expandedView
        case .minimal:
            minimalView
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: 10) {
            ToolIcon(toolName: tool.name, size: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(toolInfo.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                statusIcon
                
                if showDuration {
                    Text(formattedDuration)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ToolIcon(toolName: tool.name, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolInfo.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(tool.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    statusIcon
                    
                    if showDuration {
                        Text(formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            Divider()
            
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(tool.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if tool.status == .running {
                ProgressView(value: min(tool.computedDuration / 10.0, 0.9))
                    .progressViewStyle(.linear)
                    .tint(iconColor)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Minimal View
    
    private var minimalView: some View {
        HStack(spacing: 8) {
            Image(systemName: toolInfo.icon)
                .font(.caption)
                .foregroundStyle(iconColor)
            
            Text(toolInfo.displayName)
                .font(.caption)
                .fontWeight(.medium)
            
            Spacer()
            
            statusIcon
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // MARK: - Helper Views & Properties
    
    @ViewBuilder
    private var statusIcon: some View {
        switch tool.status {
        case .running:
            ProgressView()
                .scaleEffect(0.8)
                .tint(iconColor)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
    
    private var statusText: String {
        switch tool.status {
        case .running:
            return tool.preview.isEmpty ? "Running..." : tool.preview
        case .completed:
            return "Completed"
        case .error:
            return "Failed"
        }
    }
    
    private var formattedDuration: String {
        let duration = tool.computedDuration
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    private var backgroundColor: Color {
        switch tool.status {
        case .running:
            return iconColor.opacity(0.08)
        case .completed:
            return Color.green.opacity(0.08)
        case .error:
            return Color.red.opacity(0.08)
        }
    }
    
    private var borderColor: Color {
        switch tool.status {
        case .running:
            return iconColor.opacity(0.3)
        case .completed:
            return Color.green.opacity(0.3)
        case .error:
            return Color.red.opacity(0.3)
        }
    }
}

// MARK: - Multiple Tools Execution View

struct ToolsExecutionStack: View {
    let tools: [ActiveTool]
    var maxVisible: Int = 3
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(tools.prefix(maxVisible).enumerated()), id: \.element.startTime) { index, tool in
                ToolExecutionView(tool: tool)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            
            if tools.count > maxVisible {
                Text("+\(tools.count - maxVisible) more tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Previews

#Preview("Tool Execution Views") {
    ScrollView {
        VStack(spacing: 16) {
            Group {
                Text("Compact Style")
                    .font(.headline)
                
                ToolExecutionView(
                    tool: ActiveTool(
                        name: "terminal",
                        status: .running,
                        preview: "Executing command...",
                        startTime: Date()
                    ),
                    style: .compact
                )
                
                ToolExecutionView(
                    tool: ActiveTool(
                        name: "web_search",
                        status: .completed,
                        preview: "Found 5 results",
                        startTime: Date().addingTimeInterval(-5),
                        duration: 4.2
                    ),
                    style: .compact
                )
                
                ToolExecutionView(
                    tool: ActiveTool(
                        name: "read_file",
                        status: .error,
                        preview: "File not found",
                        startTime: Date().addingTimeInterval(-2),
                        duration: 0.5
                    ),
                    style: .compact
                )
            }
            
            Divider()
            
            Group {
                Text("Expanded Style")
                    .font(.headline)
                
                ToolExecutionView(
                    tool: ActiveTool(
                        name: "terminal",
                        status: .running,
                        preview: "ls -la /Users/demo/projects",
                        startTime: Date()
                    ),
                    style: .expanded
                )
            }
            
            Divider()
            
            Group {
                Text("Minimal Style")
                    .font(.headline)
                
                HStack {
                    ToolExecutionView(
                        tool: ActiveTool(
                            name: "web_search",
                            status: .running,
                            preview: "",
                            startTime: Date()
                        ),
                        style: .minimal
                    )
                    
                    ToolExecutionView(
                        tool: ActiveTool(
                            name: "read_file",
                            status: .completed,
                            preview: "",
                            startTime: Date(),
                            duration: 0.3
                        ),
                        style: .minimal
                    )
                }
            }
            
            Divider()
            
            Group {
                Text("Multiple Tools")
                    .font(.headline)
                
                ToolsExecutionStack(tools: [
                    ActiveTool(name: "web_search", status: .completed, preview: "Done", startTime: Date(), duration: 2.5),
                    ActiveTool(name: "read_file", status: .completed, preview: "Done", startTime: Date(), duration: 0.3),
                    ActiveTool(name: "terminal", status: .running, preview: "Running...", startTime: Date())
                ])
            }
        }
        .padding()
    }
}
