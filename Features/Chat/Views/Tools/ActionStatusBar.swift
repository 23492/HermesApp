import SwiftUI

// MARK: - Action Status Bar

struct ActionStatusBar: View {
    let activeTools: [ActiveTool]
    var onCancel: (() -> Void)?
    
    @State private var isExpanded = false
    
    private var runningTools: [ActiveTool] {
        activeTools.filter { $0.status == .running }
    }
    
    private var completedTools: [ActiveTool] {
        activeTools.filter { $0.status != .running }
    }
    
    var body: some View {
        if activeTools.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    compactView
                        .transition(.opacity)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 16 : 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: 12) {
            // Tool icons
            HStack(spacing: -8) {
                ForEach(Array(runningTools.prefix(3).enumerated()), id: \.element.startTime) { index, tool in
                    ToolIcon(toolName: tool.name, size: 24, showBackground: true)
                        .zIndex(Double(3 - index))
                        .overlay(
                            Group {
                                if index == 0 && runningTools.count > 1 {
                                    Text("+\(runningTools.count - 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        )
                }
            }
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let firstTool = runningTools.first {
                    Text(firstTool.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Spinner
            ProgressView()
                .scaleEffect(0.8)
                .tint(.accentColor)
            
            // Expand button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Cancel button
            if let onCancel = onCancel {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 600)
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Active Tools")
                    .font(.headline)
                
                Spacer()
                
                Text("\(runningTools.count) running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                Button {
                    withAnimation {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Running tools list
            if !runningTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Running")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    ForEach(runningTools, id: \.startTime) { tool in
                        ToolExecutionView(tool: tool, style: .compact)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            
            // Completed tools list
            if !completedTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    ForEach(completedTools.prefix(5), id: \.startTime) { tool in
                        ToolExecutionView(tool: tool, style: .minimal)
                            .padding(.horizontal, 16)
                    }
                    
                    if completedTools.count > 5 {
                        Text("+\(completedTools.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            
            // Cancel button
            if let onCancel = onCancel {
                Divider()
                    .padding(.horizontal, 16)
                
                Button {
                    onCancel()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: 600)
    }
    
    // MARK: - Helper Properties
    
    private var statusText: String {
        if runningTools.count == 1, let tool = runningTools.first {
            let toolInfo = ToolRegistry.info(for: tool.name)
            return "Running: \(toolInfo.displayName)"
        } else if runningTools.count > 1 {
            return "Running \(runningTools.count) tools..."
        } else if !completedTools.isEmpty {
            return "All tools completed"
        } else {
            return "Processing..."
        }
    }
}

// MARK: - Mini Action Status

struct MiniActionStatus: View {
    let toolCount: Int
    var isRunning: Bool = true
    
    var body: some View {
        HStack(spacing: 6) {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.accentColor)
            }
            
            Text("\(toolCount) tool\(toolCount == 1 ? "" : "s")")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Tool Progress Indicator

struct ToolProgressIndicator: View {
    let tools: [ActiveTool]
    
    private var totalCount: Int {
        tools.count
    }
    
    private var completedCount: Int {
        tools.filter { $0.status == .completed }.count
    }
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(completedCount)/\(totalCount) tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.linear(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return .green
        } else if progress > 0.5 {
            return .orange
        } else {
            return .accentColor
        }
    }
}

// MARK: - Previews

#Preview("Action Status Bar") {
    VStack {
        Spacer()
        
        VStack(spacing: 20) {
            // Single tool running
            ActionStatusBar(
                activeTools: [
                    ActiveTool(
                        name: "terminal",
                        status: .running,
                        preview: "Executing ls -la...",
                        startTime: Date()
                    )
                ],
                onCancel: {}
            )
            
            // Multiple tools
            ActionStatusBar(
                activeTools: [
                    ActiveTool(name: "web_search", status: .completed, preview: "Done", startTime: Date(), duration: 3.2),
                    ActiveTool(name: "read_file", status: .completed, preview: "Done", startTime: Date(), duration: 0.5),
                    ActiveTool(name: "terminal", status: .running, preview: "Running...", startTime: Date()),
                    ActiveTool(name: "write_file", status: .running, preview: "Writing...", startTime: Date())
                ],
                onCancel: {}
            )
        }
        .padding()
    }
    .background(Color(.systemGray5))
}

#Preview("Mini Status & Progress") {
    VStack(spacing: 16) {
        HStack {
            MiniActionStatus(toolCount: 3, isRunning: true)
            MiniActionStatus(toolCount: 1, isRunning: false)
        }
        
        ToolProgressIndicator(tools: [
            ActiveTool(name: "web_search", status: .completed, preview: "", startTime: Date(), duration: 1.0),
            ActiveTool(name: "read_file", status: .completed, preview: "", startTime: Date(), duration: 1.0),
            ActiveTool(name: "terminal", status: .running, preview: "", startTime: Date())
        ])
        
        ToolProgressIndicator(tools: [
            ActiveTool(name: "web_search", status: .completed, preview: "", startTime: Date(), duration: 1.0),
            ActiveTool(name: "read_file", status: .error, preview: "", startTime: Date(), duration: 1.0),
            ActiveTool(name: "terminal", status: .completed, preview: "", startTime: Date(), duration: 1.0),
            ActiveTool(name: "write_file", status: .running, preview: "", startTime: Date())
        ])
    }
    .padding()
}
