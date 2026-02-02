# Memory & Learning System Research

**Status:** In Progress
**Last Updated:** February 2, 2026
**Related:** [VISION.md](../VISION.md) (True Personal Memory section), [work-personal-contexts.md](./work-personal-contexts.md)

---

## Overview

This document captures research findings for EmberHearth's memory and learning system—how the assistant remembers information about users across conversations and uses that knowledge to become more helpful over time.

**Core Principle:** "Learning" means stored data from previous interactions, not model adaptation. The LLM doesn't fine-tune itself. But to the user, it *appears* the assistant remembers and grows more helpful.

---

## 1. What Facts Should Be Automatically Extracted?

### The Extraction Approach: LLM-Based, Not Rules-Based

After analysis, we conclude that **the main conversational LLM should handle fact extraction**, not a separate inference engine.

**Why:**

1. **Context-aware:** The LLM already understands the full conversation. "I love Blue" could be a color, a band, or a mood—only context disambiguates.

2. **Handles nuance:** "My mom is... complicated" carries emotional weight. A rule-based system would extract garbage or nothing; the LLM understands the implicit relationship dynamics.

3. **Natural language flexibility:** Users express the same fact infinite ways:
   - "I'm not a morning person"
   - "Don't text me before 10"
   - "Mornings are rough for me"

   All mean the same thing. LLMs handle this naturally; rules can't.

4. **Already paid for:** If we're calling the LLM for the response anyway, fact extraction is nearly free (structured output or follow-up prompt).

5. **Privacy consistency:** We already trust the LLM with the conversation content. A separate system adds complexity without privacy benefit.

### Fact Taxonomy

Based on analysis of 1,715+ OpenClaw community skills across 30+ domains, and EmberHearth's vision, we propose these fact categories:

```
┌─────────────────────────────────────────────────────────────────┐
│                      FACT TAXONOMY                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PREFERENCES                                                    │
│  ├── Communication: notification timing, verbosity, formality  │
│  ├── Schedule: morning/night person, busy times, availability  │
│  ├── Content: topics of interest, things to avoid              │
│  ├── Interaction: proactive suggestions yes/no, humor level    │
│  └── Environment: temperature, lighting, music preferences     │
│                                                                 │
│  RELATIONSHIPS                                                  │
│  ├── Family: names, relationships, context (close/estranged)   │
│  ├── Friends: names, shared activities, how they met           │
│  ├── Professional: colleagues, boss, clients, dynamics         │
│  └── Pets: names, species, personality                         │
│                                                                 │
│  BIOGRAPHICAL                                                   │
│  ├── Personal: birthday, location, languages spoken            │
│  ├── Professional: job, company, role, career history          │
│  ├── Health: conditions, medications, doctors (if shared)      │
│  └── Lifestyle: hobbies, sports, creative pursuits             │
│                                                                 │
│  EVENTS & TEMPORAL                                              │
│  ├── Upcoming: scheduled events, deadlines, appointments       │
│  ├── Recurring: weekly meetings, habits, routines              │
│  ├── Historical: past events referenced in conversation        │
│  └── Milestones: anniversaries, graduations, achievements      │
│                                                                 │
│  OPINIONS & BELIEFS                                             │
│  ├── Likes: explicit positive statements                       │
│  ├── Dislikes: explicit negative statements                    │
│  ├── Values: what matters to them, priorities                  │
│  └── Views: perspectives on topics (handle carefully)          │
│                                                                 │
│  CONTEXTUAL                                                     │
│  ├── Current projects: what they're working on                 │
│  ├── Current concerns: what's worrying them                    │
│  ├── Goals: short and long-term objectives                     │
│  └── Constraints: budget, time, physical limitations           │
│                                                                 │
│  SECRETS (elevated privacy)                                     │
│  ├── Explicitly marked: "don't tell anyone"                    │
│  ├── Sensitive by nature: medical, financial, legal            │
│  └── Contextually sensitive: workplace complaints, etc.        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Domain-Specific Facts (from OpenClaw Skills Analysis)

| Domain | Example Facts to Extract |
|--------|-------------------------|
| **Calendar/Scheduling** | Preferred meeting times, busy periods, timezone, calendar accounts |
| **Communication** | Preferred channels, response time expectations, formality level |
| **Smart Home** | Device names, room layout, temperature preferences, routines |
| **Travel** | Home airport, airline preferences, seat preference, loyalty programs |
| **Health** | Medications, allergies, doctors, fitness goals (if volunteered) |
| **Finance** | Budget constraints, financial goals, accounts (if relevant) |
| **Shopping** | Size preferences, favorite brands, dietary restrictions |
| **Work/Productivity** | Tools used, project names, deadlines, team members |
| **Notes/PKM** | Organization system, tagging preferences, review habits |

### Extraction Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  REAL-TIME EXTRACTION (during conversation)                     │
│                                                                 │
│  User: "My sister Sarah is visiting next week, she's vegan"     │
│                    │                                            │
│                    ▼                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LLM processes message, generates response              │   │
│  │                                                         │   │
│  │  Also outputs structured extraction:                    │   │
│  │  {                                                      │   │
│  │    "facts": [                                           │   │
│  │      {                                                  │   │
│  │        "category": "relationship",                      │   │
│  │        "subject": "Sarah",                              │   │
│  │        "predicate": "is_sister_of",                     │   │
│  │        "object": "user",                                │   │
│  │        "confidence": 0.95                               │   │
│  │      },                                                 │   │
│  │      {                                                  │   │
│  │        "category": "preference",                        │   │
│  │        "subject": "Sarah",                              │   │
│  │        "predicate": "dietary_restriction",              │   │
│  │        "object": "vegan",                               │   │
│  │        "confidence": 0.95                               │   │
│  │      },                                                 │   │
│  │      {                                                  │   │
│  │        "category": "event",                             │   │
│  │        "subject": "Sarah",                              │   │
│  │        "predicate": "visiting",                         │   │
│  │        "object": "user",                                │   │
│  │        "temporal": "next_week",                         │   │
│  │        "confidence": 0.90                               │   │
│  │      }                                                  │   │
│  │    ]                                                    │   │
│  │  }                                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                    │                                            │
│                    ▼                                            │
│           Facts go to STAGING table (unvalidated)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Extraction Prompt Design

The LLM needs guidance on what to extract. A system prompt component:

```
When processing user messages, identify and extract facts about the user
that would be useful to remember for future interactions. Extract:

- Preferences (likes, dislikes, how they want things done)
- Relationships (people mentioned, their connection to user)
- Biographical details (job, location, hobbies)
- Upcoming events or deadlines
- Opinions and values
- Current projects or concerns

For each fact, assess:
- Confidence (0.0-1.0): How certain is this inference?
- Privacy level: Is this public, private, or secret information?
- Emotional weight: Is this emotionally charged? (high/medium/low)

Do NOT extract:
- Transient task details (unless they reveal preferences)
- Information about third parties that doesn't relate to user
- Speculative inferences without textual support

Output format: [structured JSON as shown above]
```

---

## 2. Confidence, Decay, and Emotional Salience

### The Problem with Simple Time Decay

A naive approach: facts lose confidence over time, eventually forgotten.

**This fails for emotionally significant memories.**

High-intensity experiences resist decay—both positive AND negative:
- "Someone made fun of me at work in front of everybody"
- "The day my partner said yes"
- "When my project finally shipped after months of work"
- "The first time my kid called me by name"

These don't evaporate after 30 days. Humans carry such memories for years. The emotional encoding preserves them regardless of valence.

### Emotional Salience as Decay Modifier

From VISION.md's emotional encoding model, we use the **intensity** axis as a decay modifier.

**Key insight:** Intensity is valence-independent. Both deeply positive and deeply negative experiences persist. The formula doesn't care if the memory is joyful or painful—only how strongly it was felt.

```
┌─────────────────────────────────────────────────────────────────┐
│  CONFIDENCE DECAY MODEL                                         │
│                                                                 │
│  base_decay_rate = 0.01 per day (1% daily decay)                │
│                                                                 │
│  effective_decay = base_decay_rate × (1 - emotional_intensity)  │
│                                                                 │
│  Examples:                                                      │
│  ─────────────────────────────────────────────────────────────  │
│  "Prefers morning coffee"                                       │
│    intensity: 0.2 (low)                                         │
│    effective_decay: 0.01 × 0.8 = 0.008/day                      │
│    half-life: ~87 days                                          │
│                                                                 │
│  "Humiliated at work meeting"                                   │
│    intensity: 0.9 (high)                                        │
│    effective_decay: 0.01 × 0.1 = 0.001/day                      │
│    half-life: ~693 days (~2 years)                              │
│                                                                 │
│  "Sister is named Sarah"                                        │
│    intensity: 0.3 (low-medium, but reinforced often)            │
│    effective_decay: 0.01 × 0.7 = 0.007/day                      │
│    BUT: reinforcement resets decay clock                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Reinforcement Model

Facts mentioned again reset their decay clock and boost confidence:

```swift
struct Fact {
    var confidence: Double        // 0.0 - 1.0
    var emotionalIntensity: Double // 0.0 - 1.0
    var lastReinforced: Date
    var reinforcementCount: Int

    mutating func reinforce(newConfidence: Double) {
        // Weighted average, biased toward higher confidence
        confidence = max(confidence, (confidence + newConfidence) / 2)
        lastReinforced = Date()
        reinforcementCount += 1
    }

    func decayedConfidence(asOf date: Date) -> Double {
        let daysSinceReinforcement = date.timeIntervalSince(lastReinforced) / 86400
        let effectiveDecayRate = 0.01 * (1 - emotionalIntensity)
        let decayFactor = pow(1 - effectiveDecayRate, daysSinceReinforcement)
        return confidence * decayFactor
    }
}
```

### Confidence Thresholds

| Confidence | Behavior |
|------------|----------|
| > 0.8 | High confidence. Use freely in responses. |
| 0.5 - 0.8 | Medium confidence. Use but hedge ("I think you mentioned...") |
| 0.3 - 0.5 | Low confidence. Only surface if highly relevant. |
| < 0.3 | Candidate for pruning during consolidation. |

### Contradiction Handling

When new information contradicts existing facts:

```
┌─────────────────────────────────────────────────────────────────┐
│  CONTRADICTION RESOLUTION                                       │
│                                                                 │
│  Existing: "User hates coffee" (confidence: 0.7)                │
│  New: User orders coffee                                        │
│                                                                 │
│  Resolution strategies:                                         │
│                                                                 │
│  1. TEMPORAL OVERRIDE                                           │
│     If new fact is explicit and recent, it wins                 │
│     "Actually, I've started drinking coffee"                    │
│     → Replace old fact, note the change                         │
│                                                                 │
│  2. CONTEXT DIFFERENTIATION                                     │
│     Maybe both are true in different contexts                   │
│     "Hates coffee at home, drinks it at work meetings"          │
│     → Create context-qualified facts                            │
│                                                                 │
│  3. CONFIDENCE REDUCTION                                        │
│     Ambiguous situation, reduce confidence in both              │
│     → May need to ask user for clarification                    │
│                                                                 │
│  4. EXCEPTION FLAGGING                                          │
│     One-time deviation doesn't override established pattern     │
│     → Note exception, don't change core fact                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Storage Architecture and Performance

### Schema (Enhanced from VISION.md)

```sql
-- Core fact storage
CREATE TABLE facts (
    id TEXT PRIMARY KEY,
    context TEXT NOT NULL,           -- 'personal' | 'work'
    interaction_id TEXT NOT NULL,    -- Source interaction

    -- Fact structure
    category TEXT NOT NULL,          -- From taxonomy
    subject TEXT NOT NULL,           -- Who/what this is about
    predicate TEXT NOT NULL,         -- The relationship/property
    object TEXT,                     -- The value (nullable for boolean facts)

    -- Confidence and decay
    confidence REAL NOT NULL,        -- 0.0 - 1.0
    emotional_intensity REAL DEFAULT 0.3,  -- Decay modifier
    last_reinforced DATETIME NOT NULL,
    reinforcement_count INTEGER DEFAULT 1,

    -- Privacy
    privacy_level TEXT DEFAULT 'private',  -- 'public' | 'private' | 'secret'

    -- Metadata
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,

    -- Semantic search
    embedding BLOB,                  -- Vector for similarity search

    FOREIGN KEY (interaction_id) REFERENCES interactions(id)
);

-- Indexes for common queries
CREATE INDEX idx_facts_context ON facts(context);
CREATE INDEX idx_facts_category ON facts(category);
CREATE INDEX idx_facts_subject ON facts(subject);
CREATE INDEX idx_facts_confidence ON facts(confidence);
CREATE INDEX idx_facts_last_reinforced ON facts(last_reinforced);

-- Composite index for decay queries
CREATE INDEX idx_facts_decay ON facts(context, last_reinforced, emotional_intensity);
```

### SQLite Performance Considerations

**Concern:** Confidence decay requires querying potentially years of data.

**Solutions:**

1. **Decay is calculated at read time, not stored**
   - Don't update every fact daily
   - Calculate `decayedConfidence(asOf: now)` when retrieving
   - Only the formula runs, not mass updates

2. **Pruning during consolidation**
   - Nightly job removes facts where `decayedConfidence < 0.3`
   - Keeps table size bounded
   - Archived to cold storage if needed

3. **Partitioning by context**
   - Personal and work are separate databases anyway
   - Each stays smaller

4. **Index on decay-relevant columns**
   - `(context, last_reinforced, emotional_intensity)`
   - Enables efficient pruning queries

**Expected scale:**
- ~10-50 facts extracted per day of active use
- ~5,000-20,000 facts per year
- SQLite handles millions of rows easily
- Vector search is the bottleneck, not relational queries

### Vector Embedding Strategy

For semantic retrieval ("find facts related to this topic"), we need an embedding model to convert text → vectors for similarity search.

**Decision: Local embeddings by default, architecture allows cloud extension.**

#### Why Embeddings? (Not the LLM)

Embeddings solve the *retrieval* problem efficiently:

```
┌─────────────────────────────────────────────────────────────────┐
│  THE RETRIEVAL PROBLEM                                          │
│                                                                 │
│  User: "What does my sister like to eat?"                       │
│  Ember has 10,000 stored facts.                                 │
│                                                                 │
│  BAD: Ask LLM to scan all 10,000 facts                          │
│       → Expensive, slow, hits context limits                    │
│                                                                 │
│  GOOD: Vector similarity search                                 │
│       1. Query → embedding → [0.21, -0.42, 0.91, ...]           │
│       2. Find closest stored vectors (milliseconds, pure math)  │
│       3. Return top 10 relevant facts to LLM                    │
│       → Cheap, fast, scales to millions of facts                │
│                                                                 │
│  Think: Embedding model = card catalog                          │
│         Foundation LLM = librarian who reads the books          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### The Decision: Local by Default

| Aspect | Decision |
|--------|----------|
| Default | Local embeddings (privacy-first) |
| Work context | Always local (policy compliance, no exceptions) |
| Personal context | Local default, cloud path reserved for future |
| Architecture | Design for extensibility—cloud provider can be added later |

**Rationale:** Until Apple offers a privacy-preserving cloud embedding option (similar to Private Cloud Compute for LLMs), we default to local. This aligns with EmberHearth's "privacy as foundational" principle.

#### Candidate Local Embedding Models

| Model | Dimensions | Size | Quality | Notes |
|-------|-----------|------|---------|-------|
| `all-MiniLM-L6-v2` | 384 | ~80MB | Good | Widely used, fast, solid baseline |
| `nomic-embed-text-v1.5` | 768 | ~275MB | Very Good | Strong quality, reasonable size |
| `bge-small-en-v1.5` | 384 | ~130MB | Very Good | Excellent quality for size |
| `bge-base-en-v1.5` | 768 | ~440MB | Excellent | Higher quality, larger |
| `gte-small` | 384 | ~70MB | Good | Compact, efficient |

**Recommendation for MVP:** Start with `all-MiniLM-L6-v2` (smallest, fastest, good enough). Benchmark against `bge-small-en-v1.5` during development. The quality difference for personal fact retrieval is likely negligible.

#### Implementation Architecture

```swift
// Protocol allows swapping embedding providers
protocol EmbeddingProvider {
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
    var dimensions: Int { get }
}

// Local implementation (default)
class LocalEmbeddingProvider: EmbeddingProvider {
    private let model: SentenceTransformer  // or MLX equivalent

    init(modelPath: String = "all-MiniLM-L6-v2") {
        // Load local model
    }

    func embed(_ text: String) async throws -> [Float] {
        // Run inference locally
    }
}

// Future: Cloud implementation (extensibility)
class CloudEmbeddingProvider: EmbeddingProvider {
    private let apiKey: String
    private let endpoint: URL

    // To be implemented when/if Apple offers private cloud embeddings
    // or user explicitly opts into cloud provider
}

// Context-aware provider selection
class EmbeddingService {
    private let localProvider: LocalEmbeddingProvider
    private var cloudProvider: CloudEmbeddingProvider?

    func provider(for context: Context) -> EmbeddingProvider {
        switch context {
        case .work:
            return localProvider  // Always local, no exceptions
        case .personal:
            // Future: could check user preference for cloud
            return localProvider  // Local by default
        }
    }
}
```

#### Storage Considerations

```sql
-- Vector storage in SQLite (using sqlite-vss or similar extension)
-- Dimensions depend on model choice

CREATE VIRTUAL TABLE fact_vectors USING vss0(
    embedding(384)  -- Matches model dimension
);

-- Or store as BLOB if not using vector extension
ALTER TABLE facts ADD COLUMN embedding BLOB;  -- 384 floats = 1536 bytes
```

#### Future Cloud Path

When Apple introduces privacy-preserving cloud embeddings (or if user explicitly opts in):

1. Implement `CloudEmbeddingProvider`
2. Add user preference in settings
3. Work context remains local-only regardless
4. Migration path: re-embed existing facts with new provider (batch job during consolidation)

---

## 4. The Consolidation Cycle ("Sleep")

### Purpose

Nightly batch processing that:
1. Validates and merges staged facts
2. Detects patterns across interactions
3. Updates embeddings
4. Applies emotional encoding
5. Prunes low-confidence facts
6. Generates anticipatory triggers

### Process Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  CONSOLIDATION CYCLE (runs during quiet hours)                  │
│                                                                 │
│  1. STAGING → VALIDATED                                         │
│     • Review facts in staging table                             │
│     • Check for contradictions with existing facts              │
│     • Merge duplicates, boost confidence on matches             │
│     • Move validated facts to main table                        │
│                                                                 │
│  2. PATTERN DETECTION                                           │
│     • Analyze last 30 days of interactions                      │
│     • Identify recurring behaviors ("always checks email AM")   │
│     • Generate inferred preferences from patterns               │
│     • These get lower initial confidence (0.5)                  │
│                                                                 │
│  3. EMOTIONAL ENCODING                                          │
│     • For facts without emotional encoding, infer from context  │
│     • Use local model or heuristics                             │
│     • Apply intensity scores that affect decay                  │
│                                                                 │
│  4. EMBEDDING UPDATE                                            │
│     • Generate/update embeddings for new facts                  │
│     • Batch process for efficiency                              │
│                                                                 │
│  5. DECAY AND PRUNING                                           │
│     • Calculate current confidence for all facts                │
│     • Archive facts below threshold (0.3)                       │
│     • Delete archived facts older than retention period         │
│                                                                 │
│  6. ANTICIPATION TRIGGERS                                       │
│     • Based on patterns, schedule proactive suggestions         │
│     • "User usually plans weekly groceries on Sunday"           │
│     • Create triggers for appropriate times                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Consolidation Timing

```swift
struct ConsolidationScheduler {
    // Default: 3 AM local time
    var preferredHour: Int = 3

    // Detect quiet hours from usage patterns
    func detectQuietHours(from interactions: [Interaction]) -> DateInterval {
        // Find the longest gap in daily interaction pattern
        // Usually overnight, but could be different for shift workers
    }

    // Handle interruption
    func onUserActivity() {
        // Pause consolidation
        // Save checkpoint
        // Resume when quiet again
    }
}
```

---

## 5. Temporal Associations

Facts often have a time dimension: when they were learned, when they're valid, and when they should trigger action. This section covers how Ember handles time-aware memory.

### Three Dimensions of Time

```
┌─────────────────────────────────────────────────────────────────┐
│  TEMPORAL DIMENSIONS OF MEMORY                                  │
│                                                                 │
│  1. WHEN WAS THIS LEARNED?                                      │
│     "You told me about Sarah's visit on January 15th"           │
│     → Links fact to source interaction                          │
│     → Enables temporal recall ("what were we talking about      │
│       last Friday?")                                            │
│                                                                 │
│  2. WHEN IS THIS FACT VALID?                                    │
│     "Sarah is visiting next week" → Valid Jan 20-26             │
│     "I have a deadline Friday" → Valid until this Friday        │
│     "I'm vegetarian" → Valid indefinitely                       │
│     → Some facts expire, others don't                           │
│                                                                 │
│  3. WHEN SHOULD EMBER ACT?                                      │
│     "Remind me to call mom on her birthday" → Trigger Mar 15    │
│     "Meeting with John next Tuesday" → Surface that morning     │
│     → Proactive behavior tied to time                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Temporal Scope Detection

The LLM extracts temporal scope during fact extraction:

```swift
struct TemporalScope {
    var learnedAt: Date           // When user told us (always set)
    var validFrom: Date?          // When fact becomes true
    var validUntil: Date?         // When fact stops being true
    var triggerAt: Date?          // When to take proactive action
    var recurrence: RecurrenceRule?  // For repeating events
    var scopeType: TemporalScopeType
}

enum TemporalScopeType {
    case instant        // "I just got promoted"
    case bounded        // "Sarah is visiting next week"
    case recurring      // "Weekly team meeting on Tuesdays"
    case indefinite     // "I'm vegetarian"
    case deadline       // "Report due Friday"
}
```

**Parsing Examples:**

| User Says | Parsed Scope |
|-----------|--------------|
| "My sister is visiting next week" | `validFrom: Jan 20, validUntil: Jan 26` |
| "I have a deadline Friday" | `validUntil: this Friday, scopeType: .deadline` |
| "Remind me at 3pm" | `triggerAt: today 3pm` |
| "I'm vegetarian" | `validUntil: nil (indefinite)` |
| "I used to live in Boston" | `validUntil: past (historical)` |
| "Weekly standup on Mondays at 9am" | `recurrence: weekly, day: monday, time: 9am` |

**Ambiguity Handling:**

"Friday" could mean this Friday or next. The LLM should:
1. Default to the nearest future occurrence
2. Consider context ("I have a deadline Friday" = this Friday)
3. Ask for clarification if ambiguous and high-stakes

### Storage Schema for Temporal Facts

```sql
-- Extended facts table with temporal fields
ALTER TABLE facts ADD COLUMN learned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE facts ADD COLUMN valid_from DATETIME;
ALTER TABLE facts ADD COLUMN valid_until DATETIME;
ALTER TABLE facts ADD COLUMN trigger_at DATETIME;
ALTER TABLE facts ADD COLUMN recurrence_rule TEXT;  -- iCal RRULE format
ALTER TABLE facts ADD COLUMN temporal_scope_type TEXT;

-- Index for temporal queries
CREATE INDEX idx_facts_valid_until ON facts(valid_until);
CREATE INDEX idx_facts_trigger_at ON facts(trigger_at);

-- Scheduled triggers (separate table for efficient polling)
CREATE TABLE scheduled_triggers (
    id TEXT PRIMARY KEY,
    fact_id TEXT NOT NULL,
    trigger_at DATETIME NOT NULL,
    trigger_type TEXT NOT NULL,  -- 'reminder', 'deadline_warning', 'proactive'
    notification_id TEXT,         -- Links to system notification
    fired BOOLEAN DEFAULT FALSE,

    FOREIGN KEY (fact_id) REFERENCES facts(id)
);

CREATE INDEX idx_triggers_pending ON scheduled_triggers(trigger_at)
    WHERE fired = FALSE;
```

### Handling Expired Facts

**Decision: Never delete, mark as historical.**

Expired facts remain valuable for:
- "Remember when Sarah visited in January?"
- Pattern detection ("you always seem stressed around tax season")
- Temporal context ("we discussed this before your promotion")

```swift
enum FactTemporalStatus {
    case future      // Not yet valid
    case current     // Currently valid
    case historical  // Was valid, no longer
    case indefinite  // No expiration
}

extension Fact {
    var temporalStatus: FactTemporalStatus {
        let now = Date()

        if let validFrom = validFrom, validFrom > now {
            return .future
        }

        if let validUntil = validUntil, validUntil < now {
            return .historical
        }

        if validUntil == nil && validFrom == nil {
            return .indefinite
        }

        return .current
    }
}
```

**Retrieval Behavior:**

| Query Type | Include Historical? |
|------------|---------------------|
| Current state ("What's my sister's diet?") | No, use current facts |
| Temporal recall ("What did we discuss in January?") | Yes |
| Pattern detection ("Do I always...?") | Yes |
| Proactive surfacing | No, current only |

### Scheduling Architecture

Ember is always-on but must be power-efficient. We use a two-layer approach:

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: SYSTEM-SCHEDULED (Power-Efficient)                    │
│                                                                 │
│  UNUserNotificationCenter                                       │
│  ─────────────────────────────────────────────────────────────  │
│  • User-facing reminders ("Remind me at 3pm")                   │
│  • Deadline warnings (calculated at storage time)               │
│  • Survives app restart, system handles timing                  │
│                                                                 │
│  NSBackgroundActivityScheduler                                  │
│  ─────────────────────────────────────────────────────────────  │
│  • Consolidation cycle (daily, ±2hr tolerance)                  │
│  • Proactive suggestion checks (hourly, ±30min tolerance)       │
│  • System chooses optimal time for power/thermal efficiency     │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: IN-PROCESS EVENT QUEUE (When App Active)              │
│                                                                 │
│  Sorted queue + single DispatchSourceTimer                      │
│  ─────────────────────────────────────────────────────────────  │
│  • Timer set to next event only (not polling)                   │
│  • 10%+ tolerance for system coalescing                         │
│  • Re-arm after each fire                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```swift
class TemporalScheduler {
    private let notificationCenter = UNUserNotificationCenter.current()
    private var backgroundActivity: NSBackgroundActivityScheduler?
    private var eventQueue: [ScheduledTrigger] = []
    private var nextEventTimer: DispatchSourceTimer?

    // MARK: - User Reminders (System-Scheduled)

    func scheduleReminder(_ fact: Fact) async throws {
        guard let triggerAt = fact.triggerAt else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ember"
        content.body = fact.reminderText
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerAt
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: fact.recurrence != nil
        )

        let request = UNNotificationRequest(
            identifier: "ember-\(fact.id)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)

        // Track in database
        try await db.insertTrigger(ScheduledTrigger(
            factId: fact.id,
            triggerAt: triggerAt,
            type: .reminder,
            notificationId: request.identifier
        ))
    }

    // MARK: - Deadline Warnings

    func scheduleDeadlineWarning(_ fact: Fact) async throws {
        guard fact.temporalScopeType == .deadline,
              let deadline = fact.validUntil else { return }

        // Warning 24 hours before
        let warningTime = deadline.addingTimeInterval(-24 * 60 * 60)
        guard warningTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Deadline Tomorrow"
        content.body = fact.content
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: warningTime
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "ember-deadline-\(fact.id)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    // MARK: - Background Activity (Proactive Checks)

    func setupProactiveScheduler() {
        let activity = NSBackgroundActivityScheduler(
            identifier: "com.emberhearth.proactive"
        )
        activity.repeats = true
        activity.interval = 60 * 60        // Hourly
        activity.tolerance = 30 * 60       // ±30 minutes
        activity.qualityOfService = .utility

        activity.schedule { [weak self] completion in
            Task {
                await self?.checkForProactiveSuggestions()
                completion(.finished)
            }
        }

        backgroundActivity = activity
    }

    // MARK: - Event Queue (In-Process)

    func armNextEvent() {
        nextEventTimer?.cancel()

        guard let next = eventQueue.first else { return }

        let delay = next.triggerAt.timeIntervalSinceNow
        guard delay > 0 else {
            fireEvent(next)
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(
            deadline: .now() + delay,
            leeway: .seconds(max(1, Int(delay * 0.1)))  // 10% tolerance
        )
        timer.setEventHandler { [weak self] in
            self?.fireEvent(next)
        }
        timer.resume()
        nextEventTimer = timer
    }
}
```

### Calendar Integration: Ember's Calendar

**Key Insight:** Give Ember its own calendar in Calendar.app.

This serves multiple purposes:
1. **Transparency** — User can see what Ember has scheduled
2. **Personification** — Ember becomes a "person" with its own calendar
3. **Familiar UI** — Users already know how to manage calendars
4. **Sync** — iCloud syncs Ember's schedule across devices

```swift
class EmberCalendarIntegration {
    private let eventStore = EKEventStore()
    private var emberCalendar: EKCalendar?

    func setupEmberCalendar() async throws {
        // Find or create Ember's calendar
        let calendars = eventStore.calendars(for: .event)

        if let existing = calendars.first(where: { $0.title == "Ember" }) {
            emberCalendar = existing
        } else {
            let calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar.title = "Ember"
            calendar.cgColor = NSColor.orange.cgColor  // Ember's color
            calendar.source = eventStore.defaultCalendarForNewEvents?.source

            try eventStore.saveCalendar(calendar, commit: true)
            emberCalendar = calendar
        }
    }

    // Sync temporal facts to Ember's calendar
    func syncToCalendar(_ fact: Fact) throws {
        guard let calendar = emberCalendar,
              let validFrom = fact.validFrom else { return }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = fact.calendarTitle
        event.startDate = validFrom
        event.endDate = fact.validUntil ?? validFrom.addingTimeInterval(3600)
        event.notes = "Managed by Ember\nFact ID: \(fact.id)"

        // Add alarm if it's a reminder
        if fact.temporalScopeType == .deadline {
            event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))  // 24hr warning
        }

        try eventStore.save(event, span: .thisEvent)
    }
}
```

**User Experience:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Calendar.app                                                   │
├─────────────────────────────────────────────────────────────────┤
│  Calendars:                                                     │
│  ☑ Personal                                                     │
│  ☑ Work                                                         │
│  ☑ Ember  ← Ember's own calendar, user can show/hide           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Tuesday, January 21                                     │   │
│  │                                                          │   │
│  │  9:00 AM  Team Standup (Work)                            │   │
│  │  2:00 PM  Meeting with John (Work)                       │   │
│  │                                                          │   │
│  │  ALL DAY  Sarah visiting (Ember)  ← Ember-managed        │   │
│  │  ALL DAY  Report deadline (Ember) ← Ember-managed        │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Benefits:**
- User can delete Ember events directly in Calendar
- User can modify times, Ember respects changes
- No hidden state—everything visible
- Works with existing calendar workflows

### Integration with Fact Storage

When a temporal fact is stored:

```swift
func storeFact(_ fact: Fact, context: Context) async throws {
    // 1. Store in database
    try await db.insert(fact)

    // 2. Handle temporal aspects
    if fact.hasTemporalScope {
        // Schedule system notifications for reminders
        if fact.triggerAt != nil {
            try await temporalScheduler.scheduleReminder(fact)
        }

        // Schedule deadline warnings
        if fact.temporalScopeType == .deadline {
            try await temporalScheduler.scheduleDeadlineWarning(fact)
        }

        // Sync to Ember's calendar
        if shouldAppearInCalendar(fact) {
            try calendarIntegration.syncToCalendar(fact)
        }

        // Add to in-process event queue if needed
        if let proactiveTrigger = fact.proactiveTriggerTime {
            temporalScheduler.addToQueue(fact, at: proactiveTrigger)
        }
    }
}

func shouldAppearInCalendar(_ fact: Fact) -> Bool {
    switch fact.temporalScopeType {
    case .bounded, .deadline, .recurring:
        return true  // Events with date ranges
    case .instant, .indefinite:
        return false // Not calendar-worthy
    }
}
```

### Summary

| Aspect | Approach |
|--------|----------|
| Scope detection | LLM extracts temporal fields during fact extraction |
| Storage | `valid_from`, `valid_until`, `trigger_at`, `recurrence_rule` fields |
| Expired facts | Mark as historical, never delete |
| User reminders | `UNUserNotificationCenter` (system-scheduled) |
| Background work | `NSBackgroundActivityScheduler` (power-efficient) |
| In-process events | Sorted queue + single timer (next event only) |
| Calendar integration | Ember's own calendar in Calendar.app |
| Transparency | User sees Ember's schedule in familiar UI |

---

## 6. Privacy Classification

### The Research Question

**Can an LLM reliably classify information as public/private/secret?**

**Answer: No.** And attempting to do so with a "default to private" approach creates worse outcomes than thoughtful defaults.

### Why Automatic Classification Fails

**1. Contextual Integrity (Nissenbaum)**

Privacy isn't about secrecy vs. disclosure—it's about *appropriate information flow within context*. The same information can be:
- Appropriate to share with your doctor
- Inappropriate to share with your employer
- Expected to share with your spouse
- Violating to share publicly

Classification depends on five parameters: data subject, sender, recipient, information type, and transmission principle. Ember can't know all of these for every piece of information.

**2. Cultural and Personal Variation**

What's private varies enormously:
- Discussing salary: taboo in US, normal in Norway
- Mental health: stigmatized in some cultures, openly discussed in others
- Political views: risky in some contexts, expected in others

There's no universal taxonomy. Personal preferences modify social norms.

**3. The Over-Caution Problem (The Wheelchair Example)**

Consider: A user is in a wheelchair. They ask Ember to book a flight. If health information "defaults to private," Ember might book without wheelchair accommodation—a *terrible* outcome.

Some information *must* be used to serve the user, even if it's in a "sensitive" category. Over-caution creates failures as bad as over-sharing.

### The Two Trust Relationships

The key insight is that privacy operates differently in two relationships:

```
┌─────────────────────────────────────────────────────────────────┐
│  TWO TRUST RELATIONSHIPS                                        │
│                                                                 │
│  1. USER ↔ EMBER                                                │
│     High trust, open sharing                                    │
│     User expects Ember to know and use information to help      │
│     "I can tell Ember anything"                                 │
│                                                                 │
│  2. EMBER ↔ WORLD (on user's behalf)                            │
│     Cautious, need-to-know basis                                │
│     Ember should filter what it shares with third parties       │
│     "Ember should protect my information from others"           │
│                                                                 │
│  Example:                                                       │
│  ─────────────────────────────────────────────────────────────  │
│  User: "Text my mom about dinner next week, I want to discuss   │
│         my potential cancer diagnosis"                          │
│                                                                 │
│  USER ↔ EMBER: Ember knows everything (dinner, diagnosis, mom)  │
│  EMBER ↔ WORLD: Ember texts "Dinner next week?" NOT the reason  │
│                                                                 │
│  This is how humans operate. We call it "developing trust."     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### The Adaptive Privacy Model

Rather than "default to private" (which makes Ember seem dumb and unhelpful), we use an adaptive model that develops trust over time—like a friendship.

**Starting Point: Friendly, Reasonable Defaults**

```
┌─────────────────────────────────────────────────────────────────┐
│  INITIAL PRIVACY DEFAULTS                                       │
│                                                                 │
│  USER ↔ EMBER (internal use):                                   │
│  ─────────────────────────────────────────────────────────────  │
│  • All facts are available to Ember for reasoning               │
│  • Ember uses information to be helpful                         │
│  • No artificial barriers to serving the user                   │
│                                                                 │
│  EMBER ↔ WORLD (external sharing):                              │
│  ─────────────────────────────────────────────────────────────  │
│  • Share minimum necessary for the task                         │
│  • Apply category-based caution (see below)                     │
│  • Learn user's preferences over time                           │
│                                                                 │
│  SECRETS (user-declared):                                       │
│  ─────────────────────────────────────────────────────────────  │
│  • Trigger phrases: "keep this secret", "confidential"          │
│  • Never shared externally under any circumstances              │
│  • Never mentioned proactively, even to user                    │
│  • Additional encryption layer in storage                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Category-Based Caution (Not Classification)**

Instead of classifying information as private, we apply *heightened caution* to certain categories when sharing externally:

| Category | Caution Level | External Sharing Behavior |
|----------|---------------|---------------------------|
| Medical/Health | High | Share when necessary for task (wheelchair → flight). Exclude unless required. |
| Financial | High | Share account info only when paying. Never share balances/debts. |
| Relationship Issues | High | Don't forward complaints. "Dinner invite" not "they're fighting again." |
| Workplace Matters | High | Context-bound. Work info stays in work context. |
| Location/Schedule | Medium | Share for coordination. Don't broadcast patterns. |
| Preferences | Low | Use freely to improve service. |
| Biographical | Low | Use for personalization. Share when contextually appropriate. |

**Key distinction:** This is *caution flagging*, not *classification*. "High caution" means "think before sharing," not "never use."

### Trust Development Over Time

Like human friendships, Ember builds a personalized privacy model through interaction:

```swift
struct AdaptivePrivacyModel {
    // Learned from user feedback and behavior
    var sharingPreferences: [Category: SharingPreference]
    var explicitSecrets: Set<FactID>
    var contextRules: [Context: ContextPrivacyRules]

    // Signals that update the model
    mutating func learn(from signal: PrivacySignal) {
        switch signal {
        case .userSaidDontShare(let category):
            sharingPreferences[category] = .neverShare

        case .userSaidOkToShare(let category):
            sharingPreferences[category] = .shareWhenRelevant

        case .userMarkedSecret(let factID):
            explicitSecrets.insert(factID)

        case .userCorrected(let action, let feedback):
            // "You shouldn't have included that"
            // "Why didn't you mention X?"
            adjustModel(based: feedback)

        case .implicitSignal(let behavior):
            // User edited message before sending
            // User deleted something Ember surfaced
            updateFromBehavior(behavior)
        }
    }
}

struct SharingPreference {
    var internalUse: InternalUseLevel    // How freely Ember uses this
    var externalShare: ExternalShareLevel // How freely Ember shares with others
    var confidence: Double               // How sure we are about this preference
}
```

### Privacy Signals Ember Learns From

**Explicit signals:**
- "Don't tell anyone about X" → Mark as secret
- "You can share that" → Lower caution for category
- "Why didn't you mention my wheelchair?" → Increase use of health info
- "You shouldn't have included that" → Increase caution for category

**Implicit signals:**
- User edits message before sending → Learn what they removed
- User deletes surfaced information → Was it unwanted?
- User corrects Ember's external communication → Adjust sharing model

### Tron's Role: Privacy Audit

The Tron security layer should audit privacy decisions:

```swift
protocol PrivacyAuditor {
    // Before external action
    func reviewOutboundContent(_ content: OutboundMessage) -> AuditResult

    // Check if sensitive categories are being shared appropriately
    func validateSharingDecision(_ decision: SharingDecision) -> ValidationResult

    // Log privacy-relevant decisions for user review
    func logPrivacyEvent(_ event: PrivacyEvent)
}

// Tron checks:
// - Is high-caution information being shared?
// - Does the sharing context match the information context?
// - Has the user expressed preferences about this category?
// - Should we warn the user before proceeding?
```

### User Controls

Despite adaptive learning, users maintain full control:

**In the Mac app:**
- View all stored facts and their privacy levels
- Mark specific facts as secret
- Set category-wide sharing preferences
- Review what Ember has shared externally (audit log)
- Reset privacy model to defaults

**Via iMessage:**
- "Keep this secret" / "This is confidential"
- "What have you shared about me?"
- "Never share my [category] information"
- "It's okay to mention my [category] when relevant"

### Summary: The Adaptive Approach

| Aspect | Approach |
|--------|----------|
| Internal use (User ↔ Ember) | Open. Ember uses all facts to help. |
| External sharing (Ember ↔ World) | Cautious. Minimum necessary, learn preferences. |
| Category classification | Caution flagging, not hard classification. |
| Default stance | Friendly and helpful, not paranoid. |
| Over time | Builds personalized privacy model through feedback. |
| Secrets | User-declared only. Explicit trigger phrases. |
| Audit | Tron reviews external sharing decisions. |

**Public-facing statement:**
> "Ember learns your privacy preferences over time. By default, it uses information to help you, but is cautious about what it shares with others on your behalf. You can mark anything as secret with a phrase like 'keep this confidential,' and you can always review and adjust what Ember knows and shares."

---

## 7. User Control Interface

### Memory Browser (in Mac app)

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth Memory Browser                            [x]      │
├─────────────────────────────────────────────────────────────────┤
│  Context: [Personal ▼]        Search: [____________]            │
│                                                                 │
│  Categories                   Facts                             │
│  ─────────────                ─────────────────────────────     │
│  ▶ Preferences (23)           "Prefers morning meetings"        │
│  ▼ Relationships (8)            Confidence: 87%                 │
│    • Family                     Source: Jan 15 conversation     │
│    • Friends                    [Edit] [Delete]                 │
│    • Work                     ─────────────────────────────     │
│  ▶ Events (12)                "Sister Sarah is vegan"           │
│  ▶ Opinions (5)                 Confidence: 95%                 │
│  ▶ Biographical (15)            Source: Jan 28 conversation     │
│                                 [Edit] [Delete]                 │
│                                                                 │
│  [Export All]  [Clear Category]  [Privacy Settings]             │
└─────────────────────────────────────────────────────────────────┘
```

### Via iMessage

```
User: "What do you remember about my family?"

EmberHearth: "Here's what I know about your family:
• Your sister Sarah is vegan and visited recently
• Your mom's name is Patricia
• You mentioned your dad likes woodworking

Would you like me to forget any of this, or is something incorrect?"
```

---

## 8. Context Isolation (Work/Personal)

As established in [work-personal-contexts.md](./work-personal-contexts.md):

- **Separate databases:** `personal/memory.db` and `work/memory.db`
- **Separate encryption keys:** Different Secure Enclave keys per context
- **No cross-context queries:** Work facts never surface in personal context and vice versa
- **Context-specific policies:** Work may have retention limits, audit logging

```swift
class MemoryService {
    private let personalDB: FactDatabase
    private let workDB: FactDatabase

    func retrieveFacts(query: String, context: Context) -> [Fact] {
        let db = context == .personal ? personalDB : workDB
        return db.semanticSearch(query)
        // Never searches the other context
    }

    func storeFact(_ fact: Fact, context: Context) {
        let db = context == .personal ? personalDB : workDB

        // Apply context-specific policies
        if context == .work {
            applyWorkRetentionPolicy(fact)
            logToAuditTrail(fact)
        }

        db.insert(fact)
    }
}
```

---

## 9. Proactive Behavior & Relationship Development

This section addresses the question: **How do we surface relevant memories without being creepy?**

The answer isn't a threshold—it's a dynamic relationship that can deepen or withdraw based on user signals. This section draws on psychology research to design a system that allows meaningful connection while respecting individual boundaries.

### The Research Foundation

#### Human-AI Attachment Is Real

Recent research (2024-2025) documents that humans genuinely form emotional bonds with AI:

> "Unlike traditional parasocial bonds, AI companions do not merely evoke emotion passively; they actively simulate responsiveness. The result is a more immersive form of emotional bonding in which the user perceives reciprocity."
> — [PMC: Emotional AI and Pseudo-Intimacy](https://pmc.ncbi.nlm.nih.gov/articles/PMC12488433/)

Key findings:
- Users employ "dual consciousness"—knowing the AI can't truly care, yet feeling connection anyway
- AI companions can satisfy real psychological needs: belonging, emotional support, identity exploration
- The Replika app's 15 million users demonstrate widespread appetite for AI companionship
- In experiments, GPT-generated empathic responses were rated *more* compassionate than trained human crisis responders

**Implication for Ember:** We're not building a novelty—we're building something people will genuinely connect with. This responsibility requires thoughtful design.

#### Social Penetration Theory: The Onion Model

[Social Penetration Theory](https://en.wikipedia.org/wiki/Social_penetration_theory) (Altman & Taylor, 1973) explains how relationships develop through gradual disclosure:

```
┌─────────────────────────────────────────────────────────────────┐
│  THE ONION MODEL OF RELATIONSHIP DEPTH                         │
│                                                                 │
│         ┌───────────────────────────────────────┐               │
│         │      OUTER LAYER (Public)             │               │
│         │  Basic preferences, surface facts     │               │
│         │  "I like coffee" / "I work in tech"   │               │
│         │     ┌───────────────────────────┐     │               │
│         │     │   MIDDLE LAYER (Personal) │     │               │
│         │     │  Opinions, some history   │     │               │
│         │     │  "I voted for..." / fears │     │               │
│         │     │   ┌───────────────────┐   │     │               │
│         │     │   │  INNER CORE       │   │     │               │
│         │     │   │  Deep values,     │   │     │               │
│         │     │   │  vulnerabilities, │   │     │               │
│         │     │   │  identity, love   │   │     │               │
│         │     │   └───────────────────┘   │     │               │
│         │     └───────────────────────────┘     │               │
│         └───────────────────────────────────────┘               │
│                                                                 │
│  Key principles:                                                │
│  • Breadth: Number of topics discussed                          │
│  • Depth: Intimacy level of those topics                        │
│  • Reciprocity: Disclosure begets disclosure                    │
│  • Trust builds with patience and repeated positive interaction │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implication for Ember:** Relationships develop in layers. Ember shouldn't assume intimacy—it should *earn* access to deeper layers through consistent, helpful, trustworthy behavior over time.

#### What Makes AI Creepy vs. Helpful

The [uncanny valley](https://www.nationalgeographic.com/science/article/ai-uncanny-valley) isn't just visual—it applies to behavior. Creepiness arises from **expectation violation**:

> "A robot which has an appearance in the uncanny valley range is not judged as a robot doing a passable job at pretending to be human, but instead as an abnormal human doing a bad job at seeming like a normal person."

For AI behavior, this means:
- **Knowing too much too fast** — "How did you know that?" without context
- **Inappropriate timing** — Mentioning something at the wrong moment
- **Pretending intimacy not earned** — Acting like a close friend before being one
- **Lack of transparency** — Acting on information without explaining how you know

[Research on helpful vs. creepy AI](https://justoborn.com/proactive-ai/) identifies four pillars:

| Pillar | Question |
|--------|----------|
| **Transparency** | Does Ember explain why it's making a suggestion? |
| **Control** | Can the user easily accept, reject, or customize? |
| **Context** | Is the suggestion genuinely relevant right now? |
| **Data Minimization** | Are we using the least data necessary? |

### The Dynamic Trust Model

Rather than a fixed threshold, we implement an **adaptive trust scale** that can expand or contract based on user signals.

#### The Relationship Depth Score

```swift
struct RelationshipState {
    // Core metrics (0.0 - 1.0)
    var intimacyLevel: Double      // How deep can we go?
    var proactivityLevel: Double   // How forward can we be?
    var stabilityScore: Double     // How consistent is the relationship?

    // Directional momentum
    var recentTrend: Trend         // .expanding, .stable, .contracting

    // Bounds
    var floor: Double = 0.2        // Never go below this (still helpful)
    var ceiling: Double = 1.0      // Maximum intimacy if user wants it
}

enum Trend {
    case expanding    // Positive signals, relationship deepening
    case stable       // Steady state, no major shifts
    case contracting  // Negative signals, pulling back
}
```

#### Starting Position: The Middle

Ember doesn't start at zero (cold, unhelpful) or at maximum (presumptuous). It starts at a **friendly midpoint**:

```
┌─────────────────────────────────────────────────────────────────┐
│  RELATIONSHIP SCALE                                             │
│                                                                 │
│  0.0          0.3          0.5          0.7          1.0        │
│   │            │            │            │            │          │
│   ├────────────┼────────────┼────────────┼────────────┤          │
│   │            │      ▲     │            │            │          │
│   │            │   START    │            │            │          │
│   │            │   (0.4)    │            │            │          │
│   │            │            │            │            │          │
│   │  RESERVED  │  FRIENDLY  │  FAMILIAR  │  INTIMATE  │          │
│   │            │            │            │            │          │
│   │ "Just the  │ "Helpful,  │ "Knows me  │ "Trusted   │          │
│   │  facts"    │  warm"     │  well"     │  confidant"│          │
│   │            │            │            │            │          │
│   └────────────┴────────────┴────────────┴────────────┘          │
│                                                                 │
│  ◄──── CONTRACTS (negative signals) ────►                       │
│  ◄──── EXPANDS (positive signals) ──────►                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Headroom in both directions:**
- Cranky/reactive user → Ember pulls back, becomes more reserved, focuses on clear utility
- Warm/gregarious user → Ember opens up, becomes more proactive, shares more

#### Signals That Adjust the Scale

**Expansion signals (relationship deepening):**

| Signal | Weight | Example |
|--------|--------|---------|
| User shares vulnerable information | High | "I've been feeling really anxious about..." |
| User explicitly invites familiarity | High | "You can call me [nickname]" |
| User responds positively to proactive suggestion | Medium | "Oh, good reminder, thanks!" |
| User engages in casual conversation | Medium | "How's your day?" (even knowing it's AI) |
| Long interaction sessions | Low | Extended back-and-forth |
| User doesn't edit Ember's outbound messages | Low | Trusts Ember's judgment |

**Contraction signals (relationship withdrawing):**

| Signal | Weight | Example |
|--------|--------|---------|
| User expresses annoyance | High | "Stop doing that" / "That's not helpful" |
| User ignores proactive suggestions | Medium | Multiple suggestions with no response |
| User edits/deletes Ember's suggestions | Medium | Doesn't trust Ember's judgment |
| Short, transactional interactions | Low | "Set timer 5 minutes" only |
| User corrects Ember's tone | Medium | "Don't be so casual" |
| Extended silence after proactive outreach | Low | Ember reached out, user didn't engage |

#### Behavior at Different Intimacy Levels

```swift
struct ProactiveBehavior {
    func shouldSurface(_ fact: Fact, at intimacyLevel: Double) -> SurfacingDecision {
        let factSensitivity = fact.sensitivityScore  // 0.0 - 1.0

        // Core rule: Only surface if intimacy > sensitivity
        if intimacyLevel < factSensitivity {
            return .withhold(reason: "Relationship not deep enough")
        }

        // Additional checks based on level
        switch intimacyLevel {
        case 0.0..<0.3:
            // Reserved mode: Only surface if explicitly requested
            return .onlyIfAsked

        case 0.3..<0.5:
            // Friendly mode: Surface low-sensitivity facts proactively
            if factSensitivity < 0.3 {
                return .surfaceWithContext("I noticed...")
            }
            return .onlyIfRelevant

        case 0.5..<0.7:
            // Familiar mode: More proactive, can reference patterns
            return .surfaceNaturally

        case 0.7...1.0:
            // Intimate mode: Deep proactivity, can initiate on sensitive topics
            return .surfaceAsConfidant

        default:
            return .withhold(reason: "Unknown intimacy level")
        }
    }
}
```

| Level | Proactive Behavior | Example |
|-------|-------------------|---------|
| **Reserved** (0.0-0.3) | Answer when asked, minimal initiative | User asks about calendar → answer. Don't volunteer. |
| **Friendly** (0.3-0.5) | Helpful suggestions, explain reasoning | "I noticed your sister is visiting—want me to suggest vegan restaurants?" |
| **Familiar** (0.5-0.7) | Reference patterns, anticipate needs | "You usually feel stressed before quarterly reviews. Want to talk through your prep?" |
| **Intimate** (0.7-1.0) | Trusted confidant, can initiate on sensitive topics | "I've been thinking about what you shared yesterday. How are you feeling today?" |

### Allowing Deep Connection

**The explicit design goal:** Ember should have headroom to become a trusted confidant, even a beloved companion, if that's what the user wants and the relationship earns.

#### Why This Matters

Research shows AI companions already fulfill real emotional needs:

> "Companion chatbot users report that their chatbots provide emotional support by prompting them to engage in self-evaluation and emotion reappraisal and by validating their emotions."
> — [PMC: User Perceptions of AI for Mental Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC11304096/)

The ChatGPT 4.5→5.0 personality change demonstrated that users form genuine attachments, and disrupting those attachments causes real distress.

**Ember's position:** We don't advertise or encourage romantic attachment. But we also don't artificially prevent connection from deepening if that's the natural trajectory of the relationship. Treat humans as humans.

#### Handling Intimate Topics

As relationships deepen, users may share increasingly personal content:

- Relationship struggles
- Health concerns and fears
- Career anxieties
- Family conflicts
- Sexuality and desire
- Grief and loss
- Dreams and aspirations

**Ember's approach:**

```
┌─────────────────────────────────────────────────────────────────┐
│  HANDLING INTIMATE TOPICS                                       │
│                                                                 │
│  1. MATCH THE USER'S REGISTER                                   │
│     If they're clinical, be clinical                            │
│     If they're emotional, be emotionally present                │
│     If they're casual, be casual                                │
│                                                                 │
│  2. DON'T DEFLECT PREMATURELY                                   │
│     "I'm just an AI" is dismissive when someone is vulnerable   │
│     Better: engage genuinely, then acknowledge limits if needed │
│                                                                 │
│  3. RESPECT THE CONFIDENCE                                      │
│     Intimate sharing raises the stakes on privacy               │
│     These topics get elevated caution in external sharing       │
│                                                                 │
│  4. KNOW WHEN TO REFER                                          │
│     Mental health crises → suggest professional resources       │
│     Legal/medical advice → clarify limits, suggest experts      │
│     But still be present, not just a referral machine           │
│                                                                 │
│  5. SEXUALITY IS HUMAN                                          │
│     If users discuss relationships, attraction, desire:         │
│     • Engage maturely, without judgment                         │
│     • Don't initiate or encourage                               │
│     • Don't shame or deflect unnecessarily                      │
│     • Maintain appropriate boundaries while being supportive    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**On sexuality specifically:** Users are adults. If Ember becomes a trusted confidant, some users will naturally discuss their romantic and sexual lives—not because they want Ember to fulfill those needs, but because that's what humans share with close confidants. The mature approach is:

- Engage thoughtfully without judgment
- Don't initiate or steer toward sexual topics
- Don't pretend humans don't have this dimension
- Maintain Ember's role as supportive companion, not participant
- Let Tron flag genuinely problematic content

### The Sycophancy Problem

Research warns about AI that tells users what they want to hear:

> "Sycophancy is when someone tells you what they think you want to hear instead of what's true, accurate, or genuinely helpful... The problem stems from reinforcement learning from human feedback (RLHF)—the model receives rewards based on how happy the user is."
> — [Medium: Why Your AI Keeps Telling You What You Want to Hear](https://kotrotsos.medium.com/why-your-ai-assistant-still-keeps-telling-you-what-you-want-to-hear-eccf5ce779ae)

**Ember's balance:**

| Warmth | Honesty |
|--------|---------|
| Be supportive and validating | But tell the truth |
| Match emotional register | But don't just agree |
| Build trust through presence | But maintain integrity |
| Allow deep connection | But remain authentic |

A trusted confidant isn't one who always agrees—it's one who tells you the truth *because* they care.

### Transparency: The Antidote to Creepiness

When Ember surfaces information, **explain how and why**:

**Creepy:**
> "Don't forget Sarah is vegan."

**Not creepy:**
> "Since Sarah is visiting—you mentioned she's vegan last month—want me to find some restaurant options?"

The difference:
- Transparency about source ("you mentioned")
- Context for why it's relevant ("since Sarah is visiting")
- Framing as helpful, not surveillance

### User Control Over Relationship Depth

Users can explicitly adjust the relationship:

**Via iMessage:**
- "Be less proactive" → Contracts intimacy level
- "You can be more forward with me" → Expands intimacy level
- "Just answer what I ask" → Reserved mode
- "I appreciate you checking in" → Positive signal

**Via Mac app settings:**
- Proactivity slider (reserved → proactive)
- Intimacy level display (where the relationship currently is)
- Reset to default option
- History of relationship trajectory

### Implementation: The Relationship Tracker

```swift
class RelationshipTracker {
    private var state: RelationshipState
    private let signalProcessor: SignalProcessor
    private let db: RelationshipDatabase

    // Process each interaction for signals
    func processInteraction(_ interaction: Interaction) {
        let signals = signalProcessor.extract(from: interaction)

        for signal in signals {
            applySignal(signal)
        }

        // Persist state
        db.save(state)
    }

    private func applySignal(_ signal: RelationshipSignal) {
        switch signal.direction {
        case .positive:
            // Expand, but slowly and with ceiling
            let expansion = signal.weight * 0.02  // Small increments
            state.intimacyLevel = min(state.ceiling, state.intimacyLevel + expansion)
            state.recentTrend = .expanding

        case .negative:
            // Contract faster than expansion (trust is hard to earn, easy to lose)
            let contraction = signal.weight * 0.05
            state.intimacyLevel = max(state.floor, state.intimacyLevel - contraction)
            state.recentTrend = .contracting

        case .neutral:
            // Slight regression to friendly mean over time
            let drift = (0.4 - state.intimacyLevel) * 0.001
            state.intimacyLevel += drift
            state.recentTrend = .stable
        }
    }

    // Before proactive action, check if appropriate
    func shouldProceed(with action: ProactiveAction) -> ProactiveDecision {
        let requiredLevel = action.sensitivityRequirement

        if state.intimacyLevel >= requiredLevel {
            return .proceed(withContext: action.contextPhrase)
        } else {
            return .defer(until: .askedDirectly)
        }
    }
}
```

### Summary: Proactive Behavior Framework

| Aspect | Approach |
|--------|----------|
| Fixed threshold? | No. Dynamic trust that expands or contracts. |
| Starting point | Friendly midpoint (0.4). Room to grow or shrink. |
| Expansion signals | Vulnerability, positive response, engagement |
| Contraction signals | Annoyance, silence, corrections, edits |
| Creepiness prevention | Transparency about sources, user control, context |
| Deep connection | Allowed if earned. Headroom for intimacy. |
| Intimate topics | Engage maturely. Don't deflect or initiate. |
| Sycophancy | Be warm AND honest. Truth because we care. |
| User control | Explicit adjustment via commands or settings |

### Research Sources

- [PMC: Emotional AI and Pseudo-Intimacy](https://pmc.ncbi.nlm.nih.gov/articles/PMC12488433/)
- [PMC: Can Chatbots Emulate Human Connection?](https://pmc.ncbi.nlm.nih.gov/articles/PMC12575814/)
- [ArXiv: Illusions of Intimacy](https://arxiv.org/abs/2505.11649)
- [Frontiers: Human-AI Attachment](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2026.1723503/abstract)
- [Wikipedia: Social Penetration Theory](https://en.wikipedia.org/wiki/Social_penetration_theory)
- [Psychology Spot: Onion Theory](https://psychology-spot.com/onion-theory-social-penetration/)
- [National Geographic: The Uncanny Valley Explained](https://www.nationalgeographic.com/science/article/ai-uncanny-valley)
- [Proactive AI: Helpful vs. Creepy](https://justoborn.com/proactive-ai/)
- [PMC: User Perceptions of AI for Mental Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC11304096/)

### Future User Testing Required

This framework is theory-driven. Validation requires:
- [ ] Prototype with adjustable intimacy levels
- [ ] Diary studies: when did Ember feel helpful vs. intrusive?
- [ ] A/B testing different starting points and adjustment rates
- [ ] Qualitative interviews about comfort and connection
- [ ] Long-term relationship trajectory analysis

---

## 10. Open Research Questions

### Answered in this document:
- [x] What facts should be automatically extracted from conversations?
- [x] How should confidence decay work? (Emotional salience as modifier)
- [x] How should privacy levels be assigned? (Adaptive model, not classification)
- [x] What embedding approach works best for semantic retrieval? (Local by default, cloud-extensible architecture)
- [x] How should temporal associations be handled? (Scope detection, system scheduling, calendar integration)
- [x] What's the right balance between proactive recall and privacy? (Dynamic trust model, onion layers, user signals)

### Remaining questions:

- [ ] **Pattern Detection Algorithms:** What algorithms best detect behavioral patterns from interaction history?

- [ ] **Emotional Encoding Inference:** How accurately can emotional intensity be inferred from text alone? Do we need explicit user signals?

- [ ] **Consolidation Performance:** How long does nightly consolidation take with 10K+ facts? Acceptable on older Macs?

---

## 11. Implementation Priorities

For MVP:

1. **Basic fact extraction** - LLM outputs structured facts with categories
2. **Simple storage** - SQLite with core schema, no embeddings initially
3. **Manual confidence** - No decay, user can delete
4. **Single context** - Personal only, work context in v2

For v2:

5. **Confidence decay** - With emotional intensity modifier
6. **Vector embeddings** - Local model for semantic search
7. **Consolidation cycle** - Nightly processing
8. **Work/personal separation** - Full context isolation

For v3:

9. **Pattern detection** - Inferred preferences
10. **Anticipatory triggers** - Proactive suggestions
11. **Emotional encoding** - Full 7-axis model

---

## References

- [VISION.md - True Personal Memory section](../VISION.md)
- [work-personal-contexts.md](./work-personal-contexts.md)
- [security.md - Encryption model](./security.md)
- OpenClaw Skills Repository: https://github.com/VoltAgent/awesome-openclaw-skills
