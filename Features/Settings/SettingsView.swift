import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @State private var appState = AppState()
    @State private var showingResetConfirmation = false
    
    var body: some View {
        TabView {
            APISettingsView()
                .tabItem {
                    Label("API", systemImage: "server.rack")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
        .environment(appState)
    }
}

// MARK: - API Settings

struct APISettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    
    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            Section("Server Configuration") {
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        baseURL = appState.apiConfiguration.baseURL
                    }
                
                SecureField("API Key (optional)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        apiKey = appState.apiConfiguration.apiKey ?? ""
                    }
                
                HStack {
                    Button("Test Connection") {
                        Task {
                            await testConnection()
                        }
                    }
                    .disabled(testStatus == .testing)
                    
                    Spacer()
                    
                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .success:
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                                .foregroundStyle(.green)
                        }
                    case .failure(let error):
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Section("Advanced") {
                HStack {
                    Text("Timeout")
                    Spacer()
                    TextField("", value: .init(
                        get: { appState.apiConfiguration.timeout },
                        set: { updateTimeout($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Max Retries")
                    Spacer()
                    Stepper("", value: .init(
                        get: { appState.apiConfiguration.maxRetries },
                        set: { updateMaxRetries($0) }
                    ), in: 0...10)
                    Text("\(appState.apiConfiguration.maxRetries)")
                        .frame(width: 30)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func updateTimeout(_ value: Double) {
        var config = appState.apiConfiguration
        config.timeout = value
        appState.apiConfiguration = config
    }
    
    private func updateMaxRetries(_ value: Int) {
        var config = appState.apiConfiguration
        config.maxRetries = value
        appState.apiConfiguration = config
    }
    
    private func testConnection() async {
        testStatus = .testing
        
        var config = appState.apiConfiguration
        config.baseURL = baseURL
        config.apiKey = apiKey.isEmpty ? nil : apiKey
        appState.apiConfiguration = config
        
        DIContainer.shared.resetAPIClient()
        let client = await DIContainer.shared.getAPIClient(configuration: config)
        
        do {
            _ = try await client.getModels()
            testStatus = .success
        } catch {
            testStatus = .failure(error.localizedDescription)
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appState.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Text Size") {
                Picker("Message Font", selection: $appState.fontSize) {
                    ForEach(FontSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                
                Picker("Code Font", selection: $appState.codeFontSize) {
                    ForEach(FontSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingResetConfirmation = false

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section("Chat Behavior") {
                Toggle("Enable Streaming", isOn: $appState.enableStreaming)
                
                Toggle("Show Thinking", isOn: $appState.showThinking)
                
                Toggle("Auto-generate Titles", isOn: $appState.autoGenerateTitles)
            }
            
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }
}

// MARK: - iOS Settings View

struct IOSSettingsView: View {
    @State private var appState = AppState()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    NavigationLink("API Configuration") {
                        APIConfigurationView()
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $appState.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    
                    Picker("Font Size", selection: $appState.fontSize) {
                        ForEach(FontSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                }
                
                Section("Chat") {
                    Toggle("Enable Streaming", isOn: $appState.enableStreaming)
                    Toggle("Show Thinking", isOn: $appState.showThinking)
                    Toggle("Auto-generate Titles", isOn: $appState.autoGenerateTitles)
                }
                
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        appState.resetToDefaults()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .environment(appState)
        }
    }
}

struct APIConfigurationView: View {
    @Environment(AppState.self) private var appState
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    
    var body: some View {
        Form {
            Section("Server") {
                TextField("Base URL", text: $baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onAppear {
                        baseURL = appState.apiConfiguration.baseURL
                    }
                    .onChange(of: baseURL) { _, newValue in
                        var config = appState.apiConfiguration
                        config.baseURL = newValue
                        appState.apiConfiguration = config
                    }
            }
            
            Section("Authentication") {
                SecureField("API Key (optional)", text: $apiKey)
                    .onAppear {
                        apiKey = appState.apiConfiguration.apiKey ?? ""
                    }
                    .onChange(of: apiKey) { _, newValue in
                        var config = appState.apiConfiguration
                        config.apiKey = newValue.isEmpty ? nil : newValue
                        appState.apiConfiguration = config
                    }
            }
            
            Section("Advanced") {
                Stepper("Timeout: \(Int(appState.apiConfiguration.timeout))s", value: .init(
                    get: { appState.apiConfiguration.timeout },
                    set: { 
                        var config = appState.apiConfiguration
                        config.timeout = $0
                        appState.apiConfiguration = config
                    }
                ), in: 10...300, step: 10)
                
                Stepper("Max Retries: \(appState.apiConfiguration.maxRetries)", value: .init(
                    get: { appState.apiConfiguration.maxRetries },
                    set: { 
                        var config = appState.apiConfiguration
                        config.maxRetries = $0
                        appState.apiConfiguration = config
                    }
                ), in: 0...10)
            }
        }
        .navigationTitle("API Configuration")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
