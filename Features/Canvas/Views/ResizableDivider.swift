import SwiftUI

// MARK: - Resizable Divider

struct ResizableDivider: View {
    @Binding var position: CGFloat
    let minPosition: CGFloat
    let maxPosition: CGFloat
    let orientation: DividerOrientation
    let onDragEnd: (() -> Void)?
    
    @State private var isDragging = false
    @State private var dragStartPosition: CGFloat = 0
    @State private var dragStartLocation: CGFloat = 0
    
    enum DividerOrientation {
        case horizontal // Divides left/right
        case vertical   // Divides top/bottom
    }
    
    init(
        position: Binding<CGFloat>,
        minPosition: CGFloat = 0.2,
        maxPosition: CGFloat = 0.8,
        orientation: DividerOrientation = .horizontal,
        onDragEnd: (() -> Void)? = nil
    ) {
        self._position = position
        self.minPosition = minPosition
        self.maxPosition = maxPosition
        self.orientation = orientation
        self.onDragEnd = onDragEnd
    }
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = orientation == .horizontal ? geometry.size.width : geometry.size.height
            
            dividerView
                .position(
                    x: orientation == .horizontal ? position * containerSize : geometry.size.width / 2,
                    y: orientation == .horizontal ? geometry.size.height / 2 : position * containerSize
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value, containerSize: containerSize)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
                .onHover { hovering in
                    isDragging = hovering
                }
        }
    }
    
    private var dividerView: some View {
        ZStack {
            // Invisible hit area
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: orientation == .horizontal ? 20 : nil,
                    height: orientation == .vertical ? 20 : nil
                )
            
            // Visible divider
            Rectangle()
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(
                    width: orientation == .horizontal ? 2 : nil,
                    height: orientation == .vertical ? 2 : nil
                )
            
            // Drag handle indicator
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: orientation == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isDragging ? .accentColor : .secondary)
                )
                .opacity(isDragging ? 1 : 0.7)
        }
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .cursor(orientation == .horizontal ? .resizeLeftRight : .resizeUpDown)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value, containerSize: CGFloat) {
        if !isDragging {
            isDragging = true
            dragStartPosition = position
            dragStartLocation = orientation == .horizontal ? value.startLocation.x : value.startLocation.y
        }
        
        let currentLocation = orientation == .horizontal ? value.location.x : value.location.y
        let delta = currentLocation - dragStartLocation
        let newPosition = dragStartPosition + (delta / containerSize)
        
        position = max(minPosition, min(maxPosition, newPosition))
    }
    
    private func handleDragEnded() {
        isDragging = false
        onDragEnd?()
    }
}

// MARK: - Cursor Extension

#if os(macOS)
private extension View {
    func cursor(_ type: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                type.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
#else
private extension View {
    func cursor(_ type: Any) -> some View {
        self // No-op on iOS
    }
}
#endif

// MARK: - Canvas Split View

struct CanvasSplitView<Content: View, Canvas: View>: View {
    @Binding var splitPosition: CGFloat
    let minSplitPosition: CGFloat
    let maxSplitPosition: CGFloat
    let layout: CanvasLayout
    let content: () -> Content
    let canvas: () -> Canvas
    
    init(
        splitPosition: Binding<CGFloat>,
        minSplitPosition: CGFloat = 0.2,
        maxSplitPosition: CGFloat = 0.8,
        layout: CanvasLayout,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder canvas: @escaping () -> Canvas
    ) {
        self._splitPosition = splitPosition
        self.minSplitPosition = minSplitPosition
        self.maxSplitPosition = maxSplitPosition
        self.layout = layout
        self.content = content
        self.canvas = canvas
    }
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                switch layout {
                case .chatOnly:
                    content()
                case .canvasOnly:
                    canvas()
                case .sideBySide:
                    sideBySideLayout(in: geometry)
                case .stacked:
                    stackedLayout(in: geometry)
                }
            }
        }
    }
    
    private func sideBySideLayout(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let leftWidth = splitPosition * width
        let rightWidth = width - leftWidth - 2 // 2 for divider
        
        return HStack(spacing: 0) {
            content()
                .frame(width: leftWidth)
            
            ResizableDivider(
                position: $splitPosition,
                minPosition: minSplitPosition,
                maxPosition: maxSplitPosition,
                orientation: .horizontal
            )
            .frame(width: 2)
            .zIndex(1)
            
            canvas()
                .frame(width: rightWidth)
        }
    }
    
    private func stackedLayout(in geometry: GeometryProxy) -> some View {
        let height = geometry.size.height
        let topHeight = splitPosition * height
        let bottomHeight = height - topHeight - 2 // 2 for divider
        
        return VStack(spacing: 0) {
            content()
                .frame(height: topHeight)
            
            ResizableDivider(
                position: $splitPosition,
                minPosition: minSplitPosition,
                maxPosition: maxSplitPosition,
                orientation: .vertical
            )
            .frame(height: 2)
            .zIndex(1)
            
            canvas()
                .frame(height: bottomHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var position: CGFloat = 0.5
        @State private var layout: CanvasLayout = .sideBySide
        
        var body: some View {
            VStack {
                Picker("Layout", selection: $layout) {
                    ForEach(CanvasLayout.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                CanvasSplitView(
                    splitPosition: $position,
                    layout: layout,
                    content: {
                        Color.blue.opacity(0.2)
                            .overlay(Text("Chat"))
                    },
                    canvas: {
                        Color.green.opacity(0.2)
                            .overlay(Text("Canvas"))
                    }
                )
            }
        }
    }
    
    return PreviewWrapper()
}
