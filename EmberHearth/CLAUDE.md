# EmberHearth — Swift & SwiftUI Agent Guide

This file provides Swift-specific coding conventions for agents working within the EmberHearth Xcode project. It supplements the root `CLAUDE.md` with language and framework guidance.

---

## Platform

- Target **macOS 26.0** or later.
- **Swift 6.2** or later, using modern Swift concurrency throughout.
- Always choose `async`/`await` APIs over closure-based variants when they exist.
- SwiftUI backed by `@Observable` classes for shared data.
- Do not introduce third-party frameworks without asking first.


## Swift Conventions

- `@Observable` classes must be marked `@MainActor` unless the project has Main Actor default actor isolation. Flag any `@Observable` class missing this annotation.
- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Do not use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` unless unavoidable in legacy/integration contexts.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native string methods where they exist — e.g. `replacing("a", with: "b")` rather than `replacingOccurrences(of:with:)`.
- Prefer modern Foundation API — e.g. `URL.documentsDirectory`, `appending(path:)`.
- Never use C-style number formatting (`String(format:)`); use `FormatStyle` — e.g. `Text(value, format: .number.precision(.fractionLength(2)))`.
- Prefer static member lookup to struct instances — e.g. `.circle` not `Circle()`, `.borderedProminent` not `BorderedProminentButtonStyle()`.
- Never use Grand Central Dispatch (`DispatchQueue.main.async`). Use modern Swift concurrency.
- Filter text based on user input with `localizedStandardContains()`, not `contains()`.
- Avoid force unwraps and force `try` unless the failure is truly unrecoverable.
- Never use legacy `Formatter` subclasses (`DateFormatter`, `NumberFormatter`, `MeasurementFormatter`). Use `FormatStyle` API — e.g. `myDate.formatted(date: .abbreviated, time: .shortened)`.


## SwiftUI Conventions

- Use `foregroundStyle()` instead of `foregroundColor()`.
- Use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Use the `Tab` API instead of `tabItem()`.
- Never use the 1-parameter `onChange()` variant; use the 2-parameter or 0-parameter version.
- Never use `onTapGesture()` unless you specifically need tap location or count. Use `Button` for all other taps.
- Never use `Task.sleep(nanoseconds:)`; use `Task.sleep(for:)`.
- Never use `UIScreen.main.bounds` to read available space.
- Do not break views into computed properties; extract into new `View` structs.
- Do not force specific font sizes; use Dynamic Type.
- Use `navigationDestination(for:)` with `NavigationStack`, never `NavigationView`.
- Button labels with images must include text: `Button("Action", systemImage: "plus", action: doSomething)`.
- Prefer `ImageRenderer` over `UIGraphicsImageRenderer` for rendering SwiftUI views.
- Use `bold()` instead of `fontWeight(.bold)` unless a specific weight is needed.
- Prefer `containerRelativeFrame()` or `visualEffect()` over `GeometryReader` when they suffice.
- For `ForEach` over `enumerated()`, do not wrap in `Array()` — use `ForEach(items.enumerated(), id: \.element.id)`.
- Hide scroll indicators with `.scrollIndicators(.hidden)` rather than `showsIndicators: false`.
- Use modern `ScrollPosition` and `defaultScrollAnchor` APIs; avoid `ScrollViewReader`.
- Avoid `AnyView` unless absolutely required.
- Avoid hard-coded padding and spacing values unless specifically requested.
- Avoid UIKit colors in SwiftUI code.


## EmberHearth-Specific

- This is a **macOS menu-bar app**, not an iOS app. No UIKit unless explicitly needed for macOS integration (e.g. `NSStatusBar`).
- The database layer uses **SQLite** directly (not SwiftData or CoreData).
- API keys are stored in the **macOS Keychain** via `KeychainManager` — never in UserDefaults or plaintext.
- All messages are screened through the **TRON security pipeline** before processing.
- No shell/command execution — ever. This is a hard security boundary.


## Module Layout

| Module | Responsibility |
|---|---|
| `App/` | App lifecycle, status bar, permissions, service wiring |
| `Core/` | Message watching, sending, coordination, session management |
| `Database/` | SQLite database access and management |
| `LLM/` | Claude API client, streaming, token counting, circuit breaker |
| `Logging/` | Structured logging and security event tracking |
| `Memory/` | Fact extraction, storage, and retrieval |
| `Personality/` | System prompt building and verbosity adaptation |
| `Security/` | Injection scanning, credential scanning, crisis detection |
| `Views/` | SwiftUI settings UI, onboarding, status components |


## Project Structure

- Use feature-based folder organization (as above).
- One type per Swift file. Do not combine multiple structs, classes, or enums in a single file.
- Write unit tests for core application logic.
- Only write UI tests if unit tests are not possible.
- Never include secrets or API keys in the repository.


## Xcode MCP

If the Xcode MCP is configured, prefer its tools over generic alternatives:

- `DocumentationSearch` — verify API availability and correct usage before writing code
- `BuildProject` — build after changes to confirm compilation succeeds
- `GetBuildLog` — inspect build errors and warnings
- `RenderPreview` — visually verify SwiftUI views using Xcode Previews
- `XcodeListNavigatorIssues` — check for issues in the Xcode Issue Navigator
- `ExecuteSnippet` — test a code snippet in the context of a source file
- `XcodeRead`, `XcodeWrite`, `XcodeUpdate` — prefer these over generic file tools for Xcode project files
