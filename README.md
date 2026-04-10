# HermesApp

A native SwiftUI iOS/macOS chat application for the Hermes AI agent API.

![Platforms](https://img.shields.io/badge/platform-iOS%2017+%20%7C%20macOS%2014+-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)

## Overview

HermesApp is a modern, native chat client for the Hermes AI agent. Built with SwiftUI and Swift 6, it provides a seamless cross-platform experience on iOS and macOS with features rivaling web-based alternatives like OpenWebUI.

### Key Features

- **Real-time Streaming** - Server-Sent Events (SSE) for live response streaming
- **Tool Calling Visualization** - Live display of tool execution with status indicators
- **Reasoning Display** - Collapsible thinking blocks (Claude-style)
- **Canvas Support** - Side-by-side code/document editing
- **Ask User Questions** - Interactive prompts during AI tasks
- **Offline History** - SwiftData persistence for conversations
- **Universal App** - Single codebase for iOS 17+ and macOS 14+

## Screenshots

> Coming soon

## Requirements

- **iOS 17.0+** or **macOS 14.0+**
- **Xcode 15.0+**
- **Swift 6.0**
- Hermes API server running locally or remotely

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/23492/HermesApp.git
cd HermesApp
```

### 2. Open in Xcode

```bash
open Package.swift
```

Or open in Xcode directly and select **File → Open** → choose `Package.swift`.

### 3. Build & Run

Select your target (iOS Simulator or "My Mac") and press **Cmd+R**.

### 4. Start Hermes API

Ensure the Hermes API server is running:

```bash
hermes --api-server
```

Or via SSH tunnel if running on a remote server:

```bash
ssh -L 8642:localhost:8642 root@192.168.2.11
```

## Architecture

### Project Structure

```
HermesApp/
├── App/                        # App entry point & DI
│   ├── HermesApp.swift         # @main app struct
│   ├── AppState.swift          # Global state management
│   ├── DIContainer.swift       # Dependency injection
│   └── HermesCommands.swift    # macOS menu commands
├── Core/                       # Core infrastructure
│   ├── API/                    # API client
│   │   ├── HermesAPIClient.swift
│   │   └── Models.swift
│   ├── Models/                 # SwiftData models
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   └── ToolModels.swift
│   ├── Persistence/            # Data layer
│   │   └── SwiftDataStack.swift
│   └── Utils/                  # Extensions & helpers
│       ├── Extensions.swift
│       └── Logger.swift
├── Features/                   # Feature modules
│   ├── Chat/                   # Core chat feature
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── MarkdownComponents/
│   ├── Canvas/                 # Side-by-side editing
│   │   ├── Views/
│   │   └── ViewModels/
│   └── Settings/               # App settings
├── DesignSystem/               # UI components
│   ├── Components/
│   └── Theme/
└── Tests/                      # Unit tests
```

### Technology Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Persistence | SwiftData |
| Networking | URLSession + AsyncStream |
| Markdown | MarkdownUI |
| Syntax Highlighting | Splash |
| Concurrency | Swift 6 Strict Concurrency |

### API Client Architecture

The `HermesAPIClient` uses an actor-based design for thread-safe networking:

```swift
actor HermesAPIClient {
    func sendMessage(_ request: ChatRequest) async throws -> AsyncStream<ChatChunk>
    func streamRunEvents(runId: String) -> AsyncStream<RunEvent>
}
```

**Key Features:**
- SSE streaming via `URLSession.bytes`
- Structured event types (message, tool, reasoning, canvas)
- Automatic retry with exponential backoff
- Cancellation support

## Configuration

### API Settings

Configure in **Settings** (macOS) or via the app menu (iOS):

| Setting | Key | Default |
|---------|-----|---------|
| Base URL | `api.baseURL` | `http://localhost:8642/v1` |
| API Key | `api.apiKey` | (optional) |
| Timeout | `api.timeout` | 60s |
| Max Retries | `api.maxRetries` | 3 |

### UI Settings

| Setting | Key | Options |
|---------|-----|---------|
| Theme | `ui.theme` | Light / Dark / System |
| Font Size | `ui.fontSize` | Small / Medium / Large |
| Show Thinking | `ui.showThinking` | Bool |
| Enable Streaming | `ui.enableStreaming` | Bool |

## Features

### 1. Chat Interface

- Real-time message streaming
- Markdown rendering with syntax highlighting
- Message actions (copy, edit, regenerate)
- Auto-resizing input with @mentions support
- Conversation history with search

### 2. Tool Calling

Visual indicators for:
- Terminal commands (bash, shell)
- File operations (read, write, patch, search)
- Web tools (search, extract)
- Browser automation (navigate, click, type)
- Code execution (Python, JavaScript)

### 3. Reasoning Display

Collapsible thinking blocks showing the AI's thought process:

```swift
ThinkingBlock(
    reasoning: message.reasoningContent,
    isExpanded: $message.isReasoningExpanded
)
```

### 4. Canvas Support

Side-by-side editing for:
- **CodeCanvas** - Code editing with line numbers and diff view
- **DocumentCanvas** - Markdown editing
- **PreviewCanvas** - Live HTML/Markdown preview

Features:
- Resizable split view
- Apply/Discard actions
- Multiple layout modes (side-by-side, stacked)

### 5. Ask User Questions

Interactive prompts during AI execution:
- Text input questions
- Confirm/Cancel dialogs
- Multiple choice selection
- Question history

## API Compatibility

### OpenAI-Compatible Endpoints

```
POST /v1/chat/completions    # Streaming chat
GET  /v1/models              # List models
```

### Hermes-Specific Extensions

```
POST /v1/runs                # Start structured run
GET  /v1/runs/{id}/events    # SSE event stream
```

**Event Types:**
- `message.delta` - Text chunks
- `tool.started` / `tool.completed` - Tool lifecycle
- `reasoning.available` - Thinking content
- `ask_user.question` - User prompts
- `canvas.update` - Canvas artifacts

## Swift 6 Concurrency

HermesApp is built with **Swift 6 strict concurrency** enabled:

- `@MainActor` for UI components and ViewModels
- `nonisolated(unsafe)` for deinit-accessible properties
- Actor isolation for networking and persistence layers
- Sendable conformance for data models

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Code Style

- Follow Swift API Design Guidelines
- Use `@MainActor` for UI-related code
- Prefer `async/await` over completion handlers
- Document public APIs with Swift DocC comments

## Troubleshooting

### Build Errors

**"target 'HermesApp' referenced in product 'HermesApp' is empty"**

The Package.swift uses `path: "."` to include all source files. Ensure you're opening `Package.swift` directly in Xcode, not generating an Xcode project.

**Swift Compiler Crashes**

Complex view bodies may cause stack overflow. Split into `@ViewBuilder` computed properties:

```swift
var body: some View {
    VStack {
        headerSection
        contentSection
        footerSection
    }
}

@ViewBuilder
private var headerSection: some View { ... }
```

### Runtime Issues

**"Cannot access cancellables from non-isolated deinit"**

Mark cancellables as `nonisolated(unsafe)`:

```swift
@MainActor
class ViewModel: ObservableObject {
    nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
}
```

**API Connection Errors**

Verify Hermes API is running:
```bash
curl http://localhost:8642/v1/models
```

## Roadmap

- [ ] Voice input/output
- [ ] iOS Home Screen widgets
- [ ] Siri Shortcuts integration
- [ ] visionOS support
- [ ] iCloud sync for conversations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Acknowledgments

- [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) - Markdown rendering
- [Splash](https://github.com/JohnSundell/Splash) - Syntax highlighting
- [Hermes Agent](https://github.com/NousResearch/hermes-agent) - Backend API

---

**Note:** This project is part of the Hermes AI agent ecosystem. For backend documentation, see the [Hermes Agent repository](https://github.com/NousResearch/hermes-agent).
