import SwiftUI
import MarkdownUI
import Splash

// MARK: - Code Block View

/// A view for displaying code blocks with syntax highlighting and copy functionality
struct CodeBlockView: View {
    let code: String
    let language: String?

    @State private var isCopied = false
    @State private var isExpanded = true
    @Environment(\.colorScheme) private var colorScheme

    private var displayLanguage: String {
        language?.capitalized ?? "Plain Text"
    }

    private var languageColor: SwiftUI.Color {
        switch language?.lowercased() {
        case "swift":
            return .orange
        case "python", "py":
            return .blue
        case "javascript", "js":
            return .yellow
        case "typescript", "ts":
            return .cyan
        case "html":
            return .red
        case "css":
            return .purple
        case "json":
            return .green
        case "bash", "shell", "zsh":
            return .gray
        case "sql":
            return .indigo
        case "ruby", "rb":
            return .pink
        case "go":
            return .cyan
        case "rust":
            return .orange
        case "java":
            return .red
        case "kotlin":
            return .purple
        case "c", "cpp", "c++":
            return .blue
        default:
            return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with language badge and actions
            HStack {
                // Language badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(languageColor)
                        .frame(width: 8, height: 8)

                    Text(displayLanguage)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    // Expand/collapse button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(SwiftUI.Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // Copy button
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                            Text(isCopied ? "Copied" : "Copy")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(isCopied ? .green : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isCopied ? SwiftUI.Color.green.opacity(0.1) : SwiftUI.Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(codeBackground.opacity(0.5))

            Divider()
                .background(SwiftUI.Color.secondary.opacity(0.2))

            // Code content
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: true) {
                    highlightedCode
                        .padding(12)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .background(codeBackground)
            }
        }
        .background(codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SwiftUI.Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var codeBackground: SwiftUI.Color {
        colorScheme == .dark
            ? SwiftUI.Color.systemGray6.opacity(0.8)
            : SwiftUI.Color.systemGray6
    }

    @ViewBuilder
    private var highlightedCode: some View {
        if let language = language?.lowercased(), language == "swift" {
            swiftHighlightedCode
        } else {
            Markdown("```\(language ?? "")\n\(code)\n```")
                .markdownTheme(codeOnlyTheme)
        }
    }

    @ViewBuilder
    private var swiftHighlightedCode: some View {
        let theme: Splash.Theme = colorScheme == .dark
            ? .wwdc17(withFont: .init(size: 13))
            : .sunset(withFont: .init(size: 13))

        let highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))
        let highlighted = highlighter.highlight(code)

        Text(AttributedString(highlighted))
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
    }

    private var codeOnlyTheme: MarkdownUI.Theme {
        MarkdownUI.Theme()
            .code {
                FontFamilyVariant(.monospaced)
                MarkdownUI.FontSize(13)
            }
            .codeBlock { configuration in
                configuration.label
                    .textSelection(.enabled)
            }
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = code
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif

        withAnimation {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CodeBlockView(
                code: """
                struct User: Codable {
                    let id: UUID
                    let name: String
                    let email: String

                    func greet() -> String {
                        return "Hello, \\(name)!"
                    }
                }
                """,
                language: "swift"
            )

            CodeBlockView(
                code: """
                function calculateSum(a, b) {
                    return a + b;
                }

                const result = calculateSum(5, 3);
                console.log(result); // 8
                """,
                language: "javascript"
            )

            CodeBlockView(
                code: "This is some plain text without syntax highlighting",
                language: nil
            )
        }
        .padding()
    }
}
