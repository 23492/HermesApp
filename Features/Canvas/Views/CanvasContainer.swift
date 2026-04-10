import SwiftUI

// MARK: - Canvas Container

struct CanvasContainer<Content: View>: View {
    @StateObject private var viewModel: CanvasViewModel
    @ViewBuilder let content: () -> Content
    
    // Animation states
    @State private var isAnimating = false
    
    init(
        viewModel: CanvasViewModel? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        if let viewModel = viewModel {
            self._viewModel = StateObject(wrappedValue: viewModel)
        } else {
            self._viewModel = StateObject(wrappedValue: CanvasViewModel())
        }
        self.content = content
    }
    
    var body: some View {
        CanvasSplitView(
            splitPosition: $viewModel.chatWidth,
            minSplitPosition: viewModel.minChatWidth,
            maxSplitPosition: viewModel.maxChatWidth,
            layout: viewModel.layout,
            content: content,
            canvas: canvasView
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.layout)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedItemId)
        .environmentObject(viewModel)
    }
    
    // MARK: - Canvas View
    
    @ViewBuilder
    private var canvasView: some View {
        if viewModel.isVisible && viewModel.hasItems {
            VStack(spacing: 0) {
                // Toolbar
                CanvasToolbar(viewModel: viewModel)
                
                // Content based on canvas type
                canvasContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Status bar
                CanvasStatusBar(viewModel: viewModel)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            .padding(8)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if viewModel.isVisible {
            emptyCanvasView
                .transition(.opacity)
        }
    }
    
    // MARK: - Canvas Content
    
    @ViewBuilder
    private var canvasContent: some View {
        if let item = viewModel.selectedItem {
            switch item.type {
            case .code:
                CodeCanvas(viewModel: viewModel)
            case .document:
                DocumentCanvas(viewModel: viewModel)
            case .preview:
                PreviewCanvas(viewModel: viewModel)
            case .diff:
                DiffCanvasView(viewModel: viewModel)
            }
        } else {
            emptyCanvasView
        }
    }
    
    // MARK: - Empty Canvas View
    
    private var emptyCanvasView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("Canvas Empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Waiting for content from the AI...")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.hideCanvas()
            } label: {
                Text("Hide Canvas")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(8)
    }
}

// MARK: - Canvas Overlay

struct CanvasOverlay<Content: View>: View {
    @StateObject private var viewModel: CanvasViewModel
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content
    
    init(
        isPresented: Binding<Bool>,
        viewModel: CanvasViewModel? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        if let viewModel = viewModel {
            self._viewModel = StateObject(wrappedValue: viewModel)
        } else {
            self._viewModel = StateObject(wrappedValue: CanvasViewModel())
        }
        self.content = content
    }
    
    var body: some View {
        ZStack {
            content()
            
            if isPresented && viewModel.hasItems {
                canvasSheet
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
        .environmentObject(viewModel)
    }
    
    private var canvasSheet: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Compact toolbar
                    CompactCanvasToolbar(viewModel: viewModel)
                    
                    // Canvas content
                    canvasContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: min(geometry.size.width * 0.6, 600))
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.2), radius: 16, x: -4, y: 0)
                )
            }
        }
        .ignoresSafeArea(.container, edges: .vertical)
    }
    
    @ViewBuilder
    private var canvasContent: some View {
        if let item = viewModel.selectedItem {
            Group {
                switch item.type {
                case .code:
                    CodeCanvas(viewModel: viewModel)
                case .document:
                    DocumentCanvas(viewModel: viewModel)
                case .preview:
                    PreviewCanvas(viewModel: viewModel)
                case .diff:
                    DiffCanvasView(viewModel: viewModel)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.5))
                
                Text("No Content")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Floating Canvas Button

struct FloatingCanvasButton: View {
    @ObservedObject var viewModel: CanvasViewModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.state.icon)
                    .font(.system(size: 14, weight: .semibold))
                
                if viewModel.hasItems {
                    Text("\(viewModel.items.count)")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(viewModel.state.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(viewModel.state.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Canvas Toggle Button

struct CanvasToggleButton: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.toggleVisibility()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isVisible ? "square.fill" : "square")
                    .font(.system(size: 12, weight: .semibold))
                
                Text("Canvas")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(viewModel.isVisible ? .accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.isVisible ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(viewModel.isVisible ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .help("Toggle Canvas (⌘⇧C)")
    }
}

// MARK: - Canvas Badge

struct CanvasBadge: View {
    let count: Int
    let isNew: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isNew {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.accentColor)
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = CanvasViewModel()
        
        var body: some View {
            CanvasContainer(viewModel: viewModel) {
                Color.blue.opacity(0.1)
                    .overlay(Text("Chat Content"))
            }
            .onAppear {
                viewModel.addItem(CanvasItem(
                    type: .code,
                    title: "Example.swift",
                    content: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}",
                    language: "swift"
                ))
                viewModel.showCanvas()
            }
        }
    }
    
    return PreviewWrapper()
}
