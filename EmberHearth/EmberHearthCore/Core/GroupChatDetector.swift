import Foundation
import os.log

/// Policy for how EmberHearth handles group chat messages.
///
/// In MVP, only `.block` is supported. Future versions may allow read-only
/// monitoring or full social mode participation.
enum GroupChatPolicy: String, Codable, CaseIterable {
    /// Silently ignore all group chat messages. No response is sent.
    /// This is the only supported mode in MVP.
    case block

    /// Monitor group chats for context (read messages) but never respond.
    /// Future feature — not implemented in MVP.
    case readOnly

    /// Participate in group chats with social awareness.
    /// Responds when mentioned by name, maintains group context.
    /// Future feature — not implemented in MVP.
    case socialMode

    /// Human-readable description of the policy.
    var displayName: String {
        switch self {
        case .block:
            return "Block (silent ignore)"
        case .readOnly:
            return "Read Only (monitor, no responses)"
        case .socialMode:
            return "Social Mode (participate in group chats)"
        }
    }
}

/// Abstraction for checking whether a chat is a group chat at the database level.
///
/// `ChatDatabaseReader` conforms to this protocol. Tests can provide a mock
/// implementation to exercise the secondary detection path without a real database.
protocol GroupChatChecking {
    /// Checks whether a specific chat is a group chat by examining chat-level
    /// signals (group_id, participant count).
    ///
    /// - Parameter chatId: The chat ROWID from the chat table.
    /// - Returns: True if the chat is a group chat.
    /// - Throws: `ChatDatabaseError` if the query fails.
    func isGroupChat(chatId: Int64) throws -> Bool
}

extension ChatDatabaseReader: GroupChatChecking {}

/// Detects group chat messages and filters them based on the configured policy.
///
/// In MVP, all group chat messages are silently ignored (`.block` policy).
/// The detector checks the `isGroupChat` property on `ChatMessage`, which is
/// derived from the `cache_roomnames` column in chat.db.
///
/// For additional verification (e.g., when `cache_roomnames` is unexpectedly null
/// for a group chat), the detector can optionally query a `GroupChatChecking`
/// conformer (typically `ChatDatabaseReader`) for deeper checks using the `chatId`.
///
/// ## Thread Safety
/// This class is **not** thread-safe. All calls must be made from the same
/// serial context (e.g., the `MessageWatcher` poll loop). If concurrent access
/// is needed in the future, wrap the instance in an actor or protect mutable
/// state with a lock.
///
/// ## Usage
/// ```swift
/// let detector = GroupChatDetector()
///
/// let messages: [ChatMessage] = watcher.getNewMessages()
/// let directMessages = detector.filterDirectMessages(messages)
/// // directMessages contains only 1-on-1 conversations
/// ```
final class GroupChatDetector {

    // MARK: - Properties

    /// The current group chat policy. Defaults to `.block` for MVP.
    /// Persisted in UserDefaults. Unrecognized stored values fall back to `.block`.
    var policy: GroupChatPolicy {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Self.policyKey),
               let policy = GroupChatPolicy(rawValue: rawValue) {
                return policy
            }
            return .block
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.policyKey)
            logger.info("Group chat policy changed to: \(newValue.rawValue, privacy: .public)")
        }
    }

    /// Optional checker for deeper group chat verification.
    /// If provided, the detector can check chat-level signals when the
    /// message-level signal is ambiguous.
    private let groupChatChecker: GroupChatChecking?

    /// Logger for group chat detection events.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "GroupChatDetector")

    /// UserDefaults key for the group chat policy.
    private static let policyKey = "com.emberhearth.groupchatdetector.policy"

    /// Number of group chat messages blocked in the current session.
    ///
    /// Not thread-safe — only read/write from a single serial context.
    private(set) var blockedMessageCount: Int = 0

    // MARK: - Initialization

    /// Creates a new GroupChatDetector.
    ///
    /// - Parameter groupChatChecker: Optional `GroupChatChecking` conformer for
    ///   deeper group chat verification. If nil, only the message-level
    ///   `isGroupChat` property is used. In production, pass the same
    ///   `ChatDatabaseReader` used by the `MessageWatcher`.
    init(groupChatChecker: GroupChatChecking? = nil) {
        self.groupChatChecker = groupChatChecker
    }

    // MARK: - Detection

    /// Determines whether a message belongs to a group chat.
    ///
    /// Uses an OR-based strategy: if *either* signal indicates a group chat,
    /// the message is treated as one. This favors blocking over accidentally
    /// responding in a group thread, which is the safer default for an
    /// always-on assistant. The trade-off is a small theoretical risk of
    /// false-positives from the secondary signal; in practice this is
    /// negligible because `chat_handle_join` participant counts are reliable.
    ///
    /// **Primary signal:** `ChatMessage.isGroupChat`, derived from
    /// `cache_roomnames` (and `group_id`) at query time in `ChatDatabaseReader`.
    ///
    /// **Secondary signal (optional):** If a `GroupChatChecking` conformer is
    /// available and the message has a `chatId`, a deeper check is performed
    /// using participant count. This catches the rare case where
    /// `cache_roomnames` and `group_id` are both null but the chat has
    /// multiple participants.
    ///
    /// If the secondary check throws, the error is logged and the detector
    /// falls back to the primary signal only (does **not** block).
    ///
    /// - Parameter message: The message to check.
    /// - Returns: True if the message belongs to a group chat.
    func isGroupChat(_ message: ChatMessage) -> Bool {
        if message.isGroupChat {
            logger.info("Group chat detected (primary signal) for message \(message.id)")
            return true
        }

        if let chatId = message.chatId, let checker = groupChatChecker {
            do {
                let isGroup = try checker.isGroupChat(chatId: chatId)
                if isGroup {
                    logger.info("Group chat detected (secondary signal) for message \(message.id), chatId: \(chatId)")
                    return true
                }
            } catch {
                logger.warning("Secondary group chat check failed, relying on primary signal only: \(error.localizedDescription, privacy: .public)")
            }
        }

        return false
    }

    // MARK: - Filtering

    /// Filters an array of messages, returning only direct (non-group) messages.
    ///
    /// This method **always** removes group chat messages from the returned
    /// array regardless of the current policy. The policy controls how
    /// removed messages are *handled* (logged, stored for context, etc.),
    /// not whether they are filtered. Use ``shouldProcess(_:)`` when you
    /// need policy-aware per-message decisions without bulk filtering.
    ///
    /// The number of filtered messages is tracked in ``blockedMessageCount``.
    /// Order of direct messages in the input is preserved in the output.
    ///
    /// - Parameter messages: The messages to filter.
    /// - Returns: Only the messages that are NOT from group chats.
    func filterDirectMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var directMessages: [ChatMessage] = []
        var groupCount = 0

        for message in messages {
            if isGroupChat(message) {
                groupCount += 1
                handleGroupChatMessage(message)
            } else {
                directMessages.append(message)
            }
        }

        if groupCount > 0 {
            blockedMessageCount += groupCount
            logger.info("Filtered \(groupCount) group chat message(s). Total blocked this session: \(self.blockedMessageCount)")
        }

        return directMessages
    }

    /// Determines whether a message should be processed based on the current policy.
    ///
    /// - Parameter message: The message to evaluate.
    /// - Returns: True if the message should be processed (responded to).
    func shouldProcess(_ message: ChatMessage) -> Bool {
        if isGroupChat(message) {
            switch policy {
            case .block:
                return false
            case .readOnly:
                // Future: allow reading but not responding
                return false
            case .socialMode:
                // Future: allow full participation
                return true
            }
        }
        return true  // Direct messages are always processed
    }

    /// Resets the blocked message counter. Called at the start of a new session
    /// or for diagnostics.
    func resetBlockedCount() {
        blockedMessageCount = 0
    }

    // MARK: - Private

    /// Handles a group chat message according to the current policy.
    /// In MVP (.block), this is a no-op beyond logging.
    private func handleGroupChatMessage(_ message: ChatMessage) {
        switch policy {
        case .block:
            // Silent ignore — no response, just log
            logger.info("Blocked group chat message \(message.id) from \(message.phoneNumber ?? "unknown", privacy: .private)")
        case .readOnly:
            // Future: store for context without responding
            logger.info("Read-only group chat message \(message.id)")
        case .socialMode:
            // Future: process for social participation
            logger.info("Social mode group chat message \(message.id)")
        }
    }
}
