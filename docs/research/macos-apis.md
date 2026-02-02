# macOS API & Integration Research Index

**Status:** Complete
**Priority:** High (Phase 1)
**Last Updated:** February 2, 2026

---

## Overview

This document serves as an index to EmberHearth's integration research. Each app/framework has a dedicated research document with technical details, implementation examples, and feasibility assessments.

---

## Quick Reference: Feasibility Matrix

| Integration | Feasibility | API Type | Priority | Doc Link |
|-------------|-------------|----------|----------|----------|
| **Calendar/Reminders** | HIGH | EventKit | High | [calendar.md](integrations/calendar.md) |
| **Contacts** | HIGH | CNContactStore | High | [contacts.md](integrations/contacts.md) |
| **Mail** | HIGH | AppleScript | High | [mail.md](integrations/mail.md) |
| **Notes** | MEDIUM-HIGH | AppleScript | High | [notes.md](integrations/notes.md) |
| **Weather** | HIGH | WeatherKit | Medium | [weather.md](integrations/weather.md) |
| **Maps** | HIGH | MapKit | Medium | [maps.md](integrations/maps.md) |
| **Shortcuts** | HIGH | App Intents | High | [shortcuts.md](integrations/shortcuts.md) |
| **HomeKit** | HIGH | HomeKit | Medium | [homekit.md](integrations/homekit.md) |
| **Files/iCloud** | MEDIUM | FileManager | Medium | [files.md](integrations/files.md) |
| **Music** | MEDIUM | MusicKit | Low | [media.md](integrations/media.md) |
| **Health/Fitness** | LOW-MEDIUM | HealthKit (iOS only) | Low | [health-fitness.md](integrations/health-fitness.md) |
| **News** | LOW | None (use 3rd party) | Low | [news-stocks.md](integrations/news-stocks.md) |
| **Stocks** | MEDIUM | 3rd party APIs | Low | [news-stocks.md](integrations/news-stocks.md) |
| **TV App** | LOW | Broken AppleScript | Low | [media.md](integrations/media.md) |
| **Podcasts** | LOW | None | Low | [media.md](integrations/media.md) |
| **Books** | LOW | Limited | Low | [media.md](integrations/media.md) |
| **Voice Memos** | MEDIUM | Speech APIs | Low | [media.md](integrations/media.md) |
| **Clock/Timers** | MEDIUM | Notifications | Low | [utilities.md](integrations/utilities.md) |
| **iWork (Pages/Numbers/Keynote)** | MEDIUM | AppleScript | Low | [iwork.md](integrations/iwork.md) |
| **Find My** | VERY LOW | No API | Low | [find-my.md](integrations/find-my.md) |
| **Plugin Architecture** | HIGH (v2+) | XPC | Future | [plugin-architecture.md](integrations/plugin-architecture.md) |

---

## By Priority Tier

### Tier 1: Core (v1)

Essential integrations for launch:

| Integration | Why Essential |
|-------------|---------------|
| [**iMessage**](imessage.md) | Primary interface |
| [**Calendar/Reminders**](integrations/calendar.md) | Core assistant functionality |
| [**Contacts**](integrations/contacts.md) | Name resolution for messaging |
| [**Notes**](integrations/notes.md) | Quick capture use case |
| [**Mail**](integrations/mail.md) | Common daily workflow |

### Tier 2: Enhanced (v1.x)

Valuable additions post-launch:

| Integration | Value Add |
|-------------|-----------|
| [**Weather**](integrations/weather.md) | Common query type |
| [**Maps**](integrations/maps.md) | Directions, travel planning |
| [**Shortcuts**](integrations/shortcuts.md) | Extensibility, Siri integration |
| [**HomeKit**](integrations/homekit.md) | Smart home segment |
| [**Files**](integrations/files.md) | Organization assistant |

### Tier 3: Extended (v2+)

Nice-to-have and complex integrations:

| Integration | Notes |
|-------------|-------|
| [**Music**](integrations/media.md) | macOS API limitations |
| [**Health**](integrations/health-fitness.md) | Requires iOS companion app |
| [**Stocks**](integrations/news-stocks.md) | 3rd party API required |
| [**iWork**](integrations/iwork.md) | Niche use case |
| [**Plugin System**](integrations/plugin-architecture.md) | Major infrastructure |

### Not Recommended

| Integration | Reason |
|-------------|--------|
| [**Find My**](integrations/find-my.md) | No API, privacy concerns |
| [**TV App**](integrations/media.md) | AppleScript broken |
| [**Podcasts**](integrations/media.md) | No automation support |

---

## By Technical Approach

### Official Apple Frameworks

Native Swift APIs with proper documentation:

| Framework | Apps | Docs |
|-----------|------|------|
| EventKit | Calendar, Reminders | [calendar.md](integrations/calendar.md) |
| Contacts | Contacts | [contacts.md](integrations/contacts.md) |
| WeatherKit | Weather | [weather.md](integrations/weather.md) |
| MapKit | Maps | [maps.md](integrations/maps.md) |
| HomeKit | Home | [homekit.md](integrations/homekit.md) |
| MusicKit | Music | [media.md](integrations/media.md) |
| App Intents | Shortcuts | [shortcuts.md](integrations/shortcuts.md) |
| FileManager | Files | [files.md](integrations/files.md) |
| Speech | Voice Memos | [media.md](integrations/media.md) |

### AppleScript Automation

Apps controlled via AppleScript:

| App | Support Level | Docs |
|-----|---------------|------|
| Mail | Excellent | [mail.md](integrations/mail.md) |
| Notes | Good | [notes.md](integrations/notes.md) |
| Messages | Good | [imessage.md](imessage.md) |
| Pages/Numbers/Keynote | Good | [iwork.md](integrations/iwork.md) |
| Music | Fair | [media.md](integrations/media.md) |
| TV | Broken | [media.md](integrations/media.md) |
| Podcasts | None | [media.md](integrations/media.md) |

### Third-Party APIs Required

No Apple API available:

| Integration | Recommended APIs | Docs |
|-------------|------------------|------|
| News | NewsAPI.org, GNews | [news-stocks.md](integrations/news-stocks.md) |
| Stocks | Alpha Vantage, Finnhub | [news-stocks.md](integrations/news-stocks.md) |

### No Viable Approach

| Integration | Reason | Docs |
|-------------|--------|------|
| Find My | No API, privacy | [find-my.md](integrations/find-my.md) |
| Health (on Mac) | iOS only | [health-fitness.md](integrations/health-fitness.md) |

---

## Permission Requirements Summary

| Permission | Apps/Features |
|------------|---------------|
| **Full Disk Access** | iMessage (chat.db) |
| **Automation** | Mail, Notes, Messages, iWork |
| **Calendar** | Calendar, Reminders |
| **Contacts** | Contacts |
| **Location** | Weather (optional), Maps |
| **HomeKit** | Smart home devices |
| **Notifications** | Alarms, timers, alerts |
| **Network** | Weather, Maps, LLM APIs, 3rd party |

---

## Architecture Recommendations

### Recommended: XPC Service Model

```
EmberHearth Main App
    ├── MessageService.xpc (iMessage handling)
    ├── CalendarService.xpc (EventKit)
    ├── MailService.xpc (AppleScript)
    ├── NotesService.xpc (AppleScript)
    └── IntegrationService.xpc (Weather, Maps, etc.)
```

### Why XPC?

1. **Process isolation** - Service crashes don't kill the app
2. **Sandboxing** - Each service has minimal permissions
3. **Security** - Code signing verification
4. **Scalability** - Add new services without changing core

---

## Implementation Roadmap

### Phase 1: Core (Month 1-2)
- [ ] iMessage integration (AppleScript + SQLite)
- [ ] Calendar/Reminders (EventKit)
- [ ] Contacts (CNContactStore)
- [ ] Basic Notes (AppleScript)

### Phase 2: Enhanced (Month 3-4)
- [ ] Mail (AppleScript)
- [ ] Weather (WeatherKit)
- [ ] Maps (MapKit)
- [ ] Shortcuts/App Intents

### Phase 3: Extended (Month 5-6)
- [ ] HomeKit
- [ ] Files/iCloud
- [ ] Music (limited)
- [ ] Stocks (3rd party)

### Phase 4: Platform (Month 7+)
- [ ] Plugin architecture
- [ ] Third-party integrations
- [ ] iOS companion app (for Health)

---

## Research Documents

### Core Research
- [iMessage Integration](imessage.md) - Primary interface
- [Security Primitives](security.md) - Sandbox, XPC, Keychain, etc.

### Integration Research
All documents in `docs/research/integrations/`:

| Document | Covers |
|----------|--------|
| [calendar.md](integrations/calendar.md) | Calendar, Reminders, EventKit |
| [contacts.md](integrations/contacts.md) | Contacts, CNContactStore |
| [mail.md](integrations/mail.md) | Mail.app, AppleScript |
| [notes.md](integrations/notes.md) | Notes.app, AppleScript |
| [weather.md](integrations/weather.md) | WeatherKit |
| [maps.md](integrations/maps.md) | MapKit, directions |
| [shortcuts.md](integrations/shortcuts.md) | App Intents, Siri |
| [homekit.md](integrations/homekit.md) | Smart home |
| [files.md](integrations/files.md) | FileManager, iCloud |
| [media.md](integrations/media.md) | Music, TV, Podcasts, Books, Voice Memos |
| [health-fitness.md](integrations/health-fitness.md) | HealthKit (iOS) |
| [news-stocks.md](integrations/news-stocks.md) | 3rd party APIs |
| [utilities.md](integrations/utilities.md) | Clock, system info |
| [iwork.md](integrations/iwork.md) | Pages, Numbers, Keynote |
| [find-my.md](integrations/find-my.md) | Location tracking (not viable) |
| [plugin-architecture.md](integrations/plugin-architecture.md) | Extensibility design |

---

## Key Takeaways

1. **Apple provides excellent APIs** for Calendar, Contacts, Weather, Maps, HomeKit
2. **AppleScript fills gaps** for Mail, Notes, iWork
3. **Some apps have no automation** (Podcasts, Find My)
4. **Health requires iOS** - Consider companion app for v2
5. **Plugin architecture is viable** - Plan for it, implement later
6. **Security first** - XPC isolation, sandboxing, permission model

---

## Resources

### Apple Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Sandbox Guide](https://developer.apple.com/documentation/security/app-sandbox)

### Community Resources
- [macosxautomation.com](http://www.intergalactic.de/) - AppleScript guides
- [iWorkAutomation.com](https://iworkautomation.com/) - iWork scripting
- [Doug's AppleScripts](https://dougscripts.com/) - Script examples

### Open Source References
- [steipete/imsg](https://github.com/steipete/imsg) - iMessage CLI
- [BlueBubbles](https://github.com/BlueBubblesApp/bluebubbles-server) - iMessage server
- [SecureXPC](https://github.com/trilemma-dev/SecureXPC) - XPC framework
