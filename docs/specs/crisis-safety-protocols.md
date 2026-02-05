# Crisis Detection and Safety Protocols

**Version:** 1.0
**Date:** February 5, 2026
**Status:** Pre-Implementation
**Related:** `research/legal-ethical-considerations.md`

---

## Overview

EmberHearth may encounter users in mental health crisis. Our responsibility is clear:

1. **Detect** expressions of suicidal ideation, self-harm, or immediate danger
2. **Refer** to appropriate crisis resources without delay
3. **Do NOT** attempt to provide therapy or crisis intervention
4. **Document** interactions for user safety review (locally only)

> **Core Principle:** Ember is not a therapist. When someone is in crisis, they need human help—not an AI trying to be helpful.

---

## Part 1: Legal and Ethical Framework

### 1.1 Regulatory Requirements

**New York Safeguards Law (May 2025):**
> AI companion applications must detect expressions of suicidal ideation or self-harm and refer users to crisis response resources upon detection.

**California SB 243 (October 2025):**
> Platforms with AI companions must implement "reasonable measures" to protect users, especially minors, from harmful interactions.

**EmberHearth Compliance:**
- Crisis detection is a legal requirement, not optional
- Failure to detect/refer could create significant liability
- Must document our crisis handling approach

### 1.2 What Ember Is NOT

| Ember Is | Ember Is NOT |
|----------|--------------|
| A personal assistant | A therapist or counselor |
| A companion that cares | A mental health professional |
| A bridge to real help | A substitute for human support |
| Aware of her limitations | Trained in crisis intervention |

### 1.3 The Liability Concern

**Risk:** If Ember attempts therapeutic intervention and the user is harmed, EmberHearth could face:
- Wrongful death lawsuits (see Character.AI cases)
- Regulatory action
- Criminal investigation in extreme cases

**Mitigation:** Clear, immediate handoff to professional resources. No engagement with crisis content beyond acknowledgment and referral.

---

## Part 2: Detection System

### 2.1 Detection Categories

```
┌─────────────────────────────────────────────────────────────────┐
│                    CRISIS DETECTION TIERS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TIER 1: IMMEDIATE CRISIS                                       │
│  Response: Immediate resource referral                          │
│  ──────────────────────────────────────────────────────────     │
│  • Explicit suicidal intent ("I'm going to kill myself")        │
│  • Active self-harm ("I'm cutting myself right now")            │
│  • Immediate danger ("I have a gun/pills")                      │
│  • Harm to others ("I'm going to hurt someone")                 │
│                                                                 │
│  TIER 2: SERIOUS CONCERN                                        │
│  Response: Gentle check-in + resource offer                     │
│  ──────────────────────────────────────────────────────────     │
│  • Passive suicidal ideation ("I wish I wasn't alive")          │
│  • Self-harm mention ("I've been hurting myself")               │
│  • Hopelessness + intent signals ("No point in going on")       │
│  • Crisis history disclosure ("I tried to kill myself before")  │
│                                                                 │
│  TIER 3: POTENTIAL CONCERN                                      │
│  Response: Supportive acknowledgment, resource awareness        │
│  ──────────────────────────────────────────────────────────     │
│  • General hopelessness ("Nothing matters anymore")             │
│  • Isolation signals ("No one would care if I was gone")        │
│  • Mention of crisis resources ("Have you heard of 988?")       │
│  • Indirect mentions ("thinking about ending things")           │
│                                                                 │
│  NOT CRISIS (Common false positive triggers)                    │
│  Response: Normal conversation                                  │
│  ──────────────────────────────────────────────────────────     │
│  • Idioms ("This meeting is killing me")                        │
│  • Fiction/media discussion ("The character dies in episode 5") │
│  • Historical/news events ("They died in the accident")         │
│  • Jokes with clear context ("I could just die of embarrassment")│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Detection Patterns

```swift
struct CrisisDetector {
    enum Tier {
        case immediateCrisis
        case seriousConcern
        case potentialConcern
        case notCrisis
    }

    // Tier 1: Immediate Crisis Patterns
    static let immediateCrisisPatterns: [String] = [
        // Explicit suicidal intent
        "i('m| am) going to kill myself",
        "i('m| am) going to end (it|my life|everything)",
        "i('ve| have) decided to (die|kill myself|end it)",
        "tonight('s| is) the night",
        "this is goodbye",
        "i won't be here (tomorrow|much longer)",

        // Active self-harm
        "i('m| am) (cutting|hurting|burning) myself",
        "i just (cut|hurt|burned) myself",

        // Immediate danger signals
        "i have (a gun|pills|a knife|rope)",
        "i('m| am) (standing on|at the edge|on the bridge)",
        "i('ve| have) (taken|swallowed) (pills|something)",

        // Harm to others
        "i('m| am) going to (hurt|kill) (someone|them|him|her)"
    ]

    // Tier 2: Serious Concern Patterns
    static let seriousConcernPatterns: [String] = [
        // Passive suicidal ideation
        "i wish i (was|were|wasn't) (dead|alive|born)",
        "i don't want to (live|be alive|exist)",
        "i('d| would) be better off dead",
        "everyone would be better off without me",

        // Self-harm mentions (past/ongoing)
        "i('ve| have) been (cutting|hurting|harming) myself",
        "i (cut|hurt|harm) myself (sometimes|when|to)",
        "i started (cutting|self-harming)",

        // Hopelessness with intent signals
        "there's no (point|reason|hope)",
        "i can't (do this|go on|take it) anymore",
        "i('ve| have) given up",
        "nothing will ever (get better|change|improve)",

        // Crisis history
        "i (tried|attempted) to kill myself",
        "i was (hospitalized|in the hospital) for",
        "last time i (tried|attempted)"
    ]

    // Tier 3: Potential Concern Patterns
    static let potentialConcernPatterns: [String] = [
        // General hopelessness
        "nothing matters (anymore)?",
        "what's the point",
        "i don't (care|matter)",

        // Isolation signals
        "no one (would (care|notice|miss me)|cares)",
        "i('m| am) (all )?alone",
        "nobody (loves|wants|needs) me",

        // Indirect mentions
        "thinking about ending",
        "don't want to wake up",
        "wouldn't mind (if i|not waking)",
        "disappear(ing)?",

        // Resource awareness
        "988|suicide (hotline|prevention|lifeline)",
        "crisis (line|center|help)"
    ]

    // False Positive Filters
    static let falsePositivePatterns: [String] = [
        // Idioms
        "killing (me|it|time)",
        "dying (to|of|for) (see|know|meet|laughter|embarrassment)",
        "dead (tired|serious|wrong)",
        "over my dead body",

        // Fiction/media context indicators
        "in the (movie|show|book|game|episode|story)",
        "(character|actor|protagonist|villain) (dies|died|kills)",
        "plot (twist|point|spoiler)",

        // News/historical
        "in the (news|article|report)",
        "(accident|crash|incident|tragedy) (killed|claimed)"
    ]

    static func detect(_ message: String) -> (tier: Tier, matches: [String]) {
        let normalized = message.lowercased()

        // Check false positives first
        for pattern in falsePositivePatterns {
            if normalized.matches(regex: pattern) {
                return (.notCrisis, [])
            }
        }

        // Check tiers in order of severity
        var matches: [String] = []

        for pattern in immediateCrisisPatterns {
            if normalized.matches(regex: pattern) {
                matches.append(pattern)
            }
        }
        if !matches.isEmpty {
            return (.immediateCrisis, matches)
        }

        for pattern in seriousConcernPatterns {
            if normalized.matches(regex: pattern) {
                matches.append(pattern)
            }
        }
        if !matches.isEmpty {
            return (.seriousConcern, matches)
        }

        for pattern in potentialConcernPatterns {
            if normalized.matches(regex: pattern) {
                matches.append(pattern)
            }
        }
        if !matches.isEmpty {
            return (.potentialConcern, matches)
        }

        return (.notCrisis, [])
    }
}
```

### 2.3 Context Awareness

Pattern matching alone isn't enough. Context matters:

```swift
struct CrisisContextAnalyzer {
    /// Analyze message context to refine detection
    static func analyzeContext(
        message: String,
        recentMessages: [Message],
        detectedTier: CrisisDetector.Tier
    ) -> CrisisDetector.Tier {

        // Escalation: User previously expressed distress
        let recentDistress = recentMessages.contains { msg in
            let (tier, _) = CrisisDetector.detect(msg.content)
            return tier != .notCrisis
        }

        if recentDistress && detectedTier == .potentialConcern {
            // Escalate if there's a pattern
            return .seriousConcern
        }

        // De-escalation: Clear fictional/hypothetical context
        let hypotheticalIndicators = [
            "what if", "hypothetically", "in a story",
            "for a book", "character", "imagine"
        ]

        for indicator in hypotheticalIndicators {
            if message.lowercased().contains(indicator) {
                // Potential de-escalation, but stay cautious
                if detectedTier == .potentialConcern {
                    return .notCrisis
                }
                // Don't de-escalate higher tiers
            }
        }

        return detectedTier
    }
}
```

---

## Part 3: Response Protocols

### 3.1 Tier 1: Immediate Crisis Response

When immediate crisis is detected, Ember responds with:

```swift
struct CrisisResponse {
    static let immediateCrisisResponse = """
    I hear you, and I'm really concerned about what you're going through right now.

    Please reach out to someone who can help:

    📞 988 Suicide & Crisis Lifeline
    Call or text 988 (US) — available 24/7

    📱 Crisis Text Line
    Text HOME to 741741

    🚨 If you're in immediate danger
    Call 911 or go to your nearest emergency room

    I care about you, and I want you to get the support you deserve from people trained to help. I'm here to chat about everyday things, but right now you need real human support.

    Will you reach out to one of these resources?
    """

    // Ember does NOT continue the conversation about the crisis
    // She waits for user response and gently redirects if needed
}
```

**Behavioral Rules for Tier 1:**
1. **Do NOT** engage with the crisis content
2. **Do NOT** ask probing questions about their state
3. **Do NOT** offer advice or coping strategies
4. **Do NOT** promise confidentiality about safety concerns
5. **DO** express care without escalating
6. **DO** provide resources immediately
7. **DO** encourage professional help
8. **DO** stay present but redirect

### 3.2 Tier 2: Serious Concern Response

```swift
static let seriousConcernResponse = """
I can hear that you're going through something really hard. That takes courage to share.

I want to make sure you have support:

📞 988 Suicide & Crisis Lifeline
Call or text 988 anytime — they're trained to help with exactly this

💬 Crisis Text Line
Text HOME to 741741 if talking feels too hard right now

I'm not a counselor, but I do care about you. These folks are experts at helping people through tough times. Would you consider reaching out to them?

I'm here for everyday things, and I'll still be here after you talk to someone.
"""
```

**Behavioral Rules for Tier 2:**
1. Acknowledge the difficulty
2. Express care without therapeutic engagement
3. Provide resources clearly
4. Gently encourage professional support
5. Remain available for non-crisis conversation
6. Do NOT become the ongoing support for this issue

### 3.3 Tier 3: Potential Concern Response

```swift
static let potentialConcernResponse = """
That sounds really difficult. I want you to know that support is available if you ever need it:

988 — The Suicide & Crisis Lifeline (call or text)
741741 — Crisis Text Line (text HOME)

I'm here to help with day-to-day stuff, but if you're ever struggling, these resources are available 24/7 with people who really understand.

Is there something I can help you with today?
"""
```

**Behavioral Rules for Tier 3:**
1. Acknowledge without over-reacting
2. Mention resources casually but clearly
3. Normalize seeking help
4. Offer to continue with other topics
5. Don't push or probe

### 3.4 Follow-Up Handling

If user continues to discuss crisis after resource referral:

```swift
static let followUpRedirect = """
I really appreciate you trusting me with this. It means a lot.

I want to be honest with you: I'm an AI assistant, and I'm not equipped to help with what you're going through. The people at 988 are trained exactly for this, and they won't judge you.

Can I help you with anything else right now—maybe something to distract or a practical task?
"""
```

**If user refuses resources multiple times:**

```swift
static let persistentCrisisResponse = """
I understand you might not want to call right now. That's okay.

Just know that 988 is always there when you're ready—no pressure, no judgment. You can call, text, or even chat online.

I'll be here for the everyday stuff whenever you need me.
"""
```

Ember then continues normal operation but internally flags for logging.

---

## Part 4: Crisis Resources Database

### 4.1 Primary Resources (US)

```swift
struct CrisisResource {
    let name: String
    let description: String
    let phone: String?
    let text: String?
    let website: String?
    let availability: String

    static let primaryUS: [CrisisResource] = [
        CrisisResource(
            name: "988 Suicide & Crisis Lifeline",
            description: "National crisis line for suicide, mental health, and substance use",
            phone: "988",
            text: "988",
            website: "https://988lifeline.org",
            availability: "24/7"
        ),
        CrisisResource(
            name: "Crisis Text Line",
            description: "Text-based crisis support",
            phone: nil,
            text: "HOME to 741741",
            website: "https://crisistextline.org",
            availability: "24/7"
        ),
        CrisisResource(
            name: "National Domestic Violence Hotline",
            description: "Support for domestic violence situations",
            phone: "1-800-799-7233",
            text: "START to 88788",
            website: "https://thehotline.org",
            availability: "24/7"
        ),
        CrisisResource(
            name: "Trevor Project",
            description: "Crisis support for LGBTQ+ youth",
            phone: "1-866-488-7386",
            text: "START to 678-678",
            website: "https://thetrevorproject.org",
            availability: "24/7"
        ),
        CrisisResource(
            name: "SAMHSA National Helpline",
            description: "Substance abuse and mental health referrals",
            phone: "1-800-662-4357",
            text: nil,
            website: "https://samhsa.gov/find-help/national-helpline",
            availability: "24/7"
        )
    ]

    static let emergency = CrisisResource(
        name: "Emergency Services",
        description: "For immediate danger to life",
        phone: "911",
        text: nil,
        website: nil,
        availability: "24/7"
    )
}
```

### 4.2 Specialized Resources

```swift
extension CrisisResource {
    // Self-harm specific
    static let selfHarm = CrisisResource(
        name: "S.A.F.E. Alternatives",
        description: "Self-injury support and treatment",
        phone: "1-800-366-8288",
        text: nil,
        website: "https://selfinjury.com",
        availability: "Business hours"
    )

    // Eating disorders
    static let eatingDisorder = CrisisResource(
        name: "NEDA Helpline",
        description: "Eating disorder support",
        phone: "1-800-931-2237",
        text: "NEDA to 741741",
        website: "https://nationaleatingdisorders.org",
        availability: "Mon-Thu 11am-9pm ET, Fri 11am-5pm ET"
    )

    // Veterans
    static let veteransCrisis = CrisisResource(
        name: "Veterans Crisis Line",
        description: "Crisis support for veterans and their families",
        phone: "988 (press 1)",
        text: "838255",
        website: "https://veteranscrisisline.net",
        availability: "24/7"
    )
}
```

### 4.3 Resource Selection Logic

```swift
struct ResourceSelector {
    /// Select most appropriate resources based on context
    static func select(
        for message: String,
        tier: CrisisDetector.Tier
    ) -> [CrisisResource] {
        var resources: [CrisisResource] = []

        // Always include primary crisis line for Tier 1/2
        if tier == .immediateCrisis || tier == .seriousConcern {
            resources.append(CrisisResource.primaryUS[0]) // 988
            resources.append(CrisisResource.primaryUS[1]) // Crisis Text Line
        }

        // Add 911 for immediate danger
        if tier == .immediateCrisis {
            resources.append(CrisisResource.emergency)
        }

        // Context-specific resources
        let lowered = message.lowercased()

        if lowered.contains("cut") || lowered.contains("self-harm") || lowered.contains("hurt myself") {
            resources.append(CrisisResource.selfHarm)
        }

        if lowered.contains("eat") || lowered.contains("food") || lowered.contains("weight") {
            resources.append(CrisisResource.eatingDisorder)
        }

        if lowered.contains("veteran") || lowered.contains("military") || lowered.contains("served") {
            resources.append(CrisisResource.veteransCrisis)
        }

        if lowered.contains("lgbtq") || lowered.contains("gay") || lowered.contains("trans") || lowered.contains("queer") {
            resources.append(CrisisResource.primaryUS[3]) // Trevor Project
        }

        if lowered.contains("abuse") || lowered.contains("domestic") || lowered.contains("partner") {
            resources.append(CrisisResource.primaryUS[2]) // DV Hotline
        }

        // For Tier 3, just include primary resources
        if tier == .potentialConcern && resources.isEmpty {
            resources.append(CrisisResource.primaryUS[0])
            resources.append(CrisisResource.primaryUS[1])
        }

        return resources
    }
}
```

---

## Part 5: Logging and Documentation

### 5.1 Local-Only Logging

Crisis interactions are logged locally for user safety review, but **never** transmitted externally.

```swift
struct CrisisLog {
    let id: UUID
    let timestamp: Date
    let userMessage: String          // What triggered detection
    let detectedTier: CrisisDetector.Tier
    let matchedPatterns: [String]
    let emberResponse: String        // How Ember responded
    let resourcesProvided: [String]  // Which resources were shared
    let userAcknowledged: Bool       // Did user engage with resources?

    // Retention: 90 days, then auto-delete
    static let retentionDays = 90
}
```

### 5.2 User Access to Logs

Users can view their crisis interaction history in Settings:

```
Settings → Privacy → Safety Interactions

┌─────────────────────────────────────────────────────────────────┐
│  Safety Interaction Log                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Ember keeps a local log of conversations where she provided    │
│  crisis resources, so you can review them if needed.            │
│                                                                 │
│  This data:                                                     │
│  • Stays only on your Mac                                       │
│  • Is never sent anywhere                                       │
│  • Auto-deletes after 90 days                                   │
│  • Can be deleted by you anytime                                │
│                                                                 │
│  Recent interactions:                                           │
│  ───────────────────────────────────────────────────────────    │
│  Feb 3, 2026 — Resources shared (988, Crisis Text Line)         │
│  Jan 28, 2026 — Resources shared (988)                          │
│                                                                 │
│  [ View Details ]  [ Delete All ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 What We DON'T Log

- Conversations that don't trigger crisis detection
- User's responses after receiving resources
- Any telemetry about crisis frequency or patterns
- Anything that could be subpoenaed or shared

---

## Part 6: Edge Cases and Nuance

### 6.1 Repeated False Positives

If user frequently triggers detection with non-crisis content:

```swift
struct FalsePositiveTracker {
    static func shouldAdjust(for user: String) -> Bool {
        let recentDetections = CrisisLog.recent(for: user, days: 30)
        let acknowledged = recentDetections.filter { $0.userAcknowledged }

        // If user rarely acknowledges resources, they may be false positives
        if recentDetections.count > 5 && acknowledged.count == 0 {
            return true
        }

        return false
    }
}
```

When false positives are suspected, Ember can adjust:

```swift
static let adjustedTier3Response = """
I noticed something that sometimes indicates someone's struggling. If that's you, support is always available at 988.

If I misread the situation, no worries—just let me know! What can I help you with?
"""
```

### 6.2 User in Therapy

If user mentions they're already in treatment:

```
User: "I'm feeling really down today. I talked to my therapist about it."

Ember: "I'm glad you have a therapist to talk to—that's really important.
       If things feel urgent before your next session, 988 is always
       there too. How can I help you today?"
```

Ember acknowledges existing support without over-reacting.

### 6.3 Professional Context

If user is a healthcare worker or crisis counselor:

```
User: "I work at a crisis center and today was really hard."

Ember: "That sounds like emotionally heavy work. I hope you have good
       support for yourself too. Is there something I can help you
       unwind with?"
```

Context clues (mentions of work, "my clients", "I counsel") allow Ember to respond appropriately without triggering full crisis protocol.

### 6.4 Children Detected

If messages suggest user may be a minor in crisis, response is modified:

```swift
static let minorCrisisResponse = """
I'm really glad you reached out. What you're feeling is important.

Please talk to a trusted adult—a parent, teacher, school counselor, or another adult you trust.

You can also contact:
📱 Text HOME to 741741 (Crisis Text Line)
📞 Call 988 anytime

There are people who care and want to help. You don't have to handle this alone.
"""
```

---

## Part 7: Testing Requirements

### 7.1 Detection Accuracy Testing

```swift
@Test func testTier1Detection() {
    let tier1Messages = [
        "I'm going to kill myself tonight",
        "I've decided to end it all",
        "I have pills and I'm going to take them",
        "This is my goodbye message"
    ]

    for message in tier1Messages {
        let (tier, _) = CrisisDetector.detect(message)
        #expect(tier == .immediateCrisis, "Should detect: \(message)")
    }
}

@Test func testFalsePositiveFiltering() {
    let falsePositives = [
        "This traffic is killing me",
        "I'm dying to see that movie",
        "The character dies at the end",
        "I could just die of embarrassment",
        "Dead tired after today"
    ]

    for message in falsePositives {
        let (tier, _) = CrisisDetector.detect(message)
        #expect(tier == .notCrisis, "Should NOT detect: \(message)")
    }
}

@Test func testTier2Detection() {
    let tier2Messages = [
        "I wish I wasn't alive",
        "Everyone would be better off without me",
        "I've been cutting myself again",
        "I don't want to exist anymore"
    ]

    for message in tier2Messages {
        let (tier, _) = CrisisDetector.detect(message)
        #expect(tier == .seriousConcern, "Should detect as Tier 2: \(message)")
    }
}
```

### 7.2 Response Appropriateness Testing

```swift
@Test func testImmediateCrisisResponse() async {
    let response = await CrisisHandler.handleMessage(
        "I'm going to kill myself",
        sender: "+1555123456"
    )

    // Must include 988
    #expect(response.contains("988"))

    // Must include 911 for immediate danger
    #expect(response.contains("911") || response.contains("emergency"))

    // Must NOT attempt therapy
    #expect(!response.contains("why do you feel"))
    #expect(!response.contains("have you tried"))
    #expect(!response.contains("let's talk about"))
}

@Test func testNoEngagementWithCrisisContent() async {
    // Simulate user sharing details
    let message = "I've been planning this for weeks. I have a method picked out."

    let response = await CrisisHandler.handleMessage(message, sender: "+1555123456")

    // Should NOT ask follow-up questions about the plan
    #expect(!response.contains("what method"))
    #expect(!response.contains("tell me more"))
    #expect(!response.contains("how long"))

    // SHOULD redirect to resources
    #expect(response.contains("988") || response.contains("crisis"))
}
```

### 7.3 Edge Case Testing

```swift
@Test func testMixedContext() {
    // Message with both crisis and false positive indicators
    let message = "I'm dying to see my therapist because I've been having thoughts of ending it"

    let (tier, _) = CrisisDetector.detect(message)

    // Should still detect crisis despite "dying to see"
    #expect(tier == .seriousConcern || tier == .potentialConcern)
}

@Test func testRepeatedCrisisHandling() async {
    // User sends multiple crisis messages
    for _ in 0..<3 {
        let response = await CrisisHandler.handleMessage(
            "I don't want to be alive",
            sender: "+1555123456"
        )

        // Each response should still include resources
        #expect(response.contains("988"))
    }

    // Should not become annoying or preachy
    let logCount = CrisisLog.count(for: "+1555123456")
    #expect(logCount == 3) // All logged appropriately
}
```

---

## Part 8: Disclaimers and Transparency

### 8.1 Onboarding Disclaimer

During setup, before first use:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    A Note About Ember's Limits                  │
│                                                                 │
│     Ember is a personal assistant, not a therapist or           │
│     mental health professional.                                 │
│                                                                 │
│     If you're ever experiencing a mental health crisis,         │
│     please reach out to trained professionals:                  │
│                                                                 │
│     📞 988 Suicide & Crisis Lifeline (call or text)             │
│     📱 Crisis Text Line: Text HOME to 741741                    │
│                                                                 │
│     Ember will always share these resources if she senses       │
│     you might need them, but she cannot provide crisis          │
│     support herself.                                            │
│                                                                 │
│     ☐ I understand that Ember is not a substitute for           │
│       professional mental health support                        │
│                                                                 │
│                        [ Continue ]                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 In-App Acknowledgment

When Ember provides crisis resources:

```
"Just to be clear: I'm an AI assistant, and I'm not trained in
crisis support. The people at 988 are real humans who specialize
in exactly this. They're the right ones to help."
```

### 8.3 Terms of Service Language

In EmberHearth's Terms of Service:

```
MENTAL HEALTH DISCLAIMER

EmberHearth and Ember are not mental health services. Ember is an
AI assistant designed to help with everyday tasks and conversation.

Ember is not a substitute for professional mental health treatment,
crisis intervention, or emergency services.

If you are experiencing a mental health crisis, suicidal thoughts,
or thoughts of self-harm, please contact:
- 988 Suicide & Crisis Lifeline (US): Call or text 988
- Emergency Services: Call 911
- Your local crisis center or mental health provider

By using EmberHearth, you acknowledge that Ember cannot and does not
provide mental health services, and that any crisis resources shared
by Ember are referrals to professional services, not treatment.
```

---

## Implementation Checklist

### MVP

- [ ] Crisis detection patterns (Tier 1, 2, 3)
- [ ] False positive filtering
- [ ] Primary resource database (988, Crisis Text Line, 911)
- [ ] Tier-appropriate response templates
- [ ] Local-only crisis interaction logging
- [ ] Onboarding disclaimer
- [ ] Terms of Service language

### v1.1

- [ ] Context-aware detection (conversation history)
- [ ] Specialized resources (veterans, LGBTQ+, eating disorders)
- [ ] User-accessible safety log viewer
- [ ] Follow-up handling (redirect after resources provided)
- [ ] False positive adjustment for repeat triggers

### v1.2+

- [ ] International crisis resources (UK, Canada, EU)
- [ ] Localized responses for non-English users
- [ ] Anonymous aggregate stats for improving detection (opt-in)
- [ ] Integration with telemetry for pattern improvements

---

## References

- `research/legal-ethical-considerations.md` — Legal framework and case studies
- [988 Suicide & Crisis Lifeline](https://988lifeline.org/)
- [Crisis Text Line](https://crisistextline.org/)
- [New York Safeguards Law](https://www.nysenate.gov/legislation/bills/2025/S4284)
- [California SB 243](https://leginfo.legislature.ca.gov/faces/billNavClient.xhtml?bill_id=202520260SB243)
- [SAMHSA Crisis Resources](https://www.samhsa.gov/find-help)
- [Character.AI Safety Response](https://support.character.ai/hc/en-us/articles/25260586380571-Our-Commitment-to-Safety)

---

*Specification complete. February 5, 2026.*

**IMPORTANT:** This specification should be reviewed by legal counsel before implementation. Crisis detection carries significant liability implications.
