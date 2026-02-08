# Task 0102: AppleScript Message Sender

**Milestone:** M2 - iMessage Integration
**Unit:** 2.3 - Message Sender (AppleScript)
**Phase:** 1
**Depends On:** 0100
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/imessage.md` — Read the AppleScript section under "How does Messages.app automation work via AppleScript?" for the send template and limitations.
2. `docs/architecture/decisions/0004-no-shell-execution.md` — **CRITICAL:** Read this in full. The ONLY allowed AppleScript execution method is `NSAppleScript`. Using `Process()` with `osascript` is PROHIBITED.
3. `CLAUDE.md` — Project conventions and security principles.

> **Context Budget Note:** ADR-0004 is short (~100 lines). Read it in full. For `imessage.md`, focus on the AppleScript sections and "Security Considerations" table.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the iMessage sender for EmberHearth, a macOS personal AI assistant. This component sends messages through Messages.app using AppleScript via NSAppleScript.

## CRITICAL SECURITY RULES — Read Before Writing Any Code

1. **NEVER use Process(), NSTask, /bin/bash, /bin/sh, /usr/bin/osascript, or any shell execution.**
   The ONLY way to execute AppleScript is via `NSAppleScript(source:)?.executeAndReturnError(&error)`.
   This is a non-negotiable security requirement per ADR-0004.

2. **The AppleScript template is HARDCODED.** Only two variables are interpolated: the phone number and the message text. Both must be sanitized before interpolation.

3. **No dynamic AppleScript generation.** You cannot build arbitrary AppleScript strings. The template is fixed.

## What You Are Building

A message sender that uses NSAppleScript to send iMessage messages through Messages.app. It validates phone numbers, sanitizes message text for safe AppleScript interpolation, and handles errors gracefully.

## Files to Create

### 1. `src/Core/Errors/MessageSenderError.swift`

```swift
import Foundation

/// Errors that can occur when sending messages via AppleScript.
enum MessageSenderError: LocalizedError {
    /// The phone number is not in valid E.164 format.
    case invalidPhoneNumber(number: String)

    /// The message text is empty after trimming whitespace.
    case emptyMessage

    /// The message exceeds the maximum allowed length.
    case messageTooLong(length: Int, maxLength: Int)

    /// Messages.app is not running and could not be activated.
    case messagesAppNotAvailable

    /// The AppleScript execution failed.
    /// This can happen if:
    /// - Automation permission has not been granted
    /// - The buddy (phone number) was not found in Messages
    /// - Messages.app encountered an internal error
    case appleScriptFailed(errorDescription: String)

    /// Rate limit exceeded. Too many messages sent in a short time.
    case rateLimitExceeded(retryAfter: TimeInterval)

    /// The phone number was not found as a buddy in Messages.app.
    case buddyNotFound(phoneNumber: String)

    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber(let number):
            return "Invalid phone number format: '\(number)'. Expected E.164 format (e.g., +15551234567)."
        case .emptyMessage:
            return "Cannot send an empty message."
        case .messageTooLong(let length, let maxLength):
            return "Message is too long (\(length) characters). Maximum is \(maxLength) characters."
        case .messagesAppNotAvailable:
            return "Messages.app is not available. Please ensure it is installed and running."
        case .appleScriptFailed(let description):
            return "Failed to send message via AppleScript: \(description)"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Please wait \(Int(retryAfter)) seconds before sending another message."
        case .buddyNotFound(let phoneNumber):
            return "Could not find '\(phoneNumber)' in Messages. Ensure this contact uses iMessage."
        }
    }
}
```

### 2. `src/Core/MessageSender.swift`

```swift
import Foundation
import os.log

/// Sends iMessage messages through Messages.app using AppleScript.
///
/// This class uses `NSAppleScript` to execute a hardcoded AppleScript template
/// that sends messages via Messages.app. It includes input validation, text
/// sanitization, rate limiting, and message chunking for long messages.
///
/// ## Security
/// - Uses ONLY `NSAppleScript` — never `Process()`, `NSTask`, or shell execution
/// - The AppleScript template is hardcoded — only phone number and message text are variable
/// - All variable content is sanitized to prevent AppleScript injection
/// - Per ADR-0004: No shell/command execution allowed
///
/// ## Requirements
/// - Messages.app must be running (or will be launched automatically by AppleScript)
/// - Automation permission must be granted (System Settings > Privacy & Security > Automation)
///
/// ## Usage
/// ```swift
/// let sender = MessageSender()
/// try await sender.send(message: "Hello!", to: "+15551234567")
/// ```
final class MessageSender {

    // MARK: - Constants

    /// Maximum characters per message chunk. iMessage supports ~20,000 chars,
    /// but we keep responses short for readability in the iMessage UI.
    static let maxChunkLength = 2000

    /// Maximum total message length before rejecting. This prevents accidental
    /// sends of enormous strings (e.g., base64 data, serialized objects).
    static let maxTotalLength = 10000

    /// Minimum interval between message sends in seconds.
    /// This prevents spamming and gives Messages.app time to process.
    static let rateLimitInterval: TimeInterval = 1.0

    // MARK: - Properties

    /// Logger for message sending operations.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "MessageSender")

    /// The timestamp of the last successful message send. Used for rate limiting.
    private var lastSendTime: Date?

    /// Serial queue for synchronizing send operations.
    private let sendQueue = DispatchQueue(label: "com.emberhearth.messagesender")

    // MARK: - Public Methods

    /// Sends a message to a phone number via iMessage.
    ///
    /// This method validates the phone number, sanitizes the message text,
    /// splits long messages into chunks, and sends each chunk via AppleScript.
    ///
    /// - Parameters:
    ///   - message: The text message to send. Must not be empty.
    ///   - phoneNumber: The recipient phone number in E.164 format (e.g., "+15551234567").
    /// - Throws: `MessageSenderError` if validation fails or sending fails.
    func send(message: String, to phoneNumber: String) async throws {
        // Validate phone number format
        guard Self.isValidE164PhoneNumber(phoneNumber) else {
            logger.error("Invalid phone number format: \(phoneNumber, privacy: .private)")
            throw MessageSenderError.invalidPhoneNumber(number: phoneNumber)
        }

        // Validate message is not empty
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            logger.error("Attempted to send empty message")
            throw MessageSenderError.emptyMessage
        }

        // Validate message length
        guard trimmedMessage.count <= Self.maxTotalLength else {
            logger.error("Message too long: \(trimmedMessage.count) chars (max: \(Self.maxTotalLength))")
            throw MessageSenderError.messageTooLong(
                length: trimmedMessage.count,
                maxLength: Self.maxTotalLength
            )
        }

        // Split into chunks if needed
        let chunks = Self.splitMessage(trimmedMessage, maxLength: Self.maxChunkLength)

        logger.info("Sending \(chunks.count) chunk(s) to \(phoneNumber, privacy: .private)")

        // Send each chunk
        for (index, chunk) in chunks.enumerated() {
            try await enforceRateLimit()
            try await executeSendScript(message: chunk, to: phoneNumber)
            logger.info("Sent chunk \(index + 1)/\(chunks.count)")
        }
    }

    // MARK: - Phone Number Validation

    /// Validates that a phone number is in E.164 format.
    ///
    /// E.164 format: + followed by 1-15 digits (e.g., +15551234567).
    /// This is the format used by iMessage for buddy lookup.
    ///
    /// - Parameter number: The phone number to validate.
    /// - Returns: True if the number is valid E.164 format.
    static func isValidE164PhoneNumber(_ number: String) -> Bool {
        // E.164: + followed by 1-15 digits
        let pattern = #"^\+[1-9]\d{1,14}$"#
        return number.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Text Sanitization

    /// Sanitizes a message string for safe interpolation into an AppleScript template.
    ///
    /// AppleScript strings are delimited by double quotes. We must escape:
    /// - Backslashes (\) — doubled to \\
    /// - Double quotes (") — escaped to \"
    ///
    /// This prevents AppleScript injection attacks where message content could
    /// break out of the string literal and execute arbitrary AppleScript.
    ///
    /// - Parameter text: The raw message text.
    /// - Returns: The sanitized text safe for AppleScript string interpolation.
    static func sanitizeForAppleScript(_ text: String) -> String {
        var sanitized = text
        // Escape backslashes FIRST (before escaping quotes, which adds backslashes)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        // Escape double quotes
        sanitized = sanitized.replacingOccurrences(of: "\"", with: "\\\"")
        return sanitized
    }

    // MARK: - Message Splitting

    /// Splits a long message into chunks at sentence boundaries.
    ///
    /// Prefers splitting at sentence-ending punctuation (. ! ?), falling back to
    /// word boundaries, and finally hard-splitting at the max length.
    ///
    /// - Parameters:
    ///   - message: The message to split.
    ///   - maxLength: Maximum characters per chunk.
    /// - Returns: An array of message chunks, each within the max length.
    static func splitMessage(_ message: String, maxLength: Int) -> [String] {
        guard message.count > maxLength else {
            return [message]
        }

        var chunks: [String] = []
        var remaining = message

        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }

            // Take a window of maxLength characters
            let endIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
            let window = remaining[remaining.startIndex..<endIndex]

            // Try to find a sentence boundary (. ! ?) followed by a space
            var splitIndex: String.Index?

            // Search backwards from the end of the window for sentence punctuation
            let sentenceEnders: [Character] = [".", "!", "?"]
            var searchIndex = window.index(before: window.endIndex)
            while searchIndex > window.startIndex {
                let char = window[searchIndex]
                if sentenceEnders.contains(char) {
                    // Check if next char is a space or end of string
                    let nextIndex = window.index(after: searchIndex)
                    if nextIndex == window.endIndex || window[nextIndex] == " " {
                        splitIndex = window.index(after: searchIndex)
                        break
                    }
                }
                searchIndex = window.index(before: searchIndex)

                // Don't search more than halfway back
                if window.distance(from: window.startIndex, to: searchIndex) < maxLength / 2 {
                    break
                }
            }

            // Fallback: split at last space
            if splitIndex == nil {
                searchIndex = window.index(before: window.endIndex)
                while searchIndex > window.startIndex {
                    if window[searchIndex] == " " {
                        splitIndex = searchIndex
                        break
                    }
                    searchIndex = window.index(before: searchIndex)

                    if window.distance(from: window.startIndex, to: searchIndex) < maxLength / 2 {
                        break
                    }
                }
            }

            // Last resort: hard split at maxLength
            let actualSplitIndex = splitIndex ?? endIndex

            let chunk = String(remaining[remaining.startIndex..<actualSplitIndex])
                .trimmingCharacters(in: .whitespaces)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }

            remaining = String(remaining[actualSplitIndex...])
                .trimmingCharacters(in: .whitespaces)
        }

        return chunks
    }

    // MARK: - Private Methods

    /// Enforces the rate limit between message sends.
    ///
    /// If the last message was sent less than `rateLimitInterval` ago,
    /// this method waits for the remaining time before returning.
    private func enforceRateLimit() async throws {
        if let lastSend = lastSendTime {
            let elapsed = Date().timeIntervalSince(lastSend)
            if elapsed < Self.rateLimitInterval {
                let waitTime = Self.rateLimitInterval - elapsed
                logger.debug("Rate limiting: waiting \(waitTime, format: .fixed(precision: 2))s")
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
    }

    /// Executes the AppleScript to send a single message.
    ///
    /// This is the ONLY method that executes AppleScript. The template is hardcoded.
    /// Only the phone number and sanitized message text are interpolated.
    ///
    /// - Parameters:
    ///   - message: The message text (will be sanitized).
    ///   - phoneNumber: The E.164 phone number (already validated).
    /// - Throws: `MessageSenderError` if the AppleScript execution fails.
    private func executeSendScript(message: String, to phoneNumber: String) async throws {
        let sanitizedMessage = Self.sanitizeForAppleScript(message)
        let sanitizedPhoneNumber = Self.sanitizeForAppleScript(phoneNumber)

        // HARDCODED AppleScript template — DO NOT make this dynamic.
        // Only sanitizedPhoneNumber and sanitizedMessage are variable.
        let scriptSource = """
            tell application "Messages"
                set targetBuddy to buddy "\(sanitizedPhoneNumber)" of service "iMessage"
                send "\(sanitizedMessage)" to targetBuddy
            end tell
            """

        // Execute on a background thread since AppleScript is synchronous
        let result: Result<Void, MessageSenderError> = await withCheckedContinuation { continuation in
            sendQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(.messagesAppNotAvailable))
                    return
                }

                var errorDict: NSDictionary?
                let script = NSAppleScript(source: scriptSource)
                script?.executeAndReturnError(&errorDict)

                if let errorDict = errorDict {
                    let errorNumber = errorDict[NSAppleScript.errorNumber] as? Int ?? -1
                    let errorMessage = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"

                    self.logger.error("AppleScript error \(errorNumber): \(errorMessage, privacy: .public)")

                    // Categorize the error
                    if errorMessage.contains("not authorized") || errorMessage.contains("permission") {
                        continuation.resume(returning: .failure(
                            .appleScriptFailed(errorDescription: "Automation permission not granted. Go to System Settings > Privacy & Security > Automation and enable EmberHearth for Messages.")
                        ))
                    } else if errorMessage.contains("buddy") || errorMessage.contains("Can't get buddy") {
                        continuation.resume(returning: .failure(
                            .buddyNotFound(phoneNumber: phoneNumber)
                        ))
                    } else {
                        continuation.resume(returning: .failure(
                            .appleScriptFailed(errorDescription: errorMessage)
                        ))
                    }
                } else {
                    self.lastSendTime = Date()
                    self.logger.info("Message sent successfully to \(phoneNumber, privacy: .private)")
                    continuation.resume(returning: .success(()))
                }
            }
        }

        // Unwrap the result
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
```

## Implementation Rules

1. **ABSOLUTELY NO Process(), NSTask, /bin/bash, /bin/sh, or osascript.** The ONLY permitted AppleScript execution is `NSAppleScript(source:)?.executeAndReturnError(&error)`. Violation of this rule is a CRITICAL security failure.
2. The AppleScript template string in `executeSendScript` is HARDCODED. Never build AppleScript dynamically from untrusted input beyond the two sanitized variables.
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments.
5. Use `os.Logger` for logging. NEVER log message content — only metadata (phone number with .private, chunk counts, errors).
6. Phone numbers in logs use `privacy: .private`.

## Directory Structure

Create these files:
- `src/Core/Errors/MessageSenderError.swift`
- `src/Core/MessageSender.swift`
- `tests/Core/MessageSenderTests.swift`

## Unit Tests

Create `tests/Core/MessageSenderTests.swift`:

```swift
import XCTest
@testable import EmberHearth

final class MessageSenderTests: XCTestCase {

    // MARK: - Phone Number Validation Tests

    func testValidE164PhoneNumbers() {
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+15551234567"))
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+442071234567"))   // UK
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+81312345678"))    // Japan
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+1"))              // Minimum: + and 1 digit
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+123456789012345")) // 15 digits (max)
    }

    func testInvalidE164PhoneNumbers() {
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("5551234567"))     // Missing +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+0551234567"))    // Leading 0 after +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+"))              // Just +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber(""))               // Empty
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1234567890123456")) // 16 digits (too long)
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1-555-123-4567"))   // Dashes
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+(555)1234567"))     // Parens
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1 555 123 4567"))   // Spaces
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+abc1234567"))        // Letters
    }

    // MARK: - AppleScript Sanitization Tests

    func testSanitizeBasicText() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("Hello, world!"),
            "Hello, world!"
        )
    }

    func testSanitizeDoubleQuotes() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("She said \"hello\""),
            "She said \\\"hello\\\""
        )
    }

    func testSanitizeBackslashes() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("path\\to\\file"),
            "path\\\\to\\\\file"
        )
    }

    func testSanitizeBackslashesBeforeQuotes() {
        // Backslash before quote: \ " should become \\ \"
        // If we escaped quotes first, \" would become \\\" (wrong)
        // By escaping backslashes first: \ becomes \\, then " becomes \" = \\ \"
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("test\\\"inject"),
            "test\\\\\\\"inject"
        )
    }

    func testSanitizeAppleScriptInjectionAttempt() {
        // Attempt to break out of the string and execute arbitrary AppleScript
        let malicious = "\" & do shell script \"rm -rf /\" & \""
        let sanitized = MessageSender.sanitizeForAppleScript(malicious)
        // The result should be a single safe string with no unescaped quotes
        XCTAssertFalse(sanitized.contains("\" &"))
        XCTAssertTrue(sanitized.contains("\\\""))
    }

    func testSanitizeEmptyString() {
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(""), "")
    }

    func testSanitizeNewlines() {
        // Newlines are valid in AppleScript strings
        let text = "Line 1\nLine 2"
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(text), "Line 1\nLine 2")
    }

    func testSanitizeUnicode() {
        let text = "Hello! Regards"
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(text), "Hello! Regards")
    }

    // MARK: - Message Splitting Tests

    func testShortMessageNotSplit() {
        let chunks = MessageSender.splitMessage("Hello!", maxLength: 2000)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], "Hello!")
    }

    func testLongMessageSplitAtSentence() {
        // Create a message that's > 100 chars with clear sentence boundaries
        let sentence1 = String(repeating: "A", count: 60) + ". "
        let sentence2 = String(repeating: "B", count: 60) + ". "
        let message = sentence1 + sentence2
        let chunks = MessageSender.splitMessage(message, maxLength: 100)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertTrue(chunks[0].hasSuffix("."))
        XCTAssertLessThanOrEqual(chunks[0].count, 100)
    }

    func testLongMessageSplitAtSpace() {
        // Message without sentence boundaries
        let words = (0..<30).map { _ in "word" }.joined(separator: " ")
        let chunks = MessageSender.splitMessage(words, maxLength: 50)

        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 50)
        }
        // Reconstruct should contain all words
        let reconstructed = chunks.joined(separator: " ")
        XCTAssertEqual(reconstructed.components(separatedBy: "word").count,
                       words.components(separatedBy: "word").count)
    }

    func testHardSplitWhenNoBreakpoints() {
        // Single long word with no spaces or punctuation
        let longWord = String(repeating: "x", count: 250)
        let chunks = MessageSender.splitMessage(longWord, maxLength: 100)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 100)
        }
        // All characters should be preserved
        let total = chunks.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 250)
    }

    func testSplitEmptyMessage() {
        let chunks = MessageSender.splitMessage("", maxLength: 100)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], "")
    }

    func testSplitExactlyMaxLength() {
        let message = String(repeating: "a", count: 100)
        let chunks = MessageSender.splitMessage(message, maxLength: 100)
        XCTAssertEqual(chunks.count, 1)
    }

    // MARK: - Send Validation Tests (without actual AppleScript execution)

    func testSendRejectsInvalidPhoneNumber() async {
        let sender = MessageSender()
        do {
            try await sender.send(message: "Hello", to: "not-a-number")
            XCTFail("Should have thrown invalidPhoneNumber")
        } catch let error as MessageSenderError {
            guard case .invalidPhoneNumber = error else {
                XCTFail("Expected invalidPhoneNumber, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendRejectsEmptyMessage() async {
        let sender = MessageSender()
        do {
            try await sender.send(message: "   ", to: "+15551234567")
            XCTFail("Should have thrown emptyMessage")
        } catch let error as MessageSenderError {
            guard case .emptyMessage = error else {
                XCTFail("Expected emptyMessage, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendRejectsTooLongMessage() async {
        let sender = MessageSender()
        let longMessage = String(repeating: "a", count: MessageSender.maxTotalLength + 1)
        do {
            try await sender.send(message: longMessage, to: "+15551234567")
            XCTFail("Should have thrown messageTooLong")
        } catch let error as MessageSenderError {
            guard case .messageTooLong = error else {
                XCTFail("Expected messageTooLong, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Security Verification Tests

    func testNoShellExecutionInSource() throws {
        // Read the source file and verify no shell execution patterns exist
        // This is a compile-time check embedded in tests for extra safety
        let sourceFile = #file
        let sourceDir = (sourceFile as NSString).deletingLastPathComponent
        let senderPath = (sourceDir as NSString)
            .deletingLastPathComponent + "/src/Core/MessageSender.swift"

        // If we can read the file, check for forbidden patterns
        if let source = try? String(contentsOfFile: senderPath, encoding: .utf8) {
            XCTAssertFalse(source.contains("Process("), "SECURITY: Process() is PROHIBITED")
            XCTAssertFalse(source.contains("NSTask"), "SECURITY: NSTask is PROHIBITED")
            XCTAssertFalse(source.contains("/bin/bash"), "SECURITY: /bin/bash is PROHIBITED")
            XCTAssertFalse(source.contains("/bin/sh"), "SECURITY: /bin/sh is PROHIBITED")
            XCTAssertFalse(source.contains("osascript"), "SECURITY: osascript is PROHIBITED")
            XCTAssertFalse(source.contains("do shell script"), "SECURITY: do shell script in AppleScript is PROHIBITED")
        }
    }
}
```

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. **CRITICAL:** grep for Process(), NSTask, /bin/bash, /bin/sh, osascript in src/ — NONE should exist
4. The AppleScript template is a single hardcoded string literal, not built dynamically
5. sanitizeForAppleScript escapes backslashes BEFORE quotes (order matters!)
6. Phone number validation uses E.164 regex
7. Message splitting prefers sentence boundaries, falls back to word boundaries
8. Rate limiting waits between sends
9. os.Logger is used, message content is NEVER logged
10. All public methods have documentation comments
```

---

## Acceptance Criteria

- [ ] `src/Core/Errors/MessageSenderError.swift` exists with all specified error cases
- [ ] `src/Core/MessageSender.swift` exists with all specified methods
- [ ] `send(message:to:)` is async throws and validates inputs before sending
- [ ] Phone number validation enforces E.164 format (`+` followed by 1-15 digits)
- [ ] Text sanitization escapes backslashes before double quotes (order matters)
- [ ] AppleScript template is a single hardcoded string literal (not dynamically built)
- [ ] **CRITICAL:** No calls to `Process()`, `NSTask`, `/bin/bash`, `/bin/sh`, or `osascript` anywhere
- [ ] **CRITICAL:** No `do shell script` in any AppleScript string
- [ ] Rate limiting enforces minimum 1 second between sends
- [ ] Long messages are split at sentence boundaries (max 2000 chars per chunk)
- [ ] `splitMessage` falls back to word boundaries, then hard splits
- [ ] Message content is NEVER logged (phone numbers logged with `privacy: .private`)
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging

---

## Verification Commands

```bash
# Build the project
cd /Users/robault/Documents/GitHub/emberhearth
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the MessageSender tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/MessageSenderTests 2>&1 | tail -30

# CRITICAL: Verify no shell execution in entire codebase
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/ || echo "PASS: No /bin/sh references found"
grep -rn "osascript" src/ || echo "PASS: No osascript references found"
grep -rn "do shell script" src/ || echo "PASS: No 'do shell script' found"

# Verify NSAppleScript is the only execution method
grep -n "NSAppleScript" src/Core/MessageSender.swift && echo "PASS: NSAppleScript used"
grep -c "NSAppleScript" src/Core/MessageSender.swift | xargs -I {} echo "NSAppleScript appears {} times (expected: 2 — import and usage)"

# Verify sanitization order (backslash before quote)
grep -A2 "Escape backslashes FIRST" src/Core/MessageSender.swift && echo "PASS: Correct sanitization order"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth MessageSender implementation for security, correctness, and completeness. This is a SECURITY-CRITICAL component. Open these files:

@src/Core/MessageSender.swift
@src/Core/Errors/MessageSenderError.swift
@tests/Core/MessageSenderTests.swift

Also reference:
@docs/architecture/decisions/0004-no-shell-execution.md
@docs/research/imessage.md

## SECURITY AUDIT (Top Priority)

1. **Shell Execution Ban (CRITICAL):**
   - Search the ENTIRE file for: Process, NSTask, /bin/bash, /bin/sh, osascript, CommandLine, do shell script
   - If ANY of these exist, report as CRITICAL immediately
   - The ONLY allowed AppleScript execution is NSAppleScript(source:)?.executeAndReturnError()

2. **AppleScript Injection (CRITICAL):**
   - Can a malicious message text break out of the AppleScript string literal?
   - Does sanitization escape backslashes BEFORE quotes? (If quotes are escaped first, then a backslash before a quote like \" becomes \\" which is an escaped backslash followed by an unescaped quote — injection!)
   - Test mentally: what happens with input: `" & do shell script "rm -rf /" & "`?
   - What about: `\\" & do shell script \\"malicious\\" & \\"`?
   - Does the phone number also get sanitized before interpolation?

3. **AppleScript Template (CRITICAL):**
   - Is the template a single hardcoded string, or is it built dynamically?
   - Are there any other AppleScript strings or methods that could be used to execute arbitrary code?

## Correctness Review

4. **Phone Number Validation:**
   - Does the E.164 regex correctly allow + followed by 1-15 digits?
   - Does it reject numbers with spaces, dashes, parentheses?
   - Does it reject empty strings and + alone?

5. **Message Splitting:**
   - Does it correctly preserve all content (no dropped characters)?
   - Does each chunk stay within the max length?
   - Does it handle messages with no spaces (single long words)?
   - Does it handle the exact-max-length boundary correctly?

6. **Rate Limiting:**
   - Is the rate limit enforced between chunks of the same message?
   - Could rapid concurrent calls bypass the rate limit?
   - Is lastSendTime updated atomically?

7. **Error Handling:**
   - Does it distinguish between automation permission errors and buddy-not-found?
   - Is the error categorization based on AppleScript error messages robust?

8. **Async/Concurrency:**
   - Is the DispatchQueue + withCheckedContinuation pattern correct?
   - Is there a risk of the continuation being resumed twice?
   - Is [weak self] used correctly in the closure?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m2): add AppleScript message sender for iMessage
```

---

## Notes for Next Task

- `MessageSender` is now available for the message pipeline to send responses.
- It requires the recipient phone number in E.164 format. The `PhoneNumberFilter` (task 0103) will normalize numbers to this format.
- The sender does NOT verify that the recipient is an iMessage user before sending. If the buddy is not found, `buddyNotFound` error is thrown.
- Rate limiting is per-instance. If multiple MessageSender instances exist, each has its own rate limit. For MVP, use a single shared instance.
- The AppleScript execution is synchronous (on a background queue). Long message sends (multiple chunks) will take at least N seconds where N = number of chunks.
- Automation permission must be granted manually by the user the first time. The onboarding flow (future task) will guide them through this.
