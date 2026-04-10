import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    func truncating(to length: Int, truncation: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + truncation
        }
        return self
    }
    
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<Transform: View, ElseTransform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform,
        else elseTransform: (Self) -> ElseTransform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    static func sleep(milliseconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    }
}

// MARK: - Date Extensions

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

// MARK: - Data Extensions

extension Data {
    var prettyPrintedJSON: String? {
        guard let json = try? JSONSerialization.jsonObject(with: self) else { return nil }
        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    func prettyPrinted() -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: self,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Result Extensions

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var isFailure: Bool {
        !isSuccess
    }
    
    var value: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}

// MARK: - AsyncStream Extensions

extension AsyncStream {
    func collect() async -> [Element] {
        var results: [Element] = []
        for await element in self {
            results.append(element)
        }
        return results
    }
}

// MARK: - Array Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Optional Extensions

extension Optional {
    func or(_ defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
    static let xxlarge: CGFloat = 32
}

// MARK: - Binding Extensions

extension Binding {
    func onChange(_ handler: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler()
            }
        )
    }
}

// MARK: - Text Extensions

extension Text {
    func withFontSize(_ size: CGFloat) -> Text {
        self.font(.system(size: size))
    }
}

// MARK: - Color Extensions

extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

// MARK: - Publisher Extensions

#if canImport(Combine)
import Combine

extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping @Sendable (Output) async throws -> T
    ) -> Publishers.FlatMap<Future<T, Error>, Self> where Output: Sendable {
        flatMap { value in
            Future { promise in
                nonisolated(unsafe) let promise = promise
                nonisolated(unsafe) let value = value
                Task {
                    do {
                        let output = try await transform(value)
                        promise(.success(output))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
    }
}
#endif
