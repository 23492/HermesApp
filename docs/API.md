# API Documentation

HermesApp communicates with the Hermes AI agent via a REST API with Server-Sent Events (SSE) streaming.

## Base URL

```
http://localhost:8642/v1
```

Configurable in Settings → API Configuration.

## Authentication

Optional Bearer token authentication:

```
Authorization: Bearer <token>
```

## Endpoints

### Chat Completions

Send a message and receive a streaming response.

**Endpoint:** `POST /chat/completions`

**Request:**

```json
{
  "model": "anthropic/claude-sonnet-4",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "stream": true,
  "session_id": "optional-session-continuity-id"
}
```

**Response (SSE):**

```
data: {"id":"chat-123","choices":[{"delta":{"content":"Hello"}}]}

data: {"id":"chat-123","choices":[{"delta":{"content":" there"}}]}

data: [DONE]
```

### List Models

Get available AI models.

**Endpoint:** `GET /models`

**Response:**

```json
{
  "data": [
    {
      "id": "anthropic/claude-sonnet-4",
      "name": "Claude Sonnet 4",
      "provider": "anthropic"
    }
  ]
}
```

### Runs (Structured Events)

Start a structured run with detailed event streaming.

**Endpoint:** `POST /runs`

**Request:**

```json
{
  "input": "Create a Swift function to calculate fibonacci",
  "model": "anthropic/claude-sonnet-4",
  "session_id": "optional-session-id"
}
```

**Response:**

```json
{
  "run_id": "run-abc123",
  "status": "in_progress"
}
```

### Stream Run Events

Stream structured events for a run.

**Endpoint:** `GET /runs/{run_id}/events`

**Response (SSE):**

```
event: message.delta
data: {"content":"Here's a fibonacci function"}

event: tool.started
data: {"name":"write_file","arguments":{"path":"/tmp/fib.swift"}}

event: tool.completed
data: {"name":"write_file","duration":0.5}

event: reasoning.available
data: {"content":"I'll create a recursive implementation..."}

event: run.completed
data: {}
```

## Event Types

### message.delta

Text content chunk from the AI.

```json
{
  "content": "chunk of text"
}
```

### message.completed

AI message is complete.

```json
{
  "content": "full message content",
  "usage": {
    "prompt_tokens": 100,
    "completion_tokens": 50
  }
}
```

### tool.started

A tool execution has started.

```json
{
  "id": "tool-123",
  "name": "terminal_tool",
  "arguments": {
    "command": "ls -la",
    "description": "List files"
  },
  "preview": "Running: ls -la"
}
```

### tool.completed

Tool execution completed.

```json
{
  "id": "tool-123",
  "name": "terminal_tool",
  "duration": 0.25,
  "output": "file1.txt\nfile2.txt",
  "error": false
}
```

### tool.error

Tool execution failed.

```json
{
  "id": "tool-123",
  "name": "terminal_tool",
  "error": true,
  "message": "Command not found"
}
```

### reasoning.available

AI thinking/reasoning content.

```json
{
  "content": "Let me think about this step by step..."
}
```

### ask_user.question

AI is asking the user a question.

```json
{
  "question": "Should I proceed with installing the package?",
  "type": "confirm",
  "options": ["Yes", "No"]
}
```

**Question Types:**
- `text` - Free text input
- `confirm` - Yes/No confirmation
- `choice` - Multiple choice selection

### canvas.update

Canvas artifact update.

```json
{
  "items": [
    {
      "id": "canvas-1",
      "type": "code",
      "title": "fibonacci.swift",
      "content": "func fib(_ n: Int) -> Int {...}",
      "language": "swift"
    }
  ]
}
```

### run.completed

Run is complete.

```json
{
  "run_id": "run-abc123",
  "status": "completed"
}
```

### run.error

Run encountered an error.

```json
{
  "run_id": "run-abc123",
  "status": "error",
  "error": "API rate limit exceeded"
}
```

## Swift Implementation

### HermesAPIClient

```swift
actor HermesAPIClient {
    private let baseURL: String
    private let apiKey: String?
    private let session: URLSession
    
    init(baseURL: String, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }
    
    func sendMessage(_ request: ChatRequest) async throws -> AsyncStream<ChatChunk> {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (bytes, _) = try await session.bytes(for: urlRequest)
        
        return AsyncStream { continuation in
            Task {
                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        
                        if let chunk = try? JSONDecoder().decode(ChatChunk.self, from: data.data(using: .utf8)!) {
                            continuation.yield(chunk)
                        }
                    }
                }
                continuation.finish()
            }
        }
    }
}
```

### Models

```swift
// Request
struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let stream: Bool
    let sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case sessionId = "session_id"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

// Response chunks
struct ChatChunk: Codable {
    let id: String
    let choices: [Choice]
}

struct Choice: Codable {
    let delta: Delta
}

struct Delta: Codable {
    let content: String?
}

// Run events
enum RunEvent {
    case messageDelta(String)
    case toolStarted(ToolStarted)
    case toolCompleted(ToolCompleted)
    case reasoningAvailable(String)
    case askUserQuestion(AskUserQuestion)
    case canvasUpdate([CanvasItem])
    case completed
    case error(String)
}
```

## Error Codes

| Status | Code | Description |
|--------|------|-------------|
| 400 | bad_request | Invalid request format |
| 401 | unauthorized | Invalid API key |
| 404 | not_found | Model or resource not found |
| 429 | rate_limit | Rate limit exceeded |
| 500 | server_error | Internal server error |
| 503 | service_unavailable | Hermes API temporarily unavailable |

## Headers

### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| Authorization | Optional | Bearer token |
| Content-Type | Yes | application/json |
| X-Hermes-Session-Id | Optional | Session continuity ID |

### Response Headers

| Header | Description |
|--------|-------------|
| Content-Type | application/json or text/event-stream |
| X-Request-ID | Request tracking ID |

## Rate Limiting

Hermes API may enforce rate limits. When exceeded:

- Status: 429
- Response includes `Retry-After` header
- Client should implement exponential backoff

## Session Continuity

Use `X-Hermes-Session-Id` header to maintain conversation context:

```swift
// First request
let response1 = try await apiClient.sendMessage(request, sessionId: nil)
let sessionId = response1.sessionId

// Subsequent requests
let response2 = try await apiClient.sendMessage(request, sessionId: sessionId)
```

## WebSocket Alternative

For real-time bidirectional communication, future versions may support WebSocket:

```
ws://localhost:8642/v1/stream
```

Currently SSE is the primary streaming mechanism.
