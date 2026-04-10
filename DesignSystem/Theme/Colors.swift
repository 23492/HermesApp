import SwiftUI

// MARK: - Cross-Platform Color Helpers

#if os(iOS)
private let _systemBackground = Color(.systemBackground)
private let _secondarySystemBackground = Color(.secondarySystemBackground)
private let _tertiarySystemBackground = Color(.tertiarySystemBackground)
private let _systemGroupedBackground = Color(.systemGroupedBackground)
private let _secondarySystemGroupedBackground = Color(.secondarySystemGroupedBackground)
private let _systemGray6 = Color(.systemGray6)
private let _systemGray5 = Color(.systemGray5)
private let _systemGray4 = Color(.systemGray4)
#elseif os(macOS)
private let _systemBackground = Color(nsColor: .windowBackgroundColor)
private let _secondarySystemBackground = Color(nsColor: .controlBackgroundColor)
private let _tertiarySystemBackground = Color(nsColor: .underPageBackgroundColor)
private let _systemGroupedBackground = Color(nsColor: .windowBackgroundColor)
private let _secondarySystemGroupedBackground = Color(nsColor: .controlBackgroundColor)
private let _systemGray6 = Color(nsColor: .controlBackgroundColor)
private let _systemGray5 = Color(nsColor: .separatorColor)
private let _systemGray4 = Color(nsColor: .tertiaryLabelColor)
#endif

// MARK: - Design System Colors

enum HermesColors {
    // Primary
    static let primary = Color.accentColor

    // Backgrounds
    static let backgroundPrimary = _systemBackground
    static let backgroundSecondary = _secondarySystemBackground
    static let backgroundTertiary = _tertiarySystemBackground

    // Grouped backgrounds
    static let groupedBackground = _systemGroupedBackground
    static let secondaryGroupedBackground = _secondarySystemGroupedBackground

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
    static let assistantBubble = _systemGray6
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
    static var toolBackground: Color { _systemGray6 }

    // Cross-platform system colors
    static var systemBackground: Color { _systemBackground }
    static var secondarySystemBackground: Color { _secondarySystemBackground }
    static var systemGray6: Color { _systemGray6 }
    static var systemGray5: Color { _systemGray5 }
    static var systemGray4: Color { _systemGray4 }
}
