# Architecture Documentation

This document describes the architecture and design decisions of HermesApp.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Design Patterns](#design-patterns)
3. [Data Flow](#data-flow)
4. [Module Structure](#module-structure)
5. [Concurrency Model](#concurrency-model)
6. [Error Handling](#error-handling)

## High-Level Architecture

HermesApp follows a **feature-based modular architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ ChatView │  │ Canvas   │  │ Settings │  │  List    │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼─────────┘
        │             │             │             │
┌───────▼─────────────▼─────────────▼─────────────▼─────────┐
│                    ViewModel Layer                          │
│         (@Observable, @MainActor, async/await)              │
└───────┬─────────────────────────────────────────┬───────────┘
        │                                         │
┌───────▼─────────────┐              ┌────────────▼──────────┐
│    Services Layer   │              │   Persistence Layer   │
│  ┌───────────────┐  │              │  ┌─────────────────┐  │
│  │ HermesAPI     │  │              │  │ SwiftData Stack │  │
│  │ Client (Actor)│  │              │  └─────────────────┘  │
│  └───────────────┘  │              └───────────────────────┘
└─────────────────────┘
```

## Design Patterns

### 1. MVVM (Model-View-ViewModel)

The primary pattern throughout the app:

```swift
// Model (SwiftData)
@Model
class Message {
    var content: String
    var role: MessageRole
    // ...
}

// ViewModel (@Observable for SwiftUI 5.0+)
@MainActor
@Observable
class ChatViewModel {
    var messages: [Message] = []
    var isLoading = false
    
    func sendMessage(_ text: String) async {
        // ...
    }
}

// View (SwiftUI)
struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        MessageList(messages: viewModel.messages)
    }
}
```

### 2. Repository Pattern

Abstracts data access for testability:

```swift
protocol ConversationRepositoryProtocol {
    func fetchConversations() async throws -> [Conversation]
    func save(_ conversation: Conversation) async throws
    func delete(_ conversation: Conversation) async throws
}

@MainActor
class ConversationRepository: ConversationRepositoryProtocol {
    private let context: ModelContext
    
    // Implementation...
}
```

### 3. Actor-Based Networking

Thread-safe API client using Swift actors:

```swift
actor HermesAPIClient {
    private let session: URLSession
    private var activeTasks: [String: Task<Void, Never>] = [:]
    
    func sendMessage(_ request: ChatRequest) async throws -> AsyncStream<ChatChunk> {
        // Actor-isolated state access
    }
    
    func cancelRequest(id: String) {
        activeTasks[id]?.cancel()
    }
}
```

## Data Flow

### Sending a Message

```
1. User types message
   ↓
2. ChatViewModel.sendMessage() called
   ↓
3. Save user message to SwiftData
   ↓
4. Call HermesAPIClient.sendMessage()
   ↓
5. Stream response via AsyncStream
   ↓
6. Update UI with each chunk
   ↓
7. Save assistant message to SwiftData
```

### Handling Tool Calls

```
1. SSE event: tool.started received
   ↓
2. Parse tool name and arguments
   ↓
3. Create ActiveTool model
   ↓
4. Show ToolExecutionView in UI
   ↓
5. SSE event: tool.completed received
   ↓
6. Update tool result
   ↓
7. Collapse tool view or show result
```

## Module Structure

### App Module

Entry point and global configuration:

- `HermesApp.swift` - Platform-specific @main structs
- `AppState.swift` - Global app state (current conversation, settings)
- `DIContainer.swift` - Dependency registration
- `HermesCommands.swift` - macOS menu commands

### Core Module

Reusable infrastructure:

#### API
- `HermesAPIClient.swift` - Main API client (actor)
- `Models.swift` - Request/response DTOs
- `SSEParser.swift` - Server-Sent Events parsing

#### Models
SwiftData models for persistence:
- `Conversation.swift` - Chat container
- `Message.swift` - Individual messages
- `ToolModels.swift` - Tool call/result types

#### Persistence
- `SwiftDataStack.swift` - Model container setup
- `ConversationRepository.swift` - Data access
- `MessageRepository.swift` - Message operations

### Features Module

#### Chat Feature

Views:
- `ContentView.swift` - Root container
- `ChatView.swift` - Main chat interface
- `MessageBubbleView.swift` - Individual message display
- `MessageInputView.swift` - Text input with @mentions
- `ConversationListView.swift` - Sidebar/history

ViewModels:
- `ChatViewModel.swift` - Message handling, streaming
- `ConversationListViewModel.swift` - History management

Markdown Components:
- `MarkdownRenderer.swift` - MarkdownUI integration
- `CodeBlockView.swift` - Syntax highlighted code
- `InlineCodeView.swift` - Inline code styling

Tool Views:
- `ToolCallView.swift` - Tool invocation display
- `ToolResultView.swift` - Tool output display
- `ToolExecutionView.swift` - Live execution indicator
- `ActionStatusBar.swift` - Status bar for active tools
- `ToolIcon.swift` - Tool type icons

Reasoning Views:
- `ThinkingBlock.swift` - Collapsible reasoning
- `ReasoningStreamView.swift` - Real-time reasoning

Question Views:
- `AskUserQuestionView.swift` - Question prompts
- `QuestionHistoryView.swift` - Previous Q&A

#### Canvas Feature

Views:
- `CanvasContainer.swift` - Split view container
- `CodeCanvas.swift` - Code editor with diff
- `DocumentCanvas.swift` - Markdown editor
- `PreviewCanvas.swift` - Live preview
- `CanvasToolbar.swift` - Apply/Discard actions
- `ResizableDivider.swift` - Draggable divider

ViewModels:
- `CanvasViewModel.swift` - Canvas state management

### DesignSystem Module

Reusable UI components:
- `ButtonStyles.swift` - Custom button styles
- `Color+Theme.swift` - Theme colors
- `View+Modifiers.swift` - Common modifiers

## Concurrency Model

HermesApp uses **Swift 6 strict concurrency** throughout.

### @MainActor Usage

All UI-related code is marked `@MainActor`:

```swift
@MainActor
@Observable
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    func sendMessage(_ text: String) async {
        // Runs on MainActor
        isLoading = true
        
        // Call non-isolated actor method
        let stream = await apiClient.sendMessage(request)
        
        // Back on MainActor
        for await chunk in stream {
            messages.append(chunk)
        }
    }
}
```

### Actor Isolation

Heavy operations run on background actors:

```swift
actor MarkdownRenderer {
    func render(_ markdown: String) -> NSAttributedString {
        // Heavy parsing on background actor
    }
}

actor PersistenceActor {
    func save(_ message: Message) async throws {
        // Database operations
    }
}
```

### Non-Isolated Deinit

For types requiring deinit access to actor-isolated properties:

```swift
@MainActor
class ChatViewModel: ObservableObject {
    // Allow deinit access without MainActor assumption
    nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    
    nonisolated deinit {
        cancellables.removeAll()
    }
}
```

## Error Handling

### Layered Error Types

```swift
// API errors
enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(Int, String)
}

// Persistence errors
enum PersistenceError: Error {
    case saveFailed(Error)
    case fetchFailed(Error)
    case notFound
}

// User-facing errors
enum UserError: LocalizedError {
    case networkUnavailable
    case serverUnreachable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection"
        case .serverUnreachable:
            return "Cannot connect to Hermes API"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
}
```

### Error Propagation

```swift
// API Layer
func sendMessage(_ request: ChatRequest) async throws -> AsyncStream<ChatChunk> {
    guard let url = URL(string: baseURL) else {
        throw APIError.invalidURL
    }
    // ...
}

// ViewModel Layer
func sendMessage(_ text: String) async {
    do {
        let stream = try await apiClient.sendMessage(request)
        // Handle stream...
    } catch let error as APIError {
        self.error = mapToUserError(error)
    } catch {
        self.error = .unknown
    }
}

// View Layer
struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        MessageList()
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
    }
}
```

## Dependencies

### External Packages

| Package | Version | Purpose |
|---------|---------|---------|
| MarkdownUI | 2.0.0+ | Markdown rendering |
| Splash | 0.16.0+ | Syntax highlighting |

### System Frameworks

- SwiftUI
- SwiftData
- Foundation
- Combine (for cancellables)

## Performance Considerations

1. **Virtual Scrolling** - Only render visible messages
2. **Lazy Loading** - Load conversation history on demand
3. **Actor Isolation** - Prevent main thread blocking
4. **SwiftData Optimization** - Batch saves, background context
5. **Image Caching** - Cache rendered markdown

## Testing Strategy

### Unit Tests

```swift
@MainActor
final class ChatViewModelTests: XCTestCase {
    func testSendMessage() async {
        let viewModel = ChatViewModel()
        await viewModel.sendMessage("Hello")
        XCTAssertEqual(viewModel.messages.count, 2)
    }
}
```

### Integration Tests

Test API client with mock server or local Hermes instance.

### UI Tests

XCUITest for critical user flows:
- Send message
- Receive streaming response
- Tool execution display
