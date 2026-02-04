# ASV Implementation Design

**Purpose:** Technical specification for implementing the Affective State Vector
**Date:** February 4, 2026
**Status:** Design Complete

---

## Overview

The Affective State Vector (ASV) encodes emotional state as a 7-dimensional vector. This document specifies how to implement ASV storage, translation, and injection into prompts.

The key insight: **Use the LLM itself to translate numeric values into emotionally resonant words.** This avoids hardcoding emotion mappings and leverages the LLM's training on human emotional language.

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
