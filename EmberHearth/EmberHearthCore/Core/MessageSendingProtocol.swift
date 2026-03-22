// MessageSendingProtocol.swift
// EmberHearth
//
// Protocol for iMessage sending, enabling dependency injection for testing.

import Foundation

/// Abstraction over iMessage sending, enabling dependency injection and testing.
///
/// The primary conforming type is `MessageSender`, which uses AppleScript.
/// Tests use a mock conforming type that records sent messages without AppleScript.
protocol MessageSendingProtocol {

    /// Sends a text message to a phone number via iMessage.
    ///
    /// - Parameters:
    ///   - message: The text to send. Must not be empty.
    ///   - phoneNumber: The recipient in E.164 format (e.g., "+15551234567").
    /// - Throws: A `MessageSenderError` if the message cannot be sent.
    func send(message: String, to phoneNumber: String) async throws
}
