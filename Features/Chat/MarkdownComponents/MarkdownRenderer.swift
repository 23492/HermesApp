import SwiftUI
@_exported import MarkdownUI
import Splash

// MARK: - Markdown Renderer

/// A wrapper around MarkdownUI that provides custom styling and syntax highlighting
struct MarkdownRenderer: View {
    let content: String
    var theme: MarkdownThemeStyle = .default

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Markdown(content)
            .markdownTheme(theme.theme(for: colorScheme))
            .markdownCodeSyntaxHighlighter(
                SplashCodeSyntaxHighlighter(theme: colorScheme == .dark ? .wwdc17(withFont: .init(size: 14)) : .sunset(withFont: .init(size: 14)))
            )
    }
}

// MARK: - Markdown Theme Configuration

enum MarkdownThemeStyle {
    case `default`
    case compact
    case documentation

    @MainActor func theme(for colorScheme: ColorScheme) -> MarkdownUI.Theme {
        switch self {
        case .default:
            return Self.defaultTheme(for: colorScheme)
        case .compact:
            return Self.compactTheme(for: colorScheme)
        case .documentation:
            return Self.documentationTheme(for: colorScheme)
        }
    }

    @MainActor private static func defaultTheme(for colorScheme: ColorScheme) -> MarkdownUI.Theme {
        let codeBackground: SwiftUI.Color = .systemGray6

        return .init()
            .text {
                ForegroundColor(.primary)
                MarkdownUI.FontSize(16)
            }
            .code {
                FontFamilyVariant(.monospaced)
                MarkdownUI.FontSize(14)
                BackgroundColor(codeBackground)
            }
            .strong {
                FontWeight(.bold)
            }
            .emphasis {
                FontStyle(.italic)
            }
            .strikethrough {
                StrikethroughStyle(.single)
            }
            .link {
                ForegroundColor(.accentColor)
                UnderlineStyle(.single)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        MarkdownUI.FontSize(28)
                    }
                    .padding(.bottom, 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        MarkdownUI.FontSize(24)
                    }
                    .padding(.bottom, 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        MarkdownUI.FontSize(20)
                    }
                    .padding(.bottom, 4)
            }
            .heading4 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        MarkdownUI.FontSize(18)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.medium)
                        MarkdownUI.FontSize(16)
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.medium)
                        MarkdownUI.FontSize(14)
                        ForegroundColor(.gray)
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .padding(.vertical, 4)
            }
            .blockquote { configuration in
                configuration.label
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .fill(SwiftUI.Color.gray.opacity(0.5))
                            .frame(width: 4),
                        alignment: .leading
                    )
                    .background(codeBackground.opacity(0.5))
                    .padding(.vertical, 8)
            }
            .codeBlock { configuration in
                configuration.label
                    .padding(12)
                    .background(codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 4)
            }
            .table { configuration in
                configuration.label
                    .padding(.vertical, 8)
            }
            .thematicBreak {
                Divider()
                    .padding(.vertical, 16)
            }
    }

    @MainActor private static func compactTheme(for colorScheme: ColorScheme) -> MarkdownUI.Theme {
        return .init()
            .text {
                MarkdownUI.FontSize(14)
            }
            .code {
                FontFamilyVariant(.monospaced)
                MarkdownUI.FontSize(12)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle { FontWeight(.bold); MarkdownUI.FontSize(22) }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle { FontWeight(.bold); MarkdownUI.FontSize(20) }
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle { FontWeight(.semibold); MarkdownUI.FontSize(18) }
            }
    }

    @MainActor private static func documentationTheme(for colorScheme: ColorScheme) -> MarkdownUI.Theme {
        let codeBackground: SwiftUI.Color = colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05)

        return defaultTheme(for: colorScheme)
            .codeBlock { configuration in
                configuration.label
                    .padding(12)
                    .background(codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
    }
}

// MARK: - Splash Syntax Highlighter

/// Syntax highlighter using Splash for Swift code
struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let splashTheme: Splash.Theme
    private let highlighter: SyntaxHighlighter<AttributedStringOutputFormat>

    init(theme: Splash.Theme) {
        self.splashTheme = theme
        self.highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        if language?.lowercased() == "swift" {
            let highlighted = highlighter.highlight(content)
            return Text(AttributedString(highlighted))
        }
        return Text(content)
    }
}

// MARK: - Markdown Content View

/// A view that renders markdown content with proper styling for chat messages
struct MarkdownContentView: View {
    let content: String
    let isAssistant: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isAssistant {
            MarkdownRenderer(content: content, theme: .default)
        } else {
            Text(content)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MarkdownContentView(
                content: """
                # Hello World

                This is **bold** and *italic* text.

                ## Code Example
                ```swift
                func greet() {
                    print("Hello, World!")
                }
                ```

                ## List
                - Item 1
                - Item 2
                - Item 3

                ## Blockquote
                > This is a blockquote

                ## Link
                [Visit Apple](https://apple.com)
                """,
                isAssistant: true
            )
            .padding()
        }
    }
}
