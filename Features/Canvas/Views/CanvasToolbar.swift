import SwiftUI

// MARK: - Canvas Toolbar

struct CanvasToolbar: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var showingLayoutMenu = false
    @State private var showingMoreMenu = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Navigation and item info
            leftSection
            
            Spacer()
            
            // Center: Edit mode actions
            centerSection
            
            Spacer()
            
            // Right: Layout and actions
            rightSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.systemBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Left Section
    
    private var leftSection: some View {
        HStack(spacing: 8) {
            // Item selector
            if viewModel.items.count > 1 {
                Menu {
                    ForEach(viewModel.items) { item in
                        Button {
                            viewModel.selectItem(item.id)
                        } label: {
                            Label(
                                item.title,
                                systemImage: item.type.icon
                            )
                            .foregroundStyle(item.id == viewModel.selectedItemId ? Color.accentColor : Color.primary)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedItem?.type.icon ?? "doc")
                        Text(viewModel.selectedItem?.title ?? "Select Item")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else if let item = viewModel.selectedItem {
                HStack(spacing: 4) {
                    Image(systemName: item.type.icon)
                    Text(item.title)
                        .lineLimit(1)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            }
            
            // Navigation arrows
            if viewModel.items.count > 1 {
                HStack(spacing: 2) {
                    Button {
                        viewModel.selectPreviousItem()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.items.count <= 1)
                    
                    Button {
                        viewModel.selectNextItem()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.items.count <= 1)
                }
                .foregroundStyle(.secondary)
            }
            
            // Item info
            if let item = viewModel.selectedItem {
                HStack(spacing: 4) {
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    if item.type == .code {
                        Text("\(item.lineCount) lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(item.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Center Section
    
    private var centerSection: some View {
        HStack(spacing: 8) {
            if viewModel.isEditing {
                // Editing mode toolbar
                Button {
                    viewModel.discardChanges()
                } label: {
                    Label("Discard", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])
                
                if viewModel.canShowDiff {
                    Button {
                        viewModel.toggleDiff()
                    } label: {
                        Label("Diff", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.showDiff ? .accentColor : .secondary)
                }
                
                Button {
                    _ = viewModel.applyChanges()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canApplyChanges)
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                // View mode toolbar
                if let item = viewModel.selectedItem, item.canEdit {
                    Button {
                        viewModel.startEditing()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("e", modifiers: .command)
                }
            }
        }
    }
    
    // MARK: - Right Section
    
    private var rightSection: some View {
        HStack(spacing: 8) {
            // Copy button
            Button {
                viewModel.copyContent()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Copy content")
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            // Layout picker
            Menu {
                ForEach(CanvasLayout.allCases, id: \.self) { layout in
                    Button {
                        viewModel.setLayout(layout)
                    } label: {
                        Label(
                            layout.displayName,
                            systemImage: layout.icon
                        )
                        if viewModel.layout == layout {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
                
                Button {
                    viewModel.resetChatWidth()
                } label: {
                    Label("Reset Split", systemImage: "arrow.uturn.backward")
                }
            } label: {
                Image(systemName: viewModel.layout.icon)
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Change layout")
            
            // More actions
            Menu {
                Button {
                    viewModel.downloadItem()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                
                if viewModel.selectedItem?.type == .code {
                    Button {
                        // Copy as markdown code block
                        viewModel.copyContent()
                    } label: {
                        Label("Copy as Markdown", systemImage: "text.quote")
                    }
                }
                
                Divider()
                
                Button {
                    viewModel.clearItems()
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .disabled(viewModel.items.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            
            // Close button
            Button {
                viewModel.hideCanvas()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Compact Canvas Toolbar

struct CompactCanvasToolbar: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // Title
            if let item = viewModel.selectedItem {
                HStack(spacing: 4) {
                    Image(systemName: item.type.icon)
                        .font(.caption)
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Edit button
            if !viewModel.isEditing, let item = viewModel.selectedItem, item.canEdit {
                Button {
                    viewModel.startEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            
            // Copy
            Button {
                viewModel.copyContent()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            
            // Close
            Button {
                viewModel.hideCanvas()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.systemBackground)
    }
}

// MARK: - Canvas Status Bar

struct CanvasStatusBar: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // State indicator
            HStack(spacing: 4) {
                Image(systemName: viewModel.state.icon)
                    .font(.caption)
                    .foregroundStyle(viewModel.state.color)
                Text(viewModel.state.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Item count
            if viewModel.items.count > 1 {
                Text("\(viewModel.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Changes indicator
            if viewModel.hasChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.secondarySystemBackground)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        let viewModel = CanvasViewModel()
        viewModel.addItem(CanvasItem(
            type: .code,
            title: "Example.swift",
            content: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}",
            language: "swift"
        ))
        viewModel.showCanvas()
        
        return VStack(spacing: 0) {
            CanvasToolbar(viewModel: viewModel)
            
            Divider()
            
            CanvasStatusBar(viewModel: viewModel)
            
            Spacer()
        }
    }
    .frame(height: 200)
}
