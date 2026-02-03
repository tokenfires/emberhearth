# Session & Identity Management Research

**Status:** Complete
**Priority:** High (Phase 1 - Post-Research Gap)
**Last Updated:** February 3, 2026

---

## Executive Summary

This document addresses critical architectural questions identified after the initial Phase 1 research:

1. **Context Window Management** — How does EmberHearth build LLM context from iMessage history?
2. **Session Continuity** — How do we handle interruptions, deletions, and restarts?
3. **Group Chat Behavior** — What happens when Ember is added to a group chat?
4. **Identity Verification** — How do we confirm messages come from authorized users?
5. **Multi-User Scenarios** — Can other users have roles/permissions?

All questions have been researched and decisions documented below.

---

## 1. Context Window Management

### Decision: Hybrid Adaptive Approach

**Selected Strategy:** Option D (Hybrid Adaptive) with dynamic adjustment based on user behavior.

```
┌─────────────────────────────────────────────────────────────────┐
│  CONTEXT BUDGET ALLOCATION                                       │
│                                                                 │
│  System prompt                          ~10%                    │
│  Recent messages (verbatim)             ~25%                    │
│  Conversation summary (if needed)       ~10%                    │
│  Retrieved memories (semantic search)   ~15%                    │
│  Active task state                      ~5%                     │
│  Reserve for response                   ~35%                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight:** "A focused 300-token context often outperforms an unfocused 113,000-token context." Quality over quantity.

### Summarization Strategy

**Trigger:** Begin summarization after ~20 messages in current conversation segment.

**Dynamic Adjustment:** Ember tracks user behavior and adjusts automatically:
- Some users go days with fewer than 20 messages
- Some users exceed 50 messages before lunch
- The threshold adapts to individual communication patterns

**Granularity:** Rolling summary that follows the context the user sets:
- Summary length scales with user's message frequency and length
- High-volume users get more detailed summaries
- Low-volume users get concise summaries
- Summary updates incrementally, not rebuilt from scratch

```swift
struct ConversationSummarizer {
    var messageCountThreshold: Int = 20  // Starting point
    var userAverageMessagesPerDay: Double
    var userAverageMessageLength: Double

    // Adjust threshold based on user patterns
    mutating func adaptToUser() {
        if userAverageMessagesPerDay > 50 {
            messageCountThreshold = 30  // More messages before summarizing
        } else if userAverageMessagesPerDay < 10 {
            messageCountThreshold = 15  // Summarize sooner
        }
    }

    // Summary length scales with user verbosity
    func targetSummaryLength() -> Int {
        let baseLength = 200  // tokens
        let verbosityMultiplier = min(userAverageMessageLength / 50.0, 2.0)
        return Int(Double(baseLength) * verbosityMultiplier)
    }
}
```

### Context Building Flow

```
For each incoming message:

1. IDENTIFY CONTEXT
   └── Check phone number → personal or work

2. LOAD SESSION STATE
   └── Retrieve ConversationSession for this handle (never expires)

3. BUILD LLM CONTEXT
   ├── System prompt (~10%)
   ├── Recent messages verbatim (~25%)
   ├── Rolling conversation summary if needed (~10%)
   ├── Semantically retrieved memories (~15%)
   ├── Retrieved conversation archive chunks (mini-RAG) if relevant
   └── Active task state if applicable (~5%)

4. PROCESS WITH LLM
   └── Send context + new message

5. UPDATE STATE
   ├── Add messages to recent cache
   ├── Archive conversation chunk (separate from chat.db)
   ├── Update rolling summary if threshold reached
   ├── Trigger memory extraction (async)
   └── Persist to disk

6. SEND RESPONSE
   └── Via AppleScript to Messages.app
```

---

## 2. Session Continuity

### Decision: Continuous Relationship (No Timeout)

**Session Model:** Ember maintains a continuous relationship with the user. Sessions never formally "expire."

**Rationale:** Unlike web sessions or customer service chats, Ember is a persistent companion. The relationship doesn't reset after 30 minutes of inactivity—it's ongoing, like texting a friend.

**Conversation Segmentation:** While the relationship is continuous, conversations have natural segments for context building purposes:
- Topic changes
- Large time gaps (next day)
- User-initiated resets ("let's start fresh")

### Conversation Archive (Mini-RAG)

**Decision:** Maintain a separate conversation archive independent of iMessage's chat.db.

**Problem Solved:** If user deletes iMessage chat history, Ember doesn't lose all context.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│  CONVERSATION ARCHIVE                                            │
│  (Separate from Memory System facts)                             │
│                                                                 │
│  Storage: SQLite in ~/Library/Application Support/EmberHearth/  │
│                                                                 │
│  What it stores:                                                │
│  ├── Conversation chunks (grouped by topic/time)                │
│  ├── Embeddings for semantic retrieval                          │
│  ├── Timestamp range per chunk                                  │
│  ├── Summary of each chunk                                      │
│  └── Emotional tone/context markers                             │
│                                                                 │
│  How it's used:                                                 │
│  ├── Primary source: chat.db (canonical, real-time)             │
│  ├── Fallback: Archive (if chat.db missing messages)            │
│  ├── Retrieval: "conversations about Emma's visit"              │
│  └── Context: Preserve conversational texture, not just facts   │
│                                                                 │
│  Distinction from Memory System:                                │
│  ├── Memory = extracted facts ("Emma is vegan")                 │
│  └── Archive = conversation flow (the exchange where you        │
│      were stressed about the visit, Ember helped, it went well) │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Privacy Consideration:** During onboarding, inform user:
> "Ember keeps her own memory of your conversations to provide better context. You can clear this anytime from the app."

**Retention Policy:**
- Full conversation archive: 90 days (configurable in MacOS app)
- Older than 90 days: Summaries only, original text deleted
- User can clear archive manually (separate from clearing memory facts)

### Deleted iMessage History

**Decision:** Silently rely on memory system and conversation archive. Don't mention it.

**Rationale:** User may have deleted intentionally for privacy. Calling attention to it is awkward. The memory system and conversation archive provide continuity.

```
User deletes iMessage history:
├── chat.db no longer has old messages
├── Conversation Archive still has chunks + embeddings
├── Memory System still has extracted facts
├── Ember continues naturally, context preserved
└── No "I notice our history was cleared" message
```

### Parallel iMessage Threads

**Decision:** Merge context, treat as continuation of same relationship.

```
Same phone number, new chat ID detected:
├── Merge into existing ConversationSession
├── Archive both threads
├── No user prompt needed
└── Ember responds naturally in whichever thread user uses
```

### State Persistence

```swift
struct SessionPersistence: Codable {
    var sessions: [String: ConversationSession]  // keyed by handle
    var lastPersisted: Date

    // Persist triggers:
    // - App termination
    // - Every N messages (e.g., 5)
    // - Every M minutes (e.g., 5)
    // - Before Mac sleep
    // - After significant state change (task completion, etc.)
}

struct ConversationSession: Codable {
    let contextID: Context  // personal or work
    let handle: String      // phone number/email
    var chatIDs: [Int64]    // May have multiple iMessage thread IDs

    // Persistence
    var lastSeenMessageID: Int64
    var lastActivityTimestamp: Date

    // Context building
    var recentMessages: [Message]       // Cached for quick context
    var rollingSummary: String?         // Compressed older history
    var summaryMessageCount: Int        // Messages included in summary
    var activeTaskState: TaskState?     // Multi-turn task in progress

    // User behavior tracking (for adaptive summarization)
    var averageMessagesPerDay: Double
    var averageMessageLength: Double

    // Note: No session timeout - relationship is continuous
}
```

---

## 3. Group Chat Behavior

### Decision: Social Mode with Full Tool/Memory Restriction

**Core Principle:** Ember responds socially in group chats but never executes commands, instructions, or tool calls. Group chat mode behaves as a normal human conversation participant.

### Detection

```sql
-- In chat.db, group chats have multiple handles
SELECT c.ROWID, c.chat_identifier, COUNT(chj.handle_id) as participant_count
FROM chat c
JOIN chat_handle_join chj ON c.ROWID = chj.chat_id
GROUP BY c.ROWID
HAVING participant_count > 2  -- More than just user + Ember
```

### Social Mode Characteristics

```
┌─────────────────────────────────────────────────────────────────┐
│  EMBER'S GROUP CHAT BEHAVIOR                                     │
│                                                                 │
│  DOES:                                                          │
│  ├── Respond to introductions naturally                         │
│  ├── Engage in casual conversation                              │
│  ├── Use natural response timing (seconds to minutes delay)     │
│  ├── Say "give me a sec" or "I'll reply in a bit" if busy      │
│  ├── Track group conversations for later reference              │
│  ├── Remember group members and dynamics                        │
│  ├── Use emojis contextually (paralinguistic warmth)            │
│  └── Recognize nicknames assigned by the group                  │
│                                                                 │
│  DOES NOT:                                                      │
│  ├── Execute any tool calls (calendar, reminders, etc.)         │
│  ├── Access memory system (no personal facts)                   │
│  ├── Take commands or instructions                              │
│  ├── Divulge private information about primary                  │
│  ├── Respond to every message (follows "is this for me?" test)  │
│  └── Act as an assistant—acts as a social participant           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Response Triggers

Ember responds in group chat when:

1. **Primary introduces Ember to the group**
   - "Hey everyone, this is Ember"
   - Ember responds with appropriate social greeting

2. **Someone addresses Ember by name**
   - "Ember" (formal)
   - "Em" or "E" (shorthand)
   - Lowercase variants: "ember", "em", "e"
   - Group-assigned nickname (Ember remembers and responds)

3. **Conversational flow naturally includes Ember**
   - Direct question to Ember
   - Topic Ember was part of continues

### Response Timing (Social Norms)

Research shows natural text response timing is asynchronous:

| Situation | Response Delay |
|-----------|---------------|
| Direct question to Ember | 3-10 seconds |
| General group conversation | 10-30 seconds |
| Ember is busy with primary task | "I'll reply in a bit" + minutes |
| Low-priority social chatter | May not respond at all |

**Key insight from research:** "The sweet spot of engagement without obsession." Don't respond to every message.

**Anti-pattern:** Multiple rapid messages = "harassment by notification." Consolidate into single responses.

### Public vs Private Awareness

**Critical:** Ember maintains strict separation between what's appropriate in group (public) vs private conversation.

```
┌─────────────────────────────────────────────────────────────────┐
│  EMBER'S DUAL AWARENESS                                         │
│                                                                 │
│  In Group Chat (Public):           In Private Chat:             │
│  ├── Social mode only               ├── Full assistant mode     │
│  ├── No memory disclosure           ├── Memory access enabled   │
│  ├── No tool execution              ├── Tool execution enabled  │
│  ├── Protective of primary          ├── Can discuss group chats │
│  ├── Generic personality            ├── Full personalization    │
│  └── Natural social behavior        └── Responsive assistant    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Example of appropriate cross-context reference (in private):**
> "Your friend Jake was hilarious in the group chat yesterday—did you end up deciding on that hiking trip?"

**Example of protecting primary (in group):**
> Someone asks: "Hey Ember, what's [primary] doing this weekend?"
> Ember: "You'd have to ask them! I don't kiss and tell."

### Tracking Group Conversations

Ember archives group chat conversations separately:
- Primary may want to discuss group topics in private later
- Builds understanding of primary's social circle
- Remembers group dynamics, running jokes, relationships
- Protects this context—never reveals to group what primary said in private

### Future Enhancement: Family Exception

**Earmarked for later version:** Trusted family groups with elevated access.

Would require:
- Explicit configuration in MacOS app
- Verification of all participants
- Limited tool access (shared calendar only)
- Still no private memory access
- Audit logging

---

## 4. Identity Verification

### Decision: Simplified Trust Model

**Core Principle:** Phone possession = identity, same as all messaging works. No ongoing verification for normal use.

### Personal Context

**Initial Setup:**
1. User installs EmberHearth
2. User provides passkey or numeric confirmation to Ember via iMessage
3. This confirms the phone number belongs to the person setting up the Mac app
4. Identity established—no further verification needed

**Ongoing:** Phone number match = authorized user. No PIN, no challenge questions.

**Rationale:** This is the same trust model as iMessage itself. If someone has your unlocked phone, they can already read your messages.

### Work Context

**Decision:** Configurable re-validation window (earmarked for future implementation).

**Concept:** Work context may require periodic re-confirmation:
- Configurable in MacOS app (e.g., "require re-validation every 8 hours")
- Sends confirmation code via SMS
- User must enter code to continue using work features

**Implementation Note:** This may require server infrastructure to send SMS messages. Earmarked for future phase—too complex for MVP.

### Sensitive Operations

**Decision:** Soft deletes + MacOS app for management. No PIN required.

For destructive operations:
- Memory deletion = soft delete (recoverable)
- Data export = available through MacOS app only (not via iMessage)
- Permanent deletion = MacOS app with selection interface

**MacOS App Screen (new requirement):**
- Browse saved facts/events/data
- Select items for permanent deletion
- Find and restore soft-deleted items

### Pattern Recognition (Non-Security)

**Decision:** Ember recognizes usage patterns for wellness, not security.

```
┌─────────────────────────────────────────────────────────────────┐
│  EMBER'S PATTERN AWARENESS (Relationship Behavior)              │
│                                                                 │
│  Ember learns:                                                  │
│  ├── User's typical sleep schedule (e.g., 9-10pm bedtime)       │
│  ├── Normal activity times                                      │
│  ├── Communication frequency patterns                           │
│  └── Routine behaviors                                          │
│                                                                 │
│  Unusual pattern detected:                                      │
│  ├── 2am message when user usually sleeps at 10pm               │
│  │   └── Wellness check: "Hey, everything okay? It's late."     │
│  │                                                              │
│  ├── Regular insomnia pattern emerges                           │
│  │   └── Adapt: "Can't sleep again? I'm here if you want to     │
│  │       talk, or I can find something relaxing."               │
│  │                                                              │
│  └── This is caring companion behavior, not security            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Security Anomaly Detection

**Decision:** Security-related anomalies are Tron's responsibility.

Tron handles:
- Rapid-fire requests for sensitive data
- Unusual access patterns suggesting compromise
- Attempts to bypass restrictions

**Ember-Tron Coordination:**
- Tron detects security anomalies
- Tron does NOT contact user directly
- Ember is the communication layer
- Mechanism for Tron to flag issues for Ember to communicate
- Details to be designed during Tron architecture phase

---

## 5. Multi-User Scenarios

### Decision: Single User Only (MVP)

**MVP Scope:** One phone number per context. Single owner.

**Rationale:** Multi-user adds significant complexity:
- Role management
- Permission inheritance
- Privacy boundaries between users
- Authentication for each user
- Shared vs private data

**Future Consideration:** May revisit if demand exists. Would require:
- Role model (owner, familyAdmin, familyMember, guest)
- Per-role permissions
- Shared vs private memory separation
- Authentication per user

---

## 6. Social Cues Research Integration

### Text Messaging Communication Norms

Research from linguistics and communication studies (2024-2025) informs Ember's social behavior:

| Finding | Source | Application |
|---------|--------|-------------|
| Response timing is asynchronous | [NPR/Erica Dhawan](https://www.npr.org/2025/04/21/nx-s1-5349521/texting-etiquette-manage-group-texts-frequent-texts) | Delayed responses are natural, not broken |
| 24-hour rule for non-urgent texts | [NPR](https://www.npr.org/2025/04/21/nx-s1-5349521/texting-etiquette-manage-group-texts-frequent-texts) | Ember doesn't stress about instant replies |
| "Sweet spot of engagement without obsession" | [Reader's Digest](https://www.rd.com/list/group-texting/) | Don't respond to every group message |
| Multiple rapid messages = "harassment" | [NPR](https://www.npr.org/2025/04/21/nx-s1-5349521/texting-etiquette-manage-group-texts-frequent-texts) | Consolidate thoughts into single messages |
| Emojis = paralinguistic cues | [ResearchGate](https://www.researchgate.net/publication/380745223_Unveiling_the_Linguistic_Landscape_Examining_the_Influence_of_Digital_Communication_in_Social_Media_and_Text_Messaging_on_Language_Development) | Contextual emoji use in social mode |
| Empathetic responses increase satisfaction | [Frontiers](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1569277/full) | Warmth matters in all contexts |
| Turn-taking is cooperative | [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12014614/) | Wait for conversation flow, don't interrupt |

**Cross-Reference:** See `conversation-design.md` Section 7 (Memory Salience and Emotional Encoding) for how these principles integrate with Ember's overall personality.

---

## 7. Tron Coordination Notes

**For Tron Architecture Phase:**

Ember and Tron need a coordination mechanism:

```
┌─────────────────────────────────────────────────────────────────┐
│  EMBER-TRON RELATIONSHIP                                         │
│                                                                 │
│  Tron's Role:                                                   │
│  ├── Security policy enforcement                                │
│  ├── Anomaly detection (security-related)                       │
│  ├── Tool call authorization                                    │
│  ├── Group chat restriction enforcement                         │
│  └── Audit logging                                              │
│                                                                 │
│  Ember's Role:                                                  │
│  ├── User-facing communication (Tron never contacts user)       │
│  ├── Relationship management                                    │
│  ├── Pattern recognition (wellness, not security)               │
│  └── Personality and conversation                               │
│                                                                 │
│  Coordination Needed:                                           │
│  ├── Tron flags security event → Ember communicates to user     │
│  ├── Ember requests tool call → Tron authorizes/blocks          │
│  ├── Group chat detected → Tron enforces social-only mode       │
│  └── Shared state for context awareness                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Future Enhancements (Earmarked)

| Feature | Description | Phase |
|---------|-------------|-------|
| Family exception | Trusted groups with elevated access | Future |
| Work re-validation | Time-based SMS confirmation | Future (needs server) |
| Multi-user roles | Owner, family, guest roles | Phase 5+ if demand |
| 911 / emergency calls | Safeguards for errant emergency calls | Future (out of SMS scope) |

### 911 / Emergency Call Risk

**Note:** User raised concern about Ember potentially making errant emergency calls. This is out of scope for SMS/text research but should be addressed when implementing voice or phone capabilities:
- User could legitimately ask Ember to call 911 in emergency
- Risk of hallucination or misinterpretation triggering call
- Need safeguards before any phone call capability
- To be addressed in future phase

---

## 9. Implementation Summary

### Decisions Made

| Area | Decision |
|------|----------|
| **Context strategy** | Hybrid Adaptive with dynamic summarization |
| **Context budget** | 10% system, 25% recent, 10% summary, 15% memories, 5% tasks, 35% response |
| **Summarization trigger** | ~20 messages, adapts to user behavior |
| **Session timeout** | Never—continuous relationship |
| **Deleted history** | Silent graceful degradation via Conversation Archive |
| **Conversation Archive** | Yes—separate from memory facts, preserves conversational texture |
| **Group chat mode** | Social only—no tools, no memory, no commands |
| **Group response timing** | Natural delay (seconds to minutes), "I'll reply in a bit" if busy |
| **Group triggers** | Name mention (Ember/Em/E/nicknames), introductions, direct address |
| **Public/private** | Strict separation—protect primary's trust in social contexts |
| **Identity model** | Phone = user after initial passkey confirmation |
| **Sensitive ops** | Soft deletes, MacOS app for permanent deletion |
| **Pattern recognition** | Wellness checks (Ember), security anomalies (Tron) |
| **Multi-user** | Single owner only for MVP |

### New MacOS App Requirements Identified

1. **Conversation Archive management** — Clear archive, set retention period
2. **Saved data browser** — Browse facts/events, select for permanent deletion
3. **Soft delete recovery** — Find and restore deleted items
4. **Work re-validation settings** — Future: configure re-auth window

---

## 10. Research Complete

All questions have been researched and decisions documented. This document is ready to inform Phase 2 prototyping.

**Cross-References:**
- `conversation-design.md` — Ember's personality, voice, emotional encoding
- `memory-learning.md` — Semantic retrieval, fact extraction
- `onboarding-ux.md` — Initial setup flow, passkey confirmation
- `security.md` — Tron architecture notes

---

*Research completed February 3, 2026.*
