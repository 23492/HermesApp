import Foundation
import OSLog

// MARK: - Logger

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.hermes.app"
    
    static let api = Logger(subsystem: subsystem, category: "API")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let data = Logger(subsystem: subsystem, category: "Data")
    static let general = Logger(subsystem: subsystem, category: "General")
    
    // MARK: - Logging Levels
    
    static func debug(_ message: String, category: Logger = general) {
        #if DEBUG
        category.debug("🔍 \(message)")
        #endif
    }
    
    static func info(_ message: String, category: Logger = general) {
        category.info("ℹ️ \(message)")
    }
    
    static func warning(_ message: String, category: Logger = general) {
        category.warning("⚠️ \(message)")
    }
    
    static func error(_ message: String, error: Swift.Error? = nil, category: Logger = general) {
        if let error = error {
            category.error("❌ \(message): \(error.localizedDescription)")
        } else {
            category.error("❌ \(message)")
        }
    }
    
    static func success(_ message: String, category: Logger = general) {
        category.info("✅ \(message)")
    }
}

// MARK: - Logging Extensions

extension HermesAPIClient {
    func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        Log.api.debug("Request: \(method) \(url)")
    }
    
    func logResponse(_ response: URLResponse, data: Data?) {
        if let httpResponse = response as? HTTPURLResponse {
            let status = httpResponse.statusCode
            let icon = (200...299).contains(status) ? "✅" : "❌"
            Log.api.debug("Response: \(icon) \(status)")
        }
    }
}

// MARK: - Performance Logging

enum PerformanceLog {
    private static var timings: [String: Date] = [:]
    
    static func start(_ identifier: String) {
        timings[identifier] = Date()
    }
    
    static func end(_ identifier: String) -> TimeInterval? {
        guard let start = timings[identifier] else { return nil }
        timings.removeValue(forKey: identifier)
        let duration = Date().timeIntervalSince(start)
        Log.general.debug("⏱️ \(identifier): \(String(format: "%.3f", duration))s")
        return duration
    }
}
