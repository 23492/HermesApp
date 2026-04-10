# Phase 2 Code Review Report - HermesApp

**Review Date:** April 10, 2026  
**Files Reviewed:** 7  
**Reviewer:** Hermes Agent

---

## Summary

Phase 2 introduces Markdown rendering with MarkdownUI and Splash syntax highlighting. The code quality is generally good but there are **several critical and high severity issues** related to Swift 6 concurrency, memory management, and thread safety that need to be addressed before proceeding to Phase 3.

### Issue Severity Breakdown
- 🔴 **Critical:** 3 issues
- 🟠 **High:** 5 issues  
- 🟡 **Medium:** 4 issues
- 🟢 **Low:** 3 issues

---

## 🔴 Critical Issues

### 1. Unsafe Concurrency in ChatViewModel Streaming (CRITICAL)
**File:** `Features/Chat/ViewModels/ChatViewModel.swift`  
**Lines:** 115-202

**Issue:** The `startStreaming` method creates a Task that captures `self` and modifies `@Published` properties from within an unstructured Task. While the class is marked `@MainActor`, the Task closure creates a new concurrency context that may not properly inherit the main actor isolation.

```swift
streamingTask = Task {  // Line 115 - Unstructured task
    // ...
    assistantMessage.content = fullContent  // Line 135 - Potential race condition
    // ...
}
```

**Risk:** Data races, UI updates on background thread, crashes in production.

**Fix:**
```swift
streamingTask = Task { [weak self] in
    guard let self = self else { return }
    await MainActor.run {
        // UI updates here
    }
}
```

Or use `@MainActor` on the closure:
```swift
streamingTask = Task { @MainActor [weak self] in
    guard let self else { return }
    // All code now safely on MainActor
}
```

---

### 2. Memory Leak in NotificationCenter Observers (CRITICAL)
**File:** `Features/Chat/Views/ChatView.swift`  
**Lines:** 114-138

**Issue:** Notification observers are added in `onAppear` but never removed. Each time the view appears, new observers are registered, causing:
- Memory leaks
- Multiple duplicate handlers firing
- Unbounded growth of observers

```swift
.onAppear {
    setupNotificationHandlers()  // Called every appearance, never cleaned up
}
```

**Fix:** Store cancellables and remove on disappear:
```swift
struct ChatView: View {
    @State private var notificationObservers: [NSObjectProtocol] = []
    
    private func setupNotificationHandlers() {
        let observer1 = NotificationCenter.default.addObserver(...)
        notificationObservers.append(observer1)
    }
}
.onDisappear {
    for observer in notificationObservers {
        NotificationCenter.default.removeObserver(observer)
    }
    notificationObservers.removeAll()
}
```

---

### 3. Retain Cycle in CodeBlockView Copy Action (CRITICAL)
**File:** `Features/Chat/MarkdownComponents/CodeBlockView.swift`  
**Lines:** 204-208

**Issue:** `DispatchQueue.main.asyncAfter` captures `self` strongly in a closure that may outlive the view.

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    withAnimation {
        isCopied = false  // Implicit self capture
    }
}
```

**Fix:**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
    guard let self else { return }
    withAnimation {
        self.isCopied = false
    }
}
```

---

## 🟠 High Issues

### 4. Deinit Async Task Race Condition (HIGH)
**File:** `Features/Chat/ViewModels/ChatViewModel.swift`  
**Lines:** 41-46

**Issue:** `deinit` creates a Task that captures `self`, which is undefined behavior since `self` is being destroyed.

```swift
deinit {
    streamingTask?.cancel()
    Task {  // Captures self during destruction!
        await cancellationToken.cancel()
    }
}
```

**Fix:** Cancel synchronously or use a different pattern:
```swift
deinit {
    streamingTask?.cancel()
    cancellationToken.cancelSync() // If available, or restructure
}
```

---

### 5. Missing @MainActor on StreamingService Callbacks (HIGH)
**File:** `Features/Chat/ViewModels/ChatViewModel.swift`  
**Lines:** 416-418

**Issue:** Sendable closures are marked `@Sendable` but may be called on background threads, requiring MainActor hops for UI updates.

```swift
onChunk: @escaping @Sendable (String) -> Void,
onToolCall: @escaping @Sendable (ToolCall) -> Void,
onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
```

**Fix:** Document the threading contract or use MainActor-bound closures:
```swift
onChunk: @escaping @Sendable @MainActor (String) -> Void,
```

---

### 6. Strong Self Capture in Message Bubble Closures (HIGH)
**File:** `Features/Chat/Views/MessageBubbleView.swift`  
**Lines:** 64-73

**Issue:** `onTapGesture` and `onLongPressGesture` closures capture `self` strongly.

```swift
.onTapGesture {
    withAnimation {
        showActions.toggle()  // Implicit self
    }
}
```

**Fix:** While SwiftUI view structs don't have the same retain cycle issues as classes, explicit `[self]` captures improve clarity:
```swift
.onTapGesture { [self] in
    withAnimation {
        showActions.toggle()
    }
}
```

---

### 7. Unsafe Access to streamingMessage in onChange (HIGH)
**File:** `Features/Chat/Views/ChatView.swift`  
**Lines:** 91-95

**Issue:** Optional chaining in `onChange` modifier may have unexpected behavior with SwiftUI's change tracking.

```swift
.onChange(of: viewModel.streamingMessage?.content) { _, _ in
```

**Fix:** Use a computed property or observe the view model more explicitly:
```swift
.onChange(of: viewModel.streamingContentUpdateID) { _, _ in
```

---

### 8. Duplicate InlineCodeView Definition (HIGH)
**Files:** 
- `Features/Chat/MarkdownComponents/InlineCodeView.swift` (lines 1-173)
- `Features/Chat/MarkdownComponents/CodeBlockView.swift` (lines 226-252)

**Issue:** `InlineCodeView` is defined in both files, causing redeclaration errors at compile time.

**Fix:** Remove the duplicate from CodeBlockView.swift (lines 226-252).

---

## 🟡 Medium Issues

### 9. Splash Highlighter Performance on Main Thread (MEDIUM)
**File:** `Features/Chat/MarkdownComponents/MarkdownRenderer.swift`  
**Lines:** 185-197

**Issue:** Syntax highlighting runs synchronously on the main thread for large code blocks, potentially blocking UI.

```swift
func highlightCode(_ content: String, language: String?) -> Text {
    if language?.lowercased() == "swift" {
        do {
            let highlighted = try highlighter.highlight(content)  // Synchronous, main thread
            return Text(highlighted)
        }
    }
}
```

**Fix:** Consider offloading to background for large content or caching results.

---

### 10. No Error Handling for Malformed Markdown (MEDIUM)
**File:** `Features/Chat/Views/MessageBubbleView.swift`  
**Lines:** 247-253

**Issue:** Markdown rendering doesn't handle parsing errors gracefully.

**Fix:** Wrap in do-catch and provide fallback:
```swift
var body: some View {
    Markdown(content)
        .markdownTheme(markdownTheme)
        .fallback {
            Text(content)  // Fallback for parse errors
        }
}
```

---

### 11. Missing @ViewBuilder for Conditional Views (MEDIUM)
**File:** `Features/Chat/MarkdownComponents/CodeBlockView.swift`  
**Lines:** 147-157

**Issue:** `highlightedCode` uses `@ViewBuilder` but `swiftHighlightedCode` has complex logic that could fail at runtime.

**Fix:** Simplify or add proper error boundaries.

---

### 12. Hardcoded Model List (MEDIUM)
**File:** `Features/Chat/Views/MessageInputView.swift`  
**Lines:** 243-250

**Issue:** Available models are hardcoded in the view.

```swift
private let availableModels = [
    "hermes-agent",
    "gpt-4",
    // ...
]
```

**Fix:** Inject via ViewModel or configuration.

---

## 🟢 Low Issues

### 13. Inconsistent Font Loading (LOW)
**File:** `Features/Chat/MarkdownComponents/MarkdownRenderer.swift`  
**Lines:** 18

**Issue:** Font is created with `.init(size: 14)` which may not respect accessibility settings.

**Fix:** Use `UIFont.preferredFont(forTextStyle:)` equivalent.

---

### 14. Magic Numbers Throughout (LOW)
**Multiple files**

Various hardcoded values (corner radii, padding, durations) should be extracted to constants.

---

### 15. Package.swift Swift Version (LOW)
**File:** `Package.swift`  
**Line:** 1

**Issue:** Uses `swift-tools-version:5.9` but enables `StrictConcurrency`. Consider bumping to 6.0 for full Swift 6 support.

---

## Recommended Actions

### Before Phase 3 (MUST FIX):
1. Fix Critical issue #1 (Concurrency in streaming)
2. Fix Critical issue #2 (Notification observer leaks)
3. Fix Critical issue #3 (Retain cycle in CodeBlockView)
4. Fix High issue #4 (Deinit race condition)
5. Fix High issue #8 (Duplicate InlineCodeView)

### Should Fix Soon:
6. Fix High issue #5 (Missing @MainActor on callbacks)
7. Fix High issue #7 (Unsafe streamingMessage access)
8. Fix Medium issue #9 (Splash performance)

---

## Positive Findings

✅ Good use of `@MainActor` on view models  
✅ Proper use of `@Bindable` for SwiftUI observation  
✅ Good separation of concerns in view components  
✅ Proper error handling in most async operations  
✅ Good accessibility considerations with text selection  

---

## Conclusion

Phase 2 code shows good architectural decisions but has critical concurrency and memory management issues that must be addressed before production. The Swift 6 strict concurrency checking will likely catch many of these issues at compile time, but the runtime behaviors (notification leaks, retain cycles) need manual fixes.

**Recommendation:** Fix all Critical and High issues before proceeding to Phase 3.
