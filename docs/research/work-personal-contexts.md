# Work/Personal Context Separation Research

**Status:** Complete
**Priority:** High (Phase 1) - Foundational for Memory System
**Last Updated:** February 2, 2026

---

## Overview

EmberHearth must navigate two independent spaces that users occupy: **work** and **personal life**. This isn't optional—even if we tell users "don't use this for work," they will anyway. Responsible design requires engineering a hard boundary between these contexts.

This document explores how to implement context separation that protects users while enabling genuine productivity in both domains.

---

## Why This Matters

### The Problem

Users live in two worlds with different rules:

| Aspect | Personal | Work |
|--------|----------|------|
| Data ownership | User owns everything | Employer may own data |
| Privacy expectations | High | Variable (corporate policies) |
| Compliance requirements | Minimal | HIPAA, SOX, NDA, etc. |
| Consequences of leakage | Embarrassment, relationships | Termination, legal liability |
| LLM preferences | May prefer cloud quality | May require local-only |

### Real-World Scenarios

**Scenario 1: Job Search**
> User is searching for a new job while employed. Personal context contains interview schedules, salary negotiations, recruiter conversations. If ANY of this leaks to work context (even as a learned preference like "interested in management roles"), it could damage their current position.

**Scenario 2: Health Issues**
> User is dealing with a health condition. Personal context has doctor appointments, medication reminders, symptom tracking. Work context should never see "you mentioned feeling fatigued lately" or suggest schedule changes based on health data.

**Scenario 3: Corporate Confidential**
> User works on proprietary projects. Work context has client names, project codenames, financial projections. Personal assistant context should never mention "that Q3 deadline you're stressed about" to family members asking about weekend plans.

**Scenario 4: Legal Discovery**
> In litigation, work communications may be discoverable. Personal conversations should remain separate and protected. Mixing contexts creates legal exposure.

---

## Core Architecture: Two Worlds

### The Two-Session Model

EmberHearth operates through **two separate iMessage sessions**—one for work, one for personal. This provides:

1. **Clear user mental model**: "This number is for work, this number is for personal"
2. **Physical separation**: Different phone numbers/iMessage accounts
3. **No ambiguity**: Context is explicit, not inferred
4. **Easy switching**: User chooses which assistant to message

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EmberHearth Architecture                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────┐   ┌─────────────────────────────┐        │
│   │     PERSONAL CONTEXT        │   │      WORK CONTEXT           │        │
│   │                             │   │                             │        │
│   │   iMessage: +1-XXX-XXX-0001 │   │   iMessage: +1-XXX-XXX-0002 │        │
│   │   (or personal Apple ID)    │   │   (or work Apple ID)        │        │
│   │                             │   │                             │        │
│   │   ┌─────────────────────┐   │   │   ┌─────────────────────┐   │        │
│   │   │  Personal Memory    │   │   │   │    Work Memory      │   │        │
│   │   │  Database           │   │   │   │    Database         │   │        │
│   │   │  (SQLite + encrypt) │   │   │   │    (SQLite + encrypt│   │        │
│   │   └─────────────────────┘   │   │   └─────────────────────┘   │        │
│   │                             │   │                             │        │
│   │   Data Sources:             │   │   Data Sources:             │        │
│   │   • Personal calendar       │   │   • Work calendar           │        │
│   │   • Personal email          │   │   • Work email              │        │
│   │   • Personal contacts       │   │   • Work contacts           │        │
│   │   • Health/fitness          │   │   • Project files           │        │
│   │   • Family notes            │   │   • Meeting notes           │        │
│   │   • Home automation         │   │   • Slack/Teams (future)    │        │
│   │                             │   │                             │        │
│   │   LLM Routing:              │   │   LLM Routing:              │        │
│   │   • Cloud API OK            │   │   • May require local-only  │        │
│   │   • User preference         │   │   • Corporate policy        │        │
│   │                             │   │                             │        │
│   └─────────────────────────────┘   └─────────────────────────────┘        │
│                                                                             │
│                          ════════════════════                               │
│                          HARD BOUNDARY                                      │
│                          No data crosses without explicit user action       │
│                          ════════════════════                               │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    SHARED LAYER (Minimal)                            │  │
│   │                                                                       │  │
│   │   • UI/UX preferences (font size, notification settings)            │  │
│   │   • Communication style preferences (brief vs detailed)              │  │
│   │   • EmberHearth app settings (not context-specific)                 │  │
│   │   • Explicit user-initiated cross-context actions only              │  │
│   │                                                                       │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why Two iMessage Sessions?

**Alternative considered: Single session with context commands**
```
User: "[work] What's on my calendar today?"
User: "[personal] Remind me about mom's birthday"
```

**Problems with this approach:**
1. Users will forget to tag messages
2. Ambiguous queries ("What's the weather?" - which context?)
3. Accidental context leakage from auto-complete or copy/paste
4. No physical separation = easy to make mistakes
5. Harder to explain to non-technical users

**Two sessions is better because:**
1. Context is implicit from which number you message
2. No tagging required
3. Muscle memory develops (work phone vs personal phone feeling)
4. Physically impossible to accidentally mix contexts
5. Maps to how many people already separate work/personal phones

### Implementation Options

**Option A: Two Phone Numbers (Recommended for v1)**
- User sets up two iMessage-capable numbers
- One linked to personal Apple ID, one to work
- EmberHearth monitors both, routes to appropriate context
- Simplest conceptually, clearest separation

**Option B: Single Number with Contact-Based Routing**
- EmberHearth detects if conversation is with work contact vs personal
- Less clean separation
- Doesn't work for direct assistant queries

**Option C: Separate Apps (macOS App Only)**
- Personal assistant via iMessage
- Work assistant via dedicated macOS app interface
- Good separation but loses iMessage accessibility benefit

**Recommendation:** Start with Option A (two phone numbers). Users who want this level of separation likely already have work/personal phone separation.

---

## Data Isolation

### Separate Memory Databases

Each context maintains its own isolated memory store:

```swift
// Personal context
let personalDB = MemoryDatabase(
    path: "~/Library/Application Support/EmberHearth/personal/memory.db",
    encryptionKey: personalKeyFromKeychain
)

// Work context
let workDB = MemoryDatabase(
    path: "~/Library/Application Support/EmberHearth/work/memory.db",
    encryptionKey: workKeyFromKeychain
)

// NEVER share database connections
// NEVER query across contexts
// NEVER merge results
```

### What Goes Where

| Data Type | Personal Context | Work Context |
|-----------|------------------|--------------|
| Calendar events | Personal calendar | Work calendar |
| Email content | Personal accounts | Work accounts |
| Contacts | Friends, family | Colleagues, clients |
| Learned facts | Personal preferences, health, relationships | Projects, deadlines, work preferences |
| Conversation history | Personal iMessage thread | Work iMessage thread |
| Files | Personal documents | Work documents |
| Notes | Personal notes | Work notes |

### Account Mapping

During onboarding, user maps accounts to contexts:

```
EmberHearth Setup > Account Mapping

Email Accounts:
┌────────────────────────────────────────────────────────────────┐
│ john@gmail.com          [Personal ▼]                           │
│ john@company.com        [Work ▼]                               │
│ john.doe@icloud.com     [Personal ▼]                           │
└────────────────────────────────────────────────────────────────┘

Calendars:
┌────────────────────────────────────────────────────────────────┐
│ Home                    [Personal ▼]                           │
│ Work                    [Work ▼]                               │
│ Shared Family           [Personal ▼]                           │
│ Project X               [Work ▼]                               │
└────────────────────────────────────────────────────────────────┘

Contact Groups:
┌────────────────────────────────────────────────────────────────┐
│ Family                  [Personal ▼]                           │
│ Friends                 [Personal ▼]                           │
│ Company Directory       [Work ▼]                               │
│ Clients                 [Work ▼]                               │
└────────────────────────────────────────────────────────────────┘
```

---

## LLM Routing Per Context

### Different Requirements

Personal and work contexts may have different LLM routing requirements:

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth > Settings > AI Configuration                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PERSONAL CONTEXT                                               │
│  ─────────────────                                              │
│  LLM Provider: [Claude API ▼]                                   │
│  Routing Mode: [Orchestrated Hybrid ▼]                          │
│  Privacy Weight: [────●───] Balanced                            │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  WORK CONTEXT                                                   │
│  ─────────────────                                              │
│  LLM Provider: [Local Only ▼]  ⚠️ Corporate policy              │
│  Routing Mode: [Local Only ▼]                                   │
│  Privacy Weight: N/A (always local)                             │
│                                                                 │
│  ℹ️ Work context is configured for local-only processing.       │
│     No work data will be sent to external APIs.                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Policy Enforcement

Work context may have stricter requirements:

```swift
struct ContextPolicy {
    var context: Context  // .personal or .work

    // LLM restrictions
    var allowCloudAPI: Bool
    var allowedProviders: [LLMProvider]
    var requireLocalOnly: Bool

    // Data restrictions
    var allowDataExport: Bool
    var retentionPeriodDays: Int?
    var requireAuditLog: Bool

    // Feature restrictions
    var allowProactiveMessages: Bool
    var allowCrossContextSuggestions: Bool  // Always false for work
}

// Example: Strict work policy
let workPolicy = ContextPolicy(
    context: .work,
    allowCloudAPI: false,           // No cloud APIs
    allowedProviders: [.localMLX],  // Local only
    requireLocalOnly: true,
    allowDataExport: false,         // Can't export work data
    retentionPeriodDays: 90,        // Auto-delete after 90 days
    requireAuditLog: true,          // Log all actions
    allowProactiveMessages: false,  // Don't initiate contact
    allowCrossContextSuggestions: false
)
```

---

## Cross-Context Boundaries

### What Can NEVER Cross

| Data Type | Reason |
|-----------|--------|
| Conversation content | Privacy, legal |
| Learned facts | Context contamination |
| Calendar event details | Scheduling conflicts reveal info |
| Email content | Confidentiality |
| Contact information | Relationship inference |
| Search history | Intent revelation |
| File contents | Intellectual property |

### What CAN Cross (User-Controlled)

| Data Type | Example | Requires |
|-----------|---------|----------|
| UI preferences | "Dark mode" | Automatic |
| Communication style | "Be brief" | Automatic |
| Time awareness | Current time/date | Automatic |
| Explicit user action | "Add this to work calendar" | Confirmation |

### Explicit Cross-Context Actions

Sometimes users legitimately need to move information between contexts:

```
User (Personal): "Add my dentist appointment to my work calendar
                  so I show as busy"

EmberHearth: "I'll add a 'Personal Appointment' block to your
             work calendar from 2-3pm on Tuesday.

             ⚠️ Only the time block will be shared, not the
             appointment details.

             [Confirm] [Cancel] [Show as 'Busy' instead]"
```

**Rules for cross-context actions:**
1. Always require explicit user request
2. Always show confirmation with what will be shared
3. Minimize information transfer (time block, not details)
4. Log the action for user review
5. Never infer or suggest cross-context actions

---

## Context Detection & Switching

### Primary Signal: iMessage Thread

The strongest context signal is which iMessage number/thread the user is messaging:

```swift
func determineContext(from message: iMessage) -> Context {
    // Primary: Which phone number received this?
    if message.recipientNumber == personalPhoneNumber {
        return .personal
    } else if message.recipientNumber == workPhoneNumber {
        return .work
    }

    // Fallback: Check thread history
    if let existingContext = threadContextMap[message.threadID] {
        return existingContext
    }

    // Unknown: Ask user (shouldn't happen with two-number setup)
    return .unknown
}
```

### macOS App Context

When using the macOS configuration app (not iMessage):

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth                                    [Personal ▼]    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Currently viewing: Personal Context                            │
│                                                                 │
│  [Switch to Work Context]                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Visual Differentiation

Contexts should be visually distinct in the macOS app:

| Element | Personal | Work |
|---------|----------|------|
| Accent color | Blue | Orange/Red |
| Icon badge | None | Briefcase |
| Status bar | "Personal" | "Work" |
| Background tint | Subtle blue | Subtle orange |

---

## Security Implications

### Separate Encryption Keys

Each context uses a different encryption key:

```swift
// Keys stored separately in Keychain
let personalKey = Keychain.get("com.emberhearth.personal.dbkey")
let workKey = Keychain.get("com.emberhearth.work.dbkey")

// Different Keychain access groups prevent cross-access
// Even if app is compromised, both contexts aren't exposed simultaneously
```

### Audit Logging (Work Context)

Work context may require audit trails:

```swift
struct AuditLogEntry {
    var timestamp: Date
    var action: String           // "query", "memory_write", "api_call"
    var summary: String          // Non-sensitive description
    var dataAccessed: [String]   // "calendar", "email", etc.
    var llmProvider: String      // "local_mlx", "none"
    var userId: String
}

// Work context logs all actions
// Personal context does NOT log by default (privacy)
```

### Data Retention Policies

Work context may have automatic data expiration:

```swift
// Work context: Auto-delete after retention period
func enforceRetentionPolicy(context: Context) {
    guard context == .work else { return }
    guard let retentionDays = workPolicy.retentionPeriodDays else { return }

    let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 86400))
    workDB.deleteMemoriesOlderThan(cutoffDate)
    workDB.deleteConversationsOlderThan(cutoffDate)
}
```

---

## Memory System Impact

### Dual Memory Architecture

This work/personal separation fundamentally shapes the memory system design:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Memory Architecture                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌───────────────────────────────┐   ┌───────────────────────────────┐    │
│   │     PERSONAL MEMORY GRAPH     │   │      WORK MEMORY GRAPH        │    │
│   │                               │   │                               │    │
│   │   Entities:                   │   │   Entities:                   │    │
│   │   • Family members            │   │   • Colleagues                │    │
│   │   • Friends                   │   │   • Clients                   │    │
│   │   • Doctors                   │   │   • Projects                  │    │
│   │   • Personal interests        │   │   • Deadlines                 │    │
│   │                               │   │                               │    │
│   │   Facts:                      │   │   Facts:                      │    │
│   │   • "Mom's birthday: March 5" │   │   • "Q3 deadline: Sept 30"   │    │
│   │   • "Allergic to shellfish"   │   │   • "Client prefers email"   │    │
│   │   • "Prefers morning gym"     │   │   • "Jenkins deploys at 2am" │    │
│   │                               │   │                               │    │
│   │   Retrieval:                  │   │   Retrieval:                  │    │
│   │   • Semantic search           │   │   • Semantic search           │    │
│   │   • Temporal queries          │   │   • Temporal queries          │    │
│   │   • Entity relationships      │   │   • Project associations      │    │
│   │                               │   │                               │    │
│   └───────────────────────────────┘   └───────────────────────────────┘    │
│                                                                             │
│   ════════════════════════════════════════════════════════════════════     │
│   These graphs NEVER connect. No edges cross the boundary.                 │
│   Even if the same person exists in both (rare), they're separate nodes.  │
│   ════════════════════════════════════════════════════════════════════     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Retrieval Is Context-Scoped

When EmberHearth retrieves memories, it only searches the current context:

```swift
func retrieveRelevantMemories(query: String, context: Context) -> [Memory] {
    // CRITICAL: Only search the current context's database
    let db = context == .personal ? personalDB : workDB

    // Never search both
    // Never merge results
    // Never suggest from other context

    return db.semanticSearch(query: query, limit: 10)
}
```

### No Cross-Context Learning

The system must never learn patterns that cross contexts:

```swift
// WRONG: Learning that spans contexts
func learnPattern(user: User) {
    // "User is stressed when they have both work deadlines
    //  and personal health appointments"
    // ❌ This crosses contexts!
}

// RIGHT: Context-isolated learning
func learnPattern(user: User, context: Context) {
    // Personal: "User prefers morning appointments"
    // Work: "User is most productive before noon"
    // ✓ Each learned independently
}
```

---

## Onboarding Flow

### Initial Setup

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth Setup                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  How will you use EmberHearth?                                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ○ Personal only                                         │   │
│  │    Just for personal life - no work separation needed    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ○ Work only                                             │   │
│  │    Just for work - no personal data will be stored       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ● Both personal and work (RECOMMENDED)                  │   │
│  │    Separate contexts with strict data isolation          │   │
│  │    Requires two iMessage-capable phone numbers           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│                                            [Continue →]         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Two-Number Setup

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth Setup > Phone Numbers                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EmberHearth uses two separate iMessage identities to keep      │
│  your personal and work lives completely separate.              │
│                                                                 │
│  Personal Assistant Phone Number:                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  +1 (___) ___-____                                       │   │
│  │  Linked to: john@icloud.com (personal Apple ID)          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Work Assistant Phone Number:                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  +1 (___) ___-____                                       │   │
│  │  Linked to: john@company.com (work Apple ID)             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  💡 Tip: You can use a second Apple ID or a service like       │
│     Google Voice for the second number.                         │
│                                                                 │
│                                            [Continue →]         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Account Mapping

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth Setup > Account Mapping                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Tell EmberHearth which accounts belong to which context.       │
│  This determines what data each assistant can access.           │
│                                                                 │
│  📧 Email Accounts                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  john@gmail.com              [Personal ▼]                │   │
│  │  john.doe@megacorp.com       [Work ▼]                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  📅 Calendars                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Home                        [Personal ▼]                │   │
│  │  MegaCorp                    [Work ▼]                    │   │
│  │  Kids Activities             [Personal ▼]                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  👥 Contact Groups                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  All Contacts                [Ask each time ▼]           │   │
│  │  Family                      [Personal ▼]                │   │
│  │  MegaCorp Directory          [Work ▼]                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│                                            [Continue →]         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Two-session iMessage monitoring
- [ ] Separate database creation and paths
- [ ] Context detection from phone number
- [ ] Basic account mapping UI
- [ ] Context indicator in macOS app

### Phase 2: Data Isolation
- [ ] Separate encryption keys per context
- [ ] Context-scoped memory retrieval
- [ ] Account-to-context routing for Calendar, Mail, Contacts
- [ ] Audit logging for work context

### Phase 3: LLM Routing
- [ ] Per-context LLM provider settings
- [ ] Per-context routing mode (cloud/local/hybrid)
- [ ] Policy enforcement (local-only for work)
- [ ] Context passed to self-tuning architecture

### Phase 4: Cross-Context Safety
- [ ] Explicit cross-context action confirmation
- [ ] Minimal information transfer
- [ ] Action logging
- [ ] No implicit cross-context suggestions

### Phase 5: Polish
- [ ] Visual differentiation (colors, icons)
- [ ] Context-specific notification settings
- [ ] Data retention policy enforcement
- [ ] Export/backup per context

---

## Future Considerations

### Enterprise Deployment (Out of Scope for v1)

While not the current focus, the architecture should not preclude future enterprise features:
- Admin-managed work policies
- Centralized configuration
- Compliance reporting
- Remote wipe of work context

### Team Features (Future)

- Shared work context across team members (with appropriate permissions)
- Delegated access (assistant can act on behalf of manager)
- Shared knowledge base (project documentation)

### Additional Contexts (Future)

Some users may want more than two contexts:
- Personal
- Work (Day Job)
- Side Project/Freelance
- Family Caregiver

Architecture should support N contexts, though UX complexity increases.

---

## Conclusion

**Work/Personal context separation is not optional.** Users will use EmberHearth for both domains whether we design for it or not. Responsible engineering requires:

1. **Hard data boundaries** between contexts
2. **Two iMessage sessions** for unambiguous context
3. **Separate memory databases** with no cross-contamination
4. **Different LLM routing** per context (work may require local-only)
5. **Explicit user action** for any cross-context data movement

This design enables EmberHearth to be a "genuine productivity instrument" in the professional space while maintaining the personal assistant experience—without compromising either.

The two-session model maps to how many users already think about work/personal separation (different phones, different email, different calendars). We're not inventing a new mental model; we're respecting the one users already have.
