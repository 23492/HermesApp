import SwiftUI

// MARK: - Design System Colors

enum HermesColors {
    // Primary
    static let primary = Color.accentColor
    
    // Backgrounds
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let backgroundTertiary = Color(.tertiarySystemBackground)
    
    // Grouped backgrounds
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
    
    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.gray
    
    // Semantic
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // Chat specific
    static let userBubble = Color.accentColor
    static let assistantBubble = Color(.systemGray6)
    static let toolBubble = Color.purple.opacity(0.1)
    
    // Tool colors
    static let toolColors: [String: Color] = [
        "read_file": Color.blue,
        "write_file": Color.green,
        "search_files": Color.orange,
        "list_directory": Color.purple,
        "terminal": Color.black,
        "ask_user": Color.red,
        "web_search": Color.cyan,
        "web_fetch": Color.indigo,
        "batch_tool": Color.pink
    ]
    
    static func toolColor(for name: String) -> Color {
        toolColors[name] ?? Color.gray
    }
}

// MARK: - Semantic Colors for Tools

extension Color {
    static var toolRunning: Color { .orange }
    static var toolSuccess: Color { .green }
    static var toolError: Color { .red }
    static var toolBackground: Color { Color(.systemGray6) }
}
