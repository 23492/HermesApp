import XCTest
@testable import HermesApp

final class HermesAppTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testConversationCreation() {
        let conversation = Conversation(
            title: "Test Conversation",
            model: "hermes-agent"
        )
        
        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertEqual(conversation.model, "hermes-agent")
        XCTAssertFalse(conversation.isArchived)
        XCTAssertNotNil(conversation.id)
    }
    
    func testConversationTitleGeneration() {
        let conversation = Conversation()
        conversation.generateTitle(from: "Hello world this is a very long message that should be truncated")
        
        XCTAssertEqual(conversation.title, "Hello world this is a very long message that should...")
    }
    
    func testMessageCreation() {
        let message = Message(
            role: .user,
            content: "Test message"
        )
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test message")
        XCTAssertFalse(message.isStreaming)
    }
    
    func testMessageAppending() {
        let message = Message(role: .assistant, content: "Hello")
        message.appendContent(" World")
        
        XCTAssertEqual(message.content, "Hello World")
    }
    
    func testToolCallParsing() {
        let toolCall = ToolCall(
            id: "call_123",
            name: "read_file",
            arguments: "{\"path\": \"/test/file.txt\"}"
        )
        
        XCTAssertEqual(toolCall.id, "call_123")
        XCTAssertEqual(toolCall.name, "read_file")
        XCTAssertNotNil(toolCall.parsedArguments)
        XCTAssertEqual(toolCall.parsedArguments?["path"] as? String, "/test/file.txt")
    }
    
    // MARK: - API Models Tests
    
    func testChatRequestEncoding() throws {
        let request = ChatRequest(
            model: "hermes-agent",
            messages: [
                ChatMessage(role: "user", content: "Hello")
            ],
            stream: true
        )
        
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ChatRequest.self, from: data)
        
        XCTAssertEqual(decoded.model, "hermes-agent")
        XCTAssertEqual(decoded.messages.count, 1)
        XCTAssertTrue(decoded.stream)
    }
    
    func testChatChunkDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1677652288,
            "model": "hermes-agent",
            "choices": [
                {
                    "index": 0,
                    "delta": {"content": "Hello"},
                    "finish_reason": null
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let chunk = try JSONDecoder().decode(ChatChunk.self, from: data)
        
        XCTAssertEqual(chunk.id, "chatcmpl-123")
        XCTAssertEqual(chunk.object, "chat.completion.chunk")
        XCTAssertEqual(chunk.choices.first?.delta?.content, "Hello")
    }
    
    // MARK: - Tool Registry Tests
    
    func testToolRegistry() {
        let readFileInfo = ToolRegistry.info(for: "read_file")
        
        XCTAssertEqual(readFileInfo.name, "read_file")
        XCTAssertEqual(readFileInfo.displayName, "Read File")
        XCTAssertEqual(readFileInfo.category, .file)
    }
    
    func testUnknownToolFallback() {
        let unknownInfo = ToolRegistry.info(for: "unknown_tool")
        
        XCTAssertEqual(unknownInfo.name, "unknown_tool")
        XCTAssertEqual(unknownInfo.icon, "wrench")
    }
    
    // MARK: - Extensions Tests
    
    func testStringTruncation() {
        let longString = "This is a very long string"
        let truncated = longString.truncating(to: 10)
        
        XCTAssertEqual(truncated, "This is a ...")
    }
    
    func testDateTimeAgo() {
        let date = Date().addingTimeInterval(-3600) // 1 hour ago
        let timeAgo = date.timeAgo
        
        XCTAssertTrue(timeAgo.contains("hour") || timeAgo.contains("1h"))
    }
    
    // MARK: - Color Tests
    
    func testHexColorInit() {
        let redColor = Color(hex: "#FF0000")
        XCTAssertNotNil(redColor)
        
        let shortHex = Color(hex: "F00")
        XCTAssertNotNil(shortHex)
        
        let invalidHex = Color(hex: "invalid")
        XCTAssertNil(invalidHex)
    }
}
