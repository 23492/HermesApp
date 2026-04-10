import Foundation
import SwiftUI

// MARK: - Canvas State

enum CanvasState: String, Codable, CaseIterable {
    case empty = "empty"
    case creating = "creating"
    case editing = "editing"
    case reviewing = "reviewing"
    case applied = "applied"
    
    var displayName: String {
        switch self {
        case .empty:
            return "Empty"
        case .creating:
            return "Creating..."
        case .editing:
            return "Editing"
        case .reviewing:
            return "Reviewing"
        case .applied:
            return "Applied"
        }
    }
    
    var icon: String {
        switch self {
        case .empty:
            return "square.dashed"
        case .creating:
            return "sparkles"
        case .editing:
            return "pencil"
        case .reviewing:
            return "eye"
        case .applied:
            return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .empty:
            return .secondary
        case .creating:
            return .blue
        case .editing:
            return .orange
        case .reviewing:
            return .purple
        case .applied:
            return .green
        }
    }
}

// MARK: - Canvas Layout

enum CanvasLayout: String, Codable, CaseIterable {
    case chatOnly = "chat_only"
    case canvasOnly = "canvas_only"
    case sideBySide = "side_by_side"
    case stacked = "stacked"
    
    var displayName: String {
        switch self {
        case .chatOnly:
            return "Chat Only"
        case .canvasOnly:
            return "Canvas Only"
        case .sideBySide:
            return "Side by Side"
        case .stacked:
            return "Stacked"
        }
    }
    
    var icon: String {
        switch self {
        case .chatOnly:
            return "message.fill"
        case .canvasOnly:
            return "square.fill"
        case .sideBySide:
            return "square.split.2x1"
        case .stacked:
            return "square.split.1x2"
        }
    }
}

// MARK: - Canvas Type Extensions

extension CanvasType {
    var displayName: String {
        switch self {
        case .code:
            return "Code"
        case .document:
            return "Document"
        case .preview:
            return "Preview"
        case .diff:
            return "Diff"
        }
    }
    
    var icon: String {
        switch self {
        case .code:
            return "curlybraces"
        case .document:
            return "doc.text"
        case .preview:
            return "eye"
        case .diff:
            return "arrow.left.arrow.right"
        }
    }
    
    var defaultExtension: String {
        switch self {
        case .code:
            return "txt"
        case .document:
            return "md"
        case .preview:
            return "html"
        case .diff:
            return "diff"
        }
    }
}

// MARK: - Canvas Item Extensions

extension CanvasItem {
    /// The filename with appropriate extension
    var filename: String {
        let ext = language?.lowercased() ?? type.defaultExtension
        return "\(title).\(ext)"
    }
    
    /// Syntax highlighting language for code display
    var syntaxLanguage: String {
        language?.lowercased() ?? "plaintext"
    }
    
    /// Whether this canvas can be edited
    var canEdit: Bool {
        isEditable
    }
    
    /// Word count for documents
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// Line count for code
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
    
    /// Preview of content (first few lines)
    var contentPreview: String {
        let lines = content.components(separatedBy: .newlines)
        let previewLines = Array(lines.prefix(3))
        var preview = previewLines.joined(separator: "\n")
        if lines.count > 3 {
            preview += "\n..."
        }
        return preview
    }
}

// MARK: - Diff Line

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let content: String
}

enum DiffLineType {
    case unchanged
    case added
    case removed
    case header
    
    var color: Color {
        switch self {
        case .unchanged:
            return .primary
        case .added:
            return .green
        case .removed:
            return .red
        case .header:
            return .blue
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .unchanged:
            return Color.clear
        case .added:
            return Color.green.opacity(0.1)
        case .removed:
            return Color.red.opacity(0.1)
        case .header:
            return Color.blue.opacity(0.1)
        }
    }
    
    var prefix: String {
        switch self {
        case .unchanged:
            return " "
        case .added:
            return "+"
        case .removed:
            return "-"
        case .header:
            return "@"
        }
    }
}

// MARK: - Diff Parser

struct DiffParser {
    static func parse(diff: String) -> [DiffLine] {
        var lines: [DiffLine] = []
        let allLines = diff.components(separatedBy: .newlines)
        
        var oldLine = 0
        var newLine = 0
        
        for line in allLines {
            if line.hasPrefix("@@") {
                // Header line
                lines.append(DiffLine(
                    type: .header,
                    oldLineNumber: nil,
                    newLineNumber: nil,
                    content: line
                ))
                
                // Parse line numbers from header
                let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if let oldRange = Range(match.range(at: 1), in: line) {
                        oldLine = Int(line[oldRange]) ?? 0
                    }
                    if let newRange = Range(match.range(at: 2), in: line) {
                        newLine = Int(line[newRange]) ?? 0
                    }
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                // Added line
                lines.append(DiffLine(
                    type: .added,
                    oldLineNumber: nil,
                    newLineNumber: newLine,
                    content: String(line.dropFirst())
                ))
                newLine += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                // Removed line
                lines.append(DiffLine(
                    type: .removed,
                    oldLineNumber: oldLine,
                    newLineNumber: nil,
                    content: String(line.dropFirst())
                ))
                oldLine += 1
            } else if !line.hasPrefix("---") && !line.hasPrefix("+++") && !line.hasPrefix("diff") && !line.hasPrefix("index") {
                // Unchanged line
                lines.append(DiffLine(
                    type: .unchanged,
                    oldLineNumber: oldLine,
                    newLineNumber: newLine,
                    content: line
                ))
                oldLine += 1
                newLine += 1
            }
        }
        
        return lines
    }
    
    static func generateDiff(original: String, edited: String, filename: String = "file") -> String {
        let originalLines = original.components(separatedBy: .newlines)
        let editedLines = edited.components(separatedBy: .newlines)
        
        var diff = "diff --git a/\(filename) b/\(filename)\n"
        diff += "--- a/\(filename)\n"
        diff += "+++ b/\(filename)\n"
        
        // Simple line-by-line diff
        let maxLines = max(originalLines.count, editedLines.count)
        var i = 0
        var oldStart = 0
        var newStart = 0
        var inHunk = false
        
        func flushHunk(oldCount: Int, newCount: Int) {
            if oldCount > 0 || newCount > 0 {
                diff += "@@ -\(oldStart + 1),\(oldCount) +\(newStart + 1),\(newCount) @@\n"
            }
        }
        
        var oldCount = 0
        var newCount = 0
        
        while i < maxLines {
            let oldLine = i < originalLines.count ? originalLines[i] : nil
            let newLine = i < editedLines.count ? editedLines[i] : nil
            
            if oldLine != newLine {
                if !inHunk {
                    oldStart = i
                    newStart = i
                    inHunk = true
                    oldCount = 0
                    newCount = 0
                }
                
                if let old = oldLine {
                    diff += "-\(old)\n"
                    oldCount += 1
                }
                if let new = newLine {
                    diff += "+\(new)\n"
                    newCount += 1
                }
            } else {
                if inHunk {
                    flushHunk(oldCount: oldCount, newCount: newCount)
                    inHunk = false
                }
                if let line = oldLine {
                    diff += " \(line)\n"
                }
            }
            
            i += 1
        }
        
        return diff
    }
}

// MARK: - Language Detection

struct LanguageDetector {
    static func detect(from filename: String) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        let languageMap: [String: String] = [
            "swift": "swift",
            "py": "python",
            "js": "javascript",
            "ts": "typescript",
            "jsx": "jsx",
            "tsx": "tsx",
            "html": "html",
            "htm": "html",
            "css": "css",
            "scss": "scss",
            "sass": "sass",
            "json": "json",
            "xml": "xml",
            "yaml": "yaml",
            "yml": "yaml",
            "md": "markdown",
            "rb": "ruby",
            "go": "go",
            "rs": "rust",
            "java": "java",
            "kt": "kotlin",
            "cpp": "cpp",
            "c": "c",
            "h": "c",
            "cs": "csharp",
            "php": "php",
            "sh": "bash",
            "bash": "bash",
            "zsh": "bash",
            "sql": "sql",
            "dockerfile": "dockerfile",
            "makefile": "makefile"
        ]
        
        return languageMap[ext]
    }
    
    static func displayName(for language: String) -> String {
        let displayNames: [String: String] = [
            "swift": "Swift",
            "python": "Python",
            "javascript": "JavaScript",
            "typescript": "TypeScript",
            "jsx": "JSX",
            "tsx": "TSX",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "json": "JSON",
            "xml": "XML",
            "yaml": "YAML",
            "markdown": "Markdown",
            "ruby": "Ruby",
            "go": "Go",
            "rust": "Rust",
            "java": "Java",
            "kotlin": "Kotlin",
            "cpp": "C++",
            "c": "C",
            "csharp": "C#",
            "php": "PHP",
            "bash": "Shell",
            "sql": "SQL",
            "dockerfile": "Dockerfile",
            "plaintext": "Plain Text"
        ]
        
        return displayNames[language.lowercased()] ?? language.capitalized
    }
}
