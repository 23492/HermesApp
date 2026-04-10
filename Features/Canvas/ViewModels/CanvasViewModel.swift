import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Canvas View Model

@MainActor
final class CanvasViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var items: [CanvasItem] = []
    @Published var selectedItemId: UUID?
    @Published var layout: CanvasLayout = .sideBySide
    @Published var state: CanvasState = .empty
    @Published var isVisible: Bool = false
    
    // Editing state
    @Published var editedContent: String = ""
    @Published var isEditing: Bool = false
    @Published var hasChanges: Bool = false
    @Published var originalContent: String = ""
    
    // Split view sizing
    @Published var chatWidth: CGFloat = 0.5 // 50% default
    @Published var minChatWidth: CGFloat = 0.2
    @Published var maxChatWidth: CGFloat = 0.8
    
    // Diff view
    @Published var showDiff: Bool = false
    @Published var diffLines: [DiffLine] = []
    
    // Search
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var currentSearchIndex: Int = 0
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let apiClient: HermesAPIClient
    private let conversationId: UUID?
    
    // MARK: - Computed Properties
    
    var selectedItem: CanvasItem? {
        items.first { $0.id == selectedItemId }
    }
    
    var hasItems: Bool {
        !items.isEmpty
    }
    
    var canApplyChanges: Bool {
        hasChanges && selectedItem != nil
    }
    
    var canShowDiff: Bool {
        hasChanges && !originalContent.isEmpty && !editedContent.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        apiClient: HermesAPIClient = HermesAPIClient(),
        conversationId: UUID? = nil
    ) {
        self.apiClient = apiClient
        self.conversationId = conversationId
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Watch for content changes to update hasChanges
        $editedContent
            .removeDuplicates()
            .sink { [weak self] newContent in
                guard let self = self, let selected = self.selectedItem else { return }
                self.hasChanges = newContent != selected.content
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Canvas Management
    
    func addItem(_ item: CanvasItem) {
        // Update if exists, otherwise add
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        
        // Auto-select if first item
        if items.count == 1 {
            selectItem(item.id)
        }
        
        updateState()
    }
    
    func updateItems(_ newItems: [CanvasItem]) {
        // Merge with existing items
        for item in newItems {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                // Preserve edited content if currently editing
                if selectedItemId == item.id && isEditing {
                    var updatedItem = item
                    updatedItem.content = editedContent
                    items[index] = updatedItem
                } else {
                    items[index] = item
                }
            } else {
                items.append(item)
            }
        }
        
        // Auto-select first item if none selected
        if selectedItemId == nil, let first = items.first {
            selectItem(first.id)
        }
        
        updateState()
    }
    
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        
        if selectedItemId == id {
            selectedItemId = items.first?.id
            resetEditingState()
        }
        
        updateState()
    }
    
    func clearItems() {
        items.removeAll()
        selectedItemId = nil
        resetEditingState()
        updateState()
    }
    
    // MARK: - Selection
    
    func selectItem(_ id: UUID?) {
        // Save current edits before switching
        if isEditing && hasChanges, let currentId = selectedItemId {
            // Could prompt to save here
        }
        
        selectedItemId = id
        resetEditingState()
        
        if let item = selectedItem {
            editedContent = item.content
            originalContent = item.content
        }
    }
    
    func selectNextItem() {
        guard let currentId = selectedItemId,
              let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = items.first?.id
            return
        }
        
        let nextIndex = (currentIndex + 1) % items.count
        selectItem(items[nextIndex].id)
    }
    
    func selectPreviousItem() {
        guard let currentId = selectedItemId,
              let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = items.last?.id
            return
        }
        
        let prevIndex = (currentIndex - 1 + items.count) % items.count
        selectItem(items[prevIndex].id)
    }
    
    // MARK: - Editing
    
    func startEditing() {
        guard selectedItem?.canEdit == true else { return }
        isEditing = true
        state = .editing
    }
    
    func stopEditing() {
        isEditing = false
        updateState()
    }
    
    func updateContent(_ newContent: String) {
        editedContent = newContent
    }
    
    func resetChanges() {
        guard let item = selectedItem else { return }
        editedContent = originalContent
        hasChanges = false
    }
    
    func discardChanges() {
        resetChanges()
        isEditing = false
        updateState()
    }
    
    func applyChanges() -> CanvasItem? {
        guard let index = items.firstIndex(where: { $0.id == selectedItemId }) else {
            return nil
        }
        
        var updatedItem = items[index]
        updatedItem.content = editedContent
        updatedItem.updatedAt = Date()
        
        items[index] = updatedItem
        originalContent = editedContent
        hasChanges = false
        isEditing = false
        state = .applied
        
        return updatedItem
    }
    
    private func resetEditingState() {
        editedContent = selectedItem?.content ?? ""
        originalContent = selectedItem?.content ?? ""
        isEditing = false
        hasChanges = false
        showDiff = false
        diffLines = []
    }
    
    // MARK: - Layout
    
    func setLayout(_ newLayout: CanvasLayout) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            layout = newLayout
        }
    }
    
    func toggleLayout() {
        let allLayouts = CanvasLayout.allCases
        guard let currentIndex = allLayouts.firstIndex(of: layout) else { return }
        
        let nextIndex = (currentIndex + 1) % allLayouts.count
        setLayout(allLayouts[nextIndex])
    }
    
    func toggleVisibility() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible.toggle()
        }
    }
    
    func showCanvas() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }
    }
    
    func hideCanvas() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
    }
    
    // MARK: - Split View Sizing
    
    func setChatWidth(_ width: CGFloat) {
        chatWidth = max(minChatWidth, min(maxChatWidth, width))
    }
    
    func resetChatWidth() {
        chatWidth = 0.5
    }
    
    // MARK: - Diff View
    
    func toggleDiff() {
        showDiff.toggle()
        
        if showDiff {
            generateDiff()
        }
    }
    
    func generateDiff() {
        guard canShowDiff else {
            diffLines = []
            return
        }
        
        let original = originalContent
        let edited = editedContent
        let filename = selectedItem?.filename ?? "file"
        
        Task.detached(priority: .userInitiated) {
            let diff = DiffParser.generateDiff(
                original: original,
                edited: edited,
                filename: filename
            )
            let parsedDiff = DiffParser.parse(diff: diff)
            
            await MainActor.run {
                self.diffLines = parsedDiff
            }
        }
    }
    
    // MARK: - Search
    
    func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            return
        }
        
        let content = editedContent
        let query = searchText
        
        Task.detached(priority: .userInitiated) {
            var results: [SearchResult] = []
            let lines = content.components(separatedBy: .newlines)
            
            for (lineIndex, line) in lines.enumerated() {
                var searchIndex = line.startIndex
                while let range = line[searchIndex...].range(of: query, options: .caseInsensitive) {
                    let absoluteRange = NSRange(
                        location: line.distance(from: line.startIndex, to: range.lowerBound),
                        length: query.count
                    )
                    results.append(SearchResult(
                        lineNumber: lineIndex + 1,
                        range: absoluteRange,
                        lineContent: line
                    ))
                    searchIndex = range.upperBound
                }
            }
            
            await MainActor.run {
                self.searchResults = results
                self.currentSearchIndex = results.isEmpty ? 0 : 1
            }
        }
    }
    
    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex % searchResults.count) + 1
    }
    
    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = currentSearchIndex <= 1 ? searchResults.count : currentSearchIndex - 1
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
    }
    
    // MARK: - Actions
    
    func copyContent() {
        guard let item = selectedItem else { return }
        
        #if os(iOS)
        UIPasteboard.general.string = item.content
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        #endif
    }
    
    func copyEditedContent() {
        #if os(iOS)
        UIPasteboard.general.string = editedContent
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editedContent, forType: .string)
        #endif
    }
    
    func downloadItem() {
        // Implementation would save to file
        Log.info("Download requested for \(selectedItem?.filename ?? "unknown")")
    }
    
    // MARK: - State Management
    
    private func updateState() {
        if items.isEmpty {
            state = .empty
        } else if isEditing {
            state = .editing
        } else if hasChanges {
            state = .reviewing
        } else {
            state = isVisible ? .creating : .empty
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    func handleKeyCommand(_ command: CanvasKeyCommand) {
        switch command {
        case .toggleCanvas:
            toggleVisibility()
        case .toggleLayout:
            toggleLayout()
        case .startEditing:
            startEditing()
        case .applyChanges:
            _ = applyChanges()
        case .discardChanges:
            discardChanges()
        case .copyContent:
            copyContent()
        case .showDiff:
            toggleDiff()
        case .nextItem:
            selectNextItem()
        case .previousItem:
            selectPreviousItem()
        case .find:
            // Would trigger search UI
            break
        }
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let range: NSRange
    let lineContent: String
}

// MARK: - Key Commands

enum CanvasKeyCommand {
    case toggleCanvas
    case toggleLayout
    case startEditing
    case applyChanges
    case discardChanges
    case copyContent
    case showDiff
    case nextItem
    case previousItem
    case find
}
