# HermesApp

A native SwiftUI iOS/macOS chat application for the Hermes AI agent API.

## Features

### Phase 1 (Current)
- ✅ **Universal iOS/macOS app** - iOS 17.0+, macOS 14.0+
- ✅ **SwiftData persistence** - Local conversation history
- ✅ **OpenAI-compatible API** - Chat completions with streaming
- ✅ **SSE streaming** - Real-time response streaming via AsyncStream
- ✅ **Tool calling support** - Display tool calls and execution status
- ✅ **Session continuity** - X-Hermes-Session-Id header support
- ✅ **Error handling** - Retry logic with exponential backoff
- ✅ **Settings management** - API configuration, appearance settings

### Upcoming (Phase 2+)
- Markdown rendering with syntax highlighting
- Canvas support (Claude Desktop style)
- Thinking/reasoning display
- Ask User question handling
- Voice input/output
- Widgets & Shortcuts

## Architecture

### Project Structure
```
HermesApp/
├── App/                    # App entry point, state, DI
│   ├── HermesApp.swift
│   ├── AppState.swift
│   ├── DIContainer.swift
│   └── HermesCommands.swift (macOS)
├── Core/
│   ├── API/                # API client & models
│   │   ├── HermesAPIClient.swift
│   │   └── Models.swift
│   ├── Models/             # SwiftData models
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   └── ToolModels.swift
│   ├── Persistence/        # SwiftData stack
│   │   └── SwiftDataStack.swift
│   ├── Networking/         # (Future extensions)
│   └── Utils/              # Utilities
│       ├── Extensions.swift
│       └── Logger.swift
├── Features/
│   └── Chat/
│       ├── Models/
│       ├── Views/          # SwiftUI views
│       │   ├── ContentView.swift
│       │   ├── ChatView.swift
│       │   ├── ConversationListView.swift
│       │   ├── MessageBubbleView.swift
│       │   └── MessageInputView.swift
│       ├── ViewModels/     # Observable view models
│       │   ├── ChatViewModel.swift
│       │   └── ConversationListViewModel.swift
│       └── Services/
├── DesignSystem/
│   ├── Components/
│   └── Theme/
└── Resources/
```

### Key Components

#### API Client
- `HermesAPIClient` - Actor-based API client with:
  - OpenAI-compatible chat completions
  - SSE streaming with `AsyncStream<ChatChunk>`
  - Run-based events with `AsyncStream<RunEvent>`
  - Automatic retry with exponential backoff
  - Cancellation support via `CancellationToken`

#### Models (SwiftData)
- `Conversation` - Chat conversation container
- `Message` - Individual messages with tool call support
- `ToolCall`, `ToolResult`, `ActiveTool` - Tool execution tracking

#### ViewModels
- `@Observable` pattern for SwiftUI integration
- Async/await for all operations
- Proper error handling and state management

## Configuration

### API Endpoint
Default: `http://localhost:8642/v1`

Configure in Settings or via UserDefaults:
- `api.baseURL` - Base URL for Hermes API
- `api.apiKey` - Optional API key
- `api.timeout` - Request timeout (default: 60s)
- `api.maxRetries` - Max retry attempts (default: 3)

### UI Settings
- `ui.theme` - Light/Dark/System
- `ui.fontSize` - Message text size
- `ui.showThinking` - Show AI reasoning
- `ui.enableStreaming` - Enable response streaming

## Usage

### Starting Development
```bash
# 1. Open in Xcode
open HermesApp.xcodeproj

# 2. Build and run (Cmd+R)
# Select iPhone simulator or "My Mac" destination
```

### Hermes API Connection
Ensure Hermes API is running:
```bash
hermes --api-server
# or
hermes -A
```

The app connects to `http://localhost:8642/v1` by default.

## API Compatibility

### OpenAI-Compatible Endpoints
- `POST /v1/chat/completions` - Streaming chat completions
- `GET /v1/models` - List available models

### Hermes-Specific Headers
- `X-Hermes-Session-Id` - Conversation continuity

### Streaming Format
Server-Sent Events (SSE) with JSON chunks:
```
data: {"id":"...","choices":[{"delta":{"content":"Hello"}}]}

data: [DONE]
```

## Dependencies

**Phase 1**: Zero external dependencies
- Native SwiftUI for UI
- SwiftData for persistence
- URLSession for networking

**Future phases** may include:
- Splash (syntax highlighting)
- swift-markdown-ui (rich markdown)

## Platform Support

| Platform | Minimum Version | Status |
|----------|----------------|--------|
| iOS | 17.0 | ✅ Supported |
| iPadOS | 17.0 | ✅ Supported |
| macOS | 14.0 | ✅ Supported |
| visionOS | 2.0 | 🔜 Planned |

## License

MIT License - See LICENSE file for details.

## Contributing

This is part of the Hermes AI agent project. Contributions welcome!
