import SwiftUI

// MARK: - Tool Icon Component

struct ToolIcon: View {
    let toolName: String
    var size: CGFloat = 24
    var showBackground: Bool = true
    
    private var toolInfo: ToolInfo {
        ToolRegistry.info(for: toolName)
    }
    
    private var iconColor: Color {
        Color(hex: toolInfo.color) ?? .gray
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: size, height: size)
            }
            
            Image(systemName: toolInfo.icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tool Icon with Badge

struct ToolIconWithBadge: View {
    let toolName: String
    var size: CGFloat = 24
    var badge: ToolBadge?
    
    enum ToolBadge {
        case running
        case success
        case error
        case count(Int)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ToolIcon(toolName: toolName, size: size)
            
            if let badge = badge {
                badgeView(for: badge)
                    .offset(x: 4, y: -4)
            }
        }
    }
    
    @ViewBuilder
    private func badgeView(for badge: ToolBadge) -> some View {
        switch badge {
        case .running:
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                ProgressView()
                    .scaleEffect(0.4)
                    .tint(.white)
            }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .background(Circle().fill(Color.systemBackground))
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .background(Circle().fill(Color.systemBackground))
        case .count(let count):
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 14, minHeight: 14)
                .background(
                    Capsule()
                        .fill(Color.accentColor)
                )
        }
    }
}

// MARK: - Tool Category Icon

struct ToolCategoryIcon: View {
    let category: ToolCategory
    var size: CGFloat = 20
    
    var body: some View {
        Image(systemName: iconName(for: category))
            .font(.system(size: size * 0.6, weight: .medium))
            .foregroundStyle(color(for: category))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color(for: category).opacity(0.15))
            )
    }
    
    private func iconName(for category: ToolCategory) -> String {
        switch category {
        case .file:
            return "doc"
        case .search:
            return "magnifyingglass"
        case .web:
            return "globe"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .system:
            return "gearshape"
        case .other:
            return "puzzlepiece"
        }
    }
    
    private func color(for category: ToolCategory) -> Color {
        switch category {
        case .file:
            return .blue
        case .search:
            return .orange
        case .web:
            return .cyan
        case .code:
            return .purple
        case .system:
            return .gray
        case .other:
            return .indigo
        }
    }
}

// MARK: - Previews

#Preview("Tool Icons") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            ToolIcon(toolName: "terminal")
            ToolIcon(toolName: "web_search")
            ToolIcon(toolName: "read_file")
            ToolIcon(toolName: "write_file")
        }
        
        HStack(spacing: 16) {
            ToolIconWithBadge(toolName: "terminal", badge: .running)
            ToolIconWithBadge(toolName: "web_search", badge: .success)
            ToolIconWithBadge(toolName: "read_file", badge: .error)
            ToolIconWithBadge(toolName: "batch_tool", badge: .count(3))
        }
        
        HStack(spacing: 16) {
            ToolCategoryIcon(category: .file)
            ToolCategoryIcon(category: .search)
            ToolCategoryIcon(category: .web)
            ToolCategoryIcon(category: .code)
            ToolCategoryIcon(category: .system)
        }
    }
    .padding()
}
