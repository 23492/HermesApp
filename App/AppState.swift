import Foundation
import SwiftUI
import Combine

// MARK: - App State

@Observable
@MainActor
final class AppState {
    // MARK: - Properties
    
    var selectedConversationId: UUID?
    var isShowingSidebar: Bool = true
    var currentModel: String = "hermes-agent"
    
    // MARK: - API Configuration
    
    var apiConfiguration: APIConfiguration {
        get {
            APIConfiguration(
                baseURL: UserDefaults.standard.string(forKey: "api.baseURL") ?? APIConfiguration.default.baseURL,
                apiKey: UserDefaults.standard.string(forKey: "api.apiKey"),
                timeout: UserDefaults.standard.double(forKey: "api.timeout") > 0
                    ? UserDefaults.standard.double(forKey: "api.timeout")
                    : APIConfiguration.default.timeout,
                maxRetries: UserDefaults.standard.integer(forKey: "api.maxRetries") > 0
                    ? UserDefaults.standard.integer(forKey: "api.maxRetries")
                    : APIConfiguration.default.maxRetries,
                retryDelay: UserDefaults.standard.double(forKey: "api.retryDelay") > 0
                    ? UserDefaults.standard.double(forKey: "api.retryDelay")
                    : APIConfiguration.default.retryDelay
            )
        }
        set {
            UserDefaults.standard.set(newValue.baseURL, forKey: "api.baseURL")
            UserDefaults.standard.set(newValue.apiKey, forKey: "api.apiKey")
            UserDefaults.standard.set(newValue.timeout, forKey: "api.timeout")
            UserDefaults.standard.set(newValue.maxRetries, forKey: "api.maxRetries")
            UserDefaults.standard.set(newValue.retryDelay, forKey: "api.retryDelay")
        }
    }
    
    // MARK: - UI Settings
    
    var theme: AppTheme {
        get {
            AppTheme(rawValue: UserDefaults.standard.string(forKey: "ui.theme") ?? "") ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ui.theme")
            applyTheme()
        }
    }
    
    var fontSize: FontSize {
        get {
            FontSize(rawValue: UserDefaults.standard.string(forKey: "ui.fontSize") ?? "") ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ui.fontSize")
        }
    }
    
    var codeFontSize: FontSize {
        get {
            FontSize(rawValue: UserDefaults.standard.string(forKey: "ui.codeFontSize") ?? "") ?? .small
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ui.codeFontSize")
        }
    }
    
    var showThinking: Bool {
        get {
            UserDefaults.standard.bool(forKey: "ui.showThinking")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ui.showThinking")
        }
    }
    
    var enableStreaming: Bool {
        get {
            UserDefaults.standard.object(forKey: "ui.enableStreaming") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ui.enableStreaming")
        }
    }
    
    var autoGenerateTitles: Bool {
        get {
            UserDefaults.standard.object(forKey: "ui.autoGenerateTitles") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ui.autoGenerateTitles")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        applyTheme()
    }
    
    // MARK: - Theme Management
    
    private func applyTheme() {
        // Theme is applied via environment values in views
        // This can be extended for more complex theming
    }
    
    // MARK: - Helper Methods
    
    func resetToDefaults() {
        apiConfiguration = APIConfiguration.default
        theme = .system
        fontSize = .medium
        codeFontSize = .small
        showThinking = false
        enableStreaming = true
        autoGenerateTitles = true
    }
}

// MARK: - Enums

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case system
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum FontSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var value: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 20
        }
    }
}

// MARK: - Environment Key

private struct AppStateKey: EnvironmentKey {
    @MainActor
    static let defaultValue = AppState()
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
