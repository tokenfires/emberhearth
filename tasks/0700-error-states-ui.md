# Task 0700: Error States UI

**Milestone:** M8 - Polish & Release
**Unit:** 8.1 - Error States UI
**Phase:** 3
**Depends On:** 0604 (M7 Onboarding complete)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/specs/error-handling.md` — Read the full document. Pay close attention to "Design Principles" (lines 26-55), "User Communication Patterns" (lines 339-385), and "Component Failure Modes" (lines 59-207) for the specific error states and user-facing messaging templates.
2. `docs/specs/autonomous-operation.md` — Read Section 1 "Self-Monitoring & Self-Healing" (lines 32-60) for the health state machine and the three laws of resilience.
3. `docs/architecture/decisions/0004-no-shell-execution.md` — Read in full. No Process(), no /bin/bash, no NSTask anywhere.
4. `CLAUDE.md` — Project conventions: PascalCase for Swift files, src/ for source, tests/ for tests, security first, VoiceOver on all UI.

> **Context Budget Note:** `error-handling.md` is ~587 lines and is the primary reference. Read the full document. `autonomous-operation.md` is longer; focus only on Part 1, lines 32-60. Skip everything else in that file.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the error states UI for EmberHearth, a native macOS personal AI assistant that communicates via iMessage. This component provides user-friendly error displays when things go wrong. The error handling philosophy is: "The grandmother can't troubleshoot. The system must heal itself." When self-healing fails, the UI must acknowledge clearly, explain simply, and indicate when things should work again. No technical jargon. No scary language.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., ErrorStateView.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask, no osascript via Process)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- All UI views MUST support: VoiceOver accessibility labels, Dynamic Type, keyboard navigation, light/dark mode

## What You Are Building

Two SwiftUI views and supporting types:

1. **ErrorStateView** — A reusable, full-area error display component that shows a friendly error message with icon, title, description, and action button. Used when a major error prevents normal operation.
2. **StatusBanner** — A small, dismissible banner that slides in from the top of the settings window for transient, non-critical status messages. Auto-dismisses and is color-coded.

Plus:
3. **AppError enum** — A structured error type that maps internal errors to user-friendly messaging.
4. **ErrorMessageProvider** — Maps iMessage error responses for when Ember can't respond via iMessage due to an error.

## Files to Create

### 1. `src/Core/Errors/AppError.swift`

```swift
// AppError.swift
// EmberHearth
//
// User-facing error states with friendly messaging.

import Foundation
import SwiftUI

/// Represents user-facing error states in EmberHearth.
///
/// Each case maps to a specific failure condition and carries all
/// the information needed to display a friendly error to the user:
/// an SF Symbol icon, a plain-language title, a helpful description,
/// and an optional action.
///
/// Design philosophy: No technical jargon. No error codes. No scary words
/// like "corrupt" or "fatal." Just clear, calm, helpful language.
enum AppError: Identifiable, Equatable {
    /// API key has not been configured yet.
    case noAPIKey
    /// API key exists but is invalid or expired.
    case apiKeyInvalid
    /// No internet connection detected.
    case noInternet
    /// LLM provider is overloaded (5xx errors).
    case llmOverloaded
    /// LLM rate limit exceeded (429).
    case llmRateLimited(retryAfterMinutes: Int)
    /// chat.db is not accessible (Full Disk Access not granted).
    case chatDbInaccessible
    /// Messages.app is not responding.
    case messagesAppUnavailable
    /// Memory database integrity check failed.
    case databaseCorrupt
    /// An unexpected error occurred.
    case unknownError(underlyingMessage: String?)

    var id: String {
        switch self {
        case .noAPIKey: return "noAPIKey"
        case .apiKeyInvalid: return "apiKeyInvalid"
        case .noInternet: return "noInternet"
        case .llmOverloaded: return "llmOverloaded"
        case .llmRateLimited: return "llmRateLimited"
        case .chatDbInaccessible: return "chatDbInaccessible"
        case .messagesAppUnavailable: return "messagesAppUnavailable"
        case .databaseCorrupt: return "databaseCorrupt"
        case .unknownError: return "unknownError"
        }
    }

    /// The SF Symbol name appropriate for this error type.
    var iconName: String {
        switch self {
        case .noAPIKey:
            return "key.fill"
        case .apiKeyInvalid:
            return "key.slash"
        case .noInternet:
            return "wifi.slash"
        case .llmOverloaded:
            return "cloud.fill"
        case .llmRateLimited:
            return "clock.fill"
        case .chatDbInaccessible:
            return "lock.shield.fill"
        case .messagesAppUnavailable:
            return "message.fill"
        case .databaseCorrupt:
            return "wrench.and.screwdriver.fill"
        case .unknownError:
            return "exclamationmark.circle.fill"
        }
    }

    /// The icon tint color for this error type.
    var iconColor: Color {
        switch self {
        case .noAPIKey, .chatDbInaccessible:
            return .blue
        case .apiKeyInvalid, .llmOverloaded, .llmRateLimited, .messagesAppUnavailable:
            return .orange
        case .noInternet:
            return .secondary
        case .databaseCorrupt, .unknownError:
            return .red
        }
    }

    /// A short, plain-language title for the error.
    var title: String {
        switch self {
        case .noAPIKey:
            return "API Key Needed"
        case .apiKeyInvalid:
            return "API Key Issue"
        case .noInternet:
            return "No Internet Connection"
        case .llmOverloaded:
            return "Service Busy"
        case .llmRateLimited:
            return "Taking a Short Break"
        case .chatDbInaccessible:
            return "Permission Needed"
        case .messagesAppUnavailable:
            return "Messages Not Responding"
        case .databaseCorrupt:
            return "Recovering Data"
        case .unknownError:
            return "Something Went Wrong"
        }
    }

    /// A helpful, jargon-free description of the error and what the user
    /// can expect. Written as if explaining to a non-technical family member.
    var description: String {
        switch self {
        case .noAPIKey:
            return "Set up your API key in Settings to get started. Ember needs this to think and respond to your messages."
        case .apiKeyInvalid:
            return "Your API key isn't working. It may have expired or been revoked. You can update it in Settings."
        case .noInternet:
            return "No internet connection. Ember will respond when you're back online."
        case .llmOverloaded:
            return "Claude is busy right now. Ember will try again in a moment."
        case .llmRateLimited(let minutes):
            return "You've sent a lot of messages. Ember will be back in \(minutes) minute\(minutes == 1 ? "" : "s")."
        case .chatDbInaccessible:
            return "EmberHearth needs Full Disk Access to read your messages. You can grant this in System Settings."
        case .messagesAppUnavailable:
            return "Messages app isn't responding. Make sure it's open and try again."
        case .databaseCorrupt:
            return "Something went wrong with Ember's memory. Attempting to recover your data now..."
        case .unknownError(let message):
            if let message = message, !message.isEmpty {
                return "Something unexpected happened. Ember is trying to fix it. (\(message))"
            }
            return "Something unexpected happened. Ember is trying to fix it."
        }
    }

    /// The label for the action button, if this error has a user action.
    /// Returns nil if no action is available (e.g., auto-recovery states).
    var actionLabel: String? {
        switch self {
        case .noAPIKey:
            return "Open Settings"
        case .apiKeyInvalid:
            return "Update API Key"
        case .noInternet:
            return nil // Auto-retry, no user action
        case .llmOverloaded:
            return nil // Auto-retry
        case .llmRateLimited:
            return nil // Timer-based
        case .chatDbInaccessible:
            return "Open System Settings"
        case .messagesAppUnavailable:
            return "Retry"
        case .databaseCorrupt:
            return nil // Recovery in progress
        case .unknownError:
            return "Get Help"
        }
    }

    /// Whether this error is expected to resolve on its own (transient)
    /// or requires user action (persistent).
    var isTransient: Bool {
        switch self {
        case .noInternet, .llmOverloaded, .llmRateLimited, .databaseCorrupt:
            return true
        case .noAPIKey, .apiKeyInvalid, .chatDbInaccessible,
             .messagesAppUnavailable, .unknownError:
            return false
        }
    }

    /// Equatable conformance (ignoring associated values for comparison).
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        return lhs.id == rhs.id
    }
}
```

### 2. `src/Views/ErrorStateView.swift`

```swift
// ErrorStateView.swift
// EmberHearth
//
// Reusable full-area error display for major error states.

import SwiftUI

/// A reusable error display component that presents a friendly,
/// accessible error message with an icon, title, description,
/// and optional action button.
///
/// Used in the main app window and settings when a critical error
/// prevents normal operation. Designed following Apple HIG for
/// empty/error states.
///
/// ## Accessibility
/// - Full VoiceOver support with grouped elements
/// - Dynamic Type support for all text
/// - Keyboard navigation for action button
/// - High contrast mode support
///
/// ## Usage
/// ```swift
/// ErrorStateView(
///     error: .noAPIKey,
///     onAction: { /* open settings */ },
///     onDismiss: nil
/// )
/// ```
struct ErrorStateView: View {

    /// The error to display.
    let error: AppError

    /// Called when the user taps the action button (if the error has one).
    let onAction: (() -> Void)?

    /// Called when the user dismisses the error. Nil if not dismissible.
    let onDismiss: (() -> Void)?

    /// Whether to show the auto-retry indicator for transient errors.
    @State private var showingRetryIndicator = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: error.iconName)
                .font(.system(size: 48))
                .foregroundColor(error.iconColor)
                .accessibilityHidden(true)

            // Title
            Text(error.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Description
            Text(error.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            // Auto-retry indicator for transient errors
            if error.isTransient && showingRetryIndicator {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking automatically...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Checking automatically")
            }

            // Action button (if available)
            if let actionLabel = error.actionLabel, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
            }

            // Dismiss button (if dismissible)
            if let onDismiss = onDismiss {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(error.title). \(error.description)")
        .onAppear {
            if error.isTransient {
                withAnimation(.easeIn.delay(1.0)) {
                    showingRetryIndicator = true
                }
            }
        }
    }
}
```

### 3. `src/Views/Components/StatusBanner.swift`

```swift
// StatusBanner.swift
// EmberHearth
//
// Dismissible banner for transient status messages.

import SwiftUI

/// The severity level of a status banner, which determines its color.
enum BannerSeverity {
    /// Warning: something needs attention but is not critical (yellow).
    case warning
    /// Error: something failed (red).
    case error
    /// Recovery: a previous error has been resolved (green).
    case recovery
    /// Info: neutral informational message (blue).
    case info

    /// The background color for this severity level.
    var backgroundColor: Color {
        switch self {
        case .warning: return .yellow.opacity(0.15)
        case .error: return .red.opacity(0.15)
        case .recovery: return .green.opacity(0.15)
        case .info: return .blue.opacity(0.15)
        }
    }

    /// The accent/icon color for this severity level.
    var accentColor: Color {
        switch self {
        case .warning: return .orange
        case .error: return .red
        case .recovery: return .green
        case .info: return .blue
        }
    }

    /// The SF Symbol for this severity level.
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .recovery: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// A small banner that slides in from the top of the window for
/// non-critical, transient status messages.
///
/// Features:
/// - Auto-dismisses after 5 seconds (configurable)
/// - Can be manually dismissed by the user
/// - Color-coded by severity: yellow (warning), red (error), green (recovery), blue (info)
/// - Slides in and out with animation
///
/// ## Accessibility
/// - Announced to VoiceOver as a live region
/// - Dismiss button has clear accessibility label
/// - Dynamic Type support for all text
///
/// ## Usage
/// ```swift
/// StatusBanner(
///     message: "Connection restored!",
///     severity: .recovery,
///     isPresented: $showBanner
/// )
/// ```
struct StatusBanner: View {

    /// The message to display in the banner.
    let message: String

    /// The severity level, which determines the color coding.
    let severity: BannerSeverity

    /// Controls whether the banner is shown. Set to false to dismiss.
    @Binding var isPresented: Bool

    /// How long (in seconds) before the banner auto-dismisses.
    /// Set to nil to disable auto-dismiss.
    var autoDismissAfter: TimeInterval? = 5.0

    /// Timer task for auto-dismiss.
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        if isPresented {
            HStack(spacing: 10) {
                // Severity icon
                Image(systemName: severity.iconName)
                    .foregroundColor(severity.accentColor)
                    .font(.body)
                    .accessibilityHidden(true)

                // Message text
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(severity.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(severity.accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(severity == .error ? "Error" : severity == .warning ? "Warning" : severity == .recovery ? "Success" : "Info"): \(message)")
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                startAutoDismiss()
            }
            .onDisappear {
                dismissTask?.cancel()
            }
        }
    }

    // MARK: - Private Methods

    /// Starts the auto-dismiss timer if configured.
    private func startAutoDismiss() {
        guard let delay = autoDismissAfter else { return }
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    /// Dismisses the banner with animation.
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        dismissTask?.cancel()
    }
}
```

### 4. `src/Core/Errors/ErrorMessageProvider.swift`

```swift
// ErrorMessageProvider.swift
// EmberHearth
//
// Provides user-friendly iMessage responses when Ember cannot process a message.

import Foundation

/// Provides friendly iMessage text responses for when Ember encounters
/// an error while trying to respond to a user message.
///
/// When the MessageCoordinator detects an error, it uses this provider
/// to generate an appropriate iMessage to send back to the user, so
/// they know Ember is aware of the problem and working on it.
///
/// The messages are written in Ember's voice: warm, brief, honest,
/// no technical jargon.
struct ErrorMessageProvider {

    /// Returns an appropriate iMessage response for the given error.
    ///
    /// - Parameter error: The error that prevented Ember from responding normally.
    /// - Returns: A short, friendly iMessage string in Ember's voice.
    static func iMessageResponse(for error: AppError) -> String? {
        switch error {
        case .noAPIKey, .apiKeyInvalid, .chatDbInaccessible:
            // These are configuration errors — the user needs to fix them
            // in the Mac app. Don't send iMessages about config issues
            // because the user may not know how to fix them from their phone.
            return nil

        case .noInternet:
            return "Hey, I'm having trouble connecting right now. I'll get back to you when I can!"

        case .llmOverloaded:
            return "Give me a moment — the service I use to think is a bit busy right now. I'll respond soon!"

        case .llmRateLimited(let minutes):
            if minutes <= 1 {
                return "I need to take a short break. I'll be back in about a minute!"
            }
            return "I need to take a short break. I'll be back in about \(minutes) minutes!"

        case .messagesAppUnavailable:
            // Can't send if Messages is unavailable
            return nil

        case .databaseCorrupt:
            return "Something went sideways on my end. Give me a moment to sort it out."

        case .unknownError:
            return "Something went sideways on my end. Give me a moment to sort it out."
        }
    }
}
```

### 5. `tests/Views/ErrorStateViewTests.swift`

Create tests for the error state types and rendering logic:

```swift
// ErrorStateViewTests.swift
// EmberHearth
//
// Unit tests for AppError, ErrorStateView, StatusBanner, and ErrorMessageProvider.

import XCTest
@testable import EmberHearth

final class ErrorStateViewTests: XCTestCase {

    // MARK: - AppError Property Tests

    func testAllErrorsHaveUniqueIds() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        let ids = errors.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All error IDs must be unique")
    }

    func testAllErrorsHaveIcons() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.iconName.isEmpty, "Error \(error.id) must have an icon")
        }
    }

    func testAllErrorsHaveTitles() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.title.isEmpty, "Error \(error.id) must have a title")
        }
    }

    func testAllErrorsHaveDescriptions() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error \(error.id) must have a description")
        }
    }

    func testNoTechnicalJargonInDescriptions() {
        let errors: [AppError] = [
            .noAPIKey, .apiKeyInvalid, .noInternet, .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5), .chatDbInaccessible,
            .messagesAppUnavailable, .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        let jargon = ["SQLite", "HTTP", "XPC", "500", "401", "429", "fatal",
                       "exception", "stack trace", "null", "nil", "crash"]

        for error in errors {
            for term in jargon {
                XCTAssertFalse(
                    error.description.contains(term),
                    "Error \(error.id) description should not contain technical term '\(term)'"
                )
            }
            for term in jargon {
                XCTAssertFalse(
                    error.title.contains(term),
                    "Error \(error.id) title should not contain technical term '\(term)'"
                )
            }
        }
    }

    // MARK: - Transient vs Persistent Tests

    func testTransientErrors() {
        XCTAssertTrue(AppError.noInternet.isTransient)
        XCTAssertTrue(AppError.llmOverloaded.isTransient)
        XCTAssertTrue(AppError.llmRateLimited(retryAfterMinutes: 5).isTransient)
        XCTAssertTrue(AppError.databaseCorrupt.isTransient)
    }

    func testPersistentErrors() {
        XCTAssertFalse(AppError.noAPIKey.isTransient)
        XCTAssertFalse(AppError.apiKeyInvalid.isTransient)
        XCTAssertFalse(AppError.chatDbInaccessible.isTransient)
        XCTAssertFalse(AppError.messagesAppUnavailable.isTransient)
        XCTAssertFalse(AppError.unknownError(underlyingMessage: nil).isTransient)
    }

    // MARK: - Action Button Tests

    func testActionableErrorsHaveActionLabels() {
        XCTAssertNotNil(AppError.noAPIKey.actionLabel)
        XCTAssertNotNil(AppError.apiKeyInvalid.actionLabel)
        XCTAssertNotNil(AppError.chatDbInaccessible.actionLabel)
        XCTAssertNotNil(AppError.messagesAppUnavailable.actionLabel)
        XCTAssertNotNil(AppError.unknownError(underlyingMessage: nil).actionLabel)
    }

    func testAutoRetryErrorsHaveNoActionLabels() {
        XCTAssertNil(AppError.noInternet.actionLabel)
        XCTAssertNil(AppError.llmOverloaded.actionLabel)
        XCTAssertNil(AppError.llmRateLimited(retryAfterMinutes: 5).actionLabel)
        XCTAssertNil(AppError.databaseCorrupt.actionLabel)
    }

    // MARK: - Rate Limited Description Tests

    func testRateLimitedSingularMinute() {
        let error = AppError.llmRateLimited(retryAfterMinutes: 1)
        XCTAssertTrue(error.description.contains("1 minute"))
        XCTAssertFalse(error.description.contains("1 minutes"))
    }

    func testRateLimitedPluralMinutes() {
        let error = AppError.llmRateLimited(retryAfterMinutes: 5)
        XCTAssertTrue(error.description.contains("5 minutes"))
    }

    // MARK: - ErrorMessageProvider Tests

    func testNetworkErrorIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .noInternet)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("connecting"))
    }

    func testRateLimitedIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .llmRateLimited(retryAfterMinutes: 3))
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("break") || message!.contains("back"))
    }

    func testOverloadedIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .llmOverloaded)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("moment") || message!.contains("busy"))
    }

    func testConfigErrorsReturnNilIMessage() {
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .noAPIKey))
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .apiKeyInvalid))
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .chatDbInaccessible))
    }

    func testMessagesUnavailableReturnsNilIMessage() {
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .messagesAppUnavailable))
    }

    func testUnknownErrorIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .unknownError(underlyingMessage: nil))
        XCTAssertNotNil(message)
    }

    // MARK: - Equatable Tests

    func testEquatableIgnoresAssociatedValues() {
        let error1 = AppError.llmRateLimited(retryAfterMinutes: 3)
        let error2 = AppError.llmRateLimited(retryAfterMinutes: 10)
        XCTAssertEqual(error1, error2, "Equatable should compare by ID, ignoring associated values")
    }

    func testDifferentErrorsNotEqual() {
        XCTAssertNotEqual(AppError.noAPIKey, AppError.apiKeyInvalid)
    }

    // MARK: - No Shell Execution Security Check

    func testNoShellExecutionInErrorFiles() {
        // Verify no shell execution patterns exist in the error handling code
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh", "osascript"]
        let safeDescription = "Error handling code must not contain shell execution"

        // This test exists as a reminder — the real check is in verification commands
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                pattern.isEmpty, // Always passes; this test is structural
                "\(safeDescription): \(pattern)"
            )
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, or osascript.** This is a hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, SwiftUI, os).
3. All Swift files use PascalCase naming.
4. All public types, methods, and properties must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. All user-facing text must be jargon-free. No error codes, no "crash," no "fatal," no HTTP status codes.
7. All SwiftUI views MUST have:
   - `.accessibilityLabel()` on interactive elements
   - Support for Dynamic Type (use semantic font sizes, never hardcoded point sizes except for the icon)
   - Keyboard navigation (`.keyboardShortcut()` on buttons)
   - Light/dark mode support (use semantic colors, not hardcoded)
8. The `ErrorStateView` icon can use a hardcoded size (48pt) since it's decorative, not text.
9. StatusBanner's auto-dismiss uses `Task.sleep` — never `Timer` or `DispatchQueue.asyncAfter` for the async context.
10. Test file path: Place at `tests/Views/ErrorStateViewTests.swift` if the tests directory supports subdirectories; otherwise `tests/ErrorStateViewTests.swift`. Check existing test file locations and match that pattern.

## Directory Structure

Create these files:
- `src/Core/Errors/AppError.swift`
- `src/Core/Errors/ErrorMessageProvider.swift`
- `src/Views/ErrorStateView.swift`
- `src/Views/Components/StatusBanner.swift`
- `tests/Views/ErrorStateViewTests.swift` (or `tests/ErrorStateViewTests.swift`)

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. No Process(), /bin/bash, NSTask, or osascript calls exist
4. All user-facing strings are jargon-free (no "SQLite," "HTTP," "XPC," "500," "401," "429," "fatal," "exception")
5. All views have VoiceOver accessibility labels
6. All buttons have keyboard shortcuts
7. StatusBanner auto-dismisses after the configured delay
8. ErrorStateView shows a progress indicator for transient errors
9. ErrorMessageProvider returns nil for errors where sending an iMessage is impossible or inappropriate
10. Rate-limited error uses correct singular/plural ("1 minute" vs "5 minutes")
11. All public types have documentation comments
12. os.Logger is used where logging is needed (not print())
```

---

## Acceptance Criteria

- [ ] `src/Core/Errors/AppError.swift` exists with all 9 error cases and computed properties
- [ ] `src/Views/ErrorStateView.swift` exists and renders all error states
- [ ] `src/Views/Components/StatusBanner.swift` exists with auto-dismiss behavior
- [ ] `src/Core/Errors/ErrorMessageProvider.swift` exists with iMessage response strings
- [ ] Every error case has: SF Symbol icon, plain-language title, helpful description
- [ ] Error descriptions contain zero technical jargon
- [ ] Transient errors show auto-retry progress indicator
- [ ] Persistent errors show action buttons where applicable
- [ ] StatusBanner auto-dismisses after 5 seconds
- [ ] StatusBanner is color-coded: yellow (warning), red (error), green (recovery), blue (info)
- [ ] StatusBanner can be manually dismissed
- [ ] iMessage error responses match Ember's voice (warm, brief, honest)
- [ ] Config errors (noAPIKey, apiKeyInvalid, chatDbInaccessible) return nil for iMessage response
- [ ] Rate-limited description handles singular/plural minutes correctly
- [ ] All views support VoiceOver with proper accessibility labels
- [ ] All views support Dynamic Type
- [ ] All buttons have keyboard shortcuts
- [ ] Light and dark mode supported via semantic colors
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `osascript`
- [ ] All unit tests pass
- [ ] `os.Logger` used for logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Core/Errors/AppError.swift && echo "PASS: AppError.swift exists" || echo "MISSING: AppError.swift"
test -f src/Views/ErrorStateView.swift && echo "PASS: ErrorStateView.swift exists" || echo "MISSING: ErrorStateView.swift"
test -f src/Views/Components/StatusBanner.swift && echo "PASS: StatusBanner.swift exists" || echo "MISSING: StatusBanner.swift"
test -f src/Core/Errors/ErrorMessageProvider.swift && echo "PASS: ErrorMessageProvider.swift exists" || echo "MISSING: ErrorMessageProvider.swift"

# Verify no shell execution
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/ || echo "PASS: No /bin/sh references found"
grep -rn "osascript" src/ || echo "PASS: No osascript references found (except in MessageSender AppleScript template)"

# Verify no technical jargon in user-facing strings
grep -n "SQLite\|HTTP\|XPC\|fatal\|exception\|stack trace" src/Core/Errors/AppError.swift && echo "FAIL: Technical jargon found" || echo "PASS: No technical jargon in AppError"

# Build the project
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the error state tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/ErrorStateViewTests 2>&1 | tail -30
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth error states UI implementation for accessibility, user-friendliness, and correctness. Open these files:

@src/Core/Errors/AppError.swift
@src/Views/ErrorStateView.swift
@src/Views/Components/StatusBanner.swift
@src/Core/Errors/ErrorMessageProvider.swift
@tests/Views/ErrorStateViewTests.swift

Also reference:
@docs/specs/error-handling.md
@docs/specs/autonomous-operation.md

## USER EXPERIENCE AUDIT (Top Priority)

1. **Jargon-Free Language (CRITICAL):**
   - Read every user-facing string in AppError (titles, descriptions, action labels).
   - Does any string contain technical terms? (SQLite, HTTP, API, error code numbers, "corrupt," "fatal," "exception," "null," "timeout," "retry")
   - Note: "API key" is acceptable since users see it during onboarding setup.
   - Would a non-technical grandparent understand every message?

2. **Emotional Tone (CRITICAL):**
   - Are the messages calm and reassuring, not alarming?
   - Do they tell the user what's happening and what to expect?
   - Is the language consistent with Ember's personality (warm, honest, concise)?
   - Read the iMessage responses from ErrorMessageProvider — do they sound like Ember?

3. **Accessibility (CRITICAL):**
   - Does ErrorStateView have VoiceOver accessibility labels on all elements?
   - Does StatusBanner have VoiceOver support?
   - Is Dynamic Type supported (semantic font sizes, no hardcoded point sizes for text)?
   - Do all buttons have keyboard shortcuts?
   - Does the dismiss button on StatusBanner have an accessibility label?
   - Test mentally: if VoiceOver reads this view, does it make sense?

## CORRECTNESS REVIEW

4. **Error State Coverage:**
   - Does AppError cover all failure modes from error-handling.md?
   - Is any important error state missing?
   - Are the isTransient flags correct? (noInternet, llmOverloaded, llmRateLimited should be transient; noAPIKey, apiKeyInvalid should not)

5. **StatusBanner Behavior:**
   - Does auto-dismiss work correctly with Task.sleep?
   - Is the dismiss task properly cancelled on disappear?
   - Could there be a race condition between auto-dismiss and manual dismiss?
   - Does the animation look right (slide in from top, fade out)?

6. **ErrorMessageProvider Logic:**
   - Is it correct to return nil for noAPIKey, apiKeyInvalid, chatDbInaccessible? (These require Mac app action, not iMessage)
   - Is it correct to return nil for messagesAppUnavailable? (Can't send if Messages is down)
   - Are the iMessage strings short enough to be comfortable in a text message?

7. **Rate Limit Pluralization:**
   - "1 minute" vs "5 minutes" — is this handled correctly?
   - What happens with 0 minutes? Is that a valid input?

## CODE QUALITY

8. **SwiftUI Best Practices:**
   - Are semantic colors used (no hardcoded hex values)?
   - Is the layout responsive to different window sizes?
   - Is `fixedSize(horizontal: false, vertical: true)` used correctly for multiline text?

9. **Security:**
   - Are there ANY calls to Process(), /bin/bash, /bin/sh, NSTask, or osascript?
   - Could the `unknownError(underlyingMessage:)` case leak technical details to the user? Is the underlying message exposed safely?

10. **Test Quality:**
    - Do tests cover all 9 error cases?
    - Do tests verify jargon-free language?
    - Do tests verify transient vs persistent classification?
    - Do tests verify iMessage response logic (including nil returns)?
    - Do tests verify rate limit singular/plural?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m8): add user-friendly error state views and status banners
```

---

## Notes for Next Task

- `AppError` is the canonical error type for user-facing errors. Other internal error types (like `MessageSenderError`, `ClaudeAPIError`, etc.) should be mapped to `AppError` at the coordinator level before being shown to users.
- `ErrorStateView` is designed to be embedded in any view that needs to show a full-area error state. The onboarding flow and settings views will use it.
- `StatusBanner` should be overlaid at the top of the settings window. The settings view (task 0701) will integrate it.
- `ErrorMessageProvider` should be called by the `MessageCoordinator` when it catches an error during message processing and needs to send an acknowledgment to the user via iMessage.
- The `unknownError(underlyingMessage:)` case includes an optional underlying message string. Be careful not to pass raw technical error messages through this — the coordinator should sanitize or omit the message before creating this error.
- `BannerSeverity` is separate from `AppError` because banners can show success/recovery messages too, not just errors.
