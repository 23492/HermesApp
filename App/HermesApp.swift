import SwiftUI
import SwiftData

#if os(iOS)
@main
struct HermesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.conversationRepository, ConversationRepository())
                .environment(\.messageRepository, MessageRepository())
        }
        .modelContainer(SwiftDataStack.shared)
    }
}
#elseif os(macOS)
@main
struct HermesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.conversationRepository, ConversationRepository())
                .environment(\.messageRepository, MessageRepository())
        }
        .modelContainer(SwiftDataStack.shared)
        .commands {
            HermesCommands()
        }
        
        Settings {
            SettingsView()
        }
    }
}
#endif

// MARK: - App Delegate

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAppearance()
        return true
    }

    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
#endif

// MARK: - Dependency Injection Environment Keys

private struct ConversationRepositoryKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: ConversationRepositoryProtocol = ConversationRepository()
}

private struct MessageRepositoryKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: MessageRepositoryProtocol = MessageRepository()
}

extension EnvironmentValues {
    var conversationRepository: ConversationRepositoryProtocol {
        get { self[ConversationRepositoryKey.self] }
        set { self[ConversationRepositoryKey.self] = newValue }
    }
    
    var messageRepository: MessageRepositoryProtocol {
        get { self[MessageRepositoryKey.self] }
        set { self[MessageRepositoryKey.self] = newValue }
    }
}
