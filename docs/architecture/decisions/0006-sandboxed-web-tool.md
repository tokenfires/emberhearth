# ADR-0006: Sandboxed Web Tool for Ember's Research

## Status
**Accepted**

## Date
February 2026

## Context

Ember needs to access the web for:
- Looking up information
- Fetching article content
- Researching topics
- Answering questions requiring current data

If Ember uses the user's Safari session for this:
- User's cookies/sessions are exposed to fetched pages
- Prompt injection could navigate to malicious sites
- Actions could be taken in authenticated contexts
- Privacy boundary is violated

We need web access that is isolated from the user's browsing identity.

## Decision

**Implement a sandboxed web tool as part of the MCP (Model Context Protocol) layer.**

The tool provides:
- Fresh browser context (no cookies, no sessions, no stored auth)
- Headless browsing capability
- URL fetching with content extraction
- Web search functionality

The tool CANNOT:
- Access user's cookies or sessions
- Make purchases or post content
- Authenticate as the user
- Access localStorage/sessionStorage from user's browsing

## Consequences

### Positive
- **Isolation:** User's authenticated state never exposed
- **Safety:** Prompt injection can't access user accounts
- **Privacy:** Ember's research doesn't mix with user's browsing
- **Capability:** Full web research without risk
- **Clarity:** Clear boundary between observation and action

### Negative
- **Authentication required:** Cannot access paywalled content user has access to
- **Implementation complexity:** Must build/integrate headless browser
- **Resource usage:** Separate browser context consumes memory

### Neutral
- **Rate limiting needed:** Prevent abuse/excessive requests
- **Content extraction:** Must handle varied page structures

## Technical Implementation

**Option A: WKWebView in Hidden Window**
```swift
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()  // No cookies persist
let webView = WKWebView(frame: .zero, configuration: config)
// Load URL, extract content via JavaScript
```

**Option B: URLSession with Content Parsing**
```swift
let session = URLSession(configuration: .ephemeral)
let (data, _) = try await session.data(from: url)
// Parse HTML, extract article text
```

**Option C: Third-Party Library**
- Consider libraries like SwiftSoup for HTML parsing
- Or headless browser frameworks

**Recommendation:** Start with Option B (URLSession) for MVP, add WKWebView for JavaScript-rendered pages if needed.

## Tool Interface

```swift
struct WebFetchTool: MCPTool {
    func fetch(url: URL, extract: ExtractionMode) async throws -> WebContent
}

enum ExtractionMode {
    case fullHTML
    case articleText      // Main content extraction
    case metadata         // Title, description, OpenGraph
    case links            // All links on page
}

struct WebContent {
    let url: URL
    let title: String?
    let text: String?
    let metadata: [String: String]
    let fetchedAt: Date
}
```

## Web Search Integration

For search queries, options:
1. **Search API** (Brave Search, SerpAPI) — Clean, costs money
2. **Scrape search results** — Free, fragile, ToS concerns
3. **DuckDuckGo Instant Answers** — Free API for some queries

**Recommendation:** Use a search API for reliability. Budget ~$20/month for typical usage.

## Alternatives Considered

### Use User's Safari Session
- Can access authenticated content
- Rejected: Severe security and privacy risks

### No Web Access
- Maximum isolation
- Rejected: Severely limits assistant usefulness

### Proxy Through External Service
- Could add caching, filtering
- Rejected for MVP: Adds cloud dependency; privacy concerns

## References

- `docs/research/safari-integration.md` — Sandboxed web tool section
- ADR-0005 — Safari Read-Only Default
- `docs/research/security.md` — Isolation principles
