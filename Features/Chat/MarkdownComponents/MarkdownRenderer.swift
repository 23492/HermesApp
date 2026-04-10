import SwiftUI
import MarkdownUI
import Splash

// MARK: - Markdown Renderer

/// A wrapper around MarkdownUI that provides custom styling and syntax highlighting
struct MarkdownRenderer: View {
    let content: String
    var theme: MarkdownTheme = .default
    
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

enum MarkdownTheme {
    case `default`
    case compact
    case documentation
    
    func theme(for colorScheme: ColorScheme) -> Theme {
        switch self {
        case .default:
            return defaultTheme(for: colorScheme)
        case .compact:
            return compactTheme(for: colorScheme)
        case .documentation:
            return documentationTheme(for: colorScheme)
        }
    }
    
    private func defaultTheme(for colorScheme: ColorScheme) -> Theme {
        let textColor = colorScheme == .dark ? Color.primary : Color.primary
        let secondaryColor = colorScheme == .dark ? Color.gray : Color.gray
        let codeBackground = colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)
        let blockquoteBorder = colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.5)
        
        return Theme()
            .text {
                ForegroundColor(textColor)
                FontSize(16)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(14)
                BackgroundColor(codeBackground)
                ForegroundColor(textColor)
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
            .heading1 {
                FontWeight(.bold)
                FontSize(28)
                Padding(.bottom, 8)
            }
            .heading2 {
                FontWeight(.bold)
                FontSize(24)
                Padding(.bottom, 6)
            }
            .heading3 {
                FontWeight(.semibold)
                FontSize(20)
                Padding(.bottom, 4)
            }
            .heading4 {
                FontWeight(.semibold)
                FontSize(18)
            }
            .heading5 {
                FontWeight(.medium)
                FontSize(16)
            }
            .heading6 {
                FontWeight(.medium)
                FontSize(14)
                ForegroundColor(secondaryColor)
            }
            .paragraph {
                Padding(.vertical, 4)
            }
            .unorderedList {
                Margin(.bottom, 8)
            }
            .orderedList {
                Margin(.bottom, 8)
            }
            .listItem {
                MarkerStyle {
                    ForegroundColor(textColor)
                }
            }
            .blockquote {
                Padding(.horizontal, 16)
                Padding(.vertical, 8)
                Margin(.vertical, 8)
                Border(.leading, width: 4, color: blockquoteBorder)
                BackgroundColor(codeBackground.opacity(0.5))
            }
            .link {
                ForegroundColor(.accentColor)
                UnderlineStyle(.single)
            }
            .table {
                Margin(.vertical, 8)
            }
            .tableCell {
                Padding(.horizontal, 8)
                Padding(.vertical, 4)
                Border(.bottom, width: 0.5, color: blockquoteBorder)
            }
            .tableHeader {
                FontWeight(.bold)
                Border(.bottom, width: 1, color: textColor.opacity(0.5))
            }
            .thematicBreak {
                Margin(.vertical, 16)
                Border(.top, width: 1, color: blockquoteBorder)
            }
    }
    
    private func compactTheme(for colorScheme: ColorScheme) -> Theme {
        let baseTheme = defaultTheme(for: colorScheme)
        
        return baseTheme
            .text {
                FontSize(14)
            }
            .code {
                FontSize(12)
            }
            .heading1 {
                FontSize(22)
            }
            .heading2 {
                FontSize(20)
            }
            .heading3 {
                FontSize(18)
            }
    }
    
    private func documentationTheme(for colorScheme: ColorScheme) -> Theme {
        let baseTheme = defaultTheme(for: colorScheme)
        let codeBackground = colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05)
        
        return baseTheme
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
        // Use Splash for Swift code, fallback to plain text for others
        if language?.lowercased() == "swift" {
            do {
                let highlighted = try highlighter.highlight(content)
                return Text(highlighted)
            } catch {
                return Text(content)
            }
        }
        // For other languages, return plain text (MarkdownUI will handle basic styling)
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
            // Assistant messages get full markdown rendering
            MarkdownRenderer(content: content, theme: .default)
        } else {
            // User messages get simple text rendering
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
