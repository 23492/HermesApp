# Hermes Swift Frontend - Project Plan

Een comprehensive plan voor een SwiftUI cross-platform (Mac + iOS) frontend voor Hermes met OpenWebUI-feature-pariteit.

---

## Executive Summary

We bouwen HermesApp: een native SwiftUI applicatie die op zowel macOS als iOS draait, en fungeert als frontend voor de Hermes AI agent API. De app biedt een moderne, native chat experience met streaming responses, tool calling visualisatie, en alle advanced features die Hermes ondersteunt.

### Key Differentiators vs OpenWebUI
- Native macOS/iOS ervaring (geen browser)
- Offline conversation history via SwiftData
- Deep OS integration (Shortcuts, Siri, Widgets)
- Native performance (virtual scrolling, smooth animations)
- Push notifications voor lange-running tasks
- **Thinking/reasoning streaming** - Zie AI's thought process real-time
- **Canvasses** - Side-by-side code/document editing zoals Claude Desktop
- **Ask User tool** - AI kan vragen stellen tijdens een task
- **Live action status** - Tool execution, API calls, file operations zichtbaar

---

## Phase 1: Research & Foundation (Week 1)

### 1.1 Technical Architecture Decisions

#### Platform Strategy
- **Minimum OS versions**: iOS 17.0+, macOS 14.0+
- **SwiftUI als primary framework** - geen UIKit/AppKit fallback nodig voor MVP
- **Universal app** - single target met platform conditionals voor specifieke UI

#### Architecture Pattern: MVVM + SwiftData
Na analyse van de opties kiezen we voor:
- **MVVM** als primary pattern (natuurlijke fit met SwiftUI)
- **SwiftData** voor lokale persistence (conversaties, settings)
- **Actor-based networking layer** voor thread-safe API calls
- **Dependency Injection** via @Environment en custom container

Rationale:
- TCA is overkill voor MVP (leercurve, boilerplate)
- SwiftData + MVVM heeft known challenges maar is managable met juiste patterns
- Apple's recommended stack voor 2025

#### Project Structure
```
HermesApp/
├── App/
│   ├── HermesApp.swift           # App entry point
│   ├── AppState.swift            # Global app state
│   └── DIContainer.swift         # Dependency injection
├── Features/
│   ├── Chat/                     # Core chat feature
│   │   ├── Models/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Services/
│   ├── Conversations/            # History management
│   ├── Models/                   # AI model selection
│   ├── Settings/                 # App configuration
│   └── Tools/                    # Tool visualization
├── Core/
│   ├── API/                      # Hermes API client
│   ├── Models/                   # Shared data models
│   ├── Persistence/              # SwiftData stack
│   ├── Networking/               # HTTP/WebSocket layer
│   └── Utils/                    # Extensions, helpers
├── DesignSystem/
│   ├── Components/               # Reusable UI components
│   ├── Theme/                    # Colors, fonts, spacing
│   └── Markdown/                 # Markdown rendering
└── Resources/
```

### 1.2 API Analysis & Client Design

#### Hermes API Endpoints

**Option 1: OpenAI-compatible Chat Completions (Basis)**
```swift
POST /v1/chat/completions          # SSE streaming, basic
POST /v1/responses                 # Stateful conversations
GET  /v1/models                    # List available models
```

**Option 2: /v1/runs - Structured Event Streaming (Aanbevolen)**
```swift
POST /v1/runs                      # Start run, krijg run_id
GET  /v1/runs/{run_id}/events      # SSE met structured events:
                                   # - message.delta (text chunks)
                                   # - tool.started (tool begint)
                                   # - tool.completed (tool klaar)
                                   # - reasoning.available (thinking content)
                                   # - run.completed / run.error
```

**Waarom /v1/runs voor onze app?**
- Gedetailleerde lifecycle events (tool status, reasoning)
- Betere UX voor "thinking" indicators
- Ask User question handling via events
- Kanvasses ondersteuning via output items

#### Streaming Strategie

```swift
// Gebruik /v1/runs voor rijke UX
enum RunEvent {
    case messageDelta(String)                    // Tekst chunk
    case toolStarted(name: String, preview: String)  // Tool start
    case toolCompleted(name: String, duration: Double, error: Bool)
    case reasoningAvailable(text: String)        // Thinking content
    case askUserQuestion(question: String)       // AI vraagt input
    case canvasUpdate(items: [CanvasItem])       // Canvas artifacts
    case completed                               // Run klaar
    case error(String)                           // Fout
}

class RunsAPIClient {
    func startRun(input: String) async throws -> String  // run_id
    func streamEvents(runId: String) -> AsyncStream<RunEvent>
    func submitUserResponse(runId: String, response: String) async
}
```

#### API Client Architecture
- **Protocol-based design** voor testability
- **Async/await** voor alle network calls
- **URLSession with delegate** voor SSE streaming
- **Automatic retry** met exponential backoff
- **Request/response interceptors** voor logging/auth

```swift
protocol HermesAPIClient {
    func sendMessage(_ request: ChatRequest, stream: Bool) async throws -> AsyncStream<ChatChunk>
    func getModels() async throws -> [Model]
    func getConversation(id: String) async throws -> Conversation
    // ... etc
}
```

### 1.3 Data Models (SwiftData)

```swift
@Model
class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    var model: String
    var sessionId: String?  // Hermes session continuity
    var runId: String?      // Active run voor /v1/runs API
    
    // Metadata
    var totalTokens: Int?
    var isArchived: Bool
    var tags: [String]
    var canvasItems: [CanvasItem]?  // Associated canvasses
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: MessageRole  // user, assistant, system, tool
    var content: String
    var createdAt: Date
    var isStreaming: Bool
    
    // Thinking / Reasoning
    var reasoningContent: String?      // AI's thought process
    var isReasoningExpanded: Bool      // UI state
    
    // For tool calls
    var toolCalls: [ToolCall]?
    var toolResults: [ToolResult]?
    var activeTool: ActiveTool?        // Currently executing tool
    
    // Ask User Question (voor pending state)
    var pendingQuestion: String?       // AI wacht op antwoord
    var questionResponse: String?      // Gebruiker's antwoord
    
    // Media
    var attachments: [Attachment]?
    
    // Token usage (if available)
    var tokenCount: Int?
    
    // Canvas reference
    var canvasId: UUID?
}

enum MessageRole: String, Codable {
    case user, assistant, system, tool, askUser  // askUser = pending question
}

struct ToolCall: Codable {
    var id: String
    var name: String
    var arguments: String  // JSON
}

struct ToolResult: Codable {
    var toolCallId: String
    var output: String
    var isError: Bool
}

struct ActiveTool: Codable {
    var name: String
    var status: ToolStatus
    var preview: String
    var startTime: Date
    var duration: Double?
}

enum ToolStatus: String, Codable {
    case running, completed, error
}

// Canvas Models (Claude Desktop style)
struct CanvasItem: Codable, Identifiable {
    var id: UUID
    var type: CanvasType
    var title: String
    var content: String
    var language: String?  // Voor code blocks
    var isEditable: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum CanvasType: String, Codable {
    case code, document, preview, diff
}
```

### 1.4 UI Component Library

#### Core Components Needed
1. **ChatBubble** - Message rendering met markdown
2. **CodeBlock** - Syntax highlighted code met copy button
3. **ToolCallView** - Expandable tool execution visualization
4. **MessageInput** - Auto-resizing text input met attachments
5. **ConversationList** - Sidebar met search, folders
6. **ModelSelector** - Dropdown voor model selectie
7. **StreamingText** - Typewriter effect voor streaming
8. **AttachmentPreview** - Image/file thumbnails

#### NEW: Action Status & Thinking Components
9. **ThinkingBlock** - Collapsible reasoning content (zoals Claude)
10. **ActionStatusBar** - Live tool execution status
11. **ToolProgressView** - Gedetailleerde tool execution met preview
12. **AskUserQuestionView** - Modal/interstitial voor AI vragen

#### NEW: Canvas Components (Claude Desktop style)
13. **CanvasContainer** - Side-by-side chat + canvas layout
14. **CodeCanvas** - Syntax highlighted editor met edit capabilities
15. **DocumentCanvas** - Rich text document editor
16. **PreviewCanvas** - HTML/Markdown preview pane
17. **DiffCanvas** - Side-by-side diff view
18. **CanvasToolbar** - Actions voor canvas (copy, apply, discard)

#### Markdown Rendering
- **Native Text + AttributedString** voor basis formatting
- **Code highlight** via Splash (Swift-based) of native UITextView
- **LaTeX/Math** via MathJax WebView (alleen als echt nodig)
- **Mermaid diagrams** - out of scope voor MVP

---

## Phase 2: Core Implementation (Week 2-3)

### 2.1 Sprint 1: Foundation (Week 2, Days 1-3)

**Goal**: Basic chat werkt end-to-end

#### Tasks:
1. **Project Setup**
   - [ ] Xcode project aanmaken (iOS + macOS universal)
   - [ ] SwiftLint + SwiftFormat configuratie
   - [ ] Git repo + .gitignore
   - [ ] Package dependencies (via SPM):
     - Alamofire of native URLSession wrapper
     - Splash (syntax highlighting)
     - Markdown parsing

2. **API Layer**
   - [ ] HermesAPIClient protocol + implementatie
   - [ ] SSE streaming parser
   - [ ] Error handling + retry logic
   - [ ] Request/response models

3. **Persistence Layer**
   - [ ] SwiftData stack setup
   - [ ] Conversation + Message entities
   - [ ] CRUD operations
   - [ ] Migration strategie

4. **Basic Chat UI**
   - [ ] ChatView met message list
   - [ ] MessageInput met send button
   - [ ] ChatBubble basis rendering
   - [ ] ScrollView met auto-scroll

**Deliverable**: Je kunt typen, versturen, en een streaming response zien.

### 2.2 Sprint 2: Rich Chat (Week 2, Days 4-7)

**Goal**: Professionele chat experience

#### Tasks:
1. **Markdown Rendering**
   - [ ] Headers, lists, links, bold/italic
   - [ ] Code blocks met syntax highlight
   - [ ] Tables (indien haalbaar)
   - [ ] Blockquotes

2. **Message Features**
   - [ ] Copy message content
   - [ ] Regenerate response
   - [ ] Edit user message
   - [ ] Delete message
   - [ ] Message timestamps

3. **Input Enhancements**
   - [ ] Multi-line input met Option+Enter
   - [ ] Image paste/upload
   - [ ] @ mention voor model switching
   - [ ] Typing indicator

4. **Conversation Management**
   - [ ] Sidebar met conversation list
   - [ ] New conversation button
   - [ ] Delete/archive conversations
   - [ ] Auto-titling (eerste message als titel)

**Deliverable**: Chat voelt aan als een native professionele app.

### 2.3 Sprint 3: Tool Calling & Action Status (Week 3, Days 1-4)

**Goal**: Tool calls en live action status worden mooi weergegeven

#### Tasks:
1. **Tool Call Models**
   - [ ] ToolCall + ToolResult parsing
   - [ ] ActiveTool execution status tracking
   - [ ] Tool event handling van /v1/runs API

2. **Tool UI Components**
   - [ ] ToolCallView (collapsible)
   - [ ] Tool icon + name display
   - [ ] Arguments preview (formatted JSON)
   - [ ] Result display
   - [ ] Error state

3. **Action Status Bar**
   - [ ] Live tool execution indicator
   - [ ] Tool naam + preview text
   - [ ] Spinner/loading animation
   - [ ] Duration tracking
   - [ ] Success/error states

4. **Streaming Integration**
   - [ ] Tool call chunks parsen
   - [ ] Real-time tool status updates via events
   - [ ] Progress indication

5. **Tool Registry**
   - [ ] Tool icon mapping
   - [ ] Tool description display
   - [ ] Enable/disable tools per conversation

**Deliverable**: Je ziet live welke tool er draait met status updates.

### 2.4 Sprint 4: Polish (Week 3, Days 5-7)

**Goal**: App is dagelijks bruikbaar

#### Tasks:
1. **Settings**
   - [ ] API endpoint configuratie
   - [ ] API key input
   - [ ] Default model selectie
   - [ ] Theme (light/dark/system)
   - [ ] Font size

2. **Model Management**
   - [ ] Model list ophalen
   - [ ] Model selector dropdown
   - [ ] Model info display
   - [ ] Recent models

3. **Search**
   - [ ] Conversation search (SwiftData FTS)
   - [ ] Message search binnen conversation

4. **Export/Import**
   - [ ] Export conversation als Markdown
   - [ ] Export als JSON
   - [ ] Copy conversation link

**Deliverable**: App is bruikbaar als daily driver.

---

## Phase 3: Advanced Features (Week 4)

### 3.0 Phase 3 Prelude: Thinking & Reasoning (Week 3, Days 5-7)

**Goal**: Thinking streaming en ask user question support

#### Tasks:
1. **Reasoning/Thinking Support**
   - [ ] `reasoning.available` events parsen van /v1/runs
   - [ ] ThinkingBlock UI component (collapsible, zoals Claude)
   - [ ] Real-time thinking streaming
   - [ ] "Show thinking" toggle in settings
   - [ ] Persist reasoning content in SwiftData

2. **Ask User Question Tool**
   - [ ] `askUserQuestion` event handling
   - [ ] Question modal/interstitial UI
   - [ ] Input validation per question type
   - [ ] Response submission naar API
   - [ ] Resume conversation flow
   - [ ] Question history in conversation

**Deliverable**: Je ziet AI's thought process en kan antwoorden op vragen.

### 3.1 Phase 3a: Cross-Platform Polish

#### macOS Specifiek
- [ ] Keyboard shortcuts (Cmd+N new chat, Cmd+Shift+N new window)
- [ ] Menu bar commands
- [ ] Toolbar met model selector
- [ ] Multi-window support
- [ ] Drag & drop files
- [ ] Services menu integratie

#### iOS Specifiek
- [ ] Pull-to-refresh
- [ ] Swipe actions op conversations
- [ ] Haptic feedback
- [ ] SafeArea handling
- [ ] Keyboard avoidance

### 3.2 Phase 3b: Canvasses (Claude Desktop Style)

**Goal**: Side-by-side code/document editing zoals Claude Desktop

#### Canvas Architecture
```swift
// Layout modes
enum CanvasLayout {
    case chatOnly           // Alleen chat
    case canvasOnly         // Alleen canvas
    case sideBySide         // Chat links, canvas rechts (default)
    case stacked            // Chat boven, canvas onder
}

// Canvas lifecycle
enum CanvasState {
    case empty              // Geen canvas actief
    case creating           // Canvas wordt aangemaakt
    case editing            // Gebruiker edit content
    case reviewing          // AI reviewt changes
    case applied            // Changes toegepast
}
```

#### Tasks:
1. **Canvas Container**
   - [ ] Resizable split-view (chat / canvas)
   - [ ] Layout mode toggle
   - [ ] Keyboard shortcuts (Cmd+Shift+C toggle canvas)
   - [ ] Fullscreen canvas mode

2. **Code Canvas**
   - [ ] Syntax highlighting (meerdere talen)
   - [ ] Line numbers
   - [ ] Code folding
   - [ ] Edit capabilities
   - [ ] Diff view (origineel vs edited)
   - [ ] Copy/Apply/Discard actions

3. **Document Canvas**
   - [ ] Rich text editing
   - [ ] Markdown WYSIWYG
   - [ ] Export naar verschillende formaten

4. **Preview Canvas**
   - [ ] HTML rendering
   - [ ] Markdown preview
   - [ ] Image preview
   - [ ] JSON/XML formatter

5. **Canvas API Integration**
   - [ ] Canvas events van /v1/runs parsen
   - [ ] Canvas content updates streaming
   - [ ] User edits sync naar API
   - [ ] Apply changes naar conversation

**Deliverable**: Je kunt code/docs side-by-side editen zoals in Claude Desktop.

### 3.3 Phase 3c: RAG & Knowledge Base

#### Document Upload
- [ ] File picker (PDF, TXT, MD, etc)
- [ ] Drag & drop (macOS)
- [ ] Document preview
- [ ] Upload progress

#### RAG Visualization
- [ ] Citations in responses
- [ ] Source highlighting
- [ ] Source preview popup

### 3.4 Phase 3d: Voice & Vision

#### Speech-to-Text
- [ ] Voice input button
- [ ] Speech recognition (Apple Speech framework)
- [ ] Whisper API fallback

#### Text-to-Speech
- [ ] Play button op messages
- [ ] AVSpeechSynthesizer integratie
- [ ] Voice selection
- [ ] Speed control

#### Vision
- [ ] Camera capture (iOS)
- [ ] Photo library picker
- [ ] Multi-image upload
- [ ] Image analysis display

---

## Phase 4: Integration & Testing (Week 5)

### 4.1 System Integration

#### Shortcuts & Siri
- [ ] "Ask Hermes" Shortcut action
- [ ] Siri intent voor quick questions
- [ ] Conversation shortcuts

#### Widgets
- [ ] Home Screen widget (iOS)
- [ ] Today widget (macOS)
- [ ] Lock Screen widget (iOS 17+)

#### Notifications
- [ ] Push voor lange-running tasks (via Hermes cron)
- [ ] Local notifications voor completed generations

### 4.2 Testing Strategy

#### Unit Tests
- [ ] API client tests (mocked)
- [ ] ViewModel tests
- [ ] SwiftData operation tests
- [ ] Parsing/formatting tests

#### UI Tests
- [ ] End-to-end chat flow
- [ ] Conversation management
- [ ] Settings configuratie

#### Performance Tests
- [ ] Large conversation handling (1000+ messages)
- [ ] Memory profiling tijdens streaming
- [ ] Scroll performance

### 4.3 Distribution Prep

#### App Store
- [ ] App Store Connect setup
- [ ] Screenshots (iPhone + iPad + Mac)
- [ ] App Preview video
- [ ] Privacy manifest
- [ ] App review guidelines check

#### Notarization (macOS)
- [ ] Developer ID signing
- [ ] Notarization proces
- [ ] DMG packaging

---

## Technical Specifications

### Dependencies (SPM)

```swift
// Core
.github("apple/swift-algorithms")
.github("apple/swift-collections")

// Networking
.github("Alamofire/Alamofire")  // Of native URLSession

// Markdown
.github("johnxnguyen/swift-markdown")  // Of native AttributedString
.github("JohnSundell/Splash")  // Syntax highlighting

// UI Helpers
.github("SwiftUIX/SwiftUIX")  // Missing SwiftUI components
.github("sindresorhus/Defaults")  // Type-safe UserDefaults

// Testing
.github("pointfreeco/swift-snapshot-testing")  // Snapshot tests
```

### API Specification

#### Chat Request
```swift
struct ChatRequest: Codable {
    let model: String  // "hermes-agent"
    let messages: [ChatMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?
    let tools: [Tool]?
    let sessionId: String?  // X-Hermes-Session-Id
}

struct ChatMessage: Codable {
    let role: String  // "user", "assistant", "system"
    let content: String
    let name: String?  // For tool messages
    let toolCalls: [ToolCall]?
    let toolCallId: String?
}
```

#### Streaming Response
```swift
struct ChatChunk: Codable {
    let id: String
    let object: String  // "chat.completion.chunk"
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
        let toolCalls: [ToolCallDelta]?
    }
}
```

### State Management

```swift
@Observable
class ChatViewModel {
    let conversation: Conversation
    var messages: [Message] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingMessage: Message?
    
    private let apiClient: HermesAPIClient
    private let modelContainer: ModelContext
    
    func sendMessage() async {
        // 1. Save user message
        // 2. Start streaming
        // 3. Parse chunks
        // 4. Update UI
        // 5. Save assistant message
    }
}
```

---

## OpenWebUI Feature Pariteit Matrix

### Core Features
| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| **Core Chat** |
| Streaming responses | P0 | Planned | SSE via URLSession |
| Markdown rendering | P0 | Planned | AttributedString + Splash |
| Code highlighting | P0 | Planned | Splash library |
| Message editing | P1 | Planned | |
| Message regeneration | P1 | Planned | |
| Copy code button | P1 | Planned | |
| Message deletion | P1 | Planned | |
| Typing indicators | P2 | Planned | |
| Token usage display | P2 | Planned | |
| @ mention models | P2 | Planned | |
| Response rating | P3 | Backlog | |
| **Input** |
| Multi-line input | P0 | Planned | TextEditor |
| File upload | P1 | Planned | PhotosPicker + fileImporter |
| Image paste | P1 | Planned | Pasteboard |
| Voice input | P2 | Phase 3 | Speech framework |
| **Models** |
| Multi-provider support | P0 | Planned | Via Hermes API |
| Model selector | P1 | Planned | |
| Model parameters | P2 | Planned | Temperature, etc |
| **Conversations** |
| History persistence | P0 | Planned | SwiftData |
| Conversation list | P0 | Planned | |
| Search conversations | P1 | Planned | SwiftData FTS |
| Folders/collections | P2 | Backlog | |
| Export (Markdown/JSON) | P2 | Planned | |
| Branching/forking | P3 | Backlog | |
| **RAG** |
| Document upload | P2 | Phase 3 | |
| Source citations | P2 | Phase 3 | |
| Knowledge collections | P3 | Backlog | |
| **Tools** |
| Tool call display | P1 | Planned | Collapsible UI |
| Tool results | P1 | Planned | |
| Tool registry | P2 | Planned | |
| **Voice/Audio** |
| Speech-to-text | P2 | Phase 3 | |
| Text-to-speech | P2 | Phase 3 | |
| **Vision** |
| Image upload | P1 | Planned | |
| Vision model support | P1 | Planned | |
| Image generation | P3 | Backlog | |
| **Settings** |
| API configuration | P0 | Planned | |
| Theme settings | P1 | Planned | |
| Default model | P1 | Planned | |
| **Platform Features** |
| iOS support | P0 | Planned | Universal app |
| macOS support | P0 | Planned | Universal app |
| Shortcuts integration | P2 | Phase 4 | |
| Widgets | P3 | Phase 4 | |
| Push notifications | P3 | Backlog | |

### HermesApp-Exclusive Features (Niet in OpenWebUI)
| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| **Thinking/Reasoning** |
| Reasoning streaming | P1 | Planned | `/v1/runs` events |
| Thinking block UI | P1 | Planned | Collapsible zoals Claude |
| Show/hide thinking | P2 | Planned | Setting toggle |
| **Action Status** |
| Live tool execution | P1 | Planned | Real-time via events |
| Tool progress preview | P1 | Planned | Wat doet de tool |
| Action status bar | P2 | Planned | Bottom indicator |
| **Ask User Question** |
| Interstitial questions | P1 | Planned | Modal UI |
| Question types | P2 | Planned | Text, confirm, choice |
| Question history | P3 | Backlog | |
| **Canvasses** |
| Side-by-side editing | P1 | Planned | Split view layout |
| Code canvas | P1 | Planned | Syntax + diff |
| Document canvas | P2 | Planned | Rich text |
| Preview canvas | P2 | Planned | HTML/Markdown |
| Apply/Discard changes | P1 | Planned | Action buttons |

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SwiftData performance met grote conversaties | High | Medium | Pagination, lazy loading, background fetch |
| SSE streaming complexiteit | Medium | Medium | Goede error handling, reconnect logic |
| Markdown rendering performance | Medium | Medium | Native AttributedString, caching |
| Cross-platform UI inconsistencies | Low | Low | Platform conditionals, uitgebreide testing |
| Hermes API changes | Medium | Low | Versie pinning, abstraction layer |
| Large context window handling | Medium | Medium | Streaming, partial rendering |

---

## Success Criteria

### MVP Definition
- Chat werkt met streaming responses
- Markdown + code highlighting
- Conversation history werkt
- iOS + macOS beide bruikbaar
- Tool calls worden getoond
- Settings configureerbaar

### Quality Gates
- Unit test coverage > 60%
- Geen memory leaks
- 60fps scrolling
- VoiceOver support
- Dark mode support

---

## Appendix

### A. Hermes API Connection Details

```
Base URL: http://localhost:8642/v1 (configurable)
Authentication: Bearer token (optional for local)
Headers:
  - Authorization: Bearer <token>
  - X-Hermes-Session-Id: <session_id> (for continuity)
  - Content-Type: application/json
```

### B. Local Development Setup

```bash
# 1. Hermes API server starten
hermes --api-server

# 2. Xcode project openen
open HermesApp.xcodeproj

# 3. Build & run (Cmd+R)
```

### C. Useful Resources

- Hermes API docs: `/root/hermes_api_analysis.md`
- OpenWebUI features: zie OpenWebUI repository
- SwiftUI tutorials: developer.apple.com
- Markdown parsing: github.com/apple/swift-markdown

---

## Project Execution Log

### Phase 0: Research (Completed April 10, 2026)

Reference projects analyzed:
- **OmniChat** (bowenyu066/OmniChat) - macOS SwiftUI with multi-provider support, SwiftData persistence
- **Warden** (SidhuK/WardenApp) - 100% native SwiftUI, ~20MB, ~150MB RAM usage
- **MarkdownUI** (gonzalezreal/MarkdownUI) - Standard library for SwiftUI Markdown rendering
- **FoundationChat** - SwiftUI + SwiftData with tool calling demo
- **Splash** - Swift syntax highlighting

Key findings:
- MarkdownUI is the industry standard for SwiftUI Markdown
- SwiftData performance requires careful optimization for large conversations
- SSE streaming via URLSession.bytes is the preferred approach
- Swift 6 strict concurrency requires careful actor isolation

---

### Phase 1: Foundation (Completed April 10, 2026)

**Implemented:**
- ✅ Xcode project setup with Package.swift
- ✅ HermesAPIClient with SSE streaming
- ✅ SwiftData models (Conversation, Message, ToolModels)
- ✅ Error handling with retry logic
- ✅ Session continuity via headers

**Code Review Findings:**
- 7 Critical issues found (all fixed):
  - SwiftData thread-safety violation
  - @Observable + @MainActor conflict
  - Retain cycles in AsyncStream
  - Non-thread-safe JSON encoding
  - Missing Equatable on APIError
  - Actor-isolated dictionary issues
  - Double @main declaration

**Files created:** 23 Swift files, ~2,600 LOC

---

### Phase 2: Core Chat UI (Completed April 10, 2026)

**Implemented:**
- ✅ MarkdownUI integration
- ✅ Splash syntax highlighting
- ✅ MessageBubbleView with markdown rendering
- ✅ CodeBlockView with copy functionality
- ✅ MessageInputView with @mentions
- ✅ Message actions (copy, edit, regenerate)
- ✅ Auto-resizing input

**Dependencies added:**
- MarkdownUI (2.0.0+)
- Splash (0.16.0+)

---

### Phase 3: Tool Calling (Completed April 10, 2026)

**Implemented:**
- ✅ ToolCallView, ToolResultView components
- ✅ ToolExecutionView with live indicators
- ✅ ActionStatusBar
- ✅ 30+ tool icon mappings
- ✅ Tool event handling from SSE stream

**Tool support:**
- Terminal: bash, shell, run_command
- Browser: browser_navigate, browser_click, browser_type, browser_screenshot, browser_scroll, browser_find
- Code: python, javascript, execute_code, code_interpreter
- File: read_file, write_file, patch, search_files, file_info, delete_file, move_file
- Web: web_search, web_extract, fetch_url
- System: think, delay
- User: ask, confirm

---

### Phase 4: Reasoning & Ask User (Completed April 10, 2026)

**Implemented:**
- ✅ ThinkingBlock (Claude-style collapsible reasoning)
- ✅ ReasoningStreamView for real-time streaming
- ✅ AskUserQuestionView with question types (text, confirm, choice)
- ✅ QuestionHistoryView
- ✅ SSE event parsing for reasoning.available and ask_user.question

---

### Phase 5: Canvasses (Completed April 10, 2026)

**Implemented:**
- ✅ CanvasContainer with split view
- ✅ ResizableDivider
- ✅ CodeCanvas with line numbers and syntax highlighting
- ✅ DocumentCanvas for markdown editing
- ✅ PreviewCanvas for HTML/Markdown preview
- ✅ CanvasToolbar with Apply/Discard actions
- ✅ Layout modes (sideBySide, stacked, chatOnly, canvasOnly)
- ✅ Diff view for comparing changes

**Code Review Findings:**
- 1 Critical: NotificationCenter memory leak (fixed)
- 2 High: Main thread blocking for diff/search (fixed)
- 1 Medium: Line number performance for large files (optimized)

---

### Final Stats

- **43 Swift files**
- **~13,400 lines of code**
- **iOS 17.0+ / macOS 14.0+**
- **Swift 6 concurrency compliant**

---

### GitHub Repository

**URL:** https://github.com/23492/HermesApp

**Clone:**
```bash
git clone https://github.com/23492/HermesApp.git
cd HermesApp
open Package.swift
```

---

### Build Instructions

1. **Prerequisites:**
   - macOS 14.0+
   - Xcode 15.0+
   - Hermes API running on localhost:8642

2. **Open in Xcode:**
   ```bash
   cd HermesApp
   open Package.swift
   ```

3. **Select target:**
   - Choose "HermesApp" → "My Mac" or iOS Simulator
   - Add Team in Signing & Capabilities (for device testing)

4. **Start Hermes API:**
   ```bash
   hermes --api-server
   ```

5. **Build & Run:** Cmd+R

---

*Plan version: 2.0*
*Project completed: April 10, 2026*
*Repository: https://github.com/23492/HermesApp*
