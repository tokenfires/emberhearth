import Foundation

/// Errors that can occur when sending messages via AppleScript.
enum MessageSenderError: LocalizedError {
    /// The phone number is not in valid E.164 format.
    case invalidPhoneNumber(number: String)

    /// The message text is empty after trimming whitespace.
    case emptyMessage

    /// The message exceeds the maximum allowed length.
    case messageTooLong(length: Int, maxLength: Int)

    /// The AppleScript execution failed with an unrecognized error.
    case appleScriptFailed(errorDescription: String)

    /// The user has not granted Automation permission for Messages.app.
    case automationPermissionDenied

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
        case .appleScriptFailed(let description):
            return "Failed to send message via AppleScript: \(description)"
        case .automationPermissionDenied:
            return "Automation permission not granted. Go to System Settings > Privacy & Security > Automation and enable EmberHearth for Messages."
        case .buddyNotFound(let phoneNumber):
            return "Could not find '\(phoneNumber)' in Messages. Ensure this contact uses iMessage."
        }
    }
}
