import Foundation

// MARK: - API Errors

enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case networkError(String)
    case streamError(String)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message ?? "Unknown error")"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .streamError(let message):
            return "Stream error: \(message)"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter))s"
            }
            return "Rate limited. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        case .cancelled:
            return "Request cancelled"
        }
    }
}

// MARK: - API Configuration

struct APIConfiguration {
    var baseURL: String
    var apiKey: String?
    var timeout: TimeInterval
    var maxRetries: Int
    var retryDelay: TimeInterval
    
    static let `default` = APIConfiguration(
        baseURL: "http://localhost:8642/v1",
        apiKey: nil,
        timeout: 60.0,
        maxRetries: 3,
        retryDelay: 1.0
    )
}

// MARK: - Hermes API Client Protocol

protocol HermesAPIClientProtocol: AnyObject {
    func sendMessage(
        _ request: ChatRequest,
        sessionId: String?,
        cancellationToken: CancellationToken
    ) async throws -> AsyncStream<ChatChunk>
    
    func getModels() async throws -> [ModelInfo]
    
    func startRun(input: String, conversationId: String?) async throws -> String // Returns run_id
    func streamEvents(runId: String) async throws -> AsyncStream<RunEvent>
    func submitUserResponse(runId: String, response: String) async throws
}

// MARK: - Cancellation Token

actor CancellationToken {
    private var isCancelled = false
    private var continuation: CheckedContinuation<Void, Never>?
    
    func cancel() {
        isCancelled = true
        continuation?.resume()
    }
    
    func checkCancellation() throws {
        if isCancelled {
            throw APIError.cancelled
        }
    }
    
    var isCancellationRequested: Bool {
        get { isCancelled }
    }
    
    func waitForCancellation() async {
        guard !isCancelled else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

// MARK: - Hermes API Client Implementation

actor HermesAPIClient: HermesAPIClientProtocol {
    private let configuration: APIConfiguration
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    
    init(configuration: APIConfiguration = .default) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Configure URLSession with custom delegate for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout * 5
        config.waitsForConnectivity = true
        
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    func sendMessage(
        _ request: ChatRequest,
        sessionId: String? = nil,
        cancellationToken: CancellationToken = CancellationToken()
    ) async throws -> AsyncStream<ChatChunk> {
        let url = try buildURL(endpoint: "/chat/completions")
        var urlRequest = try buildRequest(url: url, method: "POST", body: request)
        
        // Add session header for conversation continuity
        if let sessionId = sessionId {
            urlRequest.setValue(sessionId, forHTTPHeaderField: "X-Hermes-Session-Id")
        }
        
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }
            
            let task = Task {
                do {
                    try await self.performStreamRequest(
                        urlRequest: urlRequest,
                        cancellationToken: cancellationToken,
                        continuation: continuation
                    )
                } catch {
                    // Error is propagated through the stream termination
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func getModels() async throws -> [ModelInfo] {
        let url = try buildURL(endpoint: "/models")
        let urlRequest = try buildRequest(url: url, method: "GET")
        
        let (data, response) = try await performRequest(urlRequest: urlRequest)
        try validateResponse(response, data: data)
        
        let modelsResponse = try decoder.decode(ModelsResponse.self, from: data)
        return modelsResponse.data
    }
    
    // MARK: - Run-based API (for structured events)
    
    func startRun(input: String, conversationId: String? = nil) async throws -> String {
        let url = try buildURL(endpoint: "/runs")
        
        let body: [String: Any] = [
            "input": input,
            "conversation_id": conversationId as Any
        ]
        
        var urlRequest = try buildRequest(url: url, method: "POST", jsonBody: body)
        
        let (data, response) = try await performRequest(urlRequest: urlRequest)
        try validateResponse(response, data: data)
        
        // Parse run_id from response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let runId = json["run_id"] as? String {
            return runId
        }
        
        throw APIError.decodingError("Failed to parse run_id from response")
    }
    
    func streamEvents(runId: String) async throws -> AsyncStream<RunEvent> {
        let url = try buildURL(endpoint: "/runs/\(runId)/events")
        var urlRequest = try buildRequest(url: url, method: "GET")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }
            
            let task = Task {
                do {
                    try await self.performRunEventStream(
                        urlRequest: urlRequest,
                        continuation: continuation
                    )
                } catch {
                    // Error is propagated through the stream termination
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func submitUserResponse(runId: String, response: String) async throws {
        let url = try buildURL(endpoint: "/runs/\(runId)/respond")
        
        let body: [String: Any] = [
            "response": response
        ]
        
        var urlRequest = try buildRequest(url: url, method: "POST", jsonBody: body)
        
        let (data, response_obj) = try await performRequest(urlRequest: urlRequest)
        try validateResponse(response_obj, data: data)
    }
    
    // MARK: - Private Methods
    
    private func buildURL(endpoint: String) throws -> URL {
        let baseURL = configuration.baseURL.hasSuffix("/")
            ? String(configuration.baseURL.dropLast())
            : configuration.baseURL
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        return url
    }
    
    private func buildRequest<T: Encodable>(
        url: URL,
        method: String,
        body: T? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return request
    }
    
    private func buildRequest(
        url: URL,
        method: String,
        jsonBody: [String: Any]? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func performRequest(urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: urlRequest)
                return (data, response)
            } catch {
                lastError = error
                
                // Check if it's a cancellation
                if (error as NSError).code == NSURLErrorCancelled {
                    throw APIError.cancelled
                }
                
                // Don't retry on client errors (4xx)
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .badServerResponse, .networkConnectionLost, .timedOut:
                        // Retryable errors
                        if attempt < configuration.maxRetries - 1 {
                            try await Task.sleep(
                                nanoseconds: UInt64(configuration.retryDelay * pow(2.0, Double(attempt)) * 1_000_000_000)
                            )
                            continue
                        }
                    default:
                        break
                    }
                }
                
                throw APIError.networkError(error.localizedDescription)
            }
        }
        
        throw lastError.map { APIError.networkError($0.localizedDescription) } 
            ?? APIError.networkError("Max retries exceeded")
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 400...499:
            let message = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
        case 500...599:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(message ?? "Server error \(httpResponse.statusCode)")
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }
    
    // MARK: - SSE Streaming
    
    private func performStreamRequest(
        urlRequest: URLRequest,
        cancellationToken: CancellationToken,
        continuation: AsyncStream<ChatChunk>.Continuation
    ) async throws {
        let (bytes, response) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        var buffer = Data()
        var accumulatedToolCalls: [String: APIToolCall] = [:] // Track tool calls by ID
        var currentEventType: String?
        
        for try await byte in bytes {
            try await cancellationToken.checkCancellation()
            
            buffer.append(byte)
            
            // Check for newline (SSE delimiter)
            if byte == 10 { // '\n'
                if let line = String(data: buffer, encoding: .utf8) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if trimmed.hasPrefix("event: ") {
                        // Store event type for next data line
                        currentEventType = String(trimmed.dropFirst(7))
                        Log.debug("SSE Event type: \(currentEventType ?? "unknown")")
                    } else if trimmed.hasPrefix("data: ") {
                        let dataContent = String(trimmed.dropFirst(6))
                        
                        if dataContent == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        
                        // Try to parse as ChatChunk first
                        if let data = dataContent.data(using: .utf8),
                           let chunk = try? decoder.decode(ChatChunk.self, from: data) {
                            // Process and accumulate tool calls
                            var processedChunk = processToolCalls(in: chunk, accumulator: &accumulatedToolCalls)
                            
                            // Inject event type from SSE event line if present
                            if let eventType = currentEventType {
                                processedChunk = injectEventType(processedChunk, eventType: eventType)
                                currentEventType = nil
                            }
                            
                            continuation.yield(processedChunk)
                        } else {
                            // Try to parse as specialized event
                            if let eventChunk = parseSpecializedEvent(
                                from: dataContent,
                                eventType: currentEventType
                            ) {
                                continuation.yield(eventChunk)
                                currentEventType = nil
                            }
                        }
                    } else if trimmed.hasPrefix("error: ") {
                        let errorMessage = String(trimmed.dropFirst(7))
                        continuation.finish()
                        throw APIError.streamError(errorMessage)
                    }
                }
                buffer.removeAll()
            }
        }
        
        continuation.finish()
    }
    
    private func injectEventType(_ chunk: ChatChunk, eventType: String) -> ChatChunk {
        // Create a new chunk with the event type injected
        // Since ChatChunk is a struct with let properties, we need to recreate it
        return ChatChunk(
            id: chunk.id,
            object: chunk.object,
            created: chunk.created,
            model: chunk.model,
            choices: chunk.choices,
            reasoningContent: chunk.reasoningContent,
            eventType: eventType
        )
    }
    
    private func parseSpecializedEvent(from jsonString: String, eventType: String?) -> ChatChunk? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let type = eventType ?? json["type"] as? String ?? json["event_type"] as? String
        
        switch type {
        case "reasoning.available", "reasoning.delta":
            if let reasoning = json["text"] as? String ?? json["reasoning"] as? String {
                return ChatChunk(
                    id: UUID().uuidString,
                    object: "chat.completion.chunk",
                    created: Int(Date().timeIntervalSince1970),
                    model: nil,
                    choices: [],
                    reasoningContent: reasoning,
                    eventType: type
                )
            }
            
        case "ask_user.question":
            if let question = json["question"] as? String {
                // Store question in metadata for view model to handle
                var choices: [Choice] = []
                if let delta = createQuestionDelta(question: question, json: json) {
                    choices = [Choice(index: 0, message: nil, delta: delta, finishReason: nil)]
                }
                
                return ChatChunk(
                    id: UUID().uuidString,
                    object: "chat.completion.chunk",
                    created: Int(Date().timeIntervalSince1970),
                    model: nil,
                    choices: choices,
                    reasoningContent: nil,
                    eventType: type
                )
            }
            
        case "canvas.update":
            // Handle canvas update events
            if let itemsData = json["items"] as? [[String: Any]] {
                let canvasItems = parseCanvasItems(from: itemsData)
                if !canvasItems.isEmpty {
                    // Create a special chunk that the view model can detect
                    return ChatChunk(
                        id: UUID().uuidString,
                        object: "chat.completion.chunk",
                        created: Int(Date().timeIntervalSince1970),
                        model: nil,
                        choices: [],
                        reasoningContent: nil,
                        eventType: type
                    )
                }
            }
            
        default:
            // Try to parse as tool event
            if let toolEvent = parseToolEvent(from: jsonString) {
                return createChatChunk(from: toolEvent)
            }
        }
        
        return nil
    }
    
    private func createQuestionDelta(question: String, json: [String: Any]) -> Delta {
        // Encode question data in a way the view model can extract
        let questionType = json["question_type"] as? String ?? "text"
        let options = json["options"] as? [String]
        let context = json["context"] as? String
        
        // Create a JSON string with question data
        var questionData: [String: Any] = [
            "question": question,
            "question_type": questionType
        ]
        if let options = options {
            questionData["options"] = options
        }
        if let context = context {
            questionData["context"] = context
        }
        
        // Return delta with question data embedded in content (view model will parse)
        if let jsonData = try? JSONSerialization.data(withJSONObject: questionData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return Delta(
                role: "assistant",
                content: "__ASK_USER_QUESTION__:\(jsonString)",
                toolCalls: nil
            )
        }
        
        return Delta(role: "assistant", content: nil, toolCalls: nil)
    }
    
    // MARK: - Canvas Item Parsing
    
    private func parseCanvasItems(from itemsData: [[String: Any]]) -> [CanvasItem] {
        return itemsData.compactMap { dict -> CanvasItem? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let typeString = dict["type"] as? String,
                  let type = CanvasType(rawValue: typeString),
                  let title = dict["title"] as? String,
                  let content = dict["content"] as? String else {
                return nil
            }
            
            return CanvasItem(
                id: id,
                type: type,
                title: title,
                content: content,
                language: dict["language"] as? String,
                isEditable: dict["is_editable"] as? Bool ?? true
            )
        }
    }
    
    // MARK: - Tool Call Processing
    
    private func processToolCalls(
        in chunk: ChatChunk,
        accumulator: inout [String: APIToolCall]
    ) -> ChatChunk {
        // Process any tool calls in the chunk and accumulate partial data
        guard let delta = chunk.choices.first?.delta,
              let toolCalls = delta.toolCalls else {
            return chunk
        }
        
        for toolCall in toolCalls {
            if var existing = accumulator[toolCall.id] {
                // Accumulate function arguments
                existing.function.arguments += toolCall.function.arguments
                accumulator[toolCall.id] = existing
            } else {
                accumulator[toolCall.id] = toolCall
            }
        }
        
        return chunk
    }
    
    // MARK: - Tool Event Parsing
    
    private func parseToolEvent(from jsonString: String) -> ToolEvent? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            return nil
        }
        
        switch eventType {
        case "tool.started":
            if let name = json["name"] as? String {
                return .started(
                    name: name,
                    preview: json["preview"] as? String ?? "Running \(name)...",
                    toolCallId: json["tool_call_id"] as? String,
                    arguments: json["arguments"] as? String
                )
            }
        case "tool.completed", "tool.done":
            if let name = json["name"] as? String {
                return .completed(
                    name: name,
                    output: json["output"] as? String ?? "",
                    duration: json["duration"] as? Double,
                    toolCallId: json["tool_call_id"] as? String
                )
            }
        case "tool.error":
            if let name = json["name"] as? String,
               let error = json["error"] as? String {
                return .error(
                    name: name,
                    error: error,
                    toolCallId: json["tool_call_id"] as? String
                )
            }
        case "tool.progress":
            if let name = json["name"] as? String,
               let progress = json["progress"] as? Double {
                return .progress(
                    name: name,
                    progress: progress,
                    message: json["message"] as? String
                )
            }
        default:
            break
        }
        
        return nil
    }
    
    private func createChatChunk(from event: ToolEvent) -> ChatChunk {
        // Create a ChatChunk that represents the tool event
        // This allows unified handling in the view model
        var metadata: [String: String] = [:]
        
        switch event {
        case .started(let name, let preview, let toolCallId, _):
            metadata["tool_event"] = "started"
            metadata["tool_name"] = name
            metadata["tool_preview"] = preview
            if let id = toolCallId {
                metadata["tool_call_id"] = id
            }
        case .completed(let name, let output, let duration, let toolCallId):
            metadata["tool_event"] = "completed"
            metadata["tool_name"] = name
            metadata["tool_output"] = output
            if let dur = duration {
                metadata["tool_duration"] = String(dur)
            }
            if let id = toolCallId {
                metadata["tool_call_id"] = id
            }
        case .error(let name, let error, let toolCallId):
            metadata["tool_event"] = "error"
            metadata["tool_name"] = name
            metadata["tool_error"] = error
            if let id = toolCallId {
                metadata["tool_call_id"] = id
            }
        case .progress(let name, let progress, _):
            metadata["tool_event"] = "progress"
            metadata["tool_name"] = name
            metadata["tool_progress"] = String(progress)
        }
        
        // Create a minimal chunk with tool event metadata
        return ChatChunk(
            id: UUID().uuidString,
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: nil,
            choices: [
                Choice(
                    index: 0,
                    message: nil,
                    delta: Delta(
                        role: nil,
                        content: nil,
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )
    }
    
    enum ToolEvent {
        case started(name: String, preview: String, toolCallId: String?, arguments: String?)
        case completed(name: String, output: String, duration: Double?, toolCallId: String?)
        case error(name: String, error: String, toolCallId: String?)
        case progress(name: String, progress: Double, message: String?)
    }
    
    private func performRunEventStream(
        urlRequest: URLRequest,
        continuation: AsyncStream<RunEvent>.Continuation
    ) async throws {
        let (bytes, response) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        var buffer = Data()
        
        for try await byte in bytes {
            buffer.append(byte)
            
            if byte == 10 { // '\n'
                if let line = String(data: buffer, encoding: .utf8) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if trimmed.hasPrefix("data: ") {
                        let dataContent = String(trimmed.dropFirst(6))
                        
                        if dataContent == "[DONE]" {
                            continuation.yield(.completed)
                            continuation.finish()
                            return
                        }
                        
                        // Parse run event from JSON
                        if let event = parseRunEvent(from: dataContent) {
                            continuation.yield(event)
                        }
                    }
                }
                buffer.removeAll()
            }
        }
        
        continuation.finish()
    }
    
    private func parseRunEvent(from jsonString: String) -> RunEvent? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            return nil
        }
        
        switch eventType {
        case "message.delta":
            if let content = json["content"] as? String {
                return .messageDelta(content)
            }
        case "tool.started":
            if let name = json["name"] as? String,
               let preview = json["preview"] as? String {
                let toolCallId = json["tool_call_id"] as? String
                return .toolStarted(name: name, preview: preview, toolCallId: toolCallId)
            }
        case "tool.completed":
            if let name = json["name"] as? String,
               let duration = json["duration"] as? Double {
                let error = json["error"] as? Bool ?? false
                let output = json["output"] as? String
                return .toolCompleted(name: name, duration: duration, error: error, output: output)
            }
        case "reasoning.available":
            if let text = json["text"] as? String {
                return .reasoningAvailable(text: text)
            }
        case "ask_user.question":
            if let question = json["question"] as? String {
                let questionType = json["question_type"] as? String
                return .askUserQuestion(question: question, questionType: questionType)
            }
        case "canvas.update":
            // Parse canvas items
            if let itemsData = json["items"] as? [[String: Any]] {
                let items = itemsData.compactMap { dict -> CanvasItem? in
                    guard let idString = dict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let typeString = dict["type"] as? String,
                          let type = CanvasType(rawValue: typeString),
                          let title = dict["title"] as? String,
                          let content = dict["content"] as? String else {
                        return nil
                    }
                    return CanvasItem(
                        id: id,
                        type: type,
                        title: title,
                        content: content,
                        language: dict["language"] as? String,
                        isEditable: dict["is_editable"] as? Bool ?? true
                    )
                }
                return .canvasUpdate(items: items)
            }
        case "run.completed":
            return .completed
        case "run.error":
            if let error = json["error"] as? String {
                return .error(error)
            }
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Retry Policy

extension HermesAPIClient {
    func withRetry<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as APIError {
                lastError = error
                
                // Don't retry on client errors or cancellations
                switch error {
                case .cancelled, .httpError(let code, _) where code < 500:
                    throw error
                case .rateLimited(let retryAfter):
                    let waitTime = retryAfter ?? delay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                default:
                    if attempt < maxRetries - 1 {
                        try await Task.sleep(
                            nanoseconds: UInt64(delay * pow(2.0, Double(attempt)) * 1_000_000_000)
                        )
                    }
                }
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    try await Task.sleep(
                        nanoseconds: UInt64(delay * pow(2.0, Double(attempt)) * 1_000_000_000)
                    )
                }
            }
        }
        
        throw lastError.map { APIError.serverError($0.localizedDescription) }
            ?? APIError.serverError("Max retries exceeded")
    }
}
