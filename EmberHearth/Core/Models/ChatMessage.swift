import Foundation

/// Represents a single message read from the iMessage chat.db database.
/// This is a read-only data model — EmberHearth never writes to chat.db.
struct ChatMessage: Identifiable, Equatable, Sendable {
    /// The ROWID from the message table in chat.db. Used for tracking
    /// which messages have already been processed.
    let id: Int64

    /// The message text content. May be nil for attachment-only messages
    /// or if the text could not be decoded from attributedBody.
    let text: String?

    /// When the message was sent or received. Converted from Apple's
    /// Core Data timestamp format (nanoseconds since 2001-01-01 00:00:00 UTC).
    let date: Date

    /// True if this message was sent by the local user, false if received.
    let isFromMe: Bool

    /// The ROWID of the handle (contact) in the handle table.
    let handleId: Int64

    /// The phone number or email address of the other party.
    /// Phone numbers are in E.164 format (e.g., "+15551234567").
    /// May be nil if the handle could not be resolved.
    let phoneNumber: String?

    /// True if this message belongs to a group chat.
    /// Group chats are detected by checking cache_roomnames on the message
    /// or group_id on the associated chat.
    let isGroupChat: Bool

    /// The chat_id from chat_message_join, linking this message to a conversation thread.
    let chatId: Int64?
}
