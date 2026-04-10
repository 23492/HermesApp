import SwiftUI

// MARK: - macOS Commands

#if os(macOS)
struct HermesCommands: Commands {
    @FocusedBinding(\.selectedConversationId) private var selectedConversationId
    
    var body: some Commands {
        // File Menu
        CommandGroup(before: .newItem) {
            Button("New Conversation") {
                NotificationCenter.default.post(
                    name: .newConversation,
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("New Window") {
                NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        // Edit Menu
        CommandMenu("Conversation") {
            Button("Clear Conversation") {
                NotificationCenter.default.post(
                    name: .clearConversation,
                    object: selectedConversationId
                )
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(selectedConversationId == nil)
            
            Divider()
            
            Button("Search Conversations") {
                NotificationCenter.default.post(
                    name: .searchConversations,
                    object: nil
                )
            }
            .keyboardShortcut("f", modifiers: .command)
            
            Divider()
            
            Button("Regenerate Response") {
                NotificationCenter.default.post(
                    name: .regenerateResponse,
                    object: selectedConversationId
                )
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(selectedConversationId == nil)
        }
        
        // View Menu
        CommandMenu("View") {
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(
                    name: .toggleSidebar,
                    object: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            
            Button("Toggle Canvas") {
                NotificationCenter.default.post(
                    name: .toggleCanvas,
                    object: nil
                )
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Focused Values

private struct SelectedConversationKey: FocusedValueKey {
    typealias Value = Binding<UUID?>
}

extension FocusedValues {
    var selectedConversationId: Binding<UUID?>? {
        get { self[SelectedConversationKey.self] }
        set { self[SelectedConversationKey.self] = newValue }
    }
}
#endif

// MARK: - Notification Names

extension Notification.Name {
    static let newConversation = Notification.Name("newConversation")
    static let clearConversation = Notification.Name("clearConversation")
    static let searchConversations = Notification.Name("searchConversations")
    static let regenerateResponse = Notification.Name("regenerateResponse")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleCanvas = Notification.Name("toggleCanvas")
}
