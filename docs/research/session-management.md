# Session & Identity Management Research

**Status:** Not Started
**Priority:** High (Phase 1 - Post-Research Gap)
**Last Updated:** February 2, 2026

---

## Executive Summary

This document addresses critical architectural questions identified after the initial Phase 1 research:

1. **Context Window Management** — How does EmberHearth build LLM context from iMessage history?
2. **Session Continuity** — How do we handle interruptions, deletions, and restarts?
3. **Group Chat Behavior** — What happens when Ember is added to a group chat?
4. **Identity Verification** — How do we confirm messages come from authorized users?
5. **Multi-User Scenarios** — Can other users have roles/permissions?

These questions are foundational to the iMessage integration and must be resolved before Phase 2 prototyping.

---

## Research Questions

### 1. Context Window Management

**Problem Statement:** LLMs have finite context windows (4K-128K tokens typically). iMessage chat history can span years with thousands of messages. How do we build effective context for each LLM request?

**Research Questions:**
- [ ] What context window sizes do our target LLMs support?
- [ ] What's the optimal balance between conversation history and system prompt?
- [ ] Should we use rolling windows, summarization, or selective retrieval?
- [ ] How does the memory system (semantic retrieval) integrate with conversation context?
- [ ] Should context strategy differ between work and personal contexts?
- [ ] How do we handle very long user messages that themselves approach context limits?

**Design Considerations:**
- We should NOT dump the complete iMessage history into every request
- We should NOT ignore history and process each message in isolation
- Context should include: recent conversation turns, relevant memories, system prompt
- May need summarization of older conversation segments
- Memory system embeddings provide semantic retrieval for relevant facts

**Architectural Options:**

```
Option A: Fixed Rolling Window
├── Last N messages (e.g., 20)
├── + Relevant memories from semantic search
├── + System prompt
└── Simple but may lose important context

Option B: Summarized History
├── Last N messages verbatim
├── + Compressed summary of older conversation
├── + Relevant memories
├── + System prompt
└── Better long-term context, more complex

Option C: Semantic Retrieval Only
├── Last N messages
├── + Query memory system for relevant context
├── + System prompt
└── Relies heavily on memory extraction quality

Option D: Hybrid Adaptive
├── Recent messages (always included)
├── + Summarized conversation segments (if conversation is long)
├── + Semantically retrieved memories
├── + Active reminders/tasks
├── + System prompt
├── Context budget allocation based on message type
└── Most sophisticated, recommended approach
```

**Related Documents:**
- `memory-learning.md` — Semantic retrieval, embedding strategy
- `local-models.md` — Context window capabilities of local models

---

### 2. Session Continuity

**Problem Statement:** What defines a "session"? How does EmberHearth maintain conversational coherence across interruptions?

**Research Questions:**
- [ ] What is the definition of a "session" vs a "conversation"?
- [ ] How long can a session be inactive before it's considered ended?
- [ ] What state persists across app restarts?
- [ ] What happens if the user accidentally deletes iMessage chat history?
- [ ] What if the user starts a second parallel iMessage thread?
- [ ] How do we handle the Mac going to sleep mid-conversation?

**Scenarios to Address:**

**Scenario A: User deletes iMessage chat history**
```
Impact:
- chat.db no longer contains old messages
- EmberHearth can't see conversation prior to deletion

Possible mitigations:
1. EmberHearth maintains its own conversation cache (not in chat.db)
2. Memory system has extracted facts, so context isn't fully lost
3. Graceful degradation: "I notice our conversation history was cleared..."

Recommendation: Mirror conversation to internal storage, use memory for context
```

**Scenario B: User starts second parallel iMessage thread**
```
How can this happen:
- User creates new conversation instead of continuing existing one
- User has multiple devices, starts thread from different device
- Bug in Messages.app creates duplicate thread

Detection:
- Same phone number (handle) but different chat ID
- Monitor for new chat creation with existing handle

Resolution options:
1. Merge context from both threads
2. Treat as continuation of same session
3. Ask user which conversation to use going forward
```

**Scenario C: EmberHearth restarts mid-conversation**
```
What must persist:
- Last-seen message timestamp (to detect new messages)
- Active session state (pending clarifications, multi-turn tasks)
- Conversation context cache

Storage:
- Persistent storage in Application Support directory
- Quick recovery on launch
```

**Scenario D: Mac sleeps/wakes**
```
Considerations:
- FSEvents may miss changes during sleep
- Re-scan chat.db on wake
- Handle messages that arrived during sleep
```

**Session State Model:**
```swift
struct ConversationSession {
    let contextID: Context  // personal or work
    let handle: String      // phone number/email
    var chatIDs: [Int64]    // May have multiple iMessage thread IDs

    // Persistence
    var lastSeenMessageID: Int64
    var lastActivityTimestamp: Date

    // Context building
    var recentMessages: [Message]       // Cached for quick context
    var conversationSummary: String?    // Compressed older history
    var activeTaskState: TaskState?     // Multi-turn task in progress

    // Session lifecycle
    var sessionStarted: Date
    var isActive: Bool
}

// Session timeout (configurable)
let sessionTimeoutMinutes: Int = 30  // After 30 min inactivity, new session
```

---

### 3. Group Chat Behavior

**Problem Statement:** What happens if a user adds Ember's phone number to a group chat? This has significant security implications.

**Research Questions:**
- [ ] Should Ember respond at all in group chats?
- [ ] How do we detect a group chat vs 1:1 conversation?
- [ ] What information should Ember share in multi-party contexts?
- [ ] Should tool calls be completely disabled in group chats?
- [ ] How do we handle mentions (@Ember) vs general group messages?
- [ ] What about family group chats where all members might be authorized?

**Group Chat Detection:**
```sql
-- In chat.db, group chats have multiple handles
SELECT c.ROWID, c.chat_identifier, COUNT(chj.handle_id) as participant_count
FROM chat c
JOIN chat_handle_join chj ON c.ROWID = chj.chat_id
GROUP BY c.ROWID
HAVING participant_count > 2  -- More than just user + Ember
```

**Security Tiers for Group Chats:**

```
Tier 1: Completely Disabled (Safest)
├── Ember does not respond in group chats at all
├── May send a one-time message: "I only respond in private conversations"
└── Zero risk of information disclosure

Tier 2: Social Only (Recommended Default)
├── Ember can respond to greetings, casual chat
├── NO access to memory system (no personal facts)
├── NO tool calls (no calendar, reminders, etc.)
├── Responses limited to general assistant capabilities
└── Effectively a "public persona"

Tier 3: Verified Family Mode (Opt-in)
├── User explicitly configures a group as "trusted"
├── Must verify all participants
├── Limited tool access (shared calendar events only)
├── NO access to private memories
├── Audit logging of all group interactions
└── Requires careful user education

Tier 4: Full Access (Not Recommended)
├── Treat group chat like 1:1
├── Full memory and tool access
├── HIGH RISK of information disclosure
└── Only for very specific use cases (e.g., personal family assistant)
```

**Tron Integration for Group Chats:**
```
Group chat security should be enforced by Tron:
- Detect group chat context before processing
- Apply appropriate tier restrictions
- Block tool calls if not authorized for group
- Sanitize responses to remove private information
- Log all group chat interactions for audit
```

**Identity Challenge in Groups:**
```
Problem: In a group chat, messages come from multiple people
- How do we know which messages are from the authorized user?
- What if someone impersonates the user?
- What if an attacker is in the group?

Detection signals:
- iMessage provides sender handle for each message
- Compare against configured owner phone number
- Only respond to owner's messages (Tier 2+)
- Or respond to anyone but with restricted access
```

---

### 4. Identity Verification

**Problem Statement:** How do we ensure messages are from authorized users, not someone who borrowed their phone or a compromised device?

**Research Questions:**
- [ ] What identity signals does iMessage provide?
- [ ] Should there be a PIN or passphrase for sensitive operations?
- [ ] How do we handle shared family devices?
- [ ] What about Apple Watch messages (same person, different device)?
- [ ] Should Ember support multiple authorized users per context?

**Identity Signals Available:**
```
From iMessage/chat.db:
├── Sender handle (phone number or Apple ID email)
├── Source device (limited - mainly iPhone vs Mac)
├── Account ID (which iMessage account sent it)
└── Read receipts (confirms delivery to specific device)

NOT available:
├── Biometric confirmation
├── Device passcode status
├── Whether device was recently unlocked
└── Physical possession verification
```

**Authentication Tiers:**

```
Tier 0: Handle Match (Default)
├── Message comes from configured phone number
├── Assume it's the authorized user
├── Sufficient for most interactions
└── Risk: Phone could be borrowed/stolen

Tier 1: Session PIN (Opt-in for Sensitive Operations)
├── User sets a PIN during onboarding
├── Required for: financial queries, deleting memories, exporting data
├── "Please confirm with your PIN to proceed"
├── Rate-limited to prevent brute force
└── Stored hashed in Keychain

Tier 2: Challenge-Response (Higher Security)
├── Ember asks a question only the user would know
├── Based on private memories
├── "To confirm it's you, what's the name of your childhood pet?"
├── Risk: Social engineering if memories aren't private enough
└── Better than nothing, not perfect

Tier 3: Out-of-Band Confirmation (Highest Security)
├── For critical operations (e.g., "delete all my data")
├── Requires confirmation in the Mac app (not iMessage)
├── Mac app can use biometric authentication
└── Most secure but highest friction
```

**Device Trust Model:**
```swift
struct TrustedDevice {
    let deviceIdentifier: String  // If detectable
    let firstSeen: Date
    let lastSeen: Date
    var trustLevel: TrustLevel

    enum TrustLevel {
        case new          // Just appeared, verify
        case recognized   // Seen before, normal trust
        case primary      // User's main device, higher trust
        case suspicious   // Unusual pattern detected
    }
}

// Alert on suspicious patterns
func detectAnomalies(message: IncomingMessage) -> [Anomaly] {
    var anomalies: [Anomaly] = []

    // New device suddenly appearing
    if !knownDevices.contains(message.sourceDevice) {
        anomalies.append(.newDevice)
    }

    // Unusual time (3 AM when user is typically asleep)
    if isUnusualTime(message.timestamp) {
        anomalies.append(.unusualTime)
    }

    // Rapid-fire requests for sensitive info
    if detectRapidSensitiveRequests() {
        anomalies.append(.possibleCompromise)
    }

    return anomalies
}
```

---

### 5. Multi-User Scenarios

**Problem Statement:** Should EmberHearth support multiple authorized users (e.g., family members, assistant)?

**Research Questions:**
- [ ] Is multi-user access a Phase 1 requirement or future enhancement?
- [ ] What roles might exist (owner, family member, read-only)?
- [ ] How does multi-user interact with work/personal contexts?
- [ ] What's the permission model for shared vs private memories?
- [ ] How do users authenticate their different roles?

**Potential Role Model:**
```swift
enum UserRole {
    case owner          // Full access, can configure everything
    case familyAdmin    // Can manage family-shared data, limited private access
    case familyMember   // Access to shared calendars, reminders; no private memories
    case guest          // Very limited, time-bounded access
}

struct AuthorizedUser {
    let phoneNumber: String
    let role: UserRole
    let context: Context  // Which context they can access
    let addedDate: Date
    let addedBy: AuthorizedUser  // Owner or familyAdmin

    // Permission flags
    var canAccessPrivateMemories: Bool
    var canModifyMemories: Bool
    var canUseSensitiveTools: Bool
    var canAddOtherUsers: Bool
}
```

**Phase Recommendation:**
- **MVP (Phase 2-3):** Single owner only. One phone number per context.
- **Phase 5+:** Consider multi-user if demand exists. Adds significant complexity.

---

## Architectural Recommendations

### Context Window Strategy (Recommended)

```
For each incoming message:

1. IDENTIFY CONTEXT
   └── Check phone number → personal or work

2. LOAD SESSION STATE
   └── Retrieve or create ConversationSession for this handle

3. BUILD LLM CONTEXT (Budget: ~50% of context window)
   ├── System prompt (~10%)
   ├── Recent messages (last 10-20 messages, ~20%)
   ├── Conversation summary if long session (~10%)
   ├── Relevant memories from semantic search (~10%)
   └── Active task state if applicable

4. PROCESS WITH LLM
   └── Send context + new message

5. UPDATE SESSION STATE
   ├── Add new messages to cache
   ├── Update last-seen timestamp
   ├── Trigger memory extraction (async)
   └── Persist to disk

6. SEND RESPONSE
   └── Via AppleScript to Messages.app
```

### Session Persistence Model

```swift
// Persisted to disk (Application Support)
struct SessionPersistence: Codable {
    var sessions: [String: ConversationSession]  // keyed by handle
    var lastPersisted: Date

    // Recovery after crash
    func recover() -> [ConversationSession] {
        // Re-scan chat.db for any missed messages
        // Update lastSeenMessageID for each session
        // Return active sessions
    }
}

// Persist on:
// - App termination
// - Every N messages
// - Every M minutes
// - Before sleep
```

### Group Chat Security (Recommended Defaults)

```
Default Behavior: Tier 2 (Social Only)

When group chat detected:
1. Log warning: "Group chat detected, restricted mode"
2. Disable memory retrieval
3. Disable all tool calls
4. Respond only to direct mentions or general conversation
5. Use generic assistant personality (no personalization)
6. Never reveal private information

User can upgrade to Tier 3 via Mac app:
- Explicitly add group chat ID to "trusted groups"
- Must verify all participants
- Enable only specific tools (shared calendar)
```

### Identity Verification (Recommended Defaults)

```
Default: Tier 0 (Handle Match)
- Sufficient for 95% of interactions

Automatic Tier 1 escalation for:
- Deleting memories
- Exporting personal data
- Changing security settings
- Adding authorized users (future)

User opt-in for higher security:
- Enable PIN for all financial queries
- Enable challenge-response for paranoid mode
- Require Mac app confirmation for destructive actions
```

---

## Open Questions for User

1. **Context window sizing:** What's the expected typical conversation length? Do users have multi-day ongoing conversations or mostly quick exchanges?

2. **Group chat priority:** Is group chat support needed for MVP, or can we defer to a later phase?

3. **Multi-user demand:** Is family sharing a priority, or is single-user sufficient for the foreseeable future?

4. **Security vs convenience tradeoff:** Should sensitive operations require PIN by default, or should this be opt-in?

5. **Recovery behavior:** If chat history is deleted, should Ember acknowledge the gap ("I notice our history was cleared") or proceed silently with what memories remain?

---

## Dependencies

- **Memory System:** Context window strategy depends on semantic retrieval working well
- **Tron:** Group chat security rules should be enforced by Tron
- **iMessage Integration:** Session detection depends on chat.db schema understanding

---

## Next Steps

1. [ ] Answer research questions through prototyping and testing
2. [ ] Decide on context window strategy (recommend: Hybrid Adaptive)
3. [ ] Define session persistence format
4. [ ] Document group chat security rules for Tron
5. [ ] Design identity verification UX
6. [ ] Update architecture docs with decisions

---

*This document captures research gaps identified on February 2, 2026. Questions should be answered during Phase 2 prototyping.*
