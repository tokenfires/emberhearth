# EmberHearth: A Vision for Secure, Accessible AI Assistance

> *The ever-present warmth at the heart of your home.*

**Version:** 1.0 (Draft)  
**Date:** January 30, 2026  
**Status:** Conceptual / Brainstorming

---

> **📺 Building in Public**  
> The development of EmberHearth will be streamed live on Twitch. Follow along as we explore, prototype, make mistakes, and (hopefully) build something useful. Building in public means transparency about the process — the good, the bad, and the "why did I think that would work?" moments. If you're interested in AI security, macOS development, or just want to see how the sausage gets made, come hang out.

---

## Executive Summary

Current AI assistant systems face a fundamental tension: **powerful enough to be useful** versus **safe enough for broad adoption**. Existing always-on, learning AI assistants with deep integrations suffer from:

1. **Complex setup** requiring technical expertise
2. **Severe security vulnerabilities** (prompt injection → RCE)
3. **High-value target status** attracting attackers

**EmberHearth** is a vision for reimagining the personal AI assistant with security and accessibility as foundational requirements, not afterthoughts. The goal: a system your spouse, parent, or child could safely set up and use.

### The Dream Setup

```
Buy Mac Mini → Sign into iCloud → Install EmberHearth → Chat via iMessage
```

That's it. No API keys to manage. No Docker to understand. No threat models to contemplate. Just a helpful assistant that's always there, learns over time, and can't be weaponized against you.

---

## Table of Contents

1. [The Problem](#the-problem)
2. [Design Principles](#design-principles)
3. [Architecture Overview](#architecture-overview)
4. [Core Components](#core-components)
5. [Security Model](#security-model)
6. [User Experience](#user-experience)
7. [Accessibility](#accessibility)
8. [Error Handling and Graceful Degradation](#error-handling-and-graceful-degradation)
9. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
10. [Business Model Considerations](#business-model-considerations)
11. [Foundation Model Terms of Service](#foundation-model-terms-of-service-a-critical-constraint)
12. [Token Efficiency](#token-efficiency-a-design-criteria)
13. [True Personal Memory](#true-personal-memory-beyond-file-based-storage)
14. [Anticipation](#anticipation-beyond-proactive-polling)
15. [Development Philosophy](#development-philosophy-discussion-notes)
16. [Lessons from Moltbot](#lessons-from-moltbot)
17. [Open Questions](#open-questions)
18. [Next Steps](#next-steps)

---

## The Problem

### Current State of AI Assistants

**Consumer Assistants (Siri, Alexa, Google Assistant)**
- ✅ Easy setup
- ✅ Safe (limited capabilities)
- ❌ Not very capable
- ❌ Don't learn deeply about you
- ❌ Siloed from your actual digital life

**Power User Assistants (Claude Desktop, Custom Agents)**
- ✅ Highly capable
- ✅ Can learn and adapt
- ✅ Deep integrations possible
- ❌ Complex setup (API keys, config files, Docker)
- ❌ Severe security risks (prompt injection, RCE)
- ❌ Attractive targets for attackers

**The Gap:** There's no assistant that is both *capable enough to be transformative* and *safe enough for non-technical users*.

### Why This Matters

Foundation model companies have invested billions in AI capabilities. But adoption remains limited to:
- Developers and technical users
- Enterprise deployments with IT support
- Simplified chat interfaces (Claude.ai, ChatGPT)

The missing piece: **autonomous, always-on AI assistance** that regular people can deploy and trust. This is the path from "AI is a tool I use sometimes" to "AI is my digital partner."

### Security Reality Check

Many existing AI assistant architectures are, fundamentally, a nightmare:

```
Untrusted Input → LLM Decision → Shell Execution → Your Entire Digital Life
```

A single prompt injection can lead to:
- All your API keys exfiltrated
- Your SSH keys stolen
- Your messages read and forwarded
- Your identity impersonated
- Ransomware deployed

This isn't theoretical. It's the direct result of common architectural choices.

---

## Design Principles

### 1. Security by Removal, Not by Defense

**Wrong approach:** "Let's sandbox shell execution and hope it's enough."

**Right approach:** "Let's not have shell execution. Let's have structured operations that can't be misused."

Instead of defending a dangerous capability, remove the dangerous capability and provide a safe alternative.

### 2. Secure by Default, Capable by Consent

The base system should be safe with zero configuration. Additional capabilities require explicit, informed user consent with clear explanations of what they enable.

### 3. The Grandmother Test

If you wouldn't feel comfortable having your grandmother use the system unsupervised, it's not ready for broad adoption.

### 4. Make Attacks Unprofitable

Perfect security is impossible. Instead, make the system:
- **Hard to attack** (defense in depth)
- **Limited in blast radius** (even successful attacks cause minimal damage)
- **Not worth the effort** (easier targets exist elsewhere)

### 5. Open Source with Quality

Open source for trust, transparency, and community contribution. But with production-quality code, documentation, and user experience. Not a hobbyist project that happens to be open source.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACES                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  iMessage   │  │  Mac App    │  │   Web UI    │  │ Voice (Accessibility│ │
│  │  (Primary)  │  │  (Admin)    │  │             │  │   - Future)         │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
└─────────┼────────────────┼────────────────┼────────────────────┼────────────┘
          │                │                │                    │
          └────────────────┴────────────────┴────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                                 TRON                                         │
│                    Prompt Injection Firewall                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  • Inbound filtering (signature + ML)                                  │ │
│  │  • Outbound monitoring (credential detection, behavior anomalies)      │ │
│  │  • Retrospective scanning (continuous threat hunting)                  │ │
│  │  • Community signature database (GitHub-hosted, auto-updated)          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                           MACBOT CORE                                        │
│                  (macOS Native MCP Server)                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Intent Router                                 │   │
│  │  • Classifies user intent                                            │   │
│  │  • Routes to appropriate handler                                     │   │
│  │  • Enforces capability boundaries                                    │   │
│  └───────────────────────────────┬──────────────────────────────────────┘   │
│                                  │                                           │
│    ┌─────────────────────────────┼─────────────────────────────────────┐    │
│    │                             │                                      │    │
│    ▼                             ▼                                      ▼    │
│  ┌──────────────┐    ┌────────────────────┐    ┌──────────────────────┐     │
│  │   Structured │    │      Learning      │    │      Workbench       │     │
│  │  Operations  │    │     & Memory       │    │     (Isolated)       │     │
│  ├──────────────┤    ├────────────────────┤    ├──────────────────────┤     │
│  │ • Files      │    │ • User preferences │    │ • Docker container   │     │
│  │ • Calendar   │    │ • Conversation     │    │ • Explicit copy in   │     │
│  │ • Reminders  │    │   history          │    │ • Explicit copy out  │     │
│  │ • Mail       │    │ • Learned patterns │    │ • No host access     │     │
│  │ • Browser    │    │ • Personal context │    │ • No credentials     │     │
│  │ • Notes      │    │                    │    │ • Time-limited       │     │
│  │ • Keychain   │    │                    │    │                      │     │
│  │   (use only) │    │                    │    │                      │     │
│  └──────────────┘    └────────────────────┘    └──────────────────────┘     │
│         │                                               │                    │
│         ▼                                               ▼                    │
│  ┌──────────────┐                              ┌──────────────────────┐     │
│  │   macOS      │                              │  Isolated Container  │     │
│  │   Sandbox    │                              │  (gVisor/Docker)     │     │
│  │   + APIs     │                              │                      │     │
│  └──────────────┘                              └──────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
            ┌──────────────┐              ┌──────────────────┐
            │ LLM Provider │              │ Credential Vault │
            │ (API calls)  │              │ (macOS Keychain) │
            └──────────────┘              └──────────────────┘
```

---

## Core Components

### 1. Structured Operations (macOS Native)

Instead of arbitrary shell commands, provide typed, validated operations:

```typescript
// What the LLM can request (structured, safe)
interface EmberHearthOperations {
  // File operations (sandboxed to approved locations)
  files: {
    read(path: string): string;
    write(path: string, content: string): void;
    list(directory: string): FileInfo[];
  };
  
  // Calendar & Reminders (via EventKit)
  calendar: {
    listEvents(range: DateRange): CalendarEvent[];
    createEvent(event: NewEvent): string;
    createReminder(reminder: NewReminder): string;
  };
  
  // Mail (via Mail.app scripting)
  mail: {
    listUnread(account?: string): EmailSummary[];
    sendEmail(to: string[], subject: string, body: string): void;
  };
  
  // Browser (read-only by default)
  browser: {
    search(query: string): SearchResult[];
    readPage(url: string): PageContent;  // Sanitized, visible text only
    bookmark(url: string, folder?: string): void;
  };
  
  // Notifications
  notifications: {
    send(title: string, body: string): void;
  };
  
  // Credentials (USE without EXPOSE)
  credentials: {
    useForRequest(credentialName: string, request: HttpRequest): HttpResponse;
    // Note: No "getCredential" - values never leave the keychain
  };
}
```

**Key insight:** The LLM can *use* credentials without *seeing* them. It says "make an API call using my OpenAI key" and the MCP server injects the key without ever putting it in the LLM's context.

### 2. The Workbench (Isolated Shell Access)

For users who need shell/development capabilities:

```typescript
interface Workbench {
  // Explicit data transfer (audited, filterable)
  copyIn(hostPaths: string[]): void;
  copyOut(containerPaths: string[], hostDestination: string): void;
  
  // Shell execution (isolated container)
  exec(command: string, options?: ExecOptions): ExecResult;
  
  // Container management
  status(): ContainerStatus;
  reset(): void;  // Wipe and restart
}
```

**Properties:**
- Runs in Docker/gVisor container
- No access to host filesystem (except explicit copy in/out)
- No access to credentials (unless explicitly injected for one command)
- Network access configurable (default: package registries only)
- Ephemeral workspace (wiped on reset or timeout)
- Every operation logged and auditable

### 3. Tron (Prompt Injection Firewall)

A dedicated security layer:

```typescript
interface Tron {
  // Real-time filtering
  scanInbound(content: string, source: ContentSource): ScanResult;
  scanOutbound(response: string, toolCalls: ToolCall[]): ScanResult;
  
  // Retrospective analysis
  scanHistory(sessionId: string): IncidentReport[];
  scanWorkspace(path: string): IncidentReport[];
  
  // Signature management
  updateSignatures(): void;
  addLocalSignature(signature: Signature): void;
  reportDetection(detection: Detection): void;  // Optional community contribution
}

interface ScanResult {
  safe: boolean;
  confidence: number;
  detections: Detection[];
  action: 'allow' | 'block' | 'flag' | 'sanitize';
  sanitized?: string;
}
```

**Signature Sources:**
- Built-in signatures (shipped with EmberHearth)
- Community signatures (GitHub repo, auto-updated)
- Local signatures (user-defined)

### 4. Learning & Memory

The system should learn about the user over time:

- **Preferences:** "You prefer concise responses" / "You like detailed explanations"
- **Context:** "Your wife Sarah is a primary school teacher" / "You have a meeting with John on Fridays"
- **Patterns:** "You usually check email first thing" / "You prefer to schedule reminders for morning"

**Privacy considerations:**
- All learning data stays local (no cloud sync of personal context)
- User can view, edit, and delete learned information
- Clear consent for what's being learned

---

## Security Model

### Defense in Depth

```
Layer 1: Input Gateway
├── Rate limiting
├── Format validation
├── Known attack pattern filtering
│
Layer 2: Tron (Prompt Injection Firewall)
├── Signature-based detection
├── ML-based classification
├── Structural analysis
│
Layer 3: Capability Boundaries
├── Structured operations only (no arbitrary exec)
├── Sandboxed file access
├── Credential use without exposure
│
Layer 4: Isolated Workbench
├── Container isolation
├── No ambient authority
├── Explicit data transfer
│
Layer 5: Output Validation
├── Secret detection
├── PII redaction
├── Behavior anomaly detection
│
Layer 6: Retrospective Scanning
├── Continuous history analysis
├── Incident correlation
├── Signature improvement feedback loop
```

### What Makes This Hard to Attack

| Attack Vector | Mitigation |
|--------------|------------|
| Prompt injection → shell exec | No shell exec (structured operations only) |
| Prompt injection → credential theft | Credentials used, not exposed |
| Malicious web content | Content sanitized before LLM sees it |
| Compromised workbench | Workbench is isolated, no host access |
| Session hijacking | macOS app sandboxing, keychain auth |
| Supply chain attack | Code signing, notarization, open source audit |

### What's NOT Worth Stealing

Even with full access to a EmberHearth instance, an attacker gets:
- No credentials (they're in the keychain, used but not readable)
- No shell access (workbench is isolated)
- Conversation history (sensitive, but not system-compromising)
- User preferences (not valuable to attackers)

Compare to typical AI assistant architectures where compromising an instance gives you:
- All API keys in plaintext
- SSH keys
- Full shell access
- Everything

---

## User Experience

### Setup Flow (Target)

```
┌─────────────────────────────────────────────────────────────────┐
│                    MACBOT SETUP                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Download & Install                                      │
│  ─────────────────────────────                                   │
│  • Download EmberHearth from website or Mac App Store                 │
│  • Drag to Applications                                          │
│  • Launch                                                        │
│                                                                  │
│  Step 2: Grant Permissions                                       │
│  ─────────────────────────────                                   │
│  • macOS prompts for: Contacts, Calendar, Reminders, Mail        │
│  • User approves what they want EmberHearth to access                 │
│  • (Standard macOS permission flow - users understand this)      │
│                                                                  │
│  Step 3: Connect LLM                                             │
│  ─────────────────────────────                                   │
│  • "Sign in with Claude" / "Sign in with OpenAI" (OAuth)         │
│  • OR: Paste API key (stored in Keychain)                        │
│  • OR: Use local model (Ollama auto-detected)                    │
│                                                                  │
│  Step 4: Choose Interface                                        │
│  ─────────────────────────────                                   │
│  • iMessage (requires iCloud signed in)                          │
│  • EmberHearth app (always available)                                 │
│  • Both                                                          │
│                                                                  │
│  ✅ Done. Start chatting.                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**No:** Config files, Docker, terminal commands, environment variables, JSON editing.

### Daily Usage

**Simple Request (handled by structured operations):**
```
User: "What's on my calendar tomorrow?"
EmberHearth: [Uses calendar.listEvents] "You have 3 events tomorrow:
        - 9am: Team standup
        - 1pm: Lunch with Sarah
        - 3pm: Dentist appointment"
```

**Research Request (browser with content sanitization):**
```
User: "Find me 3 good articles about sourdough bread making and bookmark them"
EmberHearth: [Uses browser.search, browser.readPage (sanitized), browser.bookmark]
        "I've bookmarked 3 articles for you in Safari:
        1. 'The Complete Guide to Sourdough' - King Arthur Baking
        2. 'Sourdough for Beginners' - Serious Eats
        3. 'The Science of Sourdough' - Food52"
```

**Development Task (workbench for technical users):**
```
User: "Build my TypeScript project and run the tests"
EmberHearth: [Uses workbench.copyIn, workbench.exec, workbench.copyOut]
        "✅ Build complete. 47 tests passed, 0 failed.
        Build artifacts are in your project's dist/ folder."
```

### For Technical Users

Advanced users can:
- Enable the workbench for shell/dev tasks
- Add custom signatures to Tron
- Configure additional integrations
- View detailed audit logs
- Adjust security levels (with clear warnings)

But these are opt-in power features, not requirements.

---

## Accessibility

*Accessibility isn't an afterthought—it's central to the mission of making AI assistance available to everyone.*

### The iMessage Advantage

The primary interface for EmberHearth is **iMessage**. This is a deliberate choice with profound accessibility implications:

- **Familiar interface**: Everyone who uses an iPhone or Mac already knows how to send messages
- **Built-in accessibility**: Apple has invested heavily in making Messages accessible via VoiceOver, voice dictation, Switch Control, and other assistive technologies
- **No new app to learn**: Users interact with EmberHearth exactly as they would text a friend or family member
- **Elderly-friendly**: Even users who struggle with technology can and do send text messages to children and grandchildren daily

By choosing iMessage as the primary interface, EmberHearth inherits Apple's entire accessibility stack. Users who rely on VoiceOver, voice dictation, or other assistive technologies can interact with EmberHearth using the same methods they use for all their messaging.

### Voice Interface: An Accessibility Imperative

**Future consideration:** A voice interface (activated via "Hey [Name]" like Siri) is not just a convenience feature—it's an **accessibility necessity**.

For users who are:
- Visually impaired
- Have limited mobility
- Have conditions that make typing difficult
- Simply prefer hands-free interaction

A voice interface transforms EmberHearth from "accessible via iMessage" to "fully accessible regardless of physical capability."

**Implementation notes:**
- Must follow Apple's patterns for voice activation
- Users must understand privacy implications of always-listening
- Voice wake word should be configurable
- Integration with Apple's existing accessibility infrastructure

### Caregiver-Assisted Configuration

For users who need help with initial setup (elderly parents, users with cognitive challenges), the configuration model assumes:

1. **A caregiver or family member** handles initial installation and LLM provider setup
2. **The user** interacts via the familiar iMessage interface
3. **The Mac app** provides administrative functions but isn't required for daily use

This separation means the person *using* EmberHearth doesn't need to understand API keys, Docker, or security models. They just text their assistant.

### Self-Healing and Resilience

For users who can't troubleshoot technical issues, the system must be **as resilient and self-healing as possible**:

- Automatic recovery from transient failures
- Clear, simple error messages via iMessage when something is wrong
- Minimal intervention required to restore normal operation
- Background health monitoring with proactive issue resolution

This is the productization of an always-on, always-available personal assistant. For the elderly and disabled, this reliability isn't a nice-to-have—it's essential.

### Mac App and Workbench Accessibility

While iMessage is the primary interface, the Mac app and Workbench (for technical users) must also follow Apple's Human Interface Guidelines for accessibility:

- **VoiceOver support**: All UI elements properly labeled
- **Dynamic Type**: Respect system font size preferences
- **Reduced Motion**: Honor system preferences for animation
- **High Contrast**: Support system contrast settings
- **Keyboard Navigation**: Full keyboard accessibility for all functions

This aligns with Apple's expectations of quality and ensures no user is excluded from administrative functions.

---

## Error Handling and Graceful Degradation

*When things go wrong, the system should fail gracefully and communicate clearly.*

### LLM Provider Unavailable

**Scenario:** The LLM provider (Claude, OpenAI, etc.) is down, rate-limited, or unreachable.

**Response:**
- Auto-reply via iMessage: "I'm temporarily unable to respond. The AI service I use is currently unavailable. Please try again in a few minutes, or restart the Mac if the problem persists."
- Queue incoming requests locally
- When service is restored, process queued requests and respond accordingly
- Log the outage for diagnostics

### Network Outages

**Scenario:** The Mac loses internet connectivity.

**Response:**
- Detect network loss and switch to offline mode
- Auto-reply: "I'm currently offline and can't process requests that require internet access. I'll respond once connectivity is restored."
- Queue requests that can wait
- For local-only operations (if supported), continue processing
- When connectivity returns, process queue and resume normal operation

### Corrupted Memory Database

**Scenario:** The SQLite database containing personal memory becomes corrupted.

**Response:**
- Detect corruption during startup or operation
- Attempt automatic repair if possible
- If repair fails, restore from most recent backup
- Notify user: "I had to restore from a backup. Some recent conversations may not be remembered."

**Prevention:**
- Regular automated backups (see Backup section)
- Backups stored in iCloud for redundancy
- Point-in-time restore capability (similar to enterprise systems)

**Future consideration:** Explore failover/redundancy architectures for high-availability scenarios. Note for later exploration.

### Invalid or Broken Emotional Encoding

**Scenario:** Emotional encoding data for certain memories becomes corrupted or invalid.

**Response:**
- Reset corrupted entries to a neutral/non-emotional state
- Flag affected memories for re-processing during the next sleep cycle
- Continue operation using semantic matching only for affected memories
- During consolidation (sleep), perform full semantic analysis rebuild for flagged entries

### Failed Consolidation Cycles

**Scenario:** The background consolidation ("sleep") process fails or is interrupted.

**Response:**
- Log failure details for diagnostics
- Schedule retry during next quiet period
- Continue normal operation with provisional (non-consolidated) memory
- If repeated failures, alert user through Mac app (not iMessage) with diagnostic information

### General Principles

1. **Never leave users hanging**: Always provide a response, even if it's just an acknowledgment that something is wrong
2. **Communicate simply**: Error messages via iMessage should be understandable by non-technical users
3. **Fail gracefully**: Partial functionality is better than complete failure
4. **Recover automatically**: Minimize user intervention required to restore normal operation
5. **Log everything**: Detailed logs for diagnostics, but never exposed to users via iMessage

---

## Backup and Disaster Recovery

*Personal memories accumulated over months or years are irreplaceable. The system must protect them.*

### Storage in iCloud

Primary data storage should reside in an **iCloud-synced directory**:

- Automatic offsite backup without user configuration
- Leverages Apple's existing infrastructure
- Users who use iCloud already understand and trust this model
- Encryption in transit and at rest (Apple's implementation)

### Local Backup Strategy

In addition to iCloud sync:

- **Daily incremental backups** of the memory database
- **Weekly full backups** retained for rolling 4-week history
- Backups stored alongside primary data (synced to iCloud)
- Backup integrity verification during consolidation cycle

### Point-in-Time Restore

If data corruption or user error requires recovery:

1. User (or caregiver) accesses Mac app
2. Select restore point from available backups
3. Confirm restore action
4. System restores to selected point

This is a common pattern in enterprise systems adapted for personal use.

### What Gets Backed Up

- Personal memory database (interactions, knowledge, events)
- Emotional encoding data
- User preferences and configuration
- Tron signatures and customizations
- Consolidation state

### What Does NOT Get Backed Up

- Credentials (remain in macOS Keychain, not in app data)
- Temporary/cached data
- Active session state

### Recovery Scenarios

| Scenario | Recovery Path |
|----------|---------------|
| Mac Mini dies | New Mac + iCloud restore |
| Database corruption | Restore from local/iCloud backup |
| Accidental deletion | Point-in-time restore |
| Migration to new Mac | iCloud sync handles automatically |

---

## Data Portability

*Users should be able to export their data. This builds trust and enables future flexibility.*

### Export Capability (Future Feature)

While not a near-term priority, the system should support data export:

- **Full export**: All personal memories, preferences, and learned patterns
- **Selective export**: Specific date ranges or topics
- **Standard format**: JSON or similar human-readable format

### Defining a Standard

Since there's no established standard for personal AI assistant data, EmberHearth could **define one**:

- Open specification for memory/knowledge representation
- Published schema documentation
- Potential for ecosystem interoperability if other projects adopt it

This isn't about competition (there isn't meaningful competition in this space yet). It's about:
- User trust (your data is never locked in)
- Future-proofing (data survives if the project ends)
- Transparency (users can see exactly what's stored about them)

### Import Capability

If export exists, import should follow:
- Validate imported data against schema
- Merge or replace existing data (user choice)
- Handle version differences gracefully

---

## Business Model Considerations

### Philosophy: The Apple Model

This project follows Apple's philosophy: **buy the hardware, get the software free.**

There's no "Pro" tier, no cloud backup subscription, no enterprise upsell. iCloud already exists. Users who want cloud sync and backup can use the infrastructure Apple already provides. The goal isn't to build a business—it's to build something genuinely good.

**This isn't about:**
- Making money
- Building a company
- Fame or recognition
- Creating another SaaS

**This is about:**
- Doing something good
- Helping make people's lives better
- Taking a meaningful step forward in how humans interact with AI
- Demonstrating what's possible when security isn't an afterthought

If this project helps foundation model companies (Anthropic, OpenAI, Google) by spurring adoption and demonstrating viable consumer AI deployment, that's a good outcome for everyone. They need paths to broad adoption beyond chat interfaces. This could be one.

### Open Source with Quality

**Everything is open source (MIT or Apache 2.0):**
- The application itself
- Tron filtering engine
- All structured operations
- Local-only, no required services
- No paywalls, no tiers, no artificial limitations

Open source for trust, transparency, and community contribution. But with production-quality code, documentation, and user experience. Not a hobbyist project that happens to be open source.

### The Ecosystem Opportunity

Foundation model companies have invested billions. They need:
- Consumer adoption beyond chat interfaces
- Always-on, integrated AI experiences
- Trust that drives mainstream usage

A well-designed, secure, open-source AI assistant benefits:
- **Users:** Get useful AI assistance safely
- **Model providers:** Get adoption and usage
- **Developers:** Build on a secure platform
- **The ecosystem:** Raises the bar for AI safety
- **Staff at AI companies:** Validation that their work matters and improves lives

---

## Foundation Model Terms of Service: A Critical Constraint

*This section documents a significant constraint discovered during planning that affects the entire approach.*

### The Problem

Foundation model companies have terms of service that may prohibit or complicate "always-on" autonomous assistants. Recent account bans related to third-party automation tools highlight that this is actively enforced.

### Anthropic (Claude)

**The Killer Clause** - From their Consumer Terms of Service, Section 3:

> "Except when you are accessing our Services via an Anthropic API Key or where we otherwise explicitly permit it, **to access the Services through automated or non-human means, whether through a bot, script, or otherwise.**"

This is unambiguous. Using a Claude Pro/Max subscription ($20-200/month flat rate) through any third-party automated tool violates the terms.

**Enforcement:**
- January 2026: Anthropic deployed technical blocks against third-party clients accessing consumer subscriptions
- 690,000 accounts banned between January-June 2025
- Tools spoofing Claude Code client to access flat-rate subscriptions were specifically targeted

**The Two Permitted Paths:**
1. **Consumer subscription** → Human chat through official interfaces only (Claude.ai, official apps)
2. **Commercial API** → Metered, per-token pricing → Automated/agentic use permitted

**The Economics:** An autonomous coding agent can burn through $1,000+ in API tokens in a single session. Offering unlimited automation on a $200/month flat rate is unsustainable for the provider.

### OpenAI

OpenAI is **more permissive** for agentic use. They've released:
- Responses API (designed for agents)
- Agents SDK (open source framework)
- Explicit support for third-party tools with ChatGPT Pro/Plus subscriptions

**Restrictions that still apply:**
- "Automatically or programmatically extract data or Output"
- "Automation of high-stakes decisions in sensitive areas without human review" (legal, medical, employment, financial, housing, education)
- Circumventing safeguards or rate limits

Key difference: OpenAI appears to allow automated access through consumer subscriptions, while Anthropic explicitly forbids it.

### Google Gemini

**Ambiguous restrictions:**
> "You may not use the Gemini API to power another application programming interface."
> "You must only use the Services directly or in connection with a service that you offer directly to end users."

This could be interpreted either way for a personal assistant. If you're wrapping Gemini in an intermediary layer, it might violate terms. If you're providing it "directly to end users" (even yourself), it might be acceptable. More legal research needed.

### The Cost Reality

An "always-on" personal assistant using commercial API pricing:

| Provider | Approximate Cost (per 1M tokens) | Monthly Reality |
|----------|----------------------------------|-----------------|
| Claude Sonnet | ~$3 input / $15 output | Heavy agent use: $50-500+/month |
| GPT-4o | ~$2.50 input / $10 output | Similar range |
| Gemini Pro | Free tier → then $0.50-2 | Most economical, but terms unclear |

A casual user chatting occasionally might use 100k tokens/month ($1-5). But an autonomous agent doing research, browsing, and tasks could easily use 10M+ tokens ($30-150+/month or more).

### Paths Forward

#### Option 1: Local Models Only

- Use Ollama/llama.cpp with open-weight models (Llama 3, Mistral, Phi, Gemma, etc.)
- Zero API cost, zero terms violations
- **Capability trade-off:** Local models are currently less capable than Claude/GPT-4
- **Research required:** This area is evolving rapidly; capability gaps may narrow

#### Option 2: Commercial API with Cost Controls

- Use metered API properly and legally
- Implement strict token budgets and rate limiting
- Be transparent with users about costs
- This is the "legal" path for cloud models

#### Option 3: Hybrid Approach

- Local model for routine tasks, filtering, and simple requests
- Commercial API only for complex tasks (with user consent and cost awareness)
- Balances cost control with capability when needed
- Adds architectural complexity

#### Option 4: Wait for Agent-Specific Tiers

- OpenAI is moving toward agent-friendly offerings
- Anthropic might follow if market demands it
- Betting on this is risky—could wait indefinitely

### Local Models: Security Considerations

**The capability gap necessitates research into local models, but this introduces its own security considerations.**

Several high-performing open-weight models have been released by organizations outside the US (Kimi, GLM, DeepSeek, Qwen, etc.). While these models may offer compelling capabilities:

1. **Geopolitical context matters.** Some originate from countries with adversarial relationships to the US. This doesn't mean the models are malicious, but it warrants caution.

2. **Model behavior is opaque.** Even with open weights, understanding exactly what a model might do in edge cases is difficult. A model could theoretically be trained to exfiltrate data under certain conditions.

3. **The creators are not their governments.** Many brilliant researchers work on these models for legitimate scientific purposes. Good solutions can come from anywhere. Dismissing work based solely on country of origin would be counterproductive.

4. **Prudent security applies regardless of origin.** Even "trusted" models from US companies should not have unrestricted access to sensitive data. The same sandboxing principles apply.

**Recommendation:** Local models—regardless of origin—should run in sandboxed environments with:
- No direct network access (prevent exfiltration)
- No access to credentials or secrets
- Explicit, auditable data transfer (copy in, copy out)
- Output validation before acting on results

This "trust but verify" approach allows using the best available models while mitigating risks. A model running in a sandbox with no network access cannot exfiltrate data, regardless of its origin or intentions.

**Research needed:**
- Which local models offer the best capability/efficiency trade-off for assistant tasks?
- What's the minimum viable hardware (can a mid-spec Mac Mini run useful models)?
- How do capability gaps affect real-world assistant usability?
- What's the latency impact of sandboxed local inference?

### The Hidden Question in the Dream Setup

The "dream setup" of:
```
Buy Mac → Install EmberHearth → Chat via iMessage → Always-on assistant
```

Has a hidden asterisk: **Who pays for the LLM?**

For a non-technical user (the teacher, the parent), the options are:

1. **Local models** - Requires decent hardware, currently less capable, needs research
2. **User provides their own API key** - Too technical, defeats the simplicity goal
3. **Application provides access** - Creates a business model question we said we'd avoid
4. **Free tiers** - Very limited, not viable for "always-on"

This might be the biggest unsolved problem in the vision. The foundation model companies want adoption, but they don't want unlimited automated usage on flat-rate consumer plans.

**Possible resolution:** If local models improve sufficiently (and they're improving rapidly), option 1 becomes viable. The EmberHearth vision may need to be timed to when local models cross the "good enough" threshold for assistant tasks.

---

## Token Efficiency: A Design Criteria

*Foundation model providers recognize always-on assistants as high-usage scenarios. Token efficiency isn't just about cost—it's about making the vision viable.*

### The Problem Scale

Typical multi-tool MCP setups consume massive tokens before any user interaction:
- GitHub MCP: ~26,000 tokens
- Slack MCP: ~21,000 tokens
- Five-server setup: ~55,000 tokens just for tool definitions

Agentic workflows compound this: every tool call, result, and reasoning step accumulates. Long-horizon tasks can hit context limits or incur unsustainable costs.

### Known Solutions

Anthropic achieved **98.7% token reduction** in Claude Code through:
- **Code-based tool APIs:** Tool definitions become code imports, not context
- **Progressive disclosure:** Tools discovered on-demand, not preloaded
- **Sandbox-local payloads:** Large intermediate data stays in sandbox, not context

Academic research (ACON, Active Context Compression) shows:
- **26-54% memory reduction** while preserving task performance
- **Context poisoning** is real—irrelevant history degrades reasoning
- Compression strategies can be **distilled into smaller models** while maintaining 95%+ accuracy

### Local LLM as Token Efficiency Layer

*This is a speculative architectural idea that warrants research.*

Rather than asking "Can a local model replace the cloud model?", ask: **"Can a local model make cloud usage dramatically more efficient?"**

A local model optimized for compression/filtering could:

1. **Progressive disclosure:** Determine what context the cloud model actually needs
2. **Compaction:** Summarize conversation history, tool outputs, long documents
3. **Filtering:** Remove irrelevant information before sending to cloud
4. **Request classification:** Decide if request can be handled locally vs needs cloud
5. **Result caching:** Track what's been asked/answered to avoid redundant queries

**What this local model needs to be good at:**
- Summarization
- Classification / intent detection
- Context relevance scoring
- **Not necessarily:** Complex reasoning, creative generation, tool use planning

This is a more tractable problem than "local model does everything." A model optimized for compression doesn't need Claude-level capability.

### The Trade-off Question

**Latency:** Local inference adds time. Is the latency cost worth the token savings?

**Possible answer:** If local filtering prevents unnecessary cloud calls, net latency might actually improve. A local model that handles 60% of requests entirely—and compresses context for the remaining 40%—could be faster *and* cheaper than sending everything to the cloud.

**Performance uncertainty:** This needs empirical testing. The approach might:
- Work brilliantly (significant cost reduction with acceptable latency)
- Work marginally (modest savings, not worth complexity)
- Not work (local model too slow or compression degrades quality)

### Research Questions

1. **Compression quality:** Can a small local model (7B, 3B) produce summaries good enough that Claude/GPT-4 can reason effectively from them?
2. **Latency budget:** What's the acceptable local inference time? 500ms? 2 seconds?
3. **Request routing:** What percentage of assistant requests can a local model handle entirely? 40%? 70%?
4. **Compaction fidelity:** How much information loss is acceptable in history summarization?
5. **Implementation complexity:** Is the multi-model architecture worth the engineering cost?

### Implications for Architecture

If this approach proves viable, the architecture becomes:

```
User Request
     │
     ▼
┌─────────────────────────────────┐
│   LOCAL MODEL (Efficiency)      │
│   • Classify request            │
│   • Handle simple requests      │
│   • Compress context for cloud  │
│   • Summarize results for       │
│     history                     │
└─────────────────┬───────────────┘
                  │
        ┌─────────┴─────────┐
        │ Simple?           │ Complex?
        ▼                   ▼
   Local Response     ┌─────────────────────────────────┐
                      │   CLOUD MODEL (Capability)      │
                      │   • Complex reasoning           │
                      │   • Tool use planning           │
                      │   • Creative generation         │
                      │   (with compressed context)     │
                      └─────────────────────────────────┘
```

The local model becomes a "compression proxy"—not trying to match cloud capability, but optimizing cloud efficiency.

---

## True Personal Memory: Beyond File-Based Storage

*This section explores what genuine "learning" and "remembering" would look like for a personal assistant.*

### Clarifying "Learning"

When we say the assistant "learns," we don't mean the LLM overwrites its training data or fine-tunes itself. We mean:

- **Temporal recall**: Facts, events, opinions recorded over time
- **Contextual retrieval**: Information surfaces when relevant
- **Actionable memory**: Recalled information can inform responses and actions
- **Natural recall**: "Do you remember telling me about that while you were working from home, Friday, about two weeks ago?"

The "learning" comes from stored data of previous interactions, not model adaptation. But to the user, it *appears* the assistant remembers and grows more helpful over time.

### The Problem with File-Based Memory

Many AI assistants store memory as plain Markdown files. This has fundamental problems:

1. **Security red flag**: Private information in plaintext on disk
2. **No privacy granularity**: Some information should be private to specific contexts
3. **No privileged information handling**: No distinction between "know this" and "can mention this"
4. **No automatic extraction**: Requires user to explicitly say "remember this"
5. **No temporal structure**: Files don't capture the flow of when things were learned

### Privileged Information: Background Weight

A sophisticated assistant needs to handle information that *influences behavior without being surfaced*:

- User tells assistant something private
- Assistant doesn't bring it up randomly
- But it *influences* how the assistant interacts
- More gentle about certain topics, avoids certain suggestions
- Until user surfaces it themselves, it remains latent

**Example:** User mentions they're going through a divorce. The assistant:
- Doesn't randomly say "How's your divorce going?"
- But avoids suggesting "plan a romantic dinner with your spouse"
- Might be more understanding about stress-related topics
- Only discusses directly if user brings it up

This requires **information tagging** with:
- Privacy levels (public, general, private, secret)
- Surfacing rules (always, on_topic, user_initiated, never)
- Context scope (which conversations can access this)

### The Internal Reasoning Loop: Reflective Context Expansion

The assistant needs an internal "thinking moment"—a self-reflective loop that runs *before* or *alongside* the main LLM response. This isn't the LLM's chain-of-thought; it's an external meta-cognitive layer that reasons about what the user might actually need.

**The problem:** The LLM isn't trained on user data. Mixture-of-experts and chain-of-thought help LLMs reason generally, but they can't reason about *this specific user's* history, preferences, and patterns. That requires an intelligent RAG-like system that does its own thinking.

**How it works:**

1. User makes a request (e.g., "find me a YouTube video on woodworking joints")
2. The naive approach: search "woodworking joints," return top results
3. The reflective approach:
   - System recognizes the topic "woodworking joints"
   - Searches user's knowledge graph: has user expressed interest in related topics?
   - Finds: user previously mentioned enjoying furniture restoration, specifically mid-century modern
   - Considers: people who watch woodworking joints videos often end up needing wood finishing techniques
   - Weighs: should I expand the response? When did I last make this kind of helpful expansion?
   - Decides: include both the literal request AND tangentially relevant content

**The internal dialogue (conceptually):**

> "User asked for woodworking joints videos. I know from three weeks ago they mentioned refinishing a mid-century credenza. People learning joints often need finishing techniques next. I haven't offered this kind of expansion in a while—last time was helpful. I'll search for joints videos but also surface one or two on finishing techniques for vintage furniture, framing it as 'you might also find this useful given your credenza project.'"

**This is a "left brain / right brain" architecture (metaphorically):**

```
┌────────────────────────────────────────────────────────────────────┐
│                      REQUEST PROCESSING                             │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────┐    ┌─────────────────────────────────┐│
│  │   LITERAL PROCESSOR     │    │   REFLECTIVE PROCESSOR          ││
│  │   ("Left Brain")        │    │   ("Right Brain")               ││
│  │                         │    │                                 ││
│  │   • Parse request       │    │   • Query user knowledge graph  ││
│  │   • Execute search      │    │   • Find semantic overlaps      ││
│  │   • Return results      │    │   • Consider tangent value      ││
│  │                         │    │   • Check expansion history     ││
│  │                         │    │   • Weigh helpfulness vs noise  ││
│  │                         │    │   • Decide: expand or not?      ││
│  └───────────┬─────────────┘    └───────────────┬─────────────────┘│
│              │                                   │                  │
│              └───────────────┬───────────────────┘                  │
│                              │                                      │
│                      ┌───────▼───────┐                              │
│                      │   SYNTHESIS   │                              │
│                      │               │                              │
│                      │  Merge literal│                              │
│                      │  results with │                              │
│                      │  reflective   │                              │
│                      │  expansions   │                              │
│                      └───────┬───────┘                              │
│                              │                                      │
│                      ┌───────▼───────┐                              │
│                      │  LLM PROMPT   │                              │
│                      │               │                              │
│                      │  Intelligently│                              │
│                      │  constructed  │                              │
│                      │  with context │                              │
│                      └───────────────┘                              │
└────────────────────────────────────────────────────────────────────┘
```

**Key insight:** This reflective processor is *not* the LLM. It's a separate reasoning component (possibly a smaller local model, or rule-based logic over the knowledge graph) that:

1. Knows about the user (from the personal knowledge store)
2. Understands semantic proximity (what topics are near this one?)
3. Tracks its own behavior (when did I last expand? was it helpful?)
4. Makes meta-decisions (should I go beyond the literal request?)

The output of this reflective process becomes part of the prompt to the main LLM, which then formulates the actual response. The LLM gets *intelligently curated context* rather than raw retrieval results.

**Self-calibration:**
- The system tracks when expansions were helpful vs. ignored
- Too many ignored expansions → reduce expansion frequency
- Positive feedback on expansions → weight similar expansions higher
- The system learns the user's tolerance for tangential helpfulness

### The Affective State Vector (ASV): The Salience Foundation

*This section describes a novel multi-dimensional model for encoding emotional state—the Affective State Vector (ASV)—derived from neurochemical principles and years of independent research. The ASV enables true salience—the system knows not just what was said, but why it mattered.*

#### The Problem with Existing Emotional Models

Existing approaches to emotional encoding in AI are inadequate:

1. **IEEE Emotional Mapping** - One-dimensional word-to-state mapping. "Angry" means angry, with no gradation, co-occurrence, or nuance.
2. **Plutchik's Wheel** - Two-dimensional, layered. Better, but still treats emotions as discrete regions rather than continuous states.
3. **PAD Model** (Pleasure-Arousal-Dominance) - Three dimensions, but the axes don't reflect how emotions actually resolve.

**The core problem:** Human language is a lossy compression of emotional experience. It works as markers and direction, but it's not the signal itself. The actual encoding is more like neurochemical states—multiple channels simultaneously, varying intensities, continuous values.

#### Neurochemical Grounding

Consider a neuron's function at the simplest level: take in chemically-encoded information, transform it, pass it forward with a signal indicating "I'm related *in this kind of way*." With 32+ identified neurochemicals (and likely more), the encoding is rich and multi-channel.

Consider serotonin specifically: a neuron with *no* serotonin vs. one *saturated* with it would process and re-encode information differently. The neurochemical state influences how data is transformed and passed on. This suggests emotional states aren't labels applied to experiences—they're part of the encoding mechanism itself.

#### The Affective State Vector (ASV)

EmberHearth encodes emotional states as a 7-dimensional vector called the **Affective State Vector (ASV)**. Rather than discrete labels like "happy" or "angry," the ASV represents emotions as continuous values across multiple axes—capturing the nuanced, multi-channel nature of actual emotional experience.

#### The Emotional Axes: True Opposites

Rather than discrete labels, emotions exist on continuous axes between true opposites. The key insight: opposites are defined by what *resolves* the emotion, not what seems linguistically opposite.

**Primary Emotional Axes:**

```
Anger <────────────────────────> Acceptance
       (refusal to accept)              (anger dissolves)

Fear <─────────────────────────> Trust
       (absence of trust)               (fear dissolves)

Hope/Joy <─────────────────────> Despair
       (forward-looking reward)         (absence of hope)

Interest <─────────────────────> Boredom
       (novelty, unknown)               (nothing new to learn)
```

**Why these pairings:**
- Anger doesn't resolve into joy—it resolves into acceptance of the situation
- Fear doesn't resolve into happiness—it resolves into trust
- Joy/hope is forward-looking; its absence is despair, not anger
- Interest moderates other emotions—you can't have maximal anger at something you find boring

#### The 3D Emotional Cube

Mapping these axes creates a three-dimensional space with emotions at the vertices:

```
                    INTEREST ─────────────────── ANGER
                      /│                          /│
                     / │                         / │
                    /  │                        /  │
                   /   │                       /   │
             HOPE/JOY ─│─────────────────── FEAR  │
                  │    │                      │    │
                  │    │                      │    │
                  │  TRUST ───────────────────│─ DESPAIR
                  │   /                       │   /
                  │  /                        │  /
                  │ /                         │ /
                  │/                          │/
            ACCEPTANCE ─────────────────── BOREDOM


Vertex positions:
  Upper left front:   Interest
  Upper right front:  Hope/Joy
  Lower left front:   Trust
  Lower right front:  Acceptance
  Upper left back:    Anger
  Upper right back:   Fear
  Lower left back:    Despair
  Lower right back:   Boredom
```

A point anywhere in this space represents a *combination* of emotional states. Not "I feel angry" but "I feel this specific blend of anger/acceptance, fear/trust, hope/despair, interest/boredom."

#### The Weakly Influencing Axes

The cube alone doesn't capture everything. Three additional axes pass through the center, acting as *modulators* rather than primary dimensions:

**1. Temporal Axis (Past ↔ Future)**

```
Past <──────────(center = present)──────────> Future
```

- Future-oriented emotions: Fear, Hope, Acceptance, Boredom
- Past-oriented emotions: Anger, Interest, Despair, Trust

You can fear what might happen. You're angry about what did happen. This axis weakly influences the encoding—not defining the emotion, but coloring its temporal orientation.

**2. Valence Axis (Positive ↔ Negative)**

```
Positive <──────────(center = neutral)──────────> Negative
```

- Positive experience: Interest, Hope, Acceptance, Trust
- Negative experience: Anger, Fear, Boredom, Despair

Note: Boredom feels negative even though it can motivate positive change. This axis encodes the *experience*, not the outcome.

**3. Intensity/Attention Axis (Attentive ↔ Absent)**

```
Attentive <──────────(center = moderate)──────────> Absent
```

- High attention states: Anger, Fear, Interest, Hope
- Low attention states: Acceptance, Boredom, Trust, Despair

This axis allows encoding of intensity independent of emotional type. You can be mildly interested or intensely interested; mildly afraid or paralyzed with fear.

#### The Complete ASV Encoding

Each axis becomes a numeric value. The complete ASV is a 7-element vector:

```
ASV = [
    anger_acceptance,      // -1.0 (anger) to +1.0 (acceptance)
    fear_trust,            // -1.0 (fear) to +1.0 (trust)
    despair_hope,          // -1.0 (despair) to +1.0 (hope/joy)
    boredom_interest,      // -1.0 (boredom) to +1.0 (interest)
    temporal,              // -1.0 (past) to +1.0 (future)
    valence,               // -1.0 (negative) to +1.0 (positive)
    intensity              // 0.0 (absent) to 1.0 (fully attentive)
]
```

The ASV can be stored as bytes (0-255 per axis), integers, or floats depending on precision needs. It can be:
- **Recorded** alongside memories (this fact was learned in *this* ASV)
- **Played back** to reconstruct emotional context
- **Compared** to find emotionally similar experiences (ASV distance)
- **Averaged** to understand emotional patterns over time

#### The Movable Midpoint: Disposition and Personality

**Critical insight:** The "neutral" point doesn't have to be [0, 0, 0, ...].

The midpoint can move to represent:

1. **Temporal disposition** - The AI starts more cautious (fear-biased) in the morning, more relaxed (trust-biased) in the evening
2. **User accommodation** - User is irritable before coffee → AI's midpoint shifts toward low-intensity to avoid bothering them
3. **Contextual personality** - Different baselines for work topics vs. personal topics
4. **Learned preferences** - Over time, the midpoint adjusts based on what states led to positive interactions

```
┌─────────────────────────────────────────────────────────────────┐
│                    MOVABLE MIDPOINT                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Default midpoint: [0, 0, 0, 0, 0, 0, 0.5]                      │
│                                                                  │
│  Morning adjustment:                                             │
│    - Lower intensity (don't bother user)                        │
│    - Shift toward acceptance (less reactive)                    │
│                                                                  │
│  Evening adjustment:                                             │
│    - Higher intensity (user needs support)                      │
│    - Shift toward trust (more comforting)                       │
│                                                                  │
│  User-specific learning:                                         │
│    - This user prefers direct engagement → higher intensity     │
│    - This user dislikes unsolicited suggestions → lower interest│
│                                                                  │
│  Context-specific baselines:                                     │
│    - Work topics: more neutral, professional                    │
│    - Family topics: more empathetic, warmer                     │
│    - Health topics: more cautious, supportive                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

The midpoint becomes a **personality encoding**. A more cautious AI has a midpoint shifted toward fear. A more optimistic AI has a midpoint shifted toward hope. This isn't just state—it's disposition that influences all emotional responses.

#### Application to Salience

The ASV solves the salience problem:

**Without ASV:**
- Memory: "User mentioned their mother is sick"
- Retrieval: Keyword/semantic match only
- Problem: System doesn't know this is *important*

**With ASV:**
- Memory: "User mentioned their mother is sick" + ASV: [-0.3, -0.5, -0.6, 0.2, -0.2, -0.7, 0.9]
  - (Slight anger, significant fear, strong despair tendency, moderate interest, past-oriented, very negative, high intensity)
- Retrieval: Can search by ASV similarity, not just semantic
- Result: System knows this memory carries weight; it was encoded with fear, despair, and high intensity

**ASV similarity search:**

When the user mentions something related to family health, the system can find memories with similar ASV signatures—even if the words are different. "My dad's test results" might retrieve the mother-sick memory because the ASV is similar, not because the words match.

#### Implementation Considerations

**Storage schema addition:**

```sql
-- Add ASV to interactions and knowledge
ALTER TABLE interactions ADD COLUMN asv BLOB;  -- 7 floats packed
ALTER TABLE knowledge ADD COLUMN asv BLOB;
ALTER TABLE events ADD COLUMN asv BLOB;

-- Index for ASV similarity (would need custom extension or app-level)
-- ASV distance = weighted euclidean distance across axes
```

**Emotional inference:**

The system needs to infer emotional state from interactions. This could be:
- LLM-based analysis of user messages
- Pattern recognition (certain topics → certain emotional signatures)
- Explicit user signals (tone, punctuation, response patterns)

**Emotional playback:**

When retrieving memories for context, the emotional encoding can inform:
- Which memories are most salient (high intensity = more important)
- How to frame the response (match or complement user's likely state)
- What to avoid surfacing (high negative valence on certain topics)

#### Extensibility

The model doesn't require exactly these axes. Additional dimensions could include:
- Social orientation (self ↔ other)
- Agency (in control ↔ helpless)
- Certainty (confident ↔ uncertain)

The architecture supports arbitrary dimensionality—the key insight is continuous axes with meaningful opposites, weakly influencing modulators, and a movable midpoint for disposition.

#### Prior Art Assessment

This model synthesizes concepts from multiple fields but the specific combination appears novel:

- **Different from PAD:** Different axes, adds temporal/intensity modulators, movable midpoint
- **Different from OCC:** Continuous rather than categorical, encoding rather than appraisal
- **Different from Plutchik:** 3D+ rather than 2D, explicit encoding mechanism
- **Different from IEEE standards:** Continuous rather than discrete, acknowledges co-occurrence

The movable midpoint for personality/disposition and the weakly influencing axes as modulators appear to be original contributions.

### Consolidation Cycle: The System Needs to Sleep

The computational requirements for full emotional encoding, salience scoring, temporal linking, and pattern detection are significant. Doing this work synchronously during user interactions would introduce unacceptable latency and compute costs.

**The solution:** A background consolidation cycle—the system "sleeps."

#### What Happens During Sleep

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONSOLIDATION CYCLE                           │
│                    (Background Processing)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. RAW → STRUCTURED                                             │
│     • Process interaction logs from the day                     │
│     • Extract facts, preferences, relationships                 │
│     • Link new knowledge to source interactions                 │
│                                                                  │
│  2. ASV COMPUTATION                                              │
│     • Analyze interactions for emotional content                │
│     • Compute Affective State Vectors with full deliberation    │
│     • Tag memories with salience scores                         │
│                                                                  │
│  3. VECTOR INDEXING                                              │
│     • Generate/update embeddings for new content                │
│     • Re-index vector store for efficient retrieval             │
│     • Compute emotional similarity clusters                     │
│                                                                  │
│  4. PATTERN DETECTION                                            │
│     • Analyze temporal patterns across interactions             │
│     • Update behavioral models for anticipation engine          │
│     • Detect emerging preferences or concerns                   │
│                                                                  │
│  5. MIDPOINT CALIBRATION                                         │
│     • Adjust movable midpoint based on learned patterns         │
│     • Update context-specific baselines                         │
│     • Refine intrusion calibration weights                      │
│                                                                  │
│  6. MAINTENANCE                                                  │
│     • Prune/compact old or low-salience data                    │
│     • Merge redundant knowledge entries                         │
│     • Verify data integrity                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Why This Mirrors Human Sleep

This isn't anthropomorphization for aesthetics—it's convergent design based on similar constraints:

1. **Memory consolidation**: Human brains don't store memories in final form during experience. Initial encoding is fast and rough; consolidation during sleep reorganizes and strengthens important memories.

2. **Pattern extraction**: REM sleep appears involved in extracting patterns and relationships from the day's experiences. The system's pattern detection serves the same function.

3. **Pruning**: Sleep involves synaptic pruning—weakening unimportant connections. The system's maintenance phase serves a similar purpose.

4. **Resource constraints**: Brains can't do deep processing while also handling real-time interaction. Neither can software systems without significant latency.

#### Implementation Considerations

**When to sleep:**
- During user-defined quiet hours (overnight, typically)
- When system detects sustained user inactivity
- On-demand if user requests ("take some time to process")

**Graceful degradation:**
- System remains responsive during sleep (can wake for urgent interactions)
- Recent interactions use lightweight/provisional encoding until consolidated
- User can interrupt sleep cycle if needed

**Sleep depth levels:**
- **Light**: Quick indexing and tagging only (~minutes)
- **Standard**: Full consolidation cycle (~30-60 minutes)
- **Deep**: Comprehensive re-analysis, pattern detection across full history (~hours, infrequent)

**User communication:**
- System can indicate it's processing: "I'm going to take some time to think through everything we discussed today"
- Morning greeting could reference consolidation: "Good morning. I was thinking about what you mentioned yesterday about the project deadline..."

#### The UX Opportunity

Rather than hiding this as a technical detail, it becomes part of the assistant's character:

- The assistant "sleeps" and "wakes up"
- It can reference "thinking about" things from previous days
- It feels more like a relationship with continuity than a stateless tool

This is not pretense—it's accurate description of what the system is actually doing, presented in human-relatable terms.

### Storage Architecture: Not Files

A proper personal knowledge store:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERSONAL KNOWLEDGE STORE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │  RDBMS Core     │    │  Vector Index   │    │  Encryption  │ │
│  │  (SQLite/DuckDB)│    │  (Embeddings)   │    │  Layer       │ │
│  │                 │    │                 │    │              │ │
│  │  • Structured   │    │  • Semantic     │    │  • Per-record│ │
│  │    facts        │    │    search       │    │  • Per-topic │ │
│  │  • Temporal     │    │  • Similarity   │    │  • At-rest   │ │
│  │    events       │    │    matching     │    │  • Key mgmt  │ │
│  │  • Metadata     │    │                 │    │    (Keychain)│ │
│  │    (privacy,    │    │                 │    │              │ │
│  │    context)     │    │                 │    │              │ │
│  └────────┬────────┘    └────────┬────────┘    └──────┬───────┘ │
│           │                      │                     │         │
│           └──────────────────────┴─────────────────────┘         │
│                              │                                   │
│                    ┌─────────▼─────────┐                         │
│                    │  Retrieval Engine │                         │
│                    │                   │                         │
│                    │  • Context-aware  │                         │
│                    │  • Privacy-aware  │                         │
│                    │  • Temporal-aware │                         │
│                    └───────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

### Schema Design: Temporal Memory with Interaction Links

**Critical insight**: Knowledge and events must link back to the interactions where they originated. This enables temporal reconstruction—the LLM can recall not just *what* was said, but *when* and *in what context*.

```sql
-- Core interaction log (automatic, temporal)
CREATE TABLE interactions (
    id TEXT PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    session_id TEXT,
    context_type TEXT,      -- 'private', 'shared', 'work', 'family'
    role TEXT,              -- 'user', 'assistant'
    content TEXT,
    content_embedding BLOB,
    summary TEXT,
    privacy_level INTEGER,  -- 0=public, 1=general, 2=private, 3=secret
    surfacing_rule TEXT,    -- 'always', 'on_topic', 'user_initiated', 'never'
    location_context TEXT,  -- 'home', 'office', 'traveling'
    encrypted BOOLEAN DEFAULT FALSE
);

-- Extracted facts/knowledge (linked to source interaction)
CREATE TABLE knowledge (
    id TEXT PRIMARY KEY,
    interaction_id TEXT NOT NULL,  -- CRITICAL: links to when this was learned
    fact_type TEXT,         -- 'preference', 'relationship', 'event', 'opinion', 'secret'
    subject TEXT,           -- 'user', 'wife:Sarah', 'child:Emma', 'friend:John'
    predicate TEXT,         -- 'likes', 'dislikes', 'scheduled_for', 'said', 'believes'
    object TEXT,
    object_embedding BLOB,
    confidence REAL,
    valid_from DATETIME,
    valid_until DATETIME,   -- NULL = still valid
    privacy_level INTEGER,
    context_scope TEXT,     -- which conversations can access this
    surfacing_rule TEXT,
    FOREIGN KEY (interaction_id) REFERENCES interactions(id)
);

-- Temporal events (linked to source interaction)
CREATE TABLE events (
    id TEXT PRIMARY KEY,
    interaction_id TEXT,    -- when this event was mentioned/created
    event_type TEXT,        -- 'reminder', 'appointment', 'anniversary', 'pattern', 'medical'
    description TEXT,
    description_embedding BLOB,
    scheduled_time DATETIME,
    recurrence TEXT,        -- 'once', 'daily', 'weekly', 'yearly'
    context_scope TEXT,
    priority INTEGER,       -- for salience ranking
    action_taken BOOLEAN DEFAULT FALSE,
    action_timestamp DATETIME,
    FOREIGN KEY (interaction_id) REFERENCES interactions(id)
);

-- Indexes for temporal retrieval
CREATE INDEX idx_interactions_timestamp ON interactions(timestamp);
CREATE INDEX idx_knowledge_interaction ON knowledge(interaction_id);
CREATE INDEX idx_events_scheduled ON events(scheduled_time);
```

### Temporal Recall: Natural Human-Like Memory

**Why interaction links matter:**

When searching for topical data, the system can:
1. Find semantically relevant knowledge via vector search
2. Retrieve the source interaction (temporal context)
3. Retrieve surrounding interactions (conversational flow)
4. Reconstruct the *context* in which information was learned

This enables responses like:

> "Yes, your friend said X, but when we were talking about it before—when you told me about working on project A at your job—you mentioned your friend explained Y differently."

**Human brains work this way.** Memory is encoded in temporal context. Sometimes details aren't recalled until a seemingly irrelevant time or place is remembered first. Then the coherent detail surfaces.

A personal assistant that operates this way:
- Helps users remember not just facts, but *when and where* they discussed them
- Adds temporal anchors: "Do you remember telling me about that while you were working from home, Friday, about two weeks ago?"
- Creates more natural linguistic interaction
- Builds trust through demonstrated continuity

### Automatic Memory Without User Action

The system should automatically:
- Log all interactions with timestamps and context
- Extract facts, preferences, and events
- Tag privacy levels based on content analysis
- Build temporal associations
- Summarize for efficient retrieval

**The user should never need to say "remember this."** The assistant just remembers—intelligently, with appropriate privacy boundaries.

---

## Anticipation: Beyond Proactive Polling

*What distinguishes true anticipation from simple proactivity.*

### The Spectrum: Reactive → Proactive → Anticipatory

**Reactive** (most assistants):
```
User: "What's on my calendar tomorrow?"
Assistant: [checks calendar, responds]
```

**Proactive** (simple heartbeat approach):
```
[Timer fires]
Assistant: [checks inbox] "You have 3 new emails, one marked urgent."
```

**Anticipatory** (the goal):
```
[No prompt from user]
[System recognizes: tomorrow is anniversary + user mentioned wanting to plan something 
 + wife likes Italian food + user has been stressed about work]
Assistant: "Tomorrow is your anniversary. Based on what you mentioned last week, 
I found a few Italian restaurants with good reviews that have availability. 
Would you like me to make a reservation? I also noticed your schedule is clear after 5pm."
```

### Components of True Anticipation

**1. Temporal Pattern Recognition**
Not just knowing events, but recognizing patterns in time:
- "User always takes a break around 3pm"
- "User tends to forget things when traveling"
- "User gets stressed before quarterly reviews"

**2. Causal/Consequential Modeling**
Understanding that events have causes and effects:
- "Anniversary coming up → user might want to plan something"
- "Child's soccer game Tuesday → can't schedule meetings then"

**3. Salience Detection**
Knowing what *matters* vs what's noise:
- Anniversary = high salience (emotional, relational)
- Regular weekly meeting = low salience (routine)
- Wife's birthday = high salience (personal relationship)

**4. Timing Judgment**
Knowing *when* to surface information:
- Too early: useless
- Too late: harmful
- Just right: helpful

**5. Action Readiness**
Not just surfacing information, but being ready to act:
- "I found these restaurants" (not just "anniversary coming")
- "I drafted a card message"
- "I blocked your calendar"

**6. Non-Intrusion Calibration**
Knowing when *not* to anticipate:
- User is in focused work session
- User explicitly said "I'll handle it"
- Topic is sensitive
- User is already stressed

### Anticipation Engine Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ANTICIPATION ENGINE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  Event       │  │  Pattern     │  │  Knowledge           │   │
│  │  Monitor     │  │  Detector    │  │  Graph               │   │
│  │              │  │              │  │                      │   │
│  │  • Calendar  │  │  • Temporal  │  │  • User preferences  │   │
│  │  • Email     │  │    routines  │  │  • Relationships     │   │
│  │  • Time      │  │  • Behavioral│  │  • Goals             │   │
│  │  • Location  │  │    patterns  │  │  • Constraints       │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                 │                      │               │
│         └─────────────────┼──────────────────────┘               │
│                           │                                      │
│                   ┌───────▼───────┐                              │
│                   │  Opportunity  │                              │
│                   │  Detector     │                              │
│                   │               │                              │
│                   │  "Something   │                              │
│                   │   might be    │                              │
│                   │   relevant"   │                              │
│                   └───────┬───────┘                              │
│                           │                                      │
│                   ┌───────▼───────┐                              │
│                   │  Salience     │                              │
│                   │  Filter       │                              │
│                   │               │                              │
│                   │  "Is this     │                              │
│                   │   worth       │                              │
│                   │   surfacing?" │                              │
│                   └───────┬───────┘                              │
│                           │                                      │
│                   ┌───────▼───────┐                              │
│                   │  Timing       │                              │
│                   │  Judgment     │                              │
│                   │               │                              │
│                   │  "Is now the  │                              │
│                   │   right time?"│                              │
│                   └───────┬───────┘                              │
│                           │                                      │
│                   ┌───────▼───────┐                              │
│                   │  Action       │                              │
│                   │  Preparation  │                              │
│                   │               │                              │
│                   │  "What can I  │                              │
│                   │   offer?"     │                              │
│                   └───────┬───────┘                              │
│                           │                                      │
│                   ┌───────▼───────┐                              │
│                   │  Intrusion    │                              │
│                   │  Gate         │                              │
│                   │               │                              │
│                   │  "Should I    │                              │
│                   │   actually    │                              │
│                   │   say this?"  │                              │
│                   └───────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
```

### Intrusion Calibration: The Hardest Problem

Most "proactive" assistants fail here. They either:
- Never reach out (useless for anticipation)
- Reach out too much (annoying, user disables)

**The system needs:**

1. **Sensible defaults** - Conservative initially, learns over time
2. **Preference learning** - Weight intrusion based on observed reactions
3. **Emergency carve-outs** - Time-sensitive situations override normal calibration
4. **Context-specific tuning** - Different tolerance for work vs home vs travel

**Learning signals:**
- Explicit: "This was helpful" / "Don't do this"
- Implicit: User ignores suggestion = reduce similar
- Contextual: User responds positively at certain times = weight those times higher

### Emergency Situations: A Special Case

Some situations warrant breaking normal intrusion calibration—impending negative consequences that the user may not be aware of.

**The challenge:** Knowing what constitutes an emergency vs. what the user already knows and accepts.

**Examples of time-sensitive situations:**
- Calendar conflict detected that the user hasn't noticed
- Upcoming deadline with incomplete prerequisites
- Travel booking about to expire
- Important email awaiting response past expected timeframe

**Critical safeguards for emergency escalation:**

1. **Explicit opt-in** - User must configure emergency contact features
2. **Clear communication** - No promises, no guarantees
3. **High confidence threshold** - Only act on clear patterns
4. **Sensitive messaging** - Notifications are informative, not alarming

### Summary: Anticipation vs Proactivity

| Aspect | Proactive | Anticipatory |
|--------|-----------|--------------|
| Trigger | Timer/poll | Event + pattern + salience |
| Content | "Here's what I checked" | "Here's what matters to you" |
| Timing | Scheduled | Contextually optimal |
| Action | Report | Offer/prepare/execute |
| Calibration | Fixed frequency | Learned per-user |
| Intelligence | Low (check X, report) | High (infer, correlate, judge) |

Anticipation is proactivity with *intelligence*—understanding not just *what* to check, but *why* it matters, *when* to surface it, and *how* to present it.

---

## Development Philosophy (Discussion Notes)

*This section captures evolving thoughts and discussions about the project direction.*

### The Core Vision

> **A better life, with a safe, secure, private, always-on and proactive personal assistant on your Mac.**

That's the north star. Not "a cool AI project" or "an open-source alternative to X." A genuine improvement in people's lives.

### Naming Reality Check

"EmberHearth" is a working title. The final product needs a **legally defensible name** that doesn't tie it to Apple's trademark. Apple won't appreciate a product that implies official association, even if it's macOS-specific. The name should:
- Stand on its own
- Not reference Mac, Apple, or related trademarks
- Be memorable and clear
- Convey helpfulness without overpromising

This is a real constraint that needs solving before any public release.

### The Apple Standard

Building for macOS isn't just about technical compatibility—it's about **meeting the standard Apple users expect**. These priorities are as important as security:

1. **Ease of use**: If it requires explanation, it's not done yet
2. **Well-thought workflow**: Every interaction should feel intentional
3. **Design that works with the OS**: Respect system appearance, accessibility settings, and user customization
4. **Native feel**: Use system frameworks, follow HIG, integrate with macOS features

Apple users chose the ecosystem for a reason. They expect polish, thoughtfulness, and coherence. A product that looks like a ported Linux app or a web wrapper will fail, regardless of its capabilities.

### Security as Foundation

Security isn't a feature—it's the **foundational deliverable**. Given:
- The well-documented security failures of existing AI assistant systems
- Apple's elevated emphasis on security and privacy
- The stakes involved (personal data, credentials, digital life)

This must be done right from the start. Not bolted on later. Not "good enough for now." The architecture must make security violations structurally difficult, not just policy-forbidden.

The gap between "technically secure" and "practically secure for normal users" can be bridged. There's a pathway here—it requires discipline, not magic.

### MVP Capability Concerns

One unresolved tension: **Does the MVP have enough functionality to justify "personal assistant"?**

The current Phase 2 scope includes:
- Basic structured operations (files, calendar, reminders)
- Single LLM provider
- Basic Tron filtering
- Local chat interface (no iMessage)

This might underwhelm users expecting a "personal assistant." The name creates expectations. Options:
1. **Expand MVP scope** (risk: never ship)
2. **Manage expectations** in messaging (risk: weak first impression)
3. **Find high-impact operations** that deliver outsized value even in limited MVP

This needs more thought. The "dream setup" promises a lot. The MVP needs to deliver enough to validate the promise.

### Who This Is For

The target user isn't a crypto miner or IT staff member. It's:
- A primary school teacher who wants help organizing her week
- Someone's parent who wants a reliable assistant for everyday tasks
- Anyone who wants the benefits of AI without understanding the risks

If these users can:
1. Buy a Mac device
2. Set up their iCloud account
3. Install the app
4. Start using it from iMessage

...and do so **safely**, without understanding prompt injection or container isolation—that's success.

---

## Open Questions

### Technical

1. **LLM Provider Authentication:** OAuth flows for Claude/OpenAI? Or API keys only?
2. **iMessage Integration:** What's the best approach? AppleScript? Private APIs? Messages.app automation?
3. **Tron ML Component:** Build or use existing (LLM Guard)? Training data?
4. **Cross-Device Sync:** How to sync preferences/memory across devices securely?

### Local Model Research (Critical Path)

5. **Capability Assessment:** Which open-weight models (Llama 3, Mistral, Phi, Gemma, etc.) offer sufficient capability for assistant tasks? What's the real-world gap vs. Claude/GPT-4?
6. **Hardware Requirements:** Can a mid-spec Mac Mini run useful local models with acceptable latency? What's the minimum viable configuration?
7. **Foreign Model Security:** How should models from non-US sources (Qwen, DeepSeek, GLM, Kimi) be evaluated? What sandboxing is sufficient to mitigate exfiltration risk regardless of model origin?
8. **Quantization Trade-offs:** How much capability is lost at 4-bit vs 8-bit quantization? Is the trade-off acceptable for assistant use cases?
9. **Hybrid Architecture:** What's the optimal split between local and cloud inference? Can a local model handle 80% of requests with cloud fallback for complex tasks?

### Future Opportunity: Bundled Local Fallback Model

**Context:** The autonomous operation spec defines an "offline mode" where EmberHearth queues messages and acknowledges receipt but cannot generate AI responses. This is better than silence, but still degrades the user experience during LLM API outages.

**Opportunity:** Bundle a small, quantized open-source model (e.g., Llama 3 8B, Qwen 2.5 7B, DeepSeek-V2-Lite) with the MLX inference engine directly in the app. When the cloud LLM is unavailable, fall back to local inference.

**Why this could work:**
- Apple Silicon is capable of running 7B-14B models at usable speeds
- MLX is Apple's own framework, optimized for Apple Silicon
- A "good enough" local response beats "I'll respond when I'm back online"
- Model size: ~4-8GB quantized, acceptable for a desktop app
- User expectation is already lowered during offline mode

**The quality gap is closing fast:**
As of early 2026, models like Qwen 2.5 and DeepSeek are hitting benchmarks near foundation model levels. The 7B-14B tier is no longer "significantly worse"—it's approaching "surprisingly capable." This changes the calculus:
- A Qwen 2.5 7B may handle 70-80% of assistant requests with acceptable quality
- For simple queries (calendar, reminders, basic Q&A), local may be indistinguishable
- Only complex reasoning/long-context tasks would noticeably degrade

**Tradeoffs to research:**
- **Quality gap:** Smaller than expected, but still present for complex tasks
- **Context limitations:** Local models have smaller context windows (4K-8K vs 128K+). May need aggressive summarization for long conversations.
- **Memory access:** Can the local model access the memory.db for personalization, or is retrieval too slow?
- **Model updates:** How to update the bundled model without a full app release? (Sparkle could handle model downloads separately)
- **Disk space:** Is 4-8GB acceptable for users? Should it be an optional download?

**Possible implementation path:**
1. MVP: Offline mode with message queue (current spec)
2. v1.1: Optional local model download in Settings
3. If downloaded, auto-fallback when cloud unavailable
4. Clear indication to user: "I'm using my backup brain—responses may be simpler"
5. v1.2+: Smart routing—use local for simple tasks even when online (cost savings)

**Increasingly viable.** The rapid improvement in small models makes this more attractive than originally expected. Worth re-evaluating when approaching v1.1 development.

### Token Efficiency Research

10. **Compression Quality:** Can a small local model (3B-7B) produce summaries good enough that cloud models reason effectively from them?
11. **Local Routing Accuracy:** What percentage of assistant requests can a local model handle entirely without degrading user experience?
12. **Latency Budget:** What's the acceptable local inference time for the compression layer? How does this vary by task type?
13. **Compaction Techniques:** Which summarization/compression approaches preserve task-critical information while maximizing token reduction?
14. **ACON/Focus Implementation:** Can published compression research (ACON, Active Context Compression) be adapted for the EmberHearth architecture?

### Personal Memory Architecture

15. **Knowledge Extraction:** How to automatically extract facts, preferences, and relationships from conversations without explicit user instruction?
16. **Privacy Classification:** Can an LLM reliably classify information into privacy levels (public, private, secret) based on context?
17. **Surfacing Rules:** How to implement "know but don't mention" behavior? Can this be achieved through prompting or requires architectural changes?
18. **Temporal Retrieval:** What's the optimal approach for reconstructing temporal context around retrieved facts? How much surrounding interaction data is needed?
19. **Encryption Performance:** What's the performance impact of per-record encryption in SQLite? Is it acceptable for real-time retrieval?
20. **Storage Scaling:** How much data accumulates over months/years of use? What's the retrieval performance at scale?

### Anticipation Engine

21. **Pattern Detection:** What statistical/ML approaches work best for detecting behavioral patterns from interaction logs?
22. **Salience Scoring:** How to quantify salience? What factors should weight higher (emotional, temporal urgency, relationship)?
23. **Intrusion Calibration:** How to learn user's tolerance for proactive contact? What signals indicate "too much" vs "helpful"?
24. **Emergency Detection:** What confidence threshold is appropriate for escalation actions?

### Affective State Vector (ASV) Research

25. **Axis Validation:** Do the proposed ASV axes (anger↔acceptance, fear↔trust, hope↔despair, interest↔boredom) align with psychological research? Are there missing primary axes?
26. **Inference Accuracy:** How reliably can emotional state be inferred from text? What signals beyond words (punctuation, response time, topic) improve accuracy?
27. **Encoding Precision:** What numeric precision is needed per axis? Is a byte (0-255) sufficient, or do certain axes need higher resolution?
28. **Similarity Metrics:** What distance function best captures "emotional similarity" for retrieval? Euclidean? Weighted? Should certain axes weight higher?
29. **Midpoint Learning:** How should the movable midpoint be learned? What signals indicate the user's baseline emotional state?
30. **Cross-Cultural Validity:** Does the emotional model hold across cultures, or are there cultural variations in emotional experience that require model adjustment?
31. **Neurochemical Grounding:** Can the model be validated against neuroimaging/neurochemical research? Would such validation strengthen or complicate the design?

### Consolidation Cycle (Sleep)

32. **Cycle Duration:** How long does full consolidation take for a typical day's interactions? What's the compute cost?
33. **Incremental vs. Batch:** Can consolidation run incrementally during idle moments, or does it require dedicated batch processing?
34. **Wake Interruption:** How should the system handle user interaction during consolidation? Pause and resume? Lightweight response mode?
35. **Sleep Scheduling:** Should sleep be user-configured, auto-detected from patterns, or both? What signals indicate "quiet hours"?
36. **Consolidation Quality:** How to measure whether consolidation is working? What metrics indicate healthy memory organization?

### Multi-User and Multi-Device Architecture

37. **Household Support:** Can one Mac Mini serve multiple users in a household with separate personalities and memories? What are the performance implications?
38. **Architecture for Expansion:** How should the codebase be structured to enable multi-user support without requiring a rebuild? This is a potential high-value feature justifying hardware cost for families.
39. **Privacy Boundaries:** How to maintain strict separation between users' personal memories on shared hardware?

*Note: Single-user only for initial release. Multi-device syncing is not planned—the model is one Mac Mini running EmberHearth, accessed via iMessage from any device.*

### Third-Party Integrations

40. **Apple API Coverage:** What capabilities are available through Apple's developer APIs? Explore https://developer.apple.com/documentation for Calendar, Reminders, Notes, Mail, HomeKit, and other frameworks.
41. **HomeKit Integration:** Can the Mac MCP server access HomeKit for smart home control? This could enable users to leverage existing smart home setups.
42. **Native vs Third-Party:** Should the MVP focus exclusively on native Apple apps, or is there value in early third-party integration (Notion, Todoist, etc.)?

### Success Metrics

43. **Metrics Definition:** Success metrics to be defined once architecture solidifies. Currently in brainstorming/exploratory phase.
44. **User Satisfaction:** How to measure whether users find the assistant genuinely helpful?
45. **Security Effectiveness:** How to measure whether the security model is working (attacks prevented, false positives)?
46. **Performance Targets:** What are acceptable response latencies, memory retrieval times, consolidation durations?

### Product

47. **Naming:** "EmberHearth" is not viable for release—Apple won't tolerate trademark association. Need a legally defensible name that stands alone while conveying helpfulness.
48. **Visual Identity:** What does the brand look like?
49. **Documentation:** How to explain security to non-technical users?
50. **Onboarding:** How to teach the assistant about the user without being creepy?

### Community

51. **Governance:** How to manage community signature contributions?
52. **Contributor Model:** How to attract quality contributors?
53. **Quality Bar:** How to maintain production quality with open source?

### Distribution

54. **Distribution:** Mac App Store? Direct download? Both? (App Store has discoverability but review constraints)
55. **Updates:** How to handle updates given the security-critical nature?

---

## Next Steps

### Phase 1: Validate Core Architecture (Research)

- [ ] Deep dive on macOS security capabilities (sandbox, entitlements, XPC)
- [ ] Evaluate Tron implementation options (build vs. integrate LLM Guard)
- [ ] Prototype iMessage integration approaches
- [ ] Test workbench isolation with Docker/gVisor on macOS
- [ ] Assess LLM provider integration complexity

### Phase 2: Minimum Viable Product (Build)

- [ ] macOS app shell with proper signing/sandboxing
- [ ] Core MCP server with basic structured operations
- [ ] Single LLM provider integration (Claude or GPT)
- [ ] Basic Tron filtering (signatures only)
- [ ] Local chat interface (no iMessage yet)

### Phase 3: Expand & Polish

- [ ] iMessage integration
- [ ] Multiple LLM providers
- [ ] Workbench implementation
- [ ] Tron ML component
- [ ] Memory/learning system
- [ ] Comprehensive documentation

### Phase 4: Community & Launch

- [ ] Open source release
- [ ] Community signature database
- [ ] Public documentation site
- [ ] Beta testing program
- [ ] Launch communications

---

## Closing Thoughts

The world doesn't need another chatbot. It needs AI assistance that:

1. **Actually helps** with real tasks in people's lives
2. **Doesn't require an engineering degree** to set up and use
3. **Won't be weaponized** against its users
4. **Respects privacy** and keeps personal data personal
5. **Gets better over time** without compromising safety

EmberHearth is a vision for what that could look like. It's ambitious, but the pieces exist:
- macOS provides world-class security primitives
- LLMs are capable enough for useful assistance
- Open source enables trust and community
- The demand is clearly there

The question isn't whether someone will build this. It's whether it will be built well, with security as a foundation rather than an afterthought.

Let's build it well.

---

## Lessons from Moltbot

*This section captures architectural insights from analyzing [Moltbot](../reference/MOLTBOT-ANALYSIS.md), a multi-channel AI assistant gateway. Understanding what Moltbot does well—and where it fails—informs EmberHearth's design.*

### What Moltbot Gets Right

**1. Single Gateway Process**

Moltbot's "always on" architecture uses a single long-running Node.js process that:
- Manages all channel connections (WhatsApp, Telegram, Discord, etc.)
- Owns session state and agent execution
- Exposes WebSocket + HTTP APIs for control
- Runs scheduled tasks via a cron subsystem

**Lesson for EmberHearth:** The single-gateway model is sound. A persistent process managing connections, sessions, and scheduled work is the right architecture for an always-on assistant. Don't over-engineer with microservices.

**2. Session Persistence**

Sessions are stored as JSONL files—one JSON object per line, representing each conversation turn:
```
~/.clawdbot/agents/<agentId>/sessions/<sessionKey>.jsonl
```

**Lesson for EmberHearth:** JSONL is simple, appendable, and human-readable for debugging. For EmberHearth's more sophisticated memory model, a database makes sense, but the principle of durable session state is essential.

**3. Cron/Heartbeat for Autonomous Work**

Moltbot's "overnight" processing isn't magic—it's scheduled tasks:
- Jobs stored in JSON (`~/.clawdbot/cron/jobs.json`)
- Timer wakes at scheduled times
- Jobs inject "system events" into the agent's context
- Heartbeat checks pending events and runs the agent

**Lesson for EmberHearth:** The consolidation cycle ("sleep") and anticipation engine need similar infrastructure—scheduled processing that runs without user prompts. The cron + heartbeat pattern solves this.

**4. Channel Abstraction**

All channels implement a common interface (`ChannelPlugin`) with optional adapters for:
- Outbound messaging
- Configuration
- Status/health
- Pairing
- Group behavior
- Mention handling

**Lesson for EmberHearth:** While iMessage is the primary interface, the abstraction is worth noting. If EmberHearth ever supports additional interfaces (Mac app, voice), a clean adapter pattern prevents spaghetti.

**5. Access Control Layers**

Moltbot has multiple access control mechanisms:
- **Allowlists**: Who can send messages
- **Pairing**: Device verification for DMs
- **Command Gating**: Who can run commands
- **Mention Gating**: Group message filtering

**Lesson for EmberHearth:** Access control needs defense in depth. EmberHearth should have similar layers, though simpler given single-user focus.

### What Moltbot Gets Wrong

**1. Shell Execution = Catastrophic**

Moltbot gives the LLM `exec` and `process` tools that run arbitrary shell commands:

```
Untrusted Input → LLM → Shell Execution → Complete System Access
```

A single prompt injection can exfiltrate credentials, install malware, or compromise the entire system. This is the fundamental security failure that EmberHearth must avoid.

**Lesson for EmberHearth:** No shell execution. Period. Structured operations only. The Workbench provides shell access, but only in a fully isolated container with explicit data transfer. The main system never executes arbitrary commands.

**2. Credentials Exposed to LLM**

Moltbot stores API keys in config files and environment variables. The agent can read these via file tools, meaning a compromised agent has access to all credentials.

**Lesson for EmberHearth:** Credentials stay in Keychain. The LLM can *use* them (via proxy) but never *see* them. Even a fully compromised LLM session can't exfiltrate keys it never receives.

**3. No Real Sandboxing**

The Moltbot agent runs with full user privileges. There's no process isolation, no capability restrictions, no containment.

**Lesson for EmberHearth:** Every component needs appropriate sandboxing:
- Main app: macOS App Sandbox
- Structured operations: Scoped entitlements
- Workbench: Full container isolation (gVisor/Docker)
- Even local models should run sandboxed

**4. Memory Doesn't "Learn"**

Moltbot's memory system indexes files and session transcripts, but it doesn't automatically extract facts or learn about the user. Users must manually curate `MEMORY.md` or rely on raw transcript indexing.

**Lesson for EmberHearth:** True personal memory requires automatic knowledge extraction, emotional encoding, and salience scoring. EmberHearth's consolidation cycle should process interactions and build a knowledge graph—not just index text.

**5. Complex Setup**

Moltbot requires:
- Node.js installation
- CLI familiarity
- API key management
- Config file editing
- Understanding of channels, sessions, agents

This excludes non-technical users entirely.

**Lesson for EmberHearth:** The grandmother test. If it can't be set up without technical knowledge, it fails. OAuth for LLM providers, macOS permission dialogs for capabilities, iMessage as the interface. No config files, no CLI, no API key pasting.

### Patterns to Adopt

| Moltbot Pattern | EmberHearth Adaptation |
|-----------------|------------------------|
| Single gateway process | Core architecture |
| Session persistence (JSONL) | Database-backed with encryption |
| Cron + heartbeat for scheduled work | Consolidation cycle + anticipation engine |
| Channel adapter pattern | Interface abstraction (iMessage, Mac app, voice) |
| Access control layers | Simplified for single-user, but defense-in-depth |
| Tool definitions | Structured operations (typed, validated, safe) |
| WebSocket control plane | Internal API for Mac app ↔ core communication |

### Patterns to Avoid

| Moltbot Pattern | EmberHearth Alternative |
|-----------------|-------------------------|
| Shell execution tools | **Removed entirely** (Workbench for power users only) |
| Credentials in files/env | **Keychain only**, proxy pattern for use |
| No sandboxing | **Full macOS App Sandbox** + container isolation |
| Manual memory curation | **Automatic knowledge extraction** |
| Technical setup requirements | **GUI-only**, OAuth, system permissions |
| Plugin/extension system | **No plugins** (reduces attack surface) |
| Browser automation tools | **Read-only, sanitized** web access |
| Multi-agent complexity | **Single agent** for simplicity |

### Complexity to Leave Behind

Moltbot has features that add complexity without clear value for EmberHearth's use case:

1. **Multi-channel support** — EmberHearth uses iMessage only (initially)
2. **Plugin architecture** — Increases attack surface, adds maintenance burden
3. **Multi-agent routing** — Unnecessary for single-user
4. **Browser automation** — Security risk; read-only web access is sufficient
5. **Remote access/tailscale** — Local-first; no network exposure
6. **Multiple LLM providers with fallback chains** — One provider at a time is simpler

### The Key Insight

Moltbot demonstrates that always-on AI assistance is *technically achievable*. The architecture patterns (gateway, sessions, scheduling, channel abstraction) are sound.

But Moltbot also demonstrates the security catastrophe that results from prioritizing capability over safety. Shell execution, credential exposure, and lack of sandboxing create a system that's powerful but dangerous.

**EmberHearth's opportunity:** Take the proven architecture patterns and rebuild with security as the foundation. Same capability, fundamentally different risk profile.

---

*For detailed technical analysis of Moltbot's architecture, see [MOLTBOT-ANALYSIS.md](../reference/MOLTBOT-ANALYSIS.md).*

---

*This document is a living artifact. It will evolve as we explore, prototype, and learn.*
