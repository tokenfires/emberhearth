# Research Documentation

This directory contains research findings, explorations, and analysis conducted during EmberHearth's development.

---

## Core Research

| Document | Description |
|----------|-------------|
| [iMessage Integration](imessage.md) | How to integrate with iMessage via chat.db and AppleScript |
| [macOS APIs](macos-apis.md) | Available Apple frameworks and system capabilities |
| [Security](security.md) | Sandbox, XPC, Keychain, and security architecture |
| [Local Models](local-models.md) | Feasibility of on-device LLM inference |

---

## User Experience Research

| Document | Description |
|----------|-------------|
| [Conversation Design](conversation-design.md) | Principles for natural, helpful dialogue |
| [Onboarding UX](onboarding-ux.md) | First-run experience and setup flow |
| [Session Management](session-management.md) | Context windows, conversation boundaries |
| [Personality Design](personality-design.md) | Voice, tone, and character guidelines |

---

## Memory & Learning

| Document | Description |
|----------|-------------|
| [Memory & Learning](memory-learning.md) | Long-term memory architecture and user modeling |
| [Active Data Intake](active-data-intake.md) | Background data collection and processing |
| [Work/Personal Contexts](work-personal-contexts.md) | Context separation and switching |
| [ASV Neurochemical Validation](asv-neurochemical-validation.md) | Scientific grounding for anticipatory value system |

---

## Quality & Iteration

| Document | Description |
|----------|-------------|
| [Iterative Quality Loops](iterative-quality-loops.md) | **Ralph Loop technique adapted for Ember — spec→action→review→iterate** |

---

## System Integration Research

| Document | Description |
|----------|-------------|
| [Safari Integration](safari-integration.md) | Web browsing capabilities and constraints |
| [Legal & Ethical Considerations](legal-ethical-considerations.md) | Privacy law, consent, and compliance |

---

## Apple App Integrations

Located in `integrations/` subdirectory:

| Document | Description |
|----------|-------------|
| [Calendar](integrations/calendar.md) | EventKit integration for calendar access |
| [Contacts](integrations/contacts.md) | Contacts framework integration |
| [Files](integrations/files.md) | File system access patterns |
| [Find My](integrations/find-my.md) | Location services integration |
| [Health & Fitness](integrations/health-fitness.md) | HealthKit data access |
| [HomeKit](integrations/homekit.md) | Smart home control |
| [iWork](integrations/iwork.md) | Pages, Numbers, Keynote automation |
| [Mail](integrations/mail.md) | Email integration approaches |
| [Maps](integrations/maps.md) | MapKit and location services |
| [Media](integrations/media.md) | Music, Photos, TV app access |
| [News & Stocks](integrations/news-stocks.md) | Financial and news data |
| [Notes](integrations/notes.md) | Notes app integration |
| [Shortcuts](integrations/shortcuts.md) | Shortcuts app interoperability |
| [Utilities](integrations/utilities.md) | System utilities integration |
| [Weather](integrations/weather.md) | WeatherKit integration |
| [Plugin Architecture](integrations/plugin-architecture.md) | Extensibility design for integrations |

---

## How to Use This Research

1. **Starting a new feature?** Check if relevant research exists here first
2. **Found new information?** Update the relevant doc or create a new one
3. **Making architectural decisions?** Reference these findings in ADRs

All research should inform decisions documented in `docs/architecture/decisions/`.
