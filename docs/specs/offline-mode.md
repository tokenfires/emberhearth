# Offline Mode Specification

**Version:** 1.0
**Date:** February 5, 2026
**Status:** Pre-Implementation
**Depends On:** `specs/autonomous-operation.md`

---

## Overview

When internet connectivity is unavailable, EmberHearth must handle user messages gracefully. Users should never send a message and receive nothing—that's a broken experience that erodes trust.

> **Core Principle:** Acknowledge immediately, explain simply, recover automatically.

---

## Part 1: Detection and States

### 1.1 Connectivity States

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONNECTIVITY STATES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ONLINE ────────(network fails)─────────► DEGRADED              │
│    ▲                                          │                 │
│    │                                    (LLM unreachable)       │
│    │                                          │                 │
│    │                                          ▼                 │
│    └────────(LLM responds)──────────────── OFFLINE              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

| State | Network | LLM API | User Experience |
|-------|---------|---------|-----------------|
| **ONLINE** | Available | Responding | Full functionality |
| **DEGRADED** | Available | Slow/Errors | Slower responses, may retry |
| **OFFLINE** | Unavailable OR LLM down | Unreachable | Acknowledgment + queue |

### 1.2 Detection Mechanism

```swift
class ConnectivityMonitor {
    private let networkMonitor = NWPathMonitor()
    private var llmLastSuccess: Date?
    private var consecutiveLLMFailures = 0

    enum State {
        case online
        case degraded(reason: DegradedReason)
        case offline(reason: OfflineReason)
    }

    enum DegradedReason {
        case llmSlow           // Response time > 10 seconds
        case llmRateLimited    // 429 responses
        case networkUnstable   // Intermittent connectivity
    }

    enum OfflineReason {
        case noNetwork         // NWPathMonitor reports no connectivity
        case llmUnreachable    // 4+ consecutive failures
        case apiKeyInvalid     // 401/403 responses
    }

    var currentState: State {
        // No network = offline
        if !networkMonitor.currentPath.status == .satisfied {
            return .offline(reason: .noNetwork)
        }

        // Too many LLM failures = offline
        if consecutiveLLMFailures >= 4 {
            return .offline(reason: .llmUnreachable)
        }

        // Some failures but recovering = degraded
        if consecutiveLLMFailures > 0 {
            return .degraded(reason: .llmSlow)
        }

        return .online
    }
}
```

### 1.3 State Transitions

```swift
extension ConnectivityMonitor {
    func recordLLMSuccess() {
        llmLastSuccess = Date()
        consecutiveLLMFailures = 0
        // Transition: degraded/offline → online
        notifyStateChange(.online)
    }

    func recordLLMFailure(_ error: LLMError) {
        consecutiveLLMFailures += 1

        switch error {
        case .rateLimited:
            notifyStateChange(.degraded(reason: .llmRateLimited))
        case .timeout:
            if consecutiveLLMFailures >= 4 {
                notifyStateChange(.offline(reason: .llmUnreachable))
            } else {
                notifyStateChange(.degraded(reason: .llmSlow))
            }
        case .unauthorized:
            notifyStateChange(.offline(reason: .apiKeyInvalid))
        default:
            // Generic error handling
            if consecutiveLLMFailures >= 4 {
                notifyStateChange(.offline(reason: .llmUnreachable))
            }
        }
    }
}
```

---

## Part 2: Message Queue System

### 2.1 Queue Architecture

When offline, messages are stored locally and processed when connectivity returns.

```
┌─────────────────────────────────────────────────────────────────┐
│                       MESSAGE QUEUE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Incoming Message]                                             │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ Online?     │──── YES ────► [Process Normally]               │
│  └─────────────┘                                                │
│         │                                                       │
│        NO                                                       │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────────────┐                                        │
│  │ Add to Queue        │                                        │
│  │ • Message content   │                                        │
│  │ • Sender            │                                        │
│  │ • Timestamp         │                                        │
│  │ • Priority          │                                        │
│  └─────────────────────┘                                        │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────────────┐                                        │
│  │ Send Acknowledgment │                                        │
│  └─────────────────────┘                                        │
│                                                                 │
│  ════════════════════════════════════════════════════════════   │
│                                                                 │
│  [Connectivity Restored]                                        │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────────────┐                                        │
│  │ Process Queue       │──► Oldest first (FIFO)                 │
│  │ with delay context  │──► Add "sorry for delay" prefix        │
│  └─────────────────────┘──► Clear from queue after success      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Queue Data Model

```sql
CREATE TABLE message_queue (
    id INTEGER PRIMARY KEY,
    message_id TEXT NOT NULL UNIQUE,      -- From chat.db
    sender TEXT NOT NULL,                  -- Phone/email
    content TEXT NOT NULL,
    received_at TEXT NOT NULL,             -- ISO 8601
    priority INTEGER NOT NULL DEFAULT 1,   -- 1=normal, 2=high, 3=urgent
    acknowledged BOOLEAN NOT NULL DEFAULT 0,
    processed BOOLEAN NOT NULL DEFAULT 0,
    process_attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TEXT,
    error_message TEXT
);

CREATE INDEX idx_queue_unprocessed ON message_queue(processed, received_at);
```

### 2.3 Queue Configuration

```swift
struct QueueConfig {
    // Capacity limits
    static let maxQueueSize = 100           // Max pending messages
    static let maxMessageAge = 24 * 60 * 60 // 24 hours in seconds

    // Processing behavior
    static let batchSize = 5                // Process N messages at a time
    static let delayBetweenBatch = 2.0      // Seconds between batches
    static let maxProcessAttempts = 3       // Retry failed processing

    // Acknowledgment timing
    static let ackDelaySeconds = 2.0        // Wait before sending ack
    static let ackCooldownSeconds = 300.0   // 5 min between acks to same user
}
```

### 2.4 Priority Classification

```swift
enum MessagePriority: Int {
    case normal = 1
    case high = 2
    case urgent = 3

    static func classify(_ message: IncomingMessage) -> MessagePriority {
        let content = message.content.lowercased()

        // Urgent: Time-sensitive or emergency indicators
        if content.contains("urgent") ||
           content.contains("emergency") ||
           content.contains("asap") ||
           content.contains("right now") ||
           content.contains("immediately") {
            return .urgent
        }

        // High: Questions expecting quick response
        if content.hasSuffix("?") ||
           content.contains("when") ||
           content.contains("where") ||
           content.contains("can you") {
            return .high
        }

        return .normal
    }
}
```

---

## Part 3: Acknowledgment System

### 3.1 Acknowledgment Philosophy

> **Goal:** Let the user know Ember heard them, without being annoying.

**Rules:**
- Always acknowledge the first message when going offline
- Don't spam acknowledgments for rapid follow-up messages
- Be honest about the situation without being technical
- Give a realistic time expectation when possible

### 3.2 Acknowledgment Templates

```swift
struct OfflineAcknowledgment {
    enum Template {
        case firstMessage
        case followUp
        case urgentMessage
        case prolongedOutage
        case apiKeyIssue

        var message: String {
            switch self {
            case .firstMessage:
                return """
                Got your message! I'm having a bit of trouble connecting \
                right now, but I'll respond as soon as I can. Shouldn't be long!
                """

            case .followUp:
                return """
                Still got you! I'll catch up on everything once I'm back online.
                """

            case .urgentMessage:
                return """
                I can see this is urgent! I'm having connection issues but \
                your message is at the top of my list. I'll respond the \
                moment I'm back.
                """

            case .prolongedOutage:
                return """
                I've been offline for a while now. Your messages are saved \
                and I'll work through them as soon as I can connect again. \
                Sorry for the delay!
                """

            case .apiKeyIssue:
                return """
                I'm having trouble with my AI connection. This might need \
                your help to fix—check the EmberHearth app on your Mac \
                when you get a chance.
                """
            }
        }
    }

    static func select(
        for message: IncomingMessage,
        queueState: QueueState,
        offlineReason: OfflineReason
    ) -> Template {
        // API key issues need special handling
        if case .apiKeyInvalid = offlineReason {
            return .apiKeyIssue
        }

        // Prolonged outage (> 1 hour)
        if queueState.offlineDuration > 3600 {
            return .prolongedOutage
        }

        // Urgent message
        if MessagePriority.classify(message) == .urgent {
            return .urgentMessage
        }

        // Follow-up (already acked recently to this sender)
        if queueState.recentlyAcknowledged(sender: message.sender) {
            return .followUp
        }

        return .firstMessage
    }
}
```

### 3.3 Acknowledgment Rate Limiting

```swift
class AcknowledgmentManager {
    private var lastAckBySender: [String: Date] = [:]

    func shouldSendAck(to sender: String) -> Bool {
        guard let lastAck = lastAckBySender[sender] else {
            return true // Never acked this sender
        }

        let cooldown = QueueConfig.ackCooldownSeconds
        return Date().timeIntervalSince(lastAck) > cooldown
    }

    func recordAck(to sender: String) {
        lastAckBySender[sender] = Date()
    }

    func sendAcknowledgment(
        for message: IncomingMessage,
        template: OfflineAcknowledgment.Template
    ) async throws {
        // Only send if not rate-limited
        guard shouldSendAck(to: message.sender) else {
            Logger.log(.offline, "Skipping ack to \(message.sender) - cooldown")
            return
        }

        // Small delay to avoid appearing robotic
        try await Task.sleep(nanoseconds: UInt64(QueueConfig.ackDelaySeconds * 1_000_000_000))

        // Send via Messages
        try await MessageSender.send(
            text: template.message,
            to: message.sender
        )

        recordAck(to: message.sender)
        Logger.log(.offline, "Sent ack to \(message.sender): \(template)")
    }
}
```

---

## Part 4: Recovery and Catch-Up

### 4.1 Recovery Detection

```swift
class RecoveryHandler {
    func onConnectivityRestored() async {
        Logger.log(.offline, "Connectivity restored, processing queue")

        // Notify user we're back (if they're waiting)
        await notifyRecovery()

        // Process queued messages
        await processQueue()
    }

    private func notifyRecovery() async {
        let queue = MessageQueue.shared

        // If we have pending messages, notify the most recent sender
        if let mostRecent = queue.mostRecentPending() {
            let wasLongOutage = queue.offlineDuration > 3600 // 1 hour

            if wasLongOutage {
                try? await MessageSender.send(
                    text: "I'm back online! Let me catch up on what I missed...",
                    to: mostRecent.sender
                )
            }
        }
    }
}
```

### 4.2 Queue Processing

```swift
extension RecoveryHandler {
    func processQueue() async {
        let queue = MessageQueue.shared
        var processed = 0

        while let batch = queue.nextBatch(size: QueueConfig.batchSize) {
            for message in batch {
                do {
                    try await processQueuedMessage(message)
                    queue.markProcessed(message.id)
                    processed += 1
                } catch {
                    queue.recordFailure(message.id, error: error)

                    // Skip after max attempts
                    if message.processAttempts >= QueueConfig.maxProcessAttempts {
                        queue.markFailed(message.id)
                        Logger.log(.offline, "Giving up on message \(message.id)")
                    }
                }
            }

            // Pause between batches to avoid overwhelming
            try? await Task.sleep(nanoseconds: UInt64(QueueConfig.delayBetweenBatch * 1_000_000_000))
        }

        Logger.log(.offline, "Processed \(processed) queued messages")
    }

    private func processQueuedMessage(_ message: QueuedMessage) async throws {
        let delay = Date().timeIntervalSince(message.receivedAt)

        // Build context with delay information
        var context = ConversationContext.forUser(message.sender)

        if delay > 3600 { // More than 1 hour
            context.addSystemNote(
                "This message arrived \(formatDelay(delay)) ago while I was offline."
            )
        }

        // Process normally
        let response = try await LLMService.shared.complete(
            userMessage: message.content,
            context: context
        )

        // Add delay acknowledgment to response if significant delay
        let finalResponse: String
        if delay > 3600 {
            finalResponse = "Sorry for the delay! " + response
        } else if delay > 600 { // 10 minutes
            finalResponse = response // Just respond normally for short delays
        } else {
            finalResponse = response
        }

        // Send response
        try await MessageSender.send(text: finalResponse, to: message.sender)
    }

    private func formatDelay(_ seconds: TimeInterval) -> String {
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = Int(seconds / 86400)
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
}
```

### 4.3 Queue Cleanup

```swift
extension MessageQueue {
    /// Remove stale messages that are too old to be relevant
    func cleanupStale() {
        let cutoff = Date().addingTimeInterval(-Double(QueueConfig.maxMessageAge))

        let stale = pendingMessages.filter { $0.receivedAt < cutoff }

        for message in stale {
            // Send apologetic notification
            Task {
                try? await MessageSender.send(
                    text: "I'm sorry—I was offline for a while and this message " +
                          "got too old for me to respond helpfully. What can I " +
                          "help you with now?",
                    to: message.sender
                )
            }

            markExpired(message.id)
        }

        if !stale.isEmpty {
            Logger.log(.offline, "Cleaned up \(stale.count) stale messages")
        }
    }
}
```

---

## Part 5: Offline Capabilities

### 5.1 What Works Offline

Even without LLM connectivity, some functionality can work:

| Capability | Offline Support | Notes |
|------------|-----------------|-------|
| **Receive messages** | ✅ Yes | Queued for later |
| **Send acknowledgments** | ✅ Yes | Pre-written templates |
| **Access local memory** | ✅ Yes | SQLite is local |
| **Basic pattern responses** | ✅ Limited | Time, date, simple queries |
| **Full AI responses** | ❌ No | Requires LLM |
| **Calendar queries** | ✅ Yes | EventKit is local |
| **Reminder creation** | ✅ Yes | EventKit is local |
| **Contact lookup** | ✅ Yes | Contacts is local |

### 5.2 Offline Pattern Responses

For very simple queries, Ember can respond without LLM:

```swift
struct OfflinePatternMatcher {
    static func match(_ message: String) -> String? {
        let lowered = message.lowercased().trimmingCharacters(in: .whitespaces)

        // Time queries
        if lowered == "what time is it" || lowered == "what's the time" {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "It's \(formatter.string(from: Date()))."
        }

        // Date queries
        if lowered == "what day is it" || lowered == "what's today's date" {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            return "Today is \(formatter.string(from: Date()))."
        }

        // Status queries
        if lowered.contains("are you there") || lowered == "hello" || lowered == "hi" {
            return nil // Let the offline ack system handle greetings
        }

        return nil // No pattern match, queue for LLM
    }
}
```

### 5.3 Local-Only Operations

Some operations can complete fully offline:

```swift
class OfflineCapableOperations {
    /// Check if operation can run offline
    static func canRunOffline(_ operation: Operation) -> Bool {
        switch operation {
        case .calendarQuery, .calendarCreate:
            return true // EventKit is local
        case .reminderCreate, .reminderQuery:
            return true // EventKit is local
        case .contactLookup:
            return true // Contacts is local
        case .memoryQuery, .memoryStore:
            return true // SQLite is local
        case .conversationalResponse:
            return false // Needs LLM
        case .webSearch, .webFetch:
            return false // Needs network
        }
    }

    /// Execute operation locally if possible
    static func executeOffline(_ operation: Operation) async throws -> OperationResult {
        guard canRunOffline(operation) else {
            throw OfflineError.operationRequiresNetwork
        }

        switch operation {
        case .calendarQuery(let query):
            let events = try await CalendarService.shared.query(query)
            return .calendar(events)

        case .reminderCreate(let reminder):
            try await ReminderService.shared.create(reminder)
            return .success("Reminder set!")

        // ... etc
        }
    }
}
```

---

## Part 6: User Communication

### 6.1 Ember's Voice When Offline

Ember should communicate about connectivity issues naturally:

**User asks:** "Are you there?"
**Ember (offline ack):** "I'm here! Having a bit of trouble connecting to my brain right now, but I'll respond properly soon."

**User asks (after recovery):** "What happened?"
**Ember:** "I was offline for about 20 minutes—probably an internet hiccup. But I'm back now and caught up on your messages!"

### 6.2 Status Visibility

Users can ask about Ember's status:

**User:** "Ember, status?"
**Ember (online):** "All systems go! I'm connected and ready to help."
**Ember (degraded):** "I'm running a bit slow right now—responses might take a few extra seconds."
**Ember (offline):** "I'm having trouble connecting. Your messages are saved and I'll respond when I'm back."

### 6.3 Mac App Indicator

The menu bar icon reflects connectivity status:

```
Online:     🔥 Ember (green dot)
Degraded:   🔥 Ember (yellow dot)
Offline:    🔥 Ember (red dot, "Offline")
```

Settings → Status shows detailed info:
```
┌─────────────────────────────────────────────────────────────┐
│  Connection Status                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Status: Offline                                            │
│  Since: 2:45 PM (15 minutes ago)                            │
│  Reason: Cannot reach AI service                            │
│                                                             │
│  Queued Messages: 3                                         │
│  • From: Mom (2:47 PM)                                      │
│  • From: Work Group (2:50 PM)                               │
│  • From: Mom (2:52 PM)                                      │
│                                                             │
│  [Test Connection]                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 7: Testing Requirements

### 7.1 Offline Scenarios

```swift
@Test func testOfflineAcknowledgment() async throws {
    // Simulate going offline
    mockNetwork.setOffline()
    mockLLM.setUnreachable()

    // Receive a message
    let message = IncomingMessage(sender: "+1555123456", content: "Hey Ember")
    await messageHandler.handle(message)

    // Verify acknowledgment sent
    #expect(mockMessageSender.sentMessages.count == 1)
    #expect(mockMessageSender.sentMessages[0].contains("trouble connecting"))

    // Verify queued
    #expect(MessageQueue.shared.count == 1)
}

@Test func testQueueProcessingOnRecovery() async throws {
    // Queue some messages while offline
    MessageQueue.shared.add(message1)
    MessageQueue.shared.add(message2)
    MessageQueue.shared.add(message3)

    // Restore connectivity
    mockNetwork.setOnline()
    mockLLM.setReachable()

    // Trigger recovery
    await recoveryHandler.onConnectivityRestored()

    // Verify all processed
    #expect(MessageQueue.shared.count == 0)
    #expect(mockMessageSender.sentMessages.count >= 3)
}

@Test func testAcknowledgmentRateLimiting() async throws {
    mockNetwork.setOffline()

    // Send multiple messages from same sender
    for i in 0..<5 {
        let message = IncomingMessage(sender: "+1555123456", content: "Message \(i)")
        await messageHandler.handle(message)
    }

    // Should only ack once (rate limited)
    let acksToSender = mockMessageSender.sentMessages.filter {
        $0.recipient == "+1555123456"
    }
    #expect(acksToSender.count == 1)
}

@Test func testDelayContextInRecoveryResponse() async throws {
    // Queue an old message
    let oldMessage = QueuedMessage(
        content: "What's on my calendar?",
        sender: "+1555123456",
        receivedAt: Date().addingTimeInterval(-7200) // 2 hours ago
    )
    MessageQueue.shared.add(oldMessage)

    // Process on recovery
    await recoveryHandler.processQueue()

    // Response should acknowledge delay
    let response = mockMessageSender.sentMessages.last!
    #expect(response.text.contains("Sorry for the delay"))
}
```

### 7.2 Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline during response generation | Queue the request, ack the user |
| Rapid connect/disconnect cycles | Debounce state changes, avoid ack spam |
| Queue full (100 messages) | Reject new messages with apology |
| Message older than 24 hours | Expire with apology, don't process |
| API key invalid | Special ack pointing to app settings |

---

## Implementation Checklist

### MVP

- [ ] Connectivity state machine (online/degraded/offline)
- [ ] Basic message queue (SQLite storage)
- [ ] Offline acknowledgment (single template)
- [ ] Queue processing on recovery
- [ ] Menu bar status indicator

### v1.1

- [ ] Multiple acknowledgment templates
- [ ] Acknowledgment rate limiting
- [ ] Priority classification
- [ ] Delay context in responses
- [ ] Detailed status in Mac app
- [ ] Offline pattern responses (time/date)

### v1.2+

- [ ] Local model fallback when cloud offline
- [ ] Predictive offline mode (detect degradation early)
- [ ] Smart queue prioritization
- [ ] Offline calendar/reminder operations
- [ ] Push notification on recovery

---

## References

- `specs/autonomous-operation.md` — Health monitoring, circuit breakers
- `specs/error-handling.md` — Component failure modes
- [Apple NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) — Network connectivity monitoring
- [Offline-First Web Apps](https://web.dev/offline-first/) — General offline UX patterns

---

*Specification complete. February 5, 2026.*
