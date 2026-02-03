# MVP Scope Definition

**Version:** 1.0 (MVP)
**Target:** First usable release
**Codename:** *Spark*

## Vision Statement

> A working personal assistant that users can text via iMessage, which remembers their conversations and helps with basic tasks—running on their own Mac.

MVP is the smallest useful version of EmberHearth. It proves the core value proposition without all the bells and whistles.

---

## MVP Success Criteria

A user should be able to:

1. ✅ Install EmberHearth on their Mac
2. ✅ Complete onboarding (permissions, API key)
3. ✅ Text Ember via iMessage from any device
4. ✅ Have a conversation that feels natural
5. ✅ Ask Ember to remember things ("Remember that I prefer morning meetings")
6. ✅ Have Ember recall relevant facts in future conversations
7. ✅ Feel confident their data is private and secure

---

## Feature Matrix

### Core Functionality

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| **iMessage Integration** |
| Read incoming messages | ✅ | ✅ | ✅ | ✅ |
| Send responses | ✅ | ✅ | ✅ | ✅ |
| Personal phone number routing | ✅ | ✅ | ✅ | ✅ |
| Work phone number routing | ❌ | ✅ | ✅ | ✅ |
| Group chat detection | ✅ | ✅ | ✅ | ✅ |
| Group chat social mode | ❌ | ❌ | ✅ | ✅ |
| **LLM Integration** |
| Claude API support | ✅ | ✅ | ✅ | ✅ |
| User provides API key | ✅ | ✅ | ✅ | ✅ |
| OpenAI API support | ❌ | ✅ | ✅ | ✅ |
| Local models (MLX) | ❌ | ❌ | ❌ | ✅ |
| **Memory System** |
| Fact storage (SQLite) | ✅ | ✅ | ✅ | ✅ |
| Fact extraction from conversation | ✅ | ✅ | ✅ | ✅ |
| Fact retrieval for context | ✅ | ✅ | ✅ | ✅ |
| Conversation archive | ❌ | ✅ | ✅ | ✅ |
| Semantic search (embeddings) | ❌ | ❌ | ✅ | ✅ |
| Memory decay | ❌ | ✅ | ✅ | ✅ |
| **Session Management** |
| Conversation continuity | ✅ | ✅ | ✅ | ✅ |
| Rolling summary | ✅ | ✅ | ✅ | ✅ |
| Context window management | ✅ | ✅ | ✅ | ✅ |

### Mac App

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| **Onboarding** |
| Permission request flow | ✅ | ✅ | ✅ | ✅ |
| API key setup | ✅ | ✅ | ✅ | ✅ |
| Phone number configuration | ✅ | ✅ | ✅ | ✅ |
| **Settings** |
| API key management | ✅ | ✅ | ✅ | ✅ |
| Basic preferences | ✅ | ✅ | ✅ | ✅ |
| Integration toggles | ❌ | ✅ | ✅ | ✅ |
| Advanced personality config | ❌ | ❌ | ✅ | ✅ |
| **Data Management** |
| View stored facts | ❌ | ✅ | ✅ | ✅ |
| Edit/delete facts | ❌ | ✅ | ✅ | ✅ |
| Conversation browser | ❌ | ❌ | ✅ | ✅ |
| Export data | ❌ | ❌ | ✅ | ✅ |
| **System** |
| Menu bar presence | ✅ | ✅ | ✅ | ✅ |
| Launch at login | ✅ | ✅ | ✅ | ✅ |
| Status indicator | ✅ | ✅ | ✅ | ✅ |
| Auto-updates (Sparkle) | ❌ | ✅ | ✅ | ✅ |

### Apple Integrations

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| **Calendar (EventKit)** |
| Read calendar events | ❌ | ✅ | ✅ | ✅ |
| Create calendar events | ❌ | ✅ | ✅ | ✅ |
| Calendar conflict detection | ❌ | ❌ | ✅ | ✅ |
| **Reminders (EventKit)** |
| Read reminders | ❌ | ✅ | ✅ | ✅ |
| Create reminders | ❌ | ✅ | ✅ | ✅ |
| Complete reminders | ❌ | ✅ | ✅ | ✅ |
| **Contacts** |
| Look up contacts | ❌ | ✅ | ✅ | ✅ |
| Name resolution in messages | ❌ | ✅ | ✅ | ✅ |
| **Safari** |
| Read bookmarks | ❌ | ✅ | ✅ | ✅ |
| Read history | ❌ | ❌ | ✅ | ✅ |
| Current tab awareness | ❌ | ❌ | ✅ | ✅ |
| Browser control (experimental) | ❌ | ❌ | ❌ | ✅ |
| **Notes** |
| Read notes | ❌ | ❌ | ✅ | ✅ |
| Create notes | ❌ | ❌ | ✅ | ✅ |
| **Mail** |
| Read unread emails | ❌ | ❌ | ✅ | ✅ |
| Draft emails | ❌ | ❌ | ❌ | ✅ |
| **Other** |
| Weather (WeatherKit) | ❌ | ✅ | ✅ | ✅ |
| Maps/Directions | ❌ | ❌ | ✅ | ✅ |
| HomeKit | ❌ | ❌ | ❌ | ✅ |
| Shortcuts integration | ❌ | ❌ | ❌ | ✅ |

### Active Data Intake

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| iMessage monitoring | ✅ | ✅ | ✅ | ✅ |
| Calendar change detection | ❌ | ✅ | ✅ | ✅ |
| Reminder change detection | ❌ | ✅ | ✅ | ✅ |
| Safari bookmark monitoring | ❌ | ✅ | ✅ | ✅ |
| Proactive notifications | ❌ | ❌ | ✅ | ✅ |
| Pattern-based anticipation | ❌ | ❌ | ❌ | ✅ |

### Security & Privacy

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| Keychain for API keys | ✅ | ✅ | ✅ | ✅ |
| Local-only data storage | ✅ | ✅ | ✅ | ✅ |
| Basic prompt injection defense | ✅ | ✅ | ✅ | ✅ |
| Credential detection in output | ✅ | ✅ | ✅ | ✅ |
| Group chat restrictions | ✅ | ✅ | ✅ | ✅ |
| Full Tron security layer | ❌ | ❌ | ✅ | ✅ |
| Audit logging | ❌ | ❌ | ✅ | ✅ |
| Work context isolation | ❌ | ❌ | ✅ | ✅ |

### Personality

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| Core Ember personality | ✅ | ✅ | ✅ | ✅ |
| Bounded needs model | ✅ | ✅ | ✅ | ✅ |
| Verbosity adaptation | ✅ | ✅ | ✅ | ✅ |
| User love language learning | ❌ | ✅ | ✅ | ✅ |
| Attachment-informed responses | ❌ | ❌ | ✅ | ✅ |
| Personality customization | ❌ | ❌ | ✅ | ✅ |

### Web Tool

| Feature | MVP | v1.1 | v1.2 | v2.0 |
|---------|:---:|:----:|:----:|:----:|
| URL fetching | ✅ | ✅ | ✅ | ✅ |
| Article content extraction | ✅ | ✅ | ✅ | ✅ |
| Web search (via API) | ❌ | ✅ | ✅ | ✅ |
| JavaScript rendering | ❌ | ❌ | ✅ | ✅ |

---

## MVP Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      MVP COMPONENTS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │ EmberHearth.app │     │ Messages.app    │                   │
│  │                 │     │ (via AppleScript)│                   │
│  │ • Onboarding    │     └────────┬────────┘                   │
│  │ • Settings      │              │                            │
│  │ • Menu bar      │              │ send                       │
│  │                 │              ▼                            │
│  │ ┌─────────────┐ │     ┌─────────────────┐                   │
│  │ │   Tron      │ │ ◀───│    chat.db      │                   │
│  │ │  (basic)    │ │     │ (FSEvents)      │                   │
│  │ └──────┬──────┘ │     └─────────────────┘                   │
│  │        │        │                                           │
│  │        ▼        │                                           │
│  │ ┌─────────────┐ │                                           │
│  │ │   Ember     │ │     ┌─────────────────┐                   │
│  │ │ (Prompt)    │ │◀───▶│   memory.db     │                   │
│  │ └──────┬──────┘ │     │ (SQLite)        │                   │
│  │        │        │     └─────────────────┘                   │
│  │        ▼        │                                           │
│  │ ┌─────────────┐ │     ┌─────────────────┐                   │
│  │ │ LLM Client  │─┼────▶│  Claude API     │                   │
│  │ │             │ │     │  (Anthropic)    │                   │
│  │ └─────────────┘ │     └─────────────────┘                   │
│  │                 │                                           │
│  │ ┌─────────────┐ │                                           │
│  │ │ Web Fetcher │─┼────▶ (sandboxed HTTP)                     │
│  │ └─────────────┘ │                                           │
│  │                 │                                           │
│  └─────────────────┘                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**MVP Simplifications:**
- Single process (no XPC services yet)
- Tron logic hardcoded in app
- No Apple integrations beyond iMessage
- No proactive features
- No work/personal separation

---

## Out of Scope for MVP

Explicitly deferred to later versions:

1. **Work/Personal Contexts** — Single context only
2. **Apple Integrations** — Calendar, Reminders, Contacts, Safari, Notes, Mail
3. **Proactive Notifications** — Ember only responds when messaged
4. **Conversation Archive** — Only current session + facts
5. **Semantic Search** — Keyword-based only
6. **Auto-Updates** — Manual download for MVP
7. **Data Browser UI** — No fact management interface
8. **Multiple LLM Providers** — Claude only
9. **Local Models** — Cloud only

---

## Technical Requirements

### Minimum System Requirements
- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- 4GB RAM minimum
- Internet connection (for Claude API)
- iMessage configured

### Permissions Required
- **Full Disk Access** — Read chat.db
- **Automation** — Control Messages.app
- **Notifications** — Alert user of status

### User Provides
- Anthropic API key
- Phone number(s) to respond to

---

## MVP Milestones

### M1: Foundation
- [ ] Xcode project setup with signing
- [ ] Basic SwiftUI app structure
- [ ] Menu bar presence
- [ ] Launch at login

### M2: iMessage Integration
- [ ] Read messages from chat.db
- [ ] FSEvents monitoring
- [ ] Send via AppleScript
- [ ] Phone number filtering

### M3: LLM Integration
- [ ] Claude API client
- [ ] Streaming responses
- [ ] Basic context building
- [ ] Error handling

### M4: Memory System
- [ ] SQLite setup
- [ ] Fact extraction prompt
- [ ] Fact storage
- [ ] Fact retrieval for context

### M5: Personality
- [ ] System prompt implementation
- [ ] Verbosity adaptation
- [ ] Conversation continuity
- [ ] Rolling summary

### M6: Security Basics
- [ ] Keychain for API key
- [ ] Basic injection defense
- [ ] Group chat blocking
- [ ] Credential filtering

### M7: Onboarding
- [ ] Permission request flow
- [ ] API key entry
- [ ] Phone number config
- [ ] First message test

### M8: Polish
- [ ] Error states and recovery
- [ ] Status indicators
- [ ] Basic settings UI
- [ ] Notarization

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| chat.db format changes | Low | High | Version detection, graceful failure |
| AppleScript reliability | Medium | Medium | Error recovery, retry logic |
| Claude API changes | Low | High | Abstract provider interface |
| Notarization issues | Medium | High | Early testing, Apple docs |
| Memory bloat | Medium | Medium | Aggressive summarization |

---

## Definition of Done

MVP is complete when:

1. [ ] All M1-M8 milestones complete
2. [ ] App passes notarization
3. [ ] 3 beta testers use it for 1 week
4. [ ] No P0/P1 bugs remaining
5. [ ] Basic documentation exists
6. [ ] Install/onboarding flow tested on fresh Mac
