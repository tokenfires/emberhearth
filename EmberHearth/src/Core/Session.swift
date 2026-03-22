// Session.swift
// EmberHearth
//
// Data models for conversation sessions and messages.

import Foundation

/// Represents a conversation session with a user.
///
/// A session starts when a user sends a message and no active session exists.
/// Sessions become "stale" after a configurable inactivity period (default: 4 hours).
/// Stale sessions are automatically ended and a new session is started.
struct Session: Identifiable, Equatable {

    /// Unique database identifier.
    let id: Int64

    /// The phone number of the user (E.164 format, e.g., "+15551234567").
    let phoneNumber: String

    /// When this session started.
    let startedAt: Date

    /// When this session ended. nil if the session is still active.
    var endedAt: Date?

    /// A brief summary of the conversation. Generated when the session ends.
    /// nil for active sessions (summary generation is added in M5).
    var summary: String?

    /// Number of messages in this session (user + assistant combined).
    var messageCount: Int

    /// Whether this session is currently active.
    var isActive: Bool
}

/// Represents a single message within a conversation session.
struct SessionMessage: Identifiable, Equatable {

    /// Unique database identifier.
    let id: Int64

    /// The session this message belongs to.
    let sessionId: Int64

    /// The role of the message sender.
    let role: LLMRole

    /// The text content of the message.
    let content: String

    /// When this message was sent/received.
    let timestamp: Date

    /// Estimated token count for this message (used for context window management).
    /// nil if not yet calculated.
    var tokenCount: Int?
}

