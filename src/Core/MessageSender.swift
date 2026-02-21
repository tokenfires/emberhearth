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
final class MessageSender: @unchecked Sendable {

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
    /// Only accessed from `sendQueue` to prevent data races.
    private var lastSendTime: Date?

    /// Serial queue for synchronizing send operations and protecting `lastSendTime`.
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
        guard Self.isValidE164PhoneNumber(phoneNumber) else {
            logger.error("Invalid phone number format: \(phoneNumber, privacy: .private)")
            throw MessageSenderError.invalidPhoneNumber(number: phoneNumber)
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            logger.error("Attempted to send empty message")
            throw MessageSenderError.emptyMessage
        }

        guard trimmedMessage.count <= Self.maxTotalLength else {
            logger.error("Message too long: \(trimmedMessage.count) chars (max: \(Self.maxTotalLength))")
            throw MessageSenderError.messageTooLong(
                length: trimmedMessage.count,
                maxLength: Self.maxTotalLength
            )
        }

        let chunks = Self.splitMessage(trimmedMessage, maxLength: Self.maxChunkLength)

        logger.info("Sending \(chunks.count) chunk(s) to \(phoneNumber, privacy: .private)")

        for (index, chunk) in chunks.enumerated() {
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
        let pattern = #"^\+[1-9]\d{0,14}$"#
        return number.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Text Sanitization

    /// Sanitizes a message string for safe interpolation into an AppleScript template.
    ///
    /// AppleScript strings are delimited by double quotes. We must escape:
    /// - Backslashes (\) — doubled to \\
    /// - Double quotes (") — escaped to \"
    ///
    /// **Order matters:** Backslashes are escaped first so that the backslashes
    /// introduced by quote-escaping are not themselves doubled.
    ///
    /// - Parameter text: The raw message text.
    /// - Returns: The sanitized text safe for AppleScript string interpolation.
    static func sanitizeForAppleScript(_ text: String) -> String {
        var sanitized = text
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
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

            let endIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
            let window = remaining[remaining.startIndex..<endIndex]

            var splitIndex: String.Index?

            let sentenceEnders: [Character] = [".", "!", "?"]
            var searchIndex = window.index(before: window.endIndex)
            while searchIndex > window.startIndex {
                let char = window[searchIndex]
                if sentenceEnders.contains(char) {
                    let nextIndex = window.index(after: searchIndex)
                    if nextIndex == window.endIndex || window[nextIndex] == " " {
                        splitIndex = window.index(after: searchIndex)
                        break
                    }
                }
                searchIndex = window.index(before: searchIndex)

                if window.distance(from: window.startIndex, to: searchIndex) < maxLength / 2 {
                    break
                }
            }

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

    /// Executes the AppleScript to send a single message.
    ///
    /// This is the ONLY method that executes AppleScript. The template is hardcoded.
    /// Only the phone number and sanitized message text are interpolated.
    ///
    /// Rate limiting and `lastSendTime` are managed entirely within `sendQueue`
    /// to prevent data races under concurrent callers.
    ///
    /// - Parameters:
    ///   - message: The message text (will be sanitized).
    ///   - phoneNumber: The E.164 phone number (already validated).
    /// - Throws: `MessageSenderError` if the AppleScript execution fails.
    private func executeSendScript(message: String, to phoneNumber: String) async throws {
        let sanitizedMessage = Self.sanitizeForAppleScript(message)
        let sanitizedPhoneNumber = Self.sanitizeForAppleScript(phoneNumber)

        // HARDCODED AppleScript template — DO NOT make this dynamic.
        let scriptSource = """
            tell application "Messages"
                set targetBuddy to buddy "\(sanitizedPhoneNumber)" of service "iMessage"
                send "\(sanitizedMessage)" to targetBuddy
            end tell
            """

        let rateLimitInterval = Self.rateLimitInterval
        let logger = self.logger

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sendQueue.async { [self] in
                // Rate limiting inside the serial queue prevents concurrent callers
                // from bypassing the interval check.
                if let lastSend = self.lastSendTime {
                    let elapsed = Date().timeIntervalSince(lastSend)
                    if elapsed < rateLimitInterval {
                        let waitTime = rateLimitInterval - elapsed
                        logger.debug("Rate limiting: waiting \(waitTime, format: .fixed(precision: 2))s")
                        Thread.sleep(forTimeInterval: waitTime)
                    }
                }

                var errorDict: NSDictionary?
                let script = NSAppleScript(source: scriptSource)
                script?.executeAndReturnError(&errorDict)

                if let errorDict = errorDict {
                    let errorNumber = errorDict[NSAppleScript.errorNumber] as? Int ?? -1
                    let errorMessage = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"

                    logger.error("AppleScript error \(errorNumber): \(errorMessage, privacy: .public)")

                    let senderError = Self.categorizeAppleScriptError(
                        errorNumber: errorNumber,
                        errorMessage: errorMessage,
                        phoneNumber: phoneNumber
                    )
                    continuation.resume(throwing: senderError)
                } else {
                    self.lastSendTime = Date()
                    logger.info("Message sent successfully to \(phoneNumber, privacy: .private)")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Error Categorization

    /// Maps an AppleScript error to a `MessageSenderError`.
    ///
    /// Uses `errorNumber` as the primary signal with message text as a fallback,
    /// since error numbers are stable across macOS versions while messages may change.
    private static func categorizeAppleScriptError(
        errorNumber: Int,
        errorMessage: String,
        phoneNumber: String
    ) -> MessageSenderError {
        // -1743: user cancelled / not authorized (Automation permission)
        // -1744: permission denied
        if errorNumber == -1743 || errorNumber == -1744
            || errorMessage.localizedCaseInsensitiveContains("not authorized")
            || errorMessage.localizedCaseInsensitiveContains("permission") {
            return .automationPermissionDenied
        }

        // -1728: Can't get <reference> (buddy not found)
        if errorNumber == -1728
            || errorMessage.localizedCaseInsensitiveContains("buddy") {
            return .buddyNotFound(phoneNumber: phoneNumber)
        }

        return .appleScriptFailed(errorDescription: errorMessage)
    }
}
