import Foundation

// MARK: - Dependency Injection Container

@MainActor
final class DIContainer {
    static let shared = DIContainer()
    
    // MARK: - API Client
    
    private var apiClient: HermesAPIClient?
    
    func getAPIClient(configuration: APIConfiguration? = nil) -> HermesAPIClient {
        if let existing = apiClient {
            return existing
        }
        
        let config = configuration ?? AppState().apiConfiguration
        let client = HermesAPIClient(configuration: config)
        apiClient = client
        return client
    }
    
    func resetAPIClient() {
        apiClient = nil
    }
    
    // MARK: - Repositories
    
    lazy var conversationRepository: ConversationRepositoryProtocol = {
        ConversationRepository()
    }()
    
    lazy var messageRepository: MessageRepositoryProtocol = {
        MessageRepository()
    }()
    
    // MARK: - View Models
    
    func makeChatViewModel(conversation: Conversation) -> ChatViewModel {
        ChatViewModel(
            conversation: conversation,
            apiClient: getAPIClient(),
            messageRepository: messageRepository
        )
    }
    
    func makeConversationListViewModel() -> ConversationListViewModel {
        ConversationListViewModel(
            repository: conversationRepository
        )
    }
    
    // MARK: - Services
    
    func makeStreamingService() -> StreamingService {
        StreamingService(apiClient: getAPIClient())
    }
}

// MARK: - View Model Factories

@MainActor
protocol ViewModelFactory {
    func makeChatViewModel(conversation: Conversation) -> ChatViewModel
    func makeConversationListViewModel() -> ConversationListViewModel
}

extension DIContainer: ViewModelFactory {}

// MARK: - Environment Injection

private struct DIContainerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: DIContainer = .shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
