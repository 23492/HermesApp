import SwiftUI

// MARK: - Document Canvas

struct DocumentCanvas: View {
    @ObservedObject var viewModel: CanvasViewModel
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            documentHeader
            
            // Content
            ZStack {
                if viewModel.showDiff {
                    diffView
                } else if viewModel.isEditing {
                    editingView
                } else {
                    documentDisplayView
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
    
    private var documentHeader: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text("Markdown Document")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Spacer()
            
            if viewModel.isEditing {
                HStack(spacing: 8) {
                    Text("\(viewModel.editedContent.count) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    let wordCount = viewModel.editedContent
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .count
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Text("\(viewModel.selectedItem?.content.count ?? 0) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    Text("\(viewModel.selectedItem?.wordCount ?? 0) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Document Display View
    
    private var documentDisplayView: some View {
        ScrollView {
            if let content = viewModel.selectedItem?.content {
                MarkdownContentView(content: content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                emptyStateView
            }
        }
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        ScrollView {
            TextEditor(text: $viewModel.editedContent)
                .font(.system(size: 14))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
                .focused($isTextEditorFocused)
                .onChange(of: viewModel.editedContent) { _, newValue in
                    viewModel.updateContent(newValue)
                }
        }
    }
    
    // MARK: - Diff View
    
    private var diffView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.diffLines) { line in
                    DiffLineRow(line: line)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No Document")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Select a document to view or edit")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Markdown Content View

struct MarkdownContentView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // For now, display as formatted text
            // In production, use a proper Markdown renderer
            FormattedMarkdownView(content: content)
        }
    }
}

// MARK: - Formatted Markdown View (Simple)

struct FormattedMarkdownView: View {
    let content: String
    
    var body: some View {
        let blocks = parseMarkdown(content)
        
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                markdownBlockView(block)
            }
        }
    }
    
    private func markdownBlockView(_ block: MarkdownBlock) -> some View {
        Group {
            switch block.type {
            case .heading1:
                Text(block.content)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            
            case .heading2:
                Text(block.content)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
            
            case .heading3:
                Text(block.content)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
            
            case .heading4, .heading5, .heading6:
                Text(block.content)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            
            case .paragraph:
                Text(block.content)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
            
            case .codeBlock:
                CodeBlockContent(code: block.content, language: block.metadata)
            
            case .bulletList:
                BulletListView(items: block.subItems ?? [block.content])
            
            case .numberedList:
                NumberedListView(items: block.subItems ?? [block.content])
            
            case .quote:
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 4)
                    
                    Text(block.content)
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
                .padding(.vertical, 8)
            
            case .horizontalRule:
                Divider()
                    .padding(.vertical, 8)
            
            case .table:
                Text(block.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // Simple markdown parser
    private func parseMarkdown(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentParagraph = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Code blocks
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(MarkdownBlock(
                        type: .codeBlock,
                        content: codeBlockContent,
                        metadata: codeBlockLanguage
                    ))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start code block
                    if !currentParagraph.isEmpty {
                        blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                        currentParagraph = ""
                    }
                    codeBlockLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                continue
            }
            
            // Headings
            if trimmed.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .heading1, content: String(trimmed.dropFirst(2))))
                continue
            }
            
            if trimmed.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .heading2, content: String(trimmed.dropFirst(3))))
                continue
            }
            
            if trimmed.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .heading3, content: String(trimmed.dropFirst(4))))
                continue
            }
            
            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .horizontalRule, content: ""))
                continue
            }
            
            // Blockquote
            if trimmed.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .quote, content: String(trimmed.dropFirst(2))))
                continue
            }
            
            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .bulletList, content: String(trimmed.dropFirst(2))))
                continue
            }
            
            // Numbered list
            if let match = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                blocks.append(MarkdownBlock(type: .numberedList, content: String(trimmed[match.upperBound...])))
                continue
            }
            
            // Empty line - end paragraph
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                continue
            }
            
            // Regular text
            if currentParagraph.isEmpty {
                currentParagraph = line
            } else {
                currentParagraph += "\n" + line
            }
        }
        
        // Don't forget the last paragraph
        if !currentParagraph.isEmpty {
            blocks.append(MarkdownBlock(type: .paragraph, content: currentParagraph))
        }
        
        return blocks
    }
}

// MARK: - Markdown Block

struct MarkdownBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    var metadata: String = ""
    var subItems: [String]?
    
    enum BlockType {
        case heading1, heading2, heading3, heading4, heading5, heading6
        case paragraph
        case codeBlock
        case bulletList
        case numberedList
        case quote
        case horizontalRule
        case table
    }
}

// MARK: - Code Block Content

struct CodeBlockContent: View {
    let code: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label
            if !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground).opacity(0.5))
            }
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color(.secondarySystemBackground).opacity(0.3))
        }
        .background(Color(.secondarySystemBackground).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - List Views

struct BulletListView: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(item)
                        .font(.body)
                        .lineSpacing(2)
                    Spacer()
                }
            }
        }
        .padding(.leading, 8)
    }
}

struct NumberedListView: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                    Text(item)
                        .font(.body)
                        .lineSpacing(2)
                    Spacer()
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = CanvasViewModel()
    viewModel.addItem(CanvasItem(
        type: .document,
        title: "README.md",
        content: """# Sample Document

This is a **sample** markdown document.

## Features

- Feature one
- Feature two
- Feature three

## Code Example

```swift
import SwiftUI

struct Example: View {
    var body: some View {
        Text("Hello")
    }
}
```

> This is a blockquote with some important information.

---

End of document.
"""
    ))
    viewModel.showCanvas()
    
    return DocumentCanvas(viewModel: viewModel)
}
