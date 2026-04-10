# Troubleshooting Guide

Common issues and their solutions when building or running HermesApp.

## Table of Contents

- [Build Issues](#build-issues)
- [Runtime Issues](#runtime-issues)
- [API Connection Issues](#api-connection-issues)
- [Swift 6 Concurrency Issues](#swift-6-concurrency-issues)
- [UI Issues](#ui-issues)
- [Performance Issues](#performance-issues)

## Build Issues

### "target 'HermesApp' referenced in product 'HermesApp' is empty"

**Cause:** Package.swift uses `path: "."` which requires opening `Package.swift` directly, not generating an Xcode project.

**Solution:**

```bash
# Correct - open Package.swift directly
open Package.swift

# Incorrect - don't generate xcodeproj
swift package generate-xcodeproj  # Don't do this
```

In Xcode: **File → Open** → Select `Package.swift` (not the folder).

### Swift Compiler Crash / Stack Overflow

**Symptoms:** 
- Build hangs indefinitely
- "Segmentation fault" in build log
- Compiler runs out of memory

**Cause:** Complex view bodies with many modifiers cause Swift's type checker to overflow.

**Solution:** Split body into `@ViewBuilder` computed properties:

```swift
// Before (may crash)
var body: some View {
    VStack {
        if condition1 {
            if condition2 {
                ForEach(items) { item in
                    // ... complex nested views
                }
            }
        }
        // ... more complexity
    }
    .modifier1()
    .modifier2()
    // ... many modifiers
}

// After (compiles successfully)
var body: some View {
    VStack {
        headerSection
        contentSection
        footerSection
    }
}

@ViewBuilder
private var headerSection: some View {
    if condition1 && condition2 {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
}

@ViewBuilder
private var contentSection: some View { ... }

@ViewBuilder
private var footerSection: some View { ... }
```

### "Cannot find 'PackageDescription' in scope"

**Cause:** Trying to build as a regular Xcode project instead of Swift Package.

**Solution:** Open `Package.swift` directly in Xcode, not the project folder.

### "No such module 'MarkdownUI'"

**Cause:** Dependencies not resolved.

**Solution:**

In Xcode: **File → Packages → Resolve Package Versions**

Or via terminal:

```bash
swift package resolve
```

### Build fails with "ambiguous use of"

**Cause:** Name collisions between imported modules.

**Solution:** Use fully qualified names:

```swift
// Instead of
import MarkdownUI
Text(markdown: content)  // May conflict with SwiftUI.Text

// Use
import MarkdownUI
MarkdownUI.Text(markdown: content)
```

## Runtime Issues

### App crashes on launch

**Check Console.app for crash logs:**

1. Open Console.app (Applications → Utilities)
2. Select your device
3. Filter by "HermesApp"
4. Look for crash reports

**Common causes:**
- Missing API key configuration
- SwiftData migration error
- Invalid UserDefaults values

### "Thread 1: Fatal error: Unexpectedly found nil"

**Cause:** Force unwrapping optional that is nil.

**Solution:** Check for common nil cases:

```swift
// Instead of
let url = URL(string: apiBaseURL)!

// Use
 guard let url = URL(string: apiBaseURL) else {
     Logger.error("Invalid API URL: \(apiBaseURL)")
     throw APIError.invalidURL
 }
```

### SwiftData errors

**"Failed to find current container"**

**Cause:** Model container not properly initialized.

**Solution:** Ensure `.modelContainer()` is called on the WindowGroup:

```swift
WindowGroup {
    ContentView()
}
.modelContainer(SwiftDataStack.shared)
```

**"Data validation failed"**

**Cause:** Required fields missing in model.

**Solution:** Check all `@Model` classes have default values:

```swift
@Model
class Message {
    var content: String = ""  // Default value
    var timestamp: Date = Date()
    // ...
}
```

## API Connection Issues

### "Cannot connect to server"

**Diagnose:**

```bash
# Test API availability
curl http://localhost:8642/v1/models

# Should return JSON with available models
```

**Solutions:**

1. **Check Hermes is running:**
   ```bash
   hermes --api-server
   ```

2. **Verify URL in Settings:**
   - Default: `http://localhost:8642/v1`
   - No trailing slash
   - Include `/v1` path

3. **Check firewall/network:**
   ```bash
   # Test connectivity
   telnet localhost 8642
   ```

4. **For remote servers, use SSH tunnel:**
   ```bash
   ssh -L 8642:localhost:8642 user@remote-server
   ```

### "Invalid response format"

**Cause:** Server returns HTML error page instead of JSON.

**Solutions:**
- Check API baseURL doesn't have trailing slash
- Verify correct endpoint paths
- Check server logs for errors

### Streaming not working

**Symptoms:** 
- Messages appear all at once instead of streaming
- No typing indicator

**Causes & Solutions:**

1. **Server doesn't support streaming:**
   - Check Hermes API version
   - Verify `stream: true` in request

2. **Network buffering:**
   - Some proxies buffer SSE responses
   - Try direct connection

3. **Client not reading SSE properly:**
   ```swift
   // Ensure proper SSE parsing
   for try await line in bytes.lines {
       if line.hasPrefix("data: ") {
           // Process chunk
       }
   }
   ```

## Swift 6 Concurrency Issues

### "Cannot access property 'cancellables' from non-isolated deinit"

**Cause:** `@MainActor` class trying to access actor-isolated property from `deinit`.

**Solution:** Mark property as `nonisolated(unsafe)`:

```swift
@MainActor
class ViewModel: ObservableObject {
    nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    
    nonisolated deinit {
        cancellables.removeAll()
    }
}
```

### "Call to main actor-isolated function in a synchronous nonisolated context"

**Cause:** Calling `@MainActor` method from non-isolated code.

**Solution:** Use `await MainActor.run`:

```swift
// Non-isolated context
Task {
    await MainActor.run {
        // Main actor code here
        viewModel.updateUI()
    }
}
```

Or mark the calling function as `@MainActor`:

```swift
@MainActor
func updateUI() {
    // All code here runs on main actor
    viewModel.messages.append(message)
}
```

### "Sendable conformance" warnings

**Cause:** Passing non-Sendable types across actor boundaries.

**Solution:** Make types Sendable:

```swift
// Value types are automatically Sendable
struct Message: Sendable {
    let content: String
    let timestamp: Date
}

// Classes need explicit conformance
final class APIClient: @unchecked Sendable {
    // Internal synchronization required
}
```

## UI Issues

### Markdown not rendering

**Symptoms:** Raw markdown text shown instead of formatted text.

**Causes:**
1. MarkdownUI not properly initialized
2. Theme not applied

**Solution:**

```swift
// Ensure theme is applied
Markdown(content)
    .markdownTheme(.gitHub)
```

### Code blocks without syntax highlighting

**Cause:** Splash not configured for MarkdownUI.

**Solution:**

```swift
import MarkdownUI
import Splash

// Create custom code block with Splash
struct CodeBlock: View {
    let language: String?
    let code: String
    
    var body: some View {
        // Use Splash for syntax highlighting
        Text(highlightedCode)
            .font(.system(.body, design: .monospaced))
    }
    
    private var highlightedCode: AttributedString {
        // Splash highlighting logic
    }
}
```

### Canvas split view not draggable

**Cause:** Gesture conflicts with SwiftUI.

**Solution:** Use `.gesture()` with explicit priority:

```swift
ResizableDivider()
    .gesture(
        DragGesture()
            .onChanged { value in
                // Update split position
            }
    )
```

### Keyboard covers text input

**Solution:** Use `.safeAreaInset()`:

```swift
ChatView()
    .safeAreaInset(edge: .bottom) {
        MessageInputView()
    }
```

## Performance Issues

### Slow message list scrolling

**Causes:**
1. No view recycling
2. Heavy markdown rendering on main thread
3. Large conversation history

**Solutions:**

1. **Use lazy loading:**
   ```swift
   List {
       ForEach(messages) { message in
           MessageBubbleView(message: message)
       }
   }
   ```

2. **Offload markdown rendering:**
   ```swift
   Task {
       let attributed = await markdownRenderer.render(content)
       await MainActor.run {
           self.renderedContent = attributed
       }
   }
   ```

3. **Paginate history:**
   ```swift
   // Load last 50 messages initially
   // Load more on scroll to top
   ```

### Memory leaks

**Symptoms:** App memory usage grows continuously.

**Common causes:**
1. NotificationCenter observers not removed
2. Task closures capturing self strongly
3. AsyncStream not cancelled

**Solutions:**

1. **Remove observers:**
   ```swift
   deinit {
       NotificationCenter.default.removeObserver(self)
   }
   ```

2. **Weak self in tasks:**
   ```swift
   Task { [weak self] in
       guard let self else { return }
       // Work here
   }
   ```

3. **Cancel streams:**
   ```swift
   func cancelStreaming() {
       streamTask?.cancel()
   }
   ```

### High CPU usage

**Diagnose with Instruments:**

1. Product → Profile (Cmd+I)
2. Select "Time Profiler"
3. Record while reproducing the issue

**Common fixes:**
- Reduce view update frequency
- Use `@StateObject` instead of `@ObservedObject` for view models
- Debounce rapid UI updates

## Getting Help

If issues persist:

1. **Check logs:**
   - Xcode console
   - macOS Console.app
   - Hermes API logs

2. **Enable debug logging:**
   ```swift
   Logger.isDebugEnabled = true
   ```

3. **Create minimal reproduction:**
   - Isolate the problematic code
   - Create a small test project

4. **Report issues:**
   - GitHub Issues: https://github.com/23492/HermesApp/issues
   - Include: Xcode version, macOS/iOS version, error logs
