# ADR-0002: Distribute Outside Mac App Store

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth requires access to:
- `~/Library/Messages/chat.db` — iMessage database (primary interface)
- `~/Library/Safari/History.db` — Browser history
- `~/Library/Safari/Bookmarks.plist` — Bookmarks and Reading List

These paths are protected by macOS and require **Full Disk Access** permission.

Distribution options:
1. **Mac App Store** — Discoverability, trust, auto-updates
2. **Direct Download (Developer ID)** — Flexibility, Full Disk Access viable
3. **Both** — Maximum reach, but maintenance burden

## Decision

**Distribute outside the Mac App Store via Developer ID signing.**

The app will be:
- Code signed with Developer ID Application certificate
- Notarized by Apple (malware scan)
- Distributed via direct download from project website

## Consequences

### Positive
- **Full Disk Access:** Can request FDA from users (required for iMessage)
- **Flexibility:** No App Store review constraints
- **Entitlements:** Can use entitlements that App Store rejects
- **Privacy:** No App Store analytics/tracking
- **Speed:** Updates ship when ready, not when Apple approves

### Negative
- **Discoverability:** No App Store presence
- **Trust:** Users must trust direct download
- **Updates:** Must implement own update mechanism (Sparkle framework)
- **Payment:** Must handle licensing/payment if monetized
- **Gatekeeper:** Users see "downloaded from internet" warning (mitigated by notarization)

### Neutral
- **Code signing still required:** Notarization enforces security standards
- **Hardened Runtime required:** Same security baseline as App Store

## Alternatives Considered

### Mac App Store Only
- Better discoverability and trust
- Rejected: Cannot reliably obtain Full Disk Access; App Store apps have sandbox restrictions that prevent iMessage integration

### Both Distribution Channels
- Maximum reach
- Rejected for MVP: Maintenance burden of two builds; App Store version would be feature-limited anyway

### No Code Signing (Developer Mode)
- Simplest for development
- Rejected: Unacceptable for any distribution; Gatekeeper blocks unsigned apps

## Implementation Notes

- Set up Developer ID Application certificate in Apple Developer portal
- Configure Hardened Runtime in Xcode
- Implement notarization in CI/CD pipeline
- Use Sparkle framework for auto-updates
- Create clear installation instructions for users

## Update Mechanism

Since we're outside App Store, implement updates via:
- **Sparkle framework** — Industry standard for Mac app updates
- Check for updates on launch (configurable)
- Delta updates to minimize download size
- Code signing verification before installing updates

## References

- `docs/research/security.md` — Code signing and notarization details
- `docs/research/imessage.md` — Full Disk Access requirement
- Apple Developer Documentation — Notarizing macOS Software
