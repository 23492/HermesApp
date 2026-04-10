import SwiftUI

// MARK: - Inline Code View

/// A view for displaying inline code with styling that matches the app theme
struct InlineCodeView: View {
    let code: String
    var style: InlineCodeStyle = .default
    
    @Environment(\.colorScheme) private var colorScheme
    
    enum InlineCodeStyle {
        case `default`
        case subtle
        case prominent
        
        func backgroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .default:
                return colorScheme == .dark 
                    ? Color.orange.opacity(0.15)
                    : Color.orange.opacity(0.1)
            case .subtle:
                return colorScheme == .dark
                    ? Color.gray.opacity(0.2)
                    : Color.gray.opacity(0.1)
            case .prominent:
                return colorScheme == .dark
                    ? Color.accentColor.opacity(0.2)
                    : Color.accentColor.opacity(0.15)
            }
        }
        
        func foregroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .default:
                return colorScheme == .dark
                    ? Color.orange.opacity(0.9)
                    : Color.orange.opacity(0.8)
            case .subtle:
                return colorScheme == .dark
                    ? Color.gray.opacity(0.9)
                    : Color.gray.opacity(0.8)
            case .prominent:
                return colorScheme == .dark
                    ? Color.accentColor.opacity(0.9)
                    : Color.accentColor.opacity(0.8)
            }
        }
    }
    
    var body: some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style.backgroundColor(for: colorScheme))
            .foregroundStyle(style.foregroundColor(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Inline Code Badge

/// A badge-style inline code view for short code references
struct InlineCodeBadge: View {
    let code: String
    var icon: String? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(code)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            colorScheme == .dark
                ? Color.accentColor.opacity(0.15)
                : Color.accentColor.opacity(0.1)
        )
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - Copyable Inline Code

/// An inline code view with tap-to-copy functionality
struct CopyableInlineCode: View {
    let code: String
    
    @State private var isCopied = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(isCopied ? .green : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                colorScheme == .dark
                    ? Color.orange.opacity(0.15)
                    : Color.orange.opacity(0.1)
            )
            .foregroundStyle(
                colorScheme == .dark
                    ? Color.orange.opacity(0.9)
                    : Color.orange.opacity(0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            InlineCodeView(code: "print()")
            InlineCodeView(code: "String", style: .subtle)
            InlineCodeView(code: "important", style: .prominent)
        }
        
        HStack(spacing: 12) {
            InlineCodeBadge(code: "Swift", icon: "swift")
            InlineCodeBadge(code: "v2.0.0")
            InlineCodeBadge(code: "Beta", icon: "exclamationmark.triangle.fill")
        }
        
        CopyableInlineCode(code: "npm install")
    }
    .padding()
}
