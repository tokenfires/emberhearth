# EmberHearth Feature Matrix

**Last Updated:** February 2026

This document provides a complete view of features across all planned releases.

---

## Release Overview

| Version | Codename | Focus | Target |
|---------|----------|-------|--------|
| **1.0** | Spark | Core functionality | MVP |
| **1.1** | Glow | Apple integrations | +2 months |
| **1.2** | Flame | Proactive features | +4 months |
| **2.0** | Hearth | Local models, plugins | +8 months |

---

## Complete Feature Matrix

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Included |
| ❌ | Not included |
| 🔶 | Partial/Basic |
| 🧪 | Experimental |

---

## Core Features

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **iMessage** |
| Read messages | ✅ | ✅ | ✅ | ✅ | Primary interface |
| Send responses | ✅ | ✅ | ✅ | ✅ | Via AppleScript |
| Personal number | ✅ | ✅ | ✅ | ✅ | |
| Work number | ❌ | ✅ | ✅ | ✅ | Context separation |
| Group detection | ✅ | ✅ | ✅ | ✅ | Block by default |
| Group social mode | ❌ | ❌ | ✅ | ✅ | Opt-in |
| Rich messages | ❌ | ❌ | ❌ | ✅ | Images, links |
| **LLM** |
| Claude API | ✅ | ✅ | ✅ | ✅ | Primary provider |
| OpenAI API | ❌ | ✅ | ✅ | ✅ | Alternative |
| Local (MLX) | ❌ | ❌ | ❌ | ✅ | Privacy option |
| Streaming | ✅ | ✅ | ✅ | ✅ | |
| Tool use | 🔶 | ✅ | ✅ | ✅ | MVP: web only |
| **Memory** |
| Fact storage | ✅ | ✅ | ✅ | ✅ | SQLite |
| Fact extraction | ✅ | ✅ | ✅ | ✅ | LLM-powered |
| Fact retrieval | ✅ | ✅ | ✅ | ✅ | Keyword-based |
| Semantic search | ❌ | ❌ | ✅ | ✅ | Embeddings |
| Conversation archive | ❌ | ✅ | ✅ | ✅ | Mini-RAG |
| Memory decay | ❌ | ✅ | ✅ | ✅ | Access-based |
| Emotional encoding | ❌ | ❌ | ✅ | ✅ | Intensity scores |
| **Session** |
| Continuity | ✅ | ✅ | ✅ | ✅ | |
| Rolling summary | ✅ | ✅ | ✅ | ✅ | |
| Context management | ✅ | ✅ | ✅ | ✅ | Token budgets |
| Adaptive summary | ❌ | ✅ | ✅ | ✅ | User patterns |

---

## Mac Application

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **Onboarding** |
| Permission flow | ✅ | ✅ | ✅ | ✅ | |
| API key setup | ✅ | ✅ | ✅ | ✅ | |
| Phone config | ✅ | ✅ | ✅ | ✅ | |
| Integration setup | ❌ | ✅ | ✅ | ✅ | Calendar, etc. |
| Personality quiz | ❌ | ❌ | ✅ | ✅ | Optional |
| **Settings** |
| API management | ✅ | ✅ | ✅ | ✅ | |
| Basic preferences | ✅ | ✅ | ✅ | ✅ | |
| Integration toggles | ❌ | ✅ | ✅ | ✅ | |
| Personality config | ❌ | ❌ | ✅ | ✅ | |
| Advanced options | ❌ | ❌ | ❌ | ✅ | |
| **Data Browser** |
| View facts | ❌ | ✅ | ✅ | ✅ | |
| Edit facts | ❌ | ✅ | ✅ | ✅ | |
| Delete facts | ❌ | ✅ | ✅ | ✅ | Soft delete |
| Conversation view | ❌ | ❌ | ✅ | ✅ | |
| Export data | ❌ | ❌ | ✅ | ✅ | JSON/CSV |
| **System** |
| Menu bar | ✅ | ✅ | ✅ | ✅ | |
| Launch at login | ✅ | ✅ | ✅ | ✅ | |
| Status indicator | ✅ | ✅ | ✅ | ✅ | |
| Auto-updates | ❌ | ✅ | ✅ | ✅ | Sparkle |
| Crash reporting | ❌ | ✅ | ✅ | ✅ | Opt-in |

---

## Apple Integrations

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **Calendar** |
| Read events | ❌ | ✅ | ✅ | ✅ | EventKit |
| Create events | ❌ | ✅ | ✅ | ✅ | |
| Modify events | ❌ | ❌ | ✅ | ✅ | |
| Conflict detection | ❌ | ❌ | ✅ | ✅ | Proactive |
| **Reminders** |
| Read reminders | ❌ | ✅ | ✅ | ✅ | EventKit |
| Create reminders | ❌ | ✅ | ✅ | ✅ | |
| Complete reminders | ❌ | ✅ | ✅ | ✅ | |
| Due date awareness | ❌ | ❌ | ✅ | ✅ | Proactive |
| **Contacts** |
| Look up | ❌ | ✅ | ✅ | ✅ | CNContactStore |
| Name resolution | ❌ | ✅ | ✅ | ✅ | In messages |
| Relationship context | ❌ | ❌ | ✅ | ✅ | |
| **Safari** |
| Read bookmarks | ❌ | ✅ | ✅ | ✅ | Plist |
| Read Reading List | ❌ | ✅ | ✅ | ✅ | |
| Read history | ❌ | ❌ | ✅ | ✅ | SQLite |
| Current tabs | ❌ | ❌ | ✅ | ✅ | AppleScript |
| Browser control | ❌ | ❌ | ❌ | 🧪 | Experimental |
| **Notes** |
| Read notes | ❌ | ❌ | ✅ | ✅ | AppleScript |
| Create notes | ❌ | ❌ | ✅ | ✅ | |
| Search notes | ❌ | ❌ | ❌ | ✅ | |
| **Mail** |
| Read unread | ❌ | ❌ | ✅ | ✅ | AppleScript |
| Search mail | ❌ | ❌ | ❌ | ✅ | |
| Draft emails | ❌ | ❌ | ❌ | ✅ | |
| **Weather** |
| Current weather | ❌ | ✅ | ✅ | ✅ | WeatherKit |
| Forecast | ❌ | ✅ | ✅ | ✅ | |
| **Maps** |
| Location search | ❌ | ❌ | ✅ | ✅ | MapKit |
| Directions | ❌ | ❌ | ✅ | ✅ | |
| **HomeKit** |
| Device status | ❌ | ❌ | ❌ | ✅ | |
| Control devices | ❌ | ❌ | ❌ | ✅ | |
| **Shortcuts** |
| Run shortcuts | ❌ | ❌ | ❌ | ✅ | App Intents |
| Ember as Siri | ❌ | ❌ | ❌ | ✅ | |

---

## Active Data Intake

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **Monitoring** |
| iMessage | ✅ | ✅ | ✅ | ✅ | FSEvents |
| Calendar | ❌ | ✅ | ✅ | ✅ | EventKit notif |
| Reminders | ❌ | ✅ | ✅ | ✅ | EventKit notif |
| Safari bookmarks | ❌ | ✅ | ✅ | ✅ | FSEvents |
| Safari history | ❌ | ❌ | ✅ | ✅ | FSEvents |
| Notes | ❌ | ❌ | ✅ | ✅ | FSEvents |
| Mail | ❌ | ❌ | ✅ | ✅ | Polling |
| **Proactive** |
| Event queue | ❌ | ✅ | ✅ | ✅ | |
| Priority handling | ❌ | ❌ | ✅ | ✅ | |
| Proactive messages | ❌ | ❌ | ✅ | ✅ | |
| Pattern detection | ❌ | ❌ | ❌ | ✅ | Anticipation |
| Intrusion calibration | ❌ | ❌ | ❌ | ✅ | Learn threshold |

---

## Security & Privacy

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **Data Protection** |
| Keychain secrets | ✅ | ✅ | ✅ | ✅ | |
| Local-only storage | ✅ | ✅ | ✅ | ✅ | |
| Encrypted DB | ❌ | ✅ | ✅ | ✅ | Data Protection |
| **Tron Security** |
| Basic injection defense | ✅ | ✅ | ✅ | ✅ | Signatures |
| Credential filtering | ✅ | ✅ | ✅ | ✅ | |
| Group chat blocking | ✅ | ✅ | ✅ | ✅ | |
| Full Tron layer | ❌ | ❌ | ✅ | ✅ | XPC service |
| ML detection | ❌ | ❌ | ❌ | ✅ | |
| Signature updates | ❌ | ❌ | ❌ | ✅ | Community |
| **Context Isolation** |
| Work/Personal | ❌ | ❌ | ✅ | ✅ | |
| Audit logging | ❌ | ❌ | ✅ | ✅ | Work context |
| Policy enforcement | ❌ | ❌ | ✅ | ✅ | |

---

## Personality

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| Core Ember identity | ✅ | ✅ | ✅ | ✅ | |
| Bounded needs | ✅ | ✅ | ✅ | ✅ | |
| Verbosity adaptation | ✅ | ✅ | ✅ | ✅ | |
| Love language learning | ❌ | ✅ | ✅ | ✅ | |
| Attachment-informed | ❌ | ❌ | ✅ | ✅ | Internal only |
| Customization | ❌ | ❌ | ✅ | ✅ | |
| Archetype selection | ❌ | ❌ | ✅ | ✅ | Mentor, Coach, etc. |

---

## Web Tool

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| URL fetching | ✅ | ✅ | ✅ | ✅ | Sandboxed |
| Content extraction | ✅ | ✅ | ✅ | ✅ | Article text |
| Web search | ❌ | ✅ | ✅ | ✅ | API-based |
| JS rendering | ❌ | ❌ | ✅ | ✅ | WKWebView |
| Rate limiting | ❌ | ✅ | ✅ | ✅ | |

---

## Distribution & Updates

| Feature | 1.0 | 1.1 | 1.2 | 2.0 | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| Code signing | ✅ | ✅ | ✅ | ✅ | Developer ID |
| Notarization | ✅ | ✅ | ✅ | ✅ | Required |
| Direct download | ✅ | ✅ | ✅ | ✅ | Primary |
| Auto-updates | ❌ | ✅ | ✅ | ✅ | Sparkle |
| Delta updates | ❌ | ❌ | ✅ | ✅ | |
| App Store | ❌ | ❌ | ❌ | 🔶 | Maybe limited |

---

## Future (v2.0+)

| Feature | Target | Notes |
|---------|--------|-------|
| Plugin system | 2.0 | Extensibility |
| iOS companion | 2.x | Health, location |
| Web UI | 2.x | Alternative interface |
| Voice interface | 3.0 | Natural conversation |
| Multi-user | 3.0 | Family/household |
| Enterprise | 3.x | Team deployment |

---

## Version Dependencies

```
1.0 (MVP)
 │
 ├── No external dependencies
 │
 ▼
1.1 (Integrations)
 │
 ├── Requires: 1.0 memory system
 ├── Requires: EventKit permission framework
 │
 ▼
1.2 (Proactive)
 │
 ├── Requires: 1.1 integrations
 ├── Requires: Anticipation engine
 ├── Requires: Full Tron layer
 │
 ▼
2.0 (Local Models)
 │
 ├── Requires: MLX integration
 ├── Requires: Model management
 └── Requires: Plugin architecture
```
