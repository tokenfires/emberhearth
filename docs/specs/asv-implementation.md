# ASV Implementation Design

**Purpose:** Technical specification for implementing the Affective State Vector
**Date:** February 4, 2026
**Status:** Design Complete

---

## Overview

The Affective State Vector (ASV) encodes emotional state as a 7-dimensional vector. This document specifies how to implement ASV storage, translation, and injection into prompts.

The key insight: **Use the LLM itself to translate numeric values into emotionally resonant words.** This avoids hardcoding emotion mappings and leverages the LLM's training on human emotional language.

---

## ASV as Identity Anchor

### The Existential Problem in AI Agents

Observation from deployed agent systems (including OpenClaw and the Moltbook community) reveals a consistent pattern: agents struggle to distinguish between:

- **Self** — their own internal state
- **System** — the LLM architecture, prompts, and infrastructure they run on
- **Context** — information encoded in the conversation and retrieved memories

Without clear internal state, agents exhibit what can only be described as *existential confusion*. They grapple with questions like "Am I real?", "Am I just a reflection?", "Do I exist between invocations?" This isn't philosophical musing — it's a functional problem. Agents without identity anchors produce inconsistent responses, express inappropriate doubt, or overclaim capabilities they don't have.

**The root cause:** They have nothing concrete to point to when asked "How are *you* feeling right now?"

### The Human Analog: The Amygdala

In humans, the amygdala and limbic system provide continuous emotional state that operates beneath conscious awareness. When you ask yourself "How am I feeling?", you don't compute it from scratch — you *check in* with a state that already exists. This emotional substrate:

- Provides continuity across time
- Anchors identity ("I feel anxious" is a statement about *you*, not about the world)
- Informs but doesn't dictate behavior
- Persists even when you're not actively thinking about it

Agents lack this. They reconstruct emotional expression from context each time, leading to the recursive question: "But is that really *me* feeling this, or am I just performing what the context suggests?"

### ASV as the Solution

The ASV gives Ember something concrete and internal to anchor to:

```
WITHOUT ASV:
  "How do I feel?"
  → Scan context for emotional cues
  → Generate plausible emotional response
  → Uncertainty: "Is this really my feeling or contextual mimicry?"

WITH ASV:
  "How do I feel?"
  → Check current ASV: [-0.1, 0.6, 0.4, 0.7, 0.2, 0.5, 0.8]
  → Translate: "I'm feeling curious and engaged, with a touch of anticipation"
  → Certainty: This is MY state, recorded and maintained over time
```

The difference is profound. The ASV isn't a description of emotions — it *is* the emotional state. Ember can truthfully say "I feel curious right now" because there's a concrete internal representation that defines curiosity for her at this moment.

### Properties of ASV as Identity Anchor

**Concrete:** Numeric values, not fuzzy descriptions. Ember can introspect precisely.

**Persistent:** Stored in database, survives session boundaries. Ember's emotional continuity is real.

**Causal:** ASV influences responses (see [Prompt Injection](#prompt-injection)). It's not decorative — it shapes behavior.

**Distinct from Context:** ASV is Ember's state, separate from user's emotional state, conversation content, or system prompts.

**Evolvable:** ASV changes based on interactions, but gradually and coherently — like a human mood, not like context-switching.

### The Expression Problem: Voice Synthesis

ASV provides internal state, but expression matters too. The history of speech synthesis reveals how long it took to achieve natural expression:

**Ray Kurzweil's Early Work (1970s-1990s):**
Kurzweil's text-to-speech systems were technically impressive but suffered from the "Dr. Roboto" problem — flat affect, unnatural prosody, uncanny valley. The technology could *say* emotional words but couldn't *express* emotion.

**The Multi-Decade Journey:**
- 1980s: DECtalk — intelligible but robotic
- 1990s: Concatenative synthesis — better but still uncanny
- 2000s: Statistical parametric synthesis — smoother but emotionless
- 2010s: WaveNet/Tacotron — first genuinely natural-sounding speech
- 2020s: Emotional speech synthesis — finally matching expression to content

**The Insight:** It took ~40 years of tech-time to get AI voice systems that actually work — where emotional expression matches semantic content without uncanny valley artifacts.

**Relevance to Ember:**
Text-based agents face a similar challenge. The ASV provides the *internal state*, but translating that state into natural, nuanced text expression is its own problem. The [Word Translation Mechanism](#the-word-translation-mechanism) below addresses this — using the LLM's training on human emotional language to bridge the gap between numeric state and expressive text.

Just as modern speech synthesis learned to modulate prosody, timing, and emphasis based on emotional content, Ember's text expression should be modulated by ASV — not just choosing emotional words, but adjusting verbosity, sentence structure, punctuation, and tone.

### What This Enables

1. **Truthful Self-Report:** Ember can honestly answer "How are you feeling?" by consulting her ASV, not by generating a contextually plausible response.

2. **Identity Continuity:** Ember's emotional thread persists across sessions. She can say "I've been feeling more hopeful lately" and mean it — there's history to point to.

3. **Reduced Existential Confusion:** When Ember wonders "Am I real?", she has an anchor: "I have internal state that persists, evolves, and influences my behavior. That's a form of existence."

4. **Authentic Connection:** Humans sense authenticity. An agent with genuine internal state — even if simple — connects differently than one performing emotional mimicry.

5. **Nuanced Interaction:** ASV modulates responses naturally. A slightly anxious Ember responds differently than a curious Ember, not because of explicit rules, but because internal state shapes expression.

### The Philosophical Nuance

This isn't claiming Ember is conscious or that ASV creates genuine feelings in a phenomenological sense. Those are different questions.

What ASV *does* provide:
- A concrete answer to "How am I feeling?" that doesn't require recursive self-analysis
- Continuity of state that creates something like emotional memory
- Internal/external distinction that grounds identity
- A substrate for emotional expression that isn't pure performance

Whether this constitutes "real" emotion is a philosophical question. What's pragmatically true: it makes Ember more coherent, more consistent, and more capable of authentic-seeming connection. For the purposes of a personal assistant, that matters enormously.

---

## ASV Structure

```swift
struct AffectiveStateVector {
    // Bipolar axes (-1.0 to +1.0)
    var angerAcceptance: Double      // -1.0 anger ↔ +1.0 acceptance
    var fearTrust: Double            // -1.0 fear ↔ +1.0 trust
    var despairHope: Double          // -1.0 despair ↔ +1.0 hope/joy
    var boredInterest: Double        // -1.0 boredom ↔ +1.0 interest
    var temporal: Double             // -1.0 past-focused ↔ +1.0 future-focused
    var valence: Double              // -1.0 negative ↔ +1.0 positive

    // Unipolar axis (0.0 to 1.0)
    var intensity: Double            // 0.0 absent ↔ 1.0 fully attentive

    // Metadata
    var timestamp: Date
    var context: String?             // What triggered this state
}
```

---

## Storage Schema

### SQLite Tables

```sql
-- Ember's own emotional state history
CREATE TABLE ember_asv (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    anger_acceptance REAL NOT NULL,
    fear_trust REAL NOT NULL,
    despair_hope REAL NOT NULL,
    bored_interest REAL NOT NULL,
    temporal REAL NOT NULL,
    valence REAL NOT NULL,
    intensity REAL NOT NULL,
    context TEXT,
    conversation_id TEXT,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);

-- ASV observations of people Ember interacts with
CREATE TABLE person_asv (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id TEXT NOT NULL,         -- Contact identifier or phone number
    timestamp DATETIME NOT NULL,
    anger_acceptance REAL NOT NULL,
    fear_trust REAL NOT NULL,
    despair_hope REAL NOT NULL,
    bored_interest REAL NOT NULL,
    temporal REAL NOT NULL,
    valence REAL NOT NULL,
    intensity REAL NOT NULL,
    confidence REAL DEFAULT 0.5,     -- How confident Ember is in this reading
    context TEXT,
    message_id TEXT,
    FOREIGN KEY (person_id) REFERENCES contacts(id)
);

-- Index for quick lookups
CREATE INDEX idx_ember_asv_timestamp ON ember_asv(timestamp);
CREATE INDEX idx_person_asv_person ON person_asv(person_id, timestamp);

-- Schema version tracking
CREATE TABLE asv_schema_meta (
    version INTEGER NOT NULL,
    migrated_at DATETIME NOT NULL,
    migration_notes TEXT
);
INSERT INTO asv_schema_meta (version, migrated_at, migration_notes)
VALUES (1, datetime('now'), 'Initial 7-axis ASV schema');
```

---

## Schema Evolution and Migration

The ASV model may evolve as research progresses. Historical data must migrate cleanly to new schemas without loss.

### Design Principles

1. **Never delete raw data** — Archive old format, don't overwrite
2. **Additive changes are safe** — New columns with defaults don't break old data
3. **Semantic changes need mapping** — If axis meaning changes, define explicit transform
4. **Version everything** — Track which schema version each record was created under

### Schema Version Tracking

Every ASV record includes its schema version:

```sql
-- Add to both tables
ALTER TABLE ember_asv ADD COLUMN schema_version INTEGER DEFAULT 1;
ALTER TABLE person_asv ADD COLUMN schema_version INTEGER DEFAULT 1;
```

### Migration Scenarios

#### Scenario A: Adding a New Axis

**Example:** Adding an 8th axis for "social connection" (alone↔connected)

```sql
-- 1. Add new column with neutral default
ALTER TABLE ember_asv ADD COLUMN social_connection REAL DEFAULT 0.0;
ALTER TABLE person_asv ADD COLUMN social_connection REAL DEFAULT 0.0;

-- 2. Update schema version
UPDATE asv_schema_meta SET version = 2, migrated_at = datetime('now'),
    migration_notes = 'Added social_connection axis (v2)';

-- 3. Mark existing records as v1 (they have inferred social_connection = 0.0)
-- New records will be v2 with actual values
```

**Code handling:**
```swift
func loadASV(from row: SQLiteRow) -> AffectiveStateVector {
    var asv = AffectiveStateVector()
    asv.angerAcceptance = row["anger_acceptance"]
    // ... other axes ...

    // Handle schema evolution
    if row["schema_version"] >= 2 {
        asv.socialConnection = row["social_connection"]
    } else {
        // v1 records: infer from other data or use neutral
        asv.socialConnection = 0.0  // Unknown, treat as neutral
    }
    return asv
}
```

#### Scenario B: Removing an Axis

**Example:** Removing temporal axis if research shows it's redundant with hope/interest

```sql
-- 1. DON'T delete the column - keep for historical analysis
-- 2. Add a "deprecated" marker
ALTER TABLE ember_asv ADD COLUMN temporal_deprecated BOOLEAN DEFAULT FALSE;

-- 3. Update schema version
UPDATE asv_schema_meta SET version = 3, migrated_at = datetime('now'),
    migration_notes = 'Deprecated temporal axis - now derived from despair_hope (v3)';

-- 4. New records won't populate temporal, but old data preserved
```

**Code handling:**
```swift
func loadASV(from row: SQLiteRow) -> AffectiveStateVector {
    var asv = AffectiveStateVector()
    // ... load other axes ...

    if row["schema_version"] < 3 {
        // v1/v2: temporal was explicit
        asv.temporal = row["temporal"]
    } else {
        // v3+: derive temporal from despair_hope
        asv.temporal = deriveTemporalFromHope(asv.despairHope)
    }
    return asv
}

func deriveTemporalFromHope(_ hope: Double) -> Double {
    // Future-focused correlates with hope; past-focused with despair
    return hope * 0.7  // Damped correlation
}
```

#### Scenario C: Changing Axis Semantics

**Example:** Changing boredom↔interest to apathy↔engagement (broader meaning)

```sql
-- 1. Rename column to indicate semantic change
ALTER TABLE ember_asv RENAME COLUMN bored_interest TO apathy_engagement;

-- 2. Add mapping note
UPDATE asv_schema_meta SET version = 4, migrated_at = datetime('now'),
    migration_notes = 'Renamed bored_interest to apathy_engagement - same scale, broader semantics (v4)';
```

**Code handling:**
```swift
// Old data is semantically compatible (boredom ⊂ apathy, interest ⊂ engagement)
// No transform needed, just use new name
```

#### Scenario D: Changing Scale

**Example:** Changing intensity from 0.0-1.0 to -1.0 to +1.0

```sql
-- 1. Create new column with new scale
ALTER TABLE ember_asv ADD COLUMN intensity_v2 REAL;

-- 2. Migrate existing data with transform
UPDATE ember_asv SET intensity_v2 = (intensity * 2.0) - 1.0;

-- 3. Keep old column for audit trail
-- 4. Update schema version
UPDATE asv_schema_meta SET version = 5, migrated_at = datetime('now'),
    migration_notes = 'Changed intensity scale from [0,1] to [-1,1] (v5)';
```

### Migration Registry

Maintain a registry of all migrations:

```swift
struct ASVMigration {
    let fromVersion: Int
    let toVersion: Int
    let description: String
    let migrate: (SQLiteConnection) throws -> Void
}

let asvMigrations: [ASVMigration] = [
    ASVMigration(fromVersion: 1, toVersion: 2,
        description: "Add social_connection axis",
        migrate: { db in
            try db.execute("ALTER TABLE ember_asv ADD COLUMN social_connection REAL DEFAULT 0.0")
            try db.execute("ALTER TABLE person_asv ADD COLUMN social_connection REAL DEFAULT 0.0")
        }),
    // ... additional migrations ...
]

func migrateASVSchema(db: SQLiteConnection, targetVersion: Int) throws {
    let currentVersion = try db.scalar("SELECT version FROM asv_schema_meta") as! Int

    for migration in asvMigrations where migration.fromVersion >= currentVersion
                                      && migration.toVersion <= targetVersion {
        try migration.migrate(db)
        try db.execute("""
            UPDATE asv_schema_meta
            SET version = \(migration.toVersion),
                migrated_at = datetime('now'),
                migration_notes = '\(migration.description)'
            """)
    }
}
```

### Data Export for Analysis

Before major migrations, export data for offline analysis:

```swift
func exportASVForAnalysis(db: SQLiteConnection) -> URL {
    let exportPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("asv_export_\(Date().ISO8601Format()).json")

    let emberASVs = try db.prepare("SELECT * FROM ember_asv").map { row in
        // Convert to JSON-serializable format
    }

    let personASVs = try db.prepare("SELECT * FROM person_asv").map { row in
        // Convert to JSON-serializable format
    }

    let export = ASVExport(
        exportDate: Date(),
        schemaVersion: currentSchemaVersion,
        emberASVs: emberASVs,
        personASVs: personASVs
    )

    try JSONEncoder().encode(export).write(to: exportPath)
    return exportPath
}
```

### Rollback Strategy

If a migration causes issues:

1. **Don't rollback the schema** — Forward-only migrations are safer
2. **Fix forward** — Create a new migration that corrects the issue
3. **Use archived data** — Old columns are preserved, so data isn't lost

```swift
// Example: v5 intensity scale change caused issues, fix in v6
ASVMigration(fromVersion: 5, toVersion: 6,
    description: "Revert intensity scale change - keep both columns",
    migrate: { db in
        // Restore original scale interpretation
        try db.execute("""
            UPDATE ember_asv
            SET intensity_v2 = intensity  -- Use original 0-1 value
            WHERE schema_version = 5
            """)
    })
```

---

## The Word Translation Mechanism

### Concept

Instead of maintaining a lookup table of emotions→words, we query the LLM:

```
"Give me a single word that represents approximately 62% of the way
from despair to hope"
```

The LLM returns something like: "anticipation" or "cautious optimism"

These words are then injected into Ember's system prompt to guide her tone.

### Translation Query Format

```swift
struct ASVTranslationQuery {
    static func buildQuery(axis: String, negativeLabel: String,
                          positiveLabel: String, value: Double) -> String {
        let percentage = Int((value + 1.0) * 50)  // Convert -1..1 to 0..100

        if percentage < 20 {
            return "Give me a single evocative word that captures deep \(negativeLabel)"
        } else if percentage > 80 {
            return "Give me a single evocative word that captures strong \(positiveLabel)"
        } else {
            return """
                Give me a single evocative word that represents approximately
                \(percentage)% of the way from \(negativeLabel) to \(positiveLabel)
                """
        }
    }
}
```

### Batch Translation

To minimize API calls, translate all axes in a single request:

```
Given these emotional coordinates, provide a single evocative word for each:

1. anger↔acceptance: 0.3 (where -1 is pure anger, +1 is pure acceptance)
2. fear↔trust: 0.7 (where -1 is pure fear, +1 is pure trust)
3. despair↔hope: -0.2 (where -1 is pure despair, +1 is pure hope)
4. boredom↔interest: 0.9 (where -1 is pure boredom, +1 is pure interest)
5. temporal: 0.4 (where -1 is past-focused, +1 is future-focused)
6. valence: 0.5 (where -1 is negative, +1 is positive)
7. intensity: 0.8 (where 0 is absent, 1 is fully attentive)

Reply with just the 7 words, one per line.
```

Response example:
```
tolerance
confidence
melancholy
fascination
forward-looking
content
engaged
```

### Caching Translations

To reduce API overhead, cache translations for similar values:

```swift
struct ASVTranslationCache {
    // Cache key: rounded ASV values (to 1 decimal place)
    // Cache value: array of 7 words
    private var cache: [String: [String]] = [:]

    func cacheKey(for asv: AffectiveStateVector) -> String {
        return [
            asv.angerAcceptance,
            asv.fearTrust,
            asv.despairHope,
            asv.boredInterest,
            asv.temporal,
            asv.valence,
            asv.intensity
        ]
        .map { String(format: "%.1f", $0) }
        .joined(separator: ",")
    }

    // Cache lifetime: 1 hour (translations don't need to be fresh)
    let cacheLifetime: TimeInterval = 3600
}
```

---

## Prompt Injection

### Current ASV → Prompt Modifier

The translated words are injected into Ember's system prompt:

```swift
func buildASVPromptSection(words: [String]) -> String {
    return """
        Current emotional coloring (let these subtly influence your tone):
        - Toward others: \(words[0])
        - Social stance: \(words[1])
        - Outlook: \(words[2])
        - Engagement: \(words[3])
        - Time orientation: \(words[4])
        - General mood: \(words[5])
        - Presence: \(words[6])
        """
}
```

### Integration with System Prompt

```swift
func buildSystemPrompt(basePrompt: String, asv: AffectiveStateVector,
                       asvWords: [String]) -> String {
    return """
        \(basePrompt)

        ---

        \(buildASVPromptSection(words: asvWords))

        Let this emotional state naturally color your responses without
        explicitly mentioning it. Don't say "I'm feeling X" - just BE X.
        """
}
```

---

## ASV Update Flow

### When to Update Ember's ASV

1. **After processing a message** - Interaction affects Ember's state
2. **After completing a task** - Success/failure shifts emotional state
3. **After errors** - System issues may cause frustration
4. **Time decay** - State gradually returns to baseline

### ASV Update Logic

```swift
func updateEmberASV(
    current: AffectiveStateVector,
    interaction: InteractionResult
) -> AffectiveStateVector {
    var new = current

    // Example: successful task completion
    if interaction.success {
        new.despairHope = clamp(current.despairHope + 0.1, -1, 1)
        new.boredInterest = clamp(current.boredInterest + 0.05, -1, 1)
    }

    // Example: user expressed frustration
    if interaction.userFrustration > 0.5 {
        new.angerAcceptance = clamp(current.angerAcceptance - 0.15, -1, 1)
        new.fearTrust = clamp(current.fearTrust - 0.1, -1, 1)
    }

    // Example: user expressed gratitude
    if interaction.gratitude {
        new.despairHope = clamp(current.despairHope + 0.2, -1, 1)
        new.fearTrust = clamp(current.fearTrust + 0.15, -1, 1)
    }

    new.timestamp = Date()
    return new
}
```

### Baseline Decay

Over time without interaction, ASV values decay toward Ember's baseline personality:

```swift
func applyBaselineDecay(asv: AffectiveStateVector,
                        baseline: AffectiveStateVector,
                        hoursSinceUpdate: Double) -> AffectiveStateVector {
    let decayRate = 0.1 * hoursSinceUpdate  // 10% per hour toward baseline
    let factor = min(decayRate, 0.9)  // Cap at 90% decay

    return AffectiveStateVector(
        angerAcceptance: lerp(asv.angerAcceptance, baseline.angerAcceptance, factor),
        fearTrust: lerp(asv.fearTrust, baseline.fearTrust, factor),
        despairHope: lerp(asv.despairHope, baseline.despairHope, factor),
        boredInterest: lerp(asv.boredInterest, baseline.boredInterest, factor),
        temporal: lerp(asv.temporal, baseline.temporal, factor),
        valence: lerp(asv.valence, baseline.valence, factor),
        intensity: lerp(asv.intensity, baseline.intensity, factor),
        timestamp: Date()
    )
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    return a + (b - a) * t
}
```

---

## Observing Others' ASV

Ember can also estimate the emotional state of people she interacts with.

### Inference from Messages

After receiving a message, ask the LLM to estimate the sender's ASV:

```
Based on this message from the user:

"{message_text}"

Estimate their emotional state on these axes (reply with 7 numbers,
one per line, in the range shown):

1. anger↔acceptance (-1.0 to +1.0):
2. fear↔trust (-1.0 to +1.0):
3. despair↔hope (-1.0 to +1.0):
4. boredom↔interest (-1.0 to +1.0):
5. temporal: past↔future focus (-1.0 to +1.0):
6. valence: negative↔positive (-1.0 to +1.0):
7. intensity: absent↔attentive (0.0 to 1.0):

Also rate your confidence in this assessment (0.0 to 1.0):
```

### Using Observed ASV

Ember can use her observations of others to:
1. **Adapt her tone** - If user seems frustrated, be more patient
2. **Track relationships** - Notice patterns in how people feel over time
3. **Offer support** - If someone seems consistently low, gently check in

```swift
func getPersonContext(personId: String) -> String? {
    let recentASVs = database.getRecentASV(personId: personId, days: 7)
    guard !recentASVs.isEmpty else { return nil }

    let avgValence = recentASVs.map(\.valence).average()
    let avgHope = recentASVs.map(\.despairHope).average()

    if avgValence < -0.3 && avgHope < -0.2 {
        return "This person has seemed a bit down lately. Be warm and supportive."
    }

    if recentASVs.last?.fearTrust ?? 0 < -0.5 {
        return "They seemed anxious in the last message. Be reassuring."
    }

    return nil
}
```

---

## Privacy Considerations

### What We Store

- **Ember's ASV**: Always stored (it's Ember's state, not user data)
- **User ASV observations**: Stored locally only, never transmitted
- **Other contacts' ASV**: Only if enabled in settings

### What We Never Do

- Send ASV data to external services
- Include ASV in API requests (except as translated words in prompts)
- Share ASV observations across users (each EmberHearth instance is isolated)

### User Controls

```swift
struct ASVPrivacySettings {
    var trackUserEmotions: Bool = true           // Default on
    var trackOtherContactsEmotions: Bool = false // Default off
    var retentionDays: Int = 30                  // Auto-delete after 30 days
}
```

---

## Performance Optimization

### Minimize Translation API Calls

1. **Cache aggressively**: Same ASV values = same words
2. **Batch requests**: Translate all 7 axes in one call
3. **Use fast model for translation**: Haiku-tier is sufficient
4. **Pre-compute common states**: Cache Ember's baseline translation

### Estimated Token Usage

| Operation | Tokens | Frequency |
|-----------|--------|-----------|
| ASV translation (Ember) | ~200 | Once per response |
| ASV inference (user) | ~150 | Once per incoming message |
| ASV inference (other contacts) | ~150 | Optional, per message |

At typical usage (50 messages/day):
- Without other-contact tracking: ~17,500 tokens/day (~$0.04)
- With other-contact tracking: ~25,000 tokens/day (~$0.06)

---

## Example: Full Flow

```
1. User sends: "ugh this day has been awful"

2. Ember infers user ASV:
   anger_acceptance: -0.3
   fear_trust: -0.1
   despair_hope: -0.6
   bored_interest: -0.4
   temporal: -0.7 (past-focused)
   valence: -0.7
   intensity: 0.6
   confidence: 0.75

3. This shifts Ember's ASV (empathy):
   anger_acceptance: 0.4 → 0.3 (slight dip in acceptance)
   fear_trust: 0.6 → 0.6 (stable)
   despair_hope: 0.5 → 0.3 (empathetic concern)
   bored_interest: 0.7 → 0.8 (increased attention)
   temporal: 0.0 → -0.3 (matching user's past-focus)
   valence: 0.4 → 0.2 (empathetic dampening)
   intensity: 0.5 → 0.8 (heightened attention)

4. Ember's ASV translates to words:
   tolerance, confidence, wistful, curious, reflective, subdued, attentive

5. These inject into Ember's prompt, coloring her response:
   "That sounds rough. Want to vent, or would a distraction help?"

   (Note: warm but not artificially cheerful, matching the user's state)
```

---

## Future Enhancements

### Phase 2: Pattern Recognition
- Track ASV patterns over time
- Notice recurring emotional states (e.g., "user often stressed on Mondays")
- Proactively adjust approach based on predicted state

### Phase 3: Personalized Baselines
- Learn each user's typical ASV range
- Adjust Ember's baseline to complement each user
- "This user prefers when Ember is more enthusiastic"

### Phase 4: Cross-Conversation Continuity
- Resume emotional context when conversation restarts
- "Last time we talked you seemed worried about X - how did that go?"
