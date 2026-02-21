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
