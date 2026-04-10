# Changelog

All notable changes to HermesApp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - 2026-04-10

### Added

#### Core Features
- Universal iOS/macOS support (iOS 17.0+, macOS 14.0+)
- Real-time SSE streaming from Hermes API
- SwiftData persistence for offline conversation history
- Session continuity via X-Hermes-Session-Id headers

#### Chat Interface
- Modern chat UI with message bubbles
- Markdown rendering with MarkdownUI
- Syntax highlighting with Splash
- Message actions (copy, edit, regenerate)
- Auto-resizing input with @mentions support
- Conversation list with search

#### Tool Calling
- Visual tool execution indicators
- Support for 30+ tools:
  - Terminal: bash, shell, run_command
  - File: read, write, patch, search, delete, move
  - Web: search, extract, fetch
  - Browser: navigate, click, type, screenshot, scroll
  - Code: python, javascript, execute_code
  - System: think, delay
  - User: ask, confirm
- Live action status bar
- Tool result display

#### Reasoning Display
- Claude-style collapsible thinking blocks
- Real-time reasoning streaming
- Expandable/collapsible UI

#### Canvas Support
- Side-by-side code/document editing
- CodeCanvas with line numbers and syntax highlighting
- DocumentCanvas for markdown editing
- PreviewCanvas for HTML/Markdown preview
- Resizable split view with draggable divider
- Apply/Discard actions
- Multiple layout modes (sideBySide, stacked, chatOnly, canvasOnly)
- Diff view for comparing changes

#### Ask User Questions
- Interactive question prompts during AI tasks
- Support for text input, confirm/cancel, and multiple choice
- Question history view
- Modal and inline display options

#### Architecture
- Swift 6 strict concurrency compliance
- MVVM architecture with @Observable
- Actor-based networking layer
- Repository pattern for data access
- Dependency injection via @Environment

#### Development
- Swift Package Manager project
- Xcode 15+ support
- Unit test target
- Documentation in docs/

### Technical Details

#### Swift 6 Concurrency
- All UI code marked with @MainActor
- Actor-isolated API client
- nonisolated(unsafe) for deinit-accessible properties
- Sendable conformance for data models

#### Compiler Fixes
- Split complex view bodies into @ViewBuilder properties
- Fixed @MainActor isolation issues
- Resolved ShapeStyle inference errors
- Replaced macOS 15+ APIs with compatible alternatives

#### Dependencies
- MarkdownUI 2.0.0+ (Markdown rendering)
- Splash 0.16.0+ (Syntax highlighting)

### Known Issues
- Canvas diff view performance degrades with large files (>1000 lines)
- SwiftData migration not yet implemented (app reinstall required for schema changes)

## [0.1.0] - 2026-04-09

### Added
- Initial project setup
- Basic chat interface
- Hermes API client foundation
- SwiftData models

---

## Release Notes Template

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Now removed features

### Fixed
- Bug fixes

### Security
- Security improvements
```
