# Safari Integration Research

> *"The browser is where modern life happens. A personal assistant that can't see what you're reading, saving, and researching is missing a massive piece of context."*

## Overview

Safari integration is essential for EmberHearth. Users' browsing activity reveals interests, research topics, saved articles, and ongoing projects. This document explores programmatic access options for Safari on macOS.

**Key Questions:**
- Can Ember read bookmarks, Reading List, and history?
- Can Ember interact with open tabs (read content, navigate)?
- Can Ember inject functionality into Safari pages?
- What permissions are required?

---

## Security Philosophy: Read vs. Control

> ⚠️ **Critical Design Principle:** EmberHearth is built security-first. The failures of other AI companion systems (see `legal-ethical-considerations.md`) demonstrate what happens when AI systems are given too much agency without proper boundaries.

Before diving into technical capabilities, we must distinguish between two fundamentally different types of browser integration:

### Read Access (Data Pipeline)

**Purpose:** Learning about the user to provide better assistance.

| Capability | Value | Risk Level |
|------------|-------|------------|
| Bookmarks | Understand long-term interests | Low |
| Reading List | Know what user wants to read | Low |
| History | Understand research patterns | Medium (privacy) |
| Current tab URLs | Know what user is viewing | Medium |
| Page content (read-only) | Summarize articles | Medium |

**Read access is a data pipeline.** Ember learns from this information to be a better assistant. The user's browser remains under their control.

### Control Access (Articulation)

**Purpose:** Acting on the user's behalf in the browser.

| Capability | Value | Risk Level |
|------------|-------|------------|
| Navigate to URL | Open resources for user | Medium |
| Open new tabs | Multi-step research | Medium |
| Inject JavaScript | Interact with pages | **HIGH** |
| Fill forms | Automation tasks | **HIGH** |
| Click buttons | Autonomous actions | **HIGH** |

**Control access is articulation.** Ember takes actions in the user's actual browser session. This is fundamentally different—and fundamentally more dangerous.

### The Moltbot Lesson

Other AI systems have failed by being "too open"—giving AI agents direct control over user-facing systems without adequate sandboxing. When an AI can:
- Navigate to arbitrary URLs in the user's authenticated browser
- Execute JavaScript on pages with the user's cookies/sessions
- Interact with forms and buttons

...the potential for harm scales dramatically. A prompt injection, a misunderstanding, or a bug can result in:
- Unauthorized purchases
- Data exposure
- Account compromise
- Actions the user never intended

**EmberHearth's position:** Read access by default. Control access requires explicit, informed opt-in—and even then, we prefer sandboxed alternatives.

---

## Integration Approaches

Safari offers several integration paths, each with different capabilities and tradeoffs:

| Approach | Read Data | Control Browser | Inject Content | Permissions Required |
|----------|-----------|-----------------|----------------|---------------------|
| **Direct File Access** | Bookmarks, History, Reading List | No | No | Full Disk Access |
| **AppleScript** | Current tabs/windows | Yes (navigate, open) | Yes (via do JavaScript) | Accessibility (for some) |
| **Safari App Extension** | Page content (with permission) | Limited | Yes | App Store distribution |
| **Safari Web Extension** | Page content (with permission) | Limited | Yes | App Store distribution |

---

## Approach 1: Direct File Access

### What's Available

Safari stores user data in standard file formats that can be read programmatically:

**Bookmarks & Reading List:**
```
~/Library/Safari/Bookmarks.plist
```
- Binary plist format
- Contains all bookmarks AND Reading List items
- Can be converted to XML: `plutil -convert xml1 Bookmarks.plist -o Bookmarks.xml`
- Reading List items have `ReadingList` key with `DateAdded`, `PreviewText`, etc.

**Browsing History:**
```
~/Library/Safari/History.db
```
- SQLite database
- Tables: `history_items` (unique URLs), `history_visits` (each visit)
- Timestamps are seconds from January 1, 2001 (add 978307200 for Unix epoch)
- Safari must be quit to access directly, or use Full Disk Access

**Sample History Query:**
```sql
SELECT
    datetime(hv.visit_time + 978307200, 'unixepoch', 'localtime') as visited,
    hi.url,
    hv.title
FROM history_visits hv
JOIN history_items hi ON hv.history_item = hi.id
ORDER BY hv.visit_time DESC
LIMIT 100;
```

**Other Files:**
- `~/Library/Safari/TopSites.plist` — Frequently visited sites
- `~/Library/Safari/Downloads.plist` — Download history
- `~/Library/Safari/LastSession.plist` — Tabs from last session (for recovery)

### Permissions Required

**Full Disk Access** is required to read Safari's data files:
- System Settings → Privacy & Security → Full Disk Access
- User must explicitly grant this to EmberHearth
- This is a significant permission—users may hesitate

**Implication for EmberHearth:** We can request Full Disk Access during onboarding as an optional enhancement. Users who grant it get richer context from their browsing. Users who don't still get core functionality.

### Implementation Notes

```swift
// Reading Bookmarks.plist
let bookmarksURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Safari/Bookmarks.plist")

if let bookmarks = NSDictionary(contentsOf: bookmarksURL) {
    // Parse bookmark structure
    // Look for "ReadingList" key for Reading List items
}

// Reading History.db (requires FDA)
let historyURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Safari/History.db")

// Use SQLite.swift or similar to query
```

**Important:** Safari locks History.db while running. Options:
1. Copy the file first, then read the copy
2. Wait for Safari to quit (not ideal for real-time)
3. Use Full Disk Access which may allow concurrent read access

---

## Approach 2: AppleScript Automation

### Safari's Scripting Dictionary

Safari has a limited but useful AppleScript interface:

**Available Elements:**
- `document` — A Safari document (webpage)
- `window` — A Safari window
- `tab` — A tab within a window

**Available Commands:**
- `do JavaScript` — Execute JavaScript on a page
- `email contents` — Email page contents (less useful)

### What You CAN Do

**Read current tabs and URLs:**
```applescript
tell application "Safari"
    set tabList to {}
    repeat with w in windows
        repeat with t in tabs of w
            set end of tabList to {URL of t, name of t}
        end repeat
    end repeat
    return tabList
end tell
```

**Navigate to a URL:**
```applescript
tell application "Safari"
    tell window 1
        set URL of current tab to "https://example.com"
    end tell
end tell
```

**Open URL in new tab:**
```applescript
tell application "Safari"
    tell window 1
        set newTab to make new tab with properties {URL:"https://example.com"}
    end tell
end tell
```

**Execute JavaScript on page:**
```applescript
tell application "Safari"
    tell document 1
        set pageTitle to do JavaScript "document.title"
        set pageText to do JavaScript "document.body.innerText"
    end tell
end tell
```

### What You CANNOT Do (via AppleScript)

- Directly access bookmarks (must parse Bookmarks.plist)
- Access history (must query History.db)
- Access Reading List (must parse Bookmarks.plist)
- Access cookies or local storage
- Intercept network requests

### JavaScript Injection Power

The `do JavaScript` command is powerful—it can:
- Read page content (`document.body.innerHTML`)
- Extract specific elements (`document.querySelector(...)`)
- Interact with page (`document.getElementById('button').click()`)
- Read form data (with privacy implications)

**Example: Extract article text:**
```applescript
tell application "Safari"
    tell document 1
        set articleText to do JavaScript "
            const article = document.querySelector('article') || document.body;
            article.innerText;
        "
    end tell
end tell
```

### Permissions

- Basic Safari scripting: No special permissions
- `do JavaScript`: May require "Allow JavaScript from Apple Events" in Safari settings
- GUI scripting (System Events): Requires Accessibility permission

**Safari Setting:** Safari → Settings → Advanced → "Allow JavaScript from Apple Events"
- User must enable this for `do JavaScript` to work
- Security measure to prevent malicious scripts

---

## Approach 3: Safari App Extension

### Overview

Safari App Extensions are native macOS components that integrate with Safari:

- Part of a native Mac app (distributed via App Store)
- Can display native AppKit UI in Safari toolbar/popover
- Can inject content scripts into web pages
- Can communicate bidirectionally with containing app

### Architecture

```
┌─────────────────────────────────────────────┐
│           EmberHearth.app                   │
│  ┌───────────────────────────────────────┐  │
│  │    Safari App Extension (.appex)      │  │
│  │  ┌─────────────┐  ┌────────────────┐  │  │
│  │  │ Background  │  │ Content Script │  │  │
│  │  │ (Swift)     │  │ (JavaScript)   │  │  │
│  │  └─────────────┘  └────────────────┘  │  │
│  └───────────────────────────────────────┘  │
│                    ↑↓                       │
│  ┌───────────────────────────────────────┐  │
│  │         Main App Process              │  │
│  │    (Receives data from extension)     │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Communication

**App → Extension:**
```swift
SFSafariApplication.dispatchMessage(
    withName: "getData",
    toExtensionWithIdentifier: "com.emberhearth.safari",
    userInfo: ["key": "value"]
)
```

**Extension → App:**
Use App Groups and shared UserDefaults, or XPC services.

### Capabilities

- **Page content access:** Content scripts can read DOM
- **Navigation events:** Know when user navigates
- **Toolbar button:** Native UI in Safari toolbar
- **Context menu items:** Add items to right-click menu
- **Tab/window events:** Track tab opens, closes, switches

### Limitations

- macOS only (no iOS via this method)
- Requires App Store distribution
- User must enable the extension in Safari
- Can't access bookmarks/history directly (still need file access)
- Content scripts only run on pages user visits

---

## Approach 4: Safari Web Extension

### Overview

Safari Web Extensions use the cross-platform WebExtensions API:

- Compatible with Chrome/Firefox extension code
- Works on both macOS and iOS
- HTML/CSS UI (not native)
- Still distributed via App Store in native app wrapper

### Capabilities

Similar to Safari App Extensions, but:
- Cross-platform code reuse
- HTML popover instead of native AppKit
- Same content script injection capabilities
- Native messaging still available for app communication

### When to Choose Web vs App Extension

| Use Case | Recommendation |
|----------|----------------|
| Need native macOS UI | Safari App Extension |
| Need iOS support | Safari Web Extension |
| Porting from Chrome | Safari Web Extension |
| Deep app integration | Safari App Extension |

---

## Recommended Strategy for EmberHearth

### Core Principle: Separation of Concerns

EmberHearth's browser integration follows two separate paths:

1. **Read Path:** Ember learns from user's Safari data (passive, always available)
2. **Web Tool Path:** Ember interacts with the web via sandboxed MCP tool (active, isolated)

The user's Safari session is **never directly controlled** by default.

### MVP Phase: Read-Only Integration

**Use Direct File Access (Read Path):**

1. **Bookmarks & Reading List** — Parse `Bookmarks.plist`
   - Surface saved articles as context
   - "I see you saved an article about X—would you like me to summarize it?"

2. **History** — Query `History.db` (with Full Disk Access)
   - Understand user's research patterns
   - "You've been reading a lot about Y this week..."

3. **Current Tabs** — AppleScript to enumerate open tabs (URLs and titles only)
   - Real-time awareness of what user is viewing
   - "Want me to help with what you're looking at?"

4. **Page Content** — Read-only extraction for context
   - Summarize articles user is reading
   - Extract text user highlights or selects

**What MVP does NOT include:**
- ❌ Navigating Safari to URLs
- ❌ Opening new tabs
- ❌ Executing JavaScript for interaction (only for read)
- ❌ Any browser control capabilities

### The Sandboxed Web Tool (MCP Layer)

When Ember needs to interact with the web—research, fetch content, look things up—she should NOT use the user's Safari session. Instead:

```
┌─────────────────────────────────────────────────────────────────────┐
│  EMBER'S WEB ACCESS                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   User's Safari                    Ember's Web Tool                 │
│   ┌─────────────┐                 ┌─────────────────┐              │
│   │             │                 │                 │              │
│   │  Bookmarks  │ ──READ──────▶   │  MCP Web Tool   │              │
│   │  History    │                 │  (Sandboxed)    │              │
│   │  Open Tabs  │                 │                 │              │
│   │             │                 │  • No cookies   │              │
│   │  ⚠️ USER'S  │                 │  • No sessions  │              │
│   │  SESSION    │                 │  • No auth      │              │
│   │             │                 │  • Fresh context│              │
│   └─────────────┘                 └─────────────────┘              │
│         │                                  │                        │
│         │                                  │                        │
│     DO NOT                           Ember uses                     │
│     CONTROL                          this to:                       │
│                                      • Research topics              │
│                                      • Fetch articles               │
│                                      • Look up information          │
│                                      • Web searches                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**The Sandboxed Web Tool provides:**
- Fresh browser context (no cookies, no sessions, no user auth)
- Headless browsing capability (via WebKit or similar)
- URL fetching with content extraction
- Cannot access user's authenticated state
- Cannot make purchases, post content, or take actions as user

**This is a tool call**, part of the MCP (Model Context Protocol) layer. When Ember needs to look something up:
```
Ember: "Let me look that up for you."
[Tool: web_fetch(url="https://...", extract="article_text")]
[Returns: content from sandboxed fetch]
Ember: "Here's what I found..."
```

### Post-MVP: Safari Extension (Read-Enhanced)

**Add Safari App Extension for better READ access:**

- Persistent presence in Safari toolbar (for user-initiated actions)
- Real-time page content capture (not just current tab)
- Navigation event tracking (Ember knows what user browses)
- Quick actions triggered BY USER in Safari → EmberHearth

**The extension is for read/observe, not control.**

### Experimental Feature: Direct Safari Control

For power users who explicitly want Ember to control their browser, we offer an **experimental** feature:

**Requirements to enable:**
- Explicitly opt-in via Settings → Experimental → Safari Control
- Acknowledge warning about security implications
- Separate permission request (not bundled with read access)

**What it enables:**
- Ember can open URLs in Safari
- Ember can navigate tabs
- Ember can execute JavaScript (with user confirmation per action, initially)

**Safeguards:**
- Disabled by default (must be explicitly enabled)
- Clear audit log of all browser control actions
- User can revoke at any time
- Tron reviews all navigation/control requests
- Consider: per-action confirmation until trust established

**Why experimental:**
- Higher risk surface area
- Potential for prompt injection exploitation
- User's authenticated sessions at risk
- Better alternatives exist (sandboxed web tool)

### Permission Strategy

**Onboarding Flow:**
1. Core functionality works without browser access
2. Offer "Browser Awareness" as optional enhancement (READ ONLY)
3. Explain value: "Ember learns from your browsing to help better"
4. Request Full Disk Access if user opts in
5. **Never** request Safari control permissions during onboarding

**Graceful Degradation:**
- No permissions: Ember works, uses sandboxed web tool for research
- Read access only: Ember learns from bookmarks/history/tabs
- Full access (experimental): Ember can also control Safari

### Why This Approach?

| Concern | How We Address It |
|---------|------------------|
| Prompt injection | Sandboxed tool can't access authenticated sessions |
| Unintended actions | No control by default; experimental feature requires opt-in |
| User trust | Read-only feels safe; control feels invasive |
| Capability | Sandboxed web tool provides research capability without risk |
| Power users | Experimental feature available for those who want it |
| Audit/compliance | Clear separation makes security review easier |

---

## Security Considerations

### Privacy Implications

Browser data is sensitive:
- History reveals interests, habits, potentially embarrassing content
- Bookmarks reveal long-term interests and saved content
- Open tabs reveal current focus and work

**EmberHearth Principles:**
- All data stays local (no cloud sync of browsing data)
- User controls what Ember can access
- Clear explanation of what data is used and why
- No scraping of passwords, form data, or financial info

### Sandboxing Challenges

macOS App Sandbox restricts file access:
- `~/Library/Safari/` is outside normal sandbox
- Full Disk Access entitlement OR user-granted access required
- Safari App Extension runs in separate sandbox

**Options:**
1. Request Full Disk Access entitlement (requires justification to Apple)
2. Use temporary exceptions for specific paths
3. Accept limited access in sandboxed mode

### Full Disk Access Concerns

Users may hesitate to grant FDA:
- It's a powerful permission
- Malware often requests it
- Trust must be established first

**Mitigation:**
- Make FDA optional, not required
- Demonstrate value before requesting
- Clear privacy policy
- Open source the data access code (transparency)

---

## Chrome Integration (Future)

> **Note:** Chrome integration follows similar patterns but with different file locations and APIs.

### Chrome Data Locations

```
~/Library/Application Support/Google/Chrome/Default/
├── Bookmarks          # JSON format
├── History            # SQLite database
├── Cookies            # SQLite database
├── Login Data         # SQLite (encrypted)
└── Preferences        # JSON format
```

### Chrome AppleScript

Chrome has a more complete AppleScript dictionary than Safari:
- Can read bookmarks directly via scripting
- Better tab/window control
- Similar `execute javascript` capability

### Chrome Extension API

Chrome extensions use the same WebExtensions API as Safari Web Extensions, but:
- Distributed via Chrome Web Store (not App Store)
- Can run without native app wrapper
- Native messaging requires separate configuration

**Implication:** A Safari Web Extension could be adapted for Chrome with minimal changes, but distribution is separate.

---

## Implementation Checklist

### Phase 1: Read Access + Sandboxed Web Tool (MVP)

**Read Access (Safari Data Pipeline):**
- [ ] Parse `Bookmarks.plist` for bookmarks and Reading List
- [ ] Query `History.db` for browsing history
- [ ] AppleScript wrapper for current tabs/windows (URLs and titles only)
- [ ] Read-only page content extraction (for summarization)
- [ ] Full Disk Access permission request flow
- [ ] Graceful handling when permissions denied

**Sandboxed Web Tool (MCP Layer):**
- [ ] Implement headless WebKit-based fetcher
- [ ] URL fetch with content extraction (article text, metadata)
- [ ] Web search capability (via search API or scraping)
- [ ] Strict isolation: no cookies, no sessions, no user auth
- [ ] Rate limiting and abuse prevention
- [ ] Tool call interface for LLM integration

### Phase 2: Safari Extension (Read-Enhanced)

- [ ] Create Safari App Extension target
- [ ] Implement toolbar button UI (for user-initiated actions)
- [ ] Content script for page capture (read-only)
- [ ] Navigation event tracking (observe, not control)
- [ ] Native messaging to main app
- [ ] App Store submission with extension

### Phase 3: Experimental Safari Control

- [ ] Settings UI for experimental feature opt-in
- [ ] Security warning acknowledgment flow
- [ ] AppleScript wrapper for navigation (guarded)
- [ ] AppleScript wrapper for `do JavaScript` (guarded)
- [ ] Tron integration for control request review
- [ ] Audit logging for all control actions
- [ ] Per-action confirmation mode (optional)

### Phase 4: Cross-Browser

- [ ] Chrome bookmarks/history parsing (read access)
- [ ] Chrome AppleScript integration (read access)
- [ ] Extend sandboxed web tool (browser-agnostic)
- [ ] Consider cross-platform web extension (read-focused)

---

## Research Sources

- [Safari Extensions - Apple Developer](https://developer.apple.com/safari/extensions/)
- [Safari App Extensions Documentation](https://developer.apple.com/documentation/safariservices/safari-app-extensions)
- [Safari Web Extensions Documentation](https://developer.apple.com/documentation/safariservices/safari-web-extensions)
- [go-safari: Access Safari Data (GitHub)](https://github.com/deanishe/go-safari)
- [Safari History.db Format](http://justsolve.archiveteam.org/wiki/History.db)
- [Exporting Reading List via Shortcuts - MacStories](https://www.macstories.net/mac/exporting-links-from-safari-reading-list-via-shortcuts-for-mac/)
- [Safari AppleScript Tab Finding](https://hea-www.harvard.edu/~fine/OSX/safari-tabs.html)
- [do JavaScript in Safari - alexwlchan](https://alexwlchan.net/til/2024/applescript-do-javascript/)
- [Safari App Extension vs Web Extension - Medium](https://medium.com/@gbraghin/safari-app-extension-vs-safari-web-extension-5615902bc7cd)

---

## Open Questions

1. **History access while Safari running** — Can we read History.db with FDA while Safari is open, or must we copy first?

2. **iCloud sync implications** — If bookmarks/history sync via iCloud, do we get cross-device data or just local?

3. **Private browsing** — Can/should we access private browsing tabs? (Probably not, for privacy)

4. **Safari Technology Preview** — Does it use the same data locations?

5. **Extension approval** — What's Apple's stance on extensions that send page content to containing apps? Need to review guidelines.

6. **Reading List sync** — Reading List syncs via iCloud—do we get items added on iOS?

7. **Sandboxed web tool technology** — WebKit headless? WKWebView in invisible window? Third-party library? Need to evaluate options for the MCP web tool.

8. **Search integration** — Should the sandboxed web tool use a search API (Brave, SerpAPI, etc.) or scrape search results? API is cleaner but adds cost/dependency.

9. **Experimental feature telemetry** — If users enable Safari control, should we collect anonymized data about usage patterns to understand risk?

---

## Related Documents

- `legal-ethical-considerations.md` — AI companion failures, including security/control issues
- `security.md` — EmberHearth security architecture and Tron
- `VISION.md` — Core security philosophy and shell execution prohibition

---

*Document created: February 2026*
*Revised: February 2026 — Added security philosophy (read vs. control), sandboxed web tool architecture, experimental feature framework*
*Status: Research complete — security-first architecture defined*
