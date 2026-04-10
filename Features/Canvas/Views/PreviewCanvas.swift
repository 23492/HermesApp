import SwiftUI
import WebKit

// MARK: - Preview Canvas

struct PreviewCanvas: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            previewHeader
            
            // Content
            ZStack {
                if let error = loadError {
                    errorView(message: error)
                } else if isLoading {
                    loadingView
                } else {
                    previewContent
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    
    private var previewHeader: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.caption)
                Text("Preview")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    zoomLevel = max(0.5, zoomLevel - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 45)
                
                Button {
                    zoomLevel = min(2.0, zoomLevel + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(height: 16)
                
                Button {
                    zoomLevel = 1.0
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(zoomLevel == 1.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Preview Content
    
    @ViewBuilder
    private var previewContent: some View {
        if let item = viewModel.selectedItem {
            switch item.type {
            case .preview:
                HTMLPreviewView(htmlContent: item.content, zoomLevel: $zoomLevel)
            case .document:
                MarkdownPreviewView(markdown: item.content, zoomLevel: $zoomLevel)
            case .code:
                CodePreviewView(code: item.content, language: item.language, zoomLevel: $zoomLevel)
            case .diff:
                DiffPreviewView(content: item.content, zoomLevel: $zoomLevel)
            }
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading preview...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("Preview Error")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No Preview Available")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Select an item with previewable content")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - HTML Preview View

struct HTMLPreviewView: View {
    let htmlContent: String
    @Binding var zoomLevel: CGFloat
    
    var body: some View {
        #if os(iOS)
        WebView(html: wrappedHTML)
            .scaleEffect(zoomLevel)
        #else
        // macOS fallback - show formatted text
        ScrollView {
            Text(stripHTML(htmlContent))
                .font(.body)
                .padding()
                .scaleEffect(zoomLevel)
        }
        #endif
    }
    
    private var wrappedHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    padding: 20px;
                    max-width: 100%;
                    margin: 0;
                }
                pre {
                    background: #f4f4f4;
                    padding: 15px;
                    border-radius: 5px;
                    overflow-x: auto;
                }
                code {
                    background: #f4f4f4;
                    padding: 2px 5px;
                    border-radius: 3px;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
    }
    
    private func stripHTML(_ html: String) -> String {
        // Very simple HTML stripping
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

#if os(iOS)
struct WebView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .systemBackground
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
#endif

// MARK: - Markdown Preview View

struct MarkdownPreviewView: View {
    let markdown: String
    @Binding var zoomLevel: CGFloat
    
    var body: some View {
        ScrollView {
            MarkdownContentView(content: markdown)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .scaleEffect(zoomLevel)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Code Preview View

struct CodePreviewView: View {
    let code: String
    let language: String?
    @Binding var zoomLevel: CGFloat
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers
                lineNumbers
                    .frame(width: 50 * zoomLevel)
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                
                // Code
                Text(code)
                    .font(.system(size: 13 * zoomLevel, design: .monospaced))
                    .lineSpacing(4 * zoomLevel)
                    .padding(.horizontal, 12 * zoomLevel)
                    .padding(.vertical, 8 * zoomLevel)
                    .textSelection(.enabled)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private var lineNumbers: some View {
        let lines = code.components(separatedBy: .newlines)
        
        return VStack(alignment: .trailing, spacing: 4 * zoomLevel) {
            ForEach(0..<lines.count, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: 11 * zoomLevel, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8 * zoomLevel)
            }
        }
        .padding(.vertical, 8 * zoomLevel)
    }
}

// MARK: - Diff Preview View

struct DiffPreviewView: View {
    let content: String
    @Binding var zoomLevel: CGFloat
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                let lines = DiffParser.parse(diff: content)
                ForEach(lines) { line in
                    diffLineRow(line)
                }
            }
            .padding(.vertical, 8 * zoomLevel)
            .scaleEffect(zoomLevel)
        }
    }
    
    private func diffLineRow(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11 * zoomLevel, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 45 * zoomLevel, alignment: .trailing)
                .padding(.trailing, 4 * zoomLevel)
            
            // New line number
            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11 * zoomLevel, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 45 * zoomLevel, alignment: .trailing)
                .padding(.trailing, 8 * zoomLevel)
            
            // Line prefix
            Text(line.type.prefix)
                .font(.system(size: 13 * zoomLevel, design: .monospaced))
                .foregroundStyle(line.type.color)
                .frame(width: 15 * zoomLevel, alignment: .center)
            
            // Line content
            Text(line.content)
                .font(.system(size: 13 * zoomLevel, design: .monospaced))
                .foregroundStyle(line.type == .header ? .blue : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8 * zoomLevel)
        .padding(.vertical, 1 * zoomLevel)
        .background(line.type.backgroundColor)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = CanvasViewModel()
    viewModel.addItem(CanvasItem(
        type: .preview,
        title: "preview.html",
        content: """
        <h1>Hello World</h1>
        <p>This is a <strong>preview</strong> of HTML content.</p>
        <pre><code>console.log("Hello");</code></pre>
        """
    ))
    viewModel.showCanvas()
    
    return PreviewCanvas(viewModel: viewModel)
}
