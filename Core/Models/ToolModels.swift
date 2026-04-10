import Foundation

// MARK: - Tool Call

struct ToolCall: Codable, Identifiable {
    var id: String
    var name: String
    var arguments: String // JSON string
    
    init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
    
    var parsedArguments: [String: Any]? {
        guard let data = arguments.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    var formattedArguments: String {
        guard let parsed = parsedArguments else { return arguments }
        guard let data = try? JSONSerialization.data(
            withJSONObject: parsed,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return arguments }
        return String(data: data, encoding: .utf8) ?? arguments
    }
}

// MARK: - Tool Result

struct ToolResult: Codable {
    var toolCallId: String
    var output: String
    var isError: Bool
    var completedAt: Date?
    
    init(toolCallId: String, output: String, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.output = output
        self.isError = isError
        self.completedAt = Date()
    }
}

// MARK: - Active Tool

enum ToolStatus: String, Codable {
    case running
    case completed
    case error
}

struct ActiveTool: Codable {
    var name: String
    var status: ToolStatus
    var preview: String
    var startTime: Date
    var duration: Double?
    var endTime: Date?
    
    init(
        name: String,
        status: ToolStatus,
        preview: String,
        startTime: Date,
        duration: Double? = nil,
        endTime: Date? = nil
    ) {
        self.name = name
        self.status = status
        self.preview = preview
        self.startTime = startTime
        self.duration = duration
        self.endTime = endTime
    }
    
    var computedDuration: Double {
        if let duration = duration {
            return duration
        }
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }
    
    mutating func complete(success: Bool = true) {
        self.status = success ? .completed : .error
        self.endTime = Date()
        self.duration = endTime!.timeIntervalSince(startTime)
    }
}

// MARK: - Tool Registry

struct ToolInfo: Codable, Identifiable {
    var id: String { name }
    var name: String
    var displayName: String
    var description: String
    var icon: String // SF Symbol name
    var color: String // Hex color
    var category: ToolCategory
    var isEnabled: Bool
}

enum ToolCategory: String, Codable {
    case file = "File"
    case search = "Search"
    case web = "Web"
    case code = "Code"
    case system = "System"
    case other = "Other"
}

// MARK: - Tool Icon & Color Mapping

enum ToolRegistry {
    static let defaultTools: [ToolInfo] = [
        // File Operations
        ToolInfo(
            name: "read_file",
            displayName: "Read File",
            description: "Read content from a file",
            icon: "doc.text",
            color: "#007AFF",
            category: .file,
            isEnabled: true
        ),
        ToolInfo(
            name: "write_file",
            displayName: "Write File",
            description: "Write content to a file",
            icon: "doc.badge.plus",
            color: "#34C759",
            category: .file,
            isEnabled: true
        ),
        ToolInfo(
            name: "search_files",
            displayName: "Search Files",
            description: "Search for files by content",
            icon: "magnifyingglass",
            color: "#FF9500",
            category: .search,
            isEnabled: true
        ),
        ToolInfo(
            name: "list_directory",
            displayName: "List Directory",
            description: "List contents of a directory",
            icon: "folder",
            color: "#5856D6",
            category: .file,
            isEnabled: true
        ),
        ToolInfo(
            name: "file_info",
            displayName: "File Info",
            description: "Get information about a file",
            icon: "info.circle",
            color: "#007AFF",
            category: .file,
            isEnabled: true
        ),
        ToolInfo(
            name: "delete_file",
            displayName: "Delete File",
            description: "Delete a file",
            icon: "trash",
            color: "#FF3B30",
            category: .file,
            isEnabled: true
        ),
        ToolInfo(
            name: "move_file",
            displayName: "Move File",
            description: "Move or rename a file",
            icon: "arrow.right.doc.on.clipboard",
            color: "#007AFF",
            category: .file,
            isEnabled: true
        ),
        
        // System & Terminal
        ToolInfo(
            name: "terminal",
            displayName: "Terminal",
            description: "Execute terminal commands",
            icon: "terminal",
            color: "#1C1C1E",
            category: .system,
            isEnabled: true
        ),
        ToolInfo(
            name: "bash",
            displayName: "Bash",
            description: "Execute bash commands",
            icon: "terminal.fill",
            color: "#1C1C1E",
            category: .system,
            isEnabled: true
        ),
        ToolInfo(
            name: "shell",
            displayName: "Shell",
            description: "Execute shell commands",
            icon: "command",
            color: "#1C1C1E",
            category: .system,
            isEnabled: true
        ),
        ToolInfo(
            name: "run_command",
            displayName: "Run Command",
            description: "Execute a system command",
            icon: "play.circle",
            color: "#1C1C1E",
            category: .system,
            isEnabled: true
        ),
        
        // Web & Search
        ToolInfo(
            name: "web_search",
            displayName: "Web Search",
            description: "Search the web",
            icon: "globe",
            color: "#5AC8FA",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "web_fetch",
            displayName: "Web Fetch",
            description: "Fetch content from a URL",
            icon: "arrow.down.circle",
            color: "#AF52DE",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "fetch_url",
            displayName: "Fetch URL",
            description: "Fetch content from a URL",
            icon: "link",
            color: "#AF52DE",
            category: .web,
            isEnabled: true
        ),
        
        // Browser Automation
        ToolInfo(
            name: "browser_navigate",
            displayName: "Navigate",
            description: "Navigate to a URL",
            icon: "safari",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "browser_click",
            displayName: "Click",
            description: "Click on an element",
            icon: "hand.tap",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "browser_type",
            displayName: "Type",
            description: "Type text into an element",
            icon: "keyboard",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "browser_screenshot",
            displayName: "Screenshot",
            description: "Take a screenshot",
            icon: "camera",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "browser_scroll",
            displayName: "Scroll",
            description: "Scroll the page",
            icon: "arrow.up.and.down",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        ToolInfo(
            name: "browser_find",
            displayName: "Find Element",
            description: "Find an element on the page",
            icon: "magnifyingglass",
            color: "#007AFF",
            category: .web,
            isEnabled: true
        ),
        
        // Code Operations
        ToolInfo(
            name: "code_interpreter",
            displayName: "Code Interpreter",
            description: "Execute code",
            icon: "curlybraces",
            color: "#FF9500",
            category: .code,
            isEnabled: true
        ),
        ToolInfo(
            name: "python",
            displayName: "Python",
            description: "Execute Python code",
            icon: "chevron.left.forwardslash.chevron.right",
            color: "#3478F6",
            category: .code,
            isEnabled: true
        ),
        ToolInfo(
            name: "javascript",
            displayName: "JavaScript",
            description: "Execute JavaScript code",
            icon: "j.square",
            color: "#F7DF1E",
            category: .code,
            isEnabled: true
        ),
        ToolInfo(
            name: "execute_code",
            displayName: "Execute Code",
            description: "Execute code in various languages",
            icon: "play.fill",
            color: "#34C759",
            category: .code,
            isEnabled: true
        ),
        
        // User Interaction
        ToolInfo(
            name: "ask_user",
            displayName: "Ask User",
            description: "Ask the user a question",
            icon: "person.fill.questionmark",
            color: "#FF3B30",
            category: .other,
            isEnabled: true
        ),
        ToolInfo(
            name: "ask",
            displayName: "Ask",
            description: "Ask the user for input",
            icon: "questionmark.bubble",
            color: "#FF3B30",
            category: .other,
            isEnabled: true
        ),
        ToolInfo(
            name: "confirm",
            displayName: "Confirm",
            description: "Ask for user confirmation",
            icon: "checkmark.shield",
            color: "#34C759",
            category: .other,
            isEnabled: true
        ),
        
        // Batch & Utility
        ToolInfo(
            name: "batch_tool",
            displayName: "Batch Operations",
            description: "Execute multiple operations",
            icon: "square.stack.3d.up",
            color: "#FF2D55",
            category: .other,
            isEnabled: true
        ),
        ToolInfo(
            name: "think",
            displayName: "Think",
            description: "Think through a problem",
            icon: "brain",
            color: "#AF52DE",
            category: .other,
            isEnabled: true
        ),
        ToolInfo(
            name: "delay",
            displayName: "Delay",
            description: "Wait for a specified time",
            icon: "clock",
            color: "#8E8E93",
            category: .other,
            isEnabled: true
        )
    ]
    
    static func info(for toolName: String) -> ToolInfo {
        defaultTools.first { $0.name == toolName } ?? ToolInfo(
            name: toolName,
            displayName: formatToolName(toolName),
            description: "",
            icon: "wrench",
            color: "#8E8E93",
            category: .other,
            isEnabled: true
        )
    }
    
    static func tools(for category: ToolCategory) -> [ToolInfo] {
        defaultTools.filter { $0.category == category }
    }
    
    static func categoryColor(for category: ToolCategory) -> String {
        switch category {
        case .file:
            return "#007AFF"
        case .search:
            return "#FF9500"
        case .web:
            return "#5AC8FA"
        case .code:
            return "#AF52DE"
        case .system:
            return "#1C1C1E"
        case .other:
            return "#8E8E93"
        }
    }
    
    private static func formatToolName(_ name: String) -> String {
        // Convert snake_case to Title Case
        name.split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
