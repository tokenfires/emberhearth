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

For semantic retrieval ("find facts related to this topic"):

```
┌─────────────────────────────────────────────────────────────────┐
│  EMBEDDING OPTIONS                                              │
│                                                                 │
│  Option A: Local Embedding (Privacy-First)                      │
│  ─────────────────────────────────────────────────────────────  │
│  Model: all-MiniLM-L6-v2 or similar                             │
│  Pros: No data leaves device, fast, free                        │
│  Cons: Lower quality than cloud models                          │
│  Size: ~80MB model, 384-dim vectors                             │
│                                                                 │
│  Option B: Cloud Embedding (Higher Quality)                     │
│  ─────────────────────────────────────────────────────────────  │
│  Model: OpenAI text-embedding-3-small or Anthropic equivalent   │
│  Pros: Higher quality semantic matching                         │
│  Cons: Data sent to cloud, cost per embedding                   │
│  Size: 1536-dim vectors                                         │
│                                                                 │
│  RECOMMENDATION: Local by default, cloud optional               │
│  Work context: Always local (policy compliance)                 │
│  Personal context: User choice                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

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

## 5. Privacy Classification

### Automatic Classification Heuristics

The LLM should classify privacy level during extraction:

| Signal | Likely Level |
|--------|--------------|
| "Don't tell anyone..." | Secret |
| "Between us..." | Secret |
| Medical/health information | Private (elevate to Secret if explicit) |
| Financial details | Private |
| Workplace complaints | Private (Secret if about specific people) |
| Family relationships | Private |
| General preferences | Public |
| Hobbies, interests | Public |
| Location/schedule | Private |

### User Override

Users can always:
- View all stored facts
- Change privacy level
- Delete any fact
- Mark categories as "never store"

---

## 6. User Control Interface

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

## 7. Context Isolation (Work/Personal)

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

## 8. Open Research Questions

### Answered in this document:
- [x] What facts should be automatically extracted from conversations?
- [x] How should confidence decay work? (Emotional salience as modifier)

### Remaining questions:

- [ ] **Privacy Classification:** Can an LLM reliably classify public/private/secret? What's the error rate? Need testing.

- [ ] **Embedding Model Selection:** Which local embedding model balances quality and performance for on-device use?

- [ ] **Pattern Detection Algorithms:** What algorithms best detect behavioral patterns from interaction history?

- [ ] **Proactive Recall Balance:** How do we surface relevant memories without being creepy? What's the threshold?

- [ ] **Emotional Encoding Inference:** How accurately can emotional intensity be inferred from text alone? Do we need explicit user signals?

- [ ] **Consolidation Performance:** How long does nightly consolidation take with 10K+ facts? Acceptable on older Macs?

---

## 9. Implementation Priorities

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
