import SwiftUI

// MARK: - Code Canvas

struct CodeCanvas: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var textHeight: CGFloat = 0
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            codeHeader
            
            // Content
            ZStack {
                if viewModel.showDiff {
                    diffView
                } else if viewModel.isEditing {
                    editingView
                } else {
                    codeDisplayView
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            isTextEditorFocused = viewModel.isEditing
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            isTextEditorFocused = isEditing
        }
    }
    
    // MARK: - Header
    
    private var codeHeader: some View {
        HStack {
            if let language = viewModel.selectedItem?.syntaxLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "curlybraces")
                        .font(.caption)
                    Text(LanguageDetector.displayName(for: language))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Spacer()
            
            if viewModel.isEditing {
                Text("\(viewModel.editedContent.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(viewModel.selectedItem?.content.count ?? 0) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Code Display View (Read-only)
    
    private var codeDisplayView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    lineNumberView(for: viewModel.selectedItem?.content ?? "")
                        .frame(width: 50)
                        .background(Color(.secondarySystemBackground).opacity(0.5))
                    
                    // Code content
                    Text(viewModel.selectedItem?.content ?? "")
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .textSelection(.enabled)
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    lineNumberView(for: viewModel.editedContent)
                        .frame(width: 50)
                        .background(Color(.secondarySystemBackground).opacity(0.5))
                    
                    // Text editor
                    TextEditor(text: $viewModel.editedContent)
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(minWidth: geometry.size.width - 50, minHeight: geometry.size.height, alignment: .topLeading)
                        .focused($isTextEditorFocused)
                        .onChange(of: viewModel.editedContent) { _, newValue in
                            viewModel.updateContent(newValue)
                        }
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }
    
    // MARK: - Diff View
    
    private var diffView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.diffLines) { line in
                        diffLineView(line)
                    }
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                .padding(.vertical, 8)
            }
        }
    }
    
    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 4)
            
            // New line number
            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Line prefix
            Text(line.type.prefix)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(line.type.color)
                .frame(width: 15, alignment: .center)
            
            // Line content
            Text(line.content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(line.type == .header ? .blue : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(line.type.backgroundColor)
    }
    
    // MARK: - Line Numbers
    
    private static let maxLineNumbersForPerformance = 1000
    
    private func lineNumberView(for content: String) -> some View {
        let lines = content.components(separatedBy: .newlines)
        let lineCount = lines.count
        
        // Performance optimization: limit line numbers for very large files
        let shouldShowAllLines = lineCount <= Self.maxLineNumbersForPerformance
        
        return VStack(alignment: .trailing, spacing: 4) {
            if shouldShowAllLines {
                ForEach(0..<lines.count, id: \.self) { index in
                    Text("\(index + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            } else {
                // For large files, show simplified indicator
                Text("1...\(lineCount)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                
                // Show every Nth line number to reduce rendering overhead
                let step = max(1, lineCount / 50)
                ForEach(stride(from: 1, through: lineCount, by: step).map { $0 }, id: \.self) { lineNum in
                    Text("\(lineNum)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Syntax Highlighted Code View

struct SyntaxHighlightedCodeView: View {
    let code: String
    let language: String
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers
                LineNumberView(code: code)
                    .frame(width: 50)
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                
                // Highlighted code
                highlightedCode
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .textSelection(.enabled)
            }
        }
    }
    
    private var highlightedCode: some View {
        // Simple syntax highlighting based on common patterns
        // For production, would use a proper syntax highlighter
        Text(code)
            .font(.system(size: 13, design: .monospaced))
            .lineSpacing(4)
    }
}

// MARK: - Line Number View

struct LineNumberView: View {
    let code: String
    
    private var lineCount: Int {
        max(1, code.components(separatedBy: .newlines).count)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(1...lineCount, id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Code Editor View

struct CodeEditorView: View {
    @Binding var text: String
    let language: String
    @FocusState var isFocused: Bool
    let onChange: (String) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    LineNumberView(code: text)
                        .frame(width: 50)
                        .background(Color(.secondarySystemBackground).opacity(0.5))
                    
                    // Editor
                    TextEditor(text: $text)
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(minWidth: geometry.size.width - 50, minHeight: geometry.size.height)
                        .focused($isFocused)
                        .onChange(of: text) { _, newValue in
                            onChange(newValue)
                        }
                }
            }
        }
    }
}

// MARK: - Diff View

struct DiffCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Diff header
            HStack {
                Label("Comparing Changes", systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(viewModel.diffLines.filter { $0.type == .added }.count) additions")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text("\(viewModel.diffLines.filter { $0.type == .removed }.count) deletions")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            
            // Diff content
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.diffLines) { line in
                        DiffLineRow(line: line)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct DiffLineRow: View {
    let line: DiffLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 45, alignment: .trailing)
                .padding(.trailing, 4)
            
            // New line number
            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 45, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Line prefix
            Text(line.type.prefix)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(line.type.color)
                .frame(width: 15, alignment: .center)
            
            // Line content
            Text(line.content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(lineColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(line.type.backgroundColor)
    }
    
    private var lineColor: Color {
        switch line.type {
        case .header:
            return .blue
        case .added, .removed:
            return .primary
        case .unchanged:
            return .primary.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = CanvasViewModel()
    viewModel.addItem(CanvasItem(
        type: .code,
        title: "Example.swift",
        content: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello, World!\")\n            .font(.title)\n    }\n}",
        language: "swift"
    ))
    viewModel.showCanvas()
    
    return CodeCanvas(viewModel: viewModel)
}
