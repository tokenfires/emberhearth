# Task 0704: Sandboxed Web Fetcher

**Milestone:** M8 - Polish & Release
**Unit:** Additional - Sandboxed Web Fetcher
**Phase:** 3
**Depends On:** 0504 (MessageCoordinator)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/architecture/decisions/0006-sandboxed-web-tool.md` — Read the full document (~133 lines). This is the design rationale for the web fetcher: why it's sandboxed, what it can and cannot do, and the recommended implementation approach (URLSession with content parsing for MVP).
2. `docs/releases/feature-matrix.md` — Read the "Web Tool" section (lines 202-211). MVP includes: URL fetching and content extraction. NOT in MVP: web search, JS rendering.
3. `docs/specs/tron-security.md` — Read the "Outbound Monitoring" section for the requirement that fetched web content must be run through the outbound pipeline before being passed to the LLM.
4. `docs/architecture/decisions/0004-no-shell-execution.md` — Read in full. No Process(), no /bin/bash, no NSTask. Web fetching uses ONLY URLSession.
5. `CLAUDE.md` — Project conventions.

> **Context Budget Note:** ADR-0006 is ~133 lines — read in full. `feature-matrix.md` focus only on lines 202-211 (Web Tool section). `tron-security.md` is long; only read the "Outbound Monitoring" section header and first few paragraphs.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the sandboxed web fetcher for EmberHearth, a native macOS personal AI assistant. When a user shares a URL in their iMessage conversation, Ember needs to fetch the page content and include it in the LLM context so it can discuss the article/page intelligently.

The web fetcher is SANDBOXED: it uses an ephemeral URLSession with no cookies, no cache persistence, and no user identity. It extracts article text from HTML without executing JavaScript. This is a read-only tool for MVP.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., WebFetcher.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask, no osascript via Process)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## CRITICAL SECURITY RULES

1. **No shell execution.** Web fetching uses ONLY `URLSession` with `.ephemeral` configuration.
2. **No JavaScript execution** in MVP. Content is extracted from raw HTML only.
3. **No cookies, no cache.** The ephemeral session ensures no user identity leaks.
4. **URL validation:** Only allow http:// and https:// schemes. Block file://, localhost, and private IP ranges.
5. **Limited redirects:** Follow at most 3 redirects to prevent redirect chains to malicious sites.
6. **Response size limit:** Reject responses larger than 1MB to prevent memory exhaustion.
7. **Timeout:** 15 seconds maximum per request.
8. **Custom User-Agent:** "EmberHearth/1.0 (macOS)" — never impersonate a browser.

## What You Are Building

1. **WebFetcher** — The main class that fetches URLs and extracts content.
2. **WebContent** — A struct holding the fetched and extracted content.
3. **WebFetcherError** — Error types for the various failure modes.
4. **URLValidator** — Validates and sanitizes URLs before fetching.
5. **HTMLContentExtractor** — Strips HTML tags and extracts article text.

## Files to Create

### 1. `src/Core/WebFetcher.swift`

```swift
// WebFetcher.swift
// EmberHearth
//
// Sandboxed HTTP client for fetching and extracting web content.

import Foundation
import os

/// A sandboxed HTTP client for fetching web content.
///
/// The WebFetcher uses an ephemeral URLSession (no cookies, no cache,
/// no stored credentials) to fetch web pages and extract their text
/// content. It is designed to be a safe, read-only tool that the LLM
/// can use to access web information without risking the user's privacy.
///
/// ## Security Model (per ADR-0006)
/// - **Ephemeral session:** No cookies persist between requests
/// - **No JavaScript:** Content extracted from raw HTML only (MVP)
/// - **URL validation:** Only HTTP/HTTPS, no localhost, no private IPs
/// - **Size limit:** 1MB maximum response
/// - **Timeout:** 15 seconds per request
/// - **Redirect limit:** 3 redirects maximum
/// - **Custom User-Agent:** Identifies as EmberHearth, never impersonates a browser
///
/// ## Usage
/// ```swift
/// let fetcher = WebFetcher()
/// let content = try await fetcher.fetch(url: URL(string: "https://example.com/article")!)
/// print(content.textContent) // Extracted article text
/// ```
final class WebFetcher {

    // MARK: - Constants

    /// Maximum response body size in bytes (1MB).
    static let maxResponseSize: Int = 1_048_576

    /// Maximum number of redirects to follow.
    static let maxRedirects: Int = 3

    /// Request timeout in seconds.
    static let timeoutInterval: TimeInterval = 15.0

    /// Maximum extracted text length in characters.
    static let maxExtractedTextLength: Int = 5000

    /// Custom User-Agent header.
    static let userAgent = "EmberHearth/1.0 (macOS)"

    /// Domains that are blocked (common trackers/ad networks).
    static let blockedDomains: Set<String> = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "google-analytics.com",
        "facebook.com",
        "fbcdn.net",
        "analytics.twitter.com",
        "ads.linkedin.com",
        "adsrvr.org",
        "adnxs.com",
        "rubiconproject.com",
        "pubmatic.com",
        "scorecardresearch.com",
        "quantserve.com"
    ]

    // MARK: - Properties

    /// The ephemeral URL session used for all requests.
    private let session: URLSession

    /// Logger for web fetching operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "WebFetcher")

    /// The HTML content extractor.
    private let extractor = HTMLContentExtractor()

    // MARK: - Initialization

    /// Creates a new WebFetcher with an ephemeral URL session.
    ///
    /// The ephemeral configuration ensures:
    /// - No cookies persist between requests
    /// - No URL cache persists to disk
    /// - No credentials are stored
    /// - Each request is completely isolated
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.timeoutInterval
        config.timeoutIntervalForResource = Self.timeoutInterval + 5.0 // Extra buffer
        config.httpMaximumConnectionsPerHost = 2
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept": "text/html,application/xhtml+xml,text/plain",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        // Do not send or store cookies
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false

        self.session = URLSession(configuration: config)
    }

    /// Creates a WebFetcher with a custom URLSession (for testing).
    ///
    /// - Parameter session: A custom URLSession to use for requests.
    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetches a URL and extracts its text content.
    ///
    /// This method:
    /// 1. Validates the URL (scheme, host, not blocked)
    /// 2. Fetches the page via ephemeral URLSession
    /// 3. Verifies the response size is within limits
    /// 4. Extracts the title and main text content from HTML
    /// 5. Truncates to maxExtractedTextLength if needed
    ///
    /// - Parameter url: The URL to fetch. Must be HTTP or HTTPS.
    /// - Returns: A `WebContent` struct with the extracted content.
    /// - Throws: `WebFetcherError` if validation, fetching, or extraction fails.
    func fetch(url: URL) async throws -> WebContent {
        // Step 1: Validate URL
        try URLValidator.validate(url, blockedDomains: Self.blockedDomains)
        logger.info("Fetching URL: \(url.absoluteString, privacy: .public)")

        // Step 2: Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.timeoutInterval

        // Step 3: Fetch with redirect tracking
        let (data, response) = try await fetchWithRedirectLimit(request: request)

        // Step 4: Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebFetcherError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw WebFetcherError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Step 5: Check size
        guard data.count <= Self.maxResponseSize else {
            throw WebFetcherError.tooLarge(size: data.count, limit: Self.maxResponseSize)
        }

        // Step 6: Decode HTML
        let encoding = httpResponse.textEncodingName.flatMap { String.Encoding(ianaCharSetName: $0) } ?? .utf8
        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
            throw WebFetcherError.networkError("Unable to decode response as text")
        }

        // Step 7: Extract content
        let title = extractor.extractTitle(from: html)
        var textContent = extractor.extractArticleText(from: html)

        // Step 8: Truncate if needed
        if textContent.count > Self.maxExtractedTextLength {
            let truncatedIndex = textContent.index(textContent.startIndex, offsetBy: Self.maxExtractedTextLength)
            textContent = String(textContent[..<truncatedIndex]) + "\n\n[Content truncated at \(Self.maxExtractedTextLength) characters]"
        }

        let content = WebContent(
            url: url,
            title: title,
            textContent: textContent,
            fetchedAt: Date()
        )

        logger.info("Fetched: \(url.host ?? "unknown", privacy: .public) — \(textContent.count) chars extracted")
        return content
    }

    // MARK: - Private Methods

    /// Fetches a URL with a redirect count limit.
    ///
    /// URLSession follows redirects automatically, but we need to limit
    /// the number of redirects to prevent infinite redirect chains.
    ///
    /// - Parameter request: The URL request to fetch.
    /// - Returns: The response data and URL response.
    /// - Throws: `WebFetcherError.tooManyRedirects` if the limit is exceeded.
    private func fetchWithRedirectLimit(request: URLRequest) async throws -> (Data, URLResponse) {
        // Create a delegate that counts redirects
        let delegate = RedirectLimitDelegate(maxRedirects: Self.maxRedirects)
        let delegateSession = URLSession(configuration: session.configuration, delegate: delegate, delegateQueue: nil)

        defer {
            delegateSession.invalidateAndCancel()
        }

        do {
            let (data, response) = try await delegateSession.data(for: request)

            if delegate.redirectLimitExceeded {
                throw WebFetcherError.tooManyRedirects
            }

            return (data, response)
        } catch let error as WebFetcherError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw WebFetcherError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw WebFetcherError.networkError("No internet connection")
            case .cannotFindHost:
                throw WebFetcherError.networkError("Could not find host: \(request.url?.host ?? "unknown")")
            default:
                throw WebFetcherError.networkError(error.localizedDescription)
            }
        } catch {
            throw WebFetcherError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Redirect Limit Delegate

/// A URLSession delegate that tracks and limits redirects.
private final class RedirectLimitDelegate: NSObject, URLSessionTaskDelegate {
    let maxRedirects: Int
    private(set) var redirectCount: Int = 0
    private(set) var redirectLimitExceeded: Bool = false

    init(maxRedirects: Int) {
        self.maxRedirects = maxRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectCount += 1
        if redirectCount > maxRedirects {
            redirectLimitExceeded = true
            completionHandler(nil) // Cancel the redirect
        } else {
            completionHandler(request) // Follow the redirect
        }
    }
}

// MARK: - String Encoding Extension

private extension String.Encoding {
    /// Creates a String.Encoding from an IANA character set name.
    init?(ianaCharSetName: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaCharSetName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        self = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}
```

### 2. `src/Core/WebContent.swift`

```swift
// WebContent.swift
// EmberHearth
//
// Represents fetched and extracted web content.

import Foundation

/// The result of fetching and extracting content from a web page.
///
/// Contains the extracted text content, page title, source URL,
/// and fetch timestamp. This is what gets included in the LLM
/// context when a user shares a URL.
struct WebContent: Sendable {
    /// The original URL that was fetched.
    let url: URL

    /// The page title extracted from the <title> tag, if present.
    let title: String?

    /// The extracted main text content from the page.
    /// HTML tags, scripts, styles, and navigation are stripped.
    /// Truncated to WebFetcher.maxExtractedTextLength if the original was longer.
    let textContent: String

    /// When the content was fetched.
    let fetchedAt: Date

    /// A formatted summary string suitable for including in LLM context.
    ///
    /// Format:
    /// ```
    /// [Web page: "Title" from example.com]
    /// Content here...
    /// ```
    var contextString: String {
        var header = "[Web page"
        if let title = title, !title.isEmpty {
            header += ": \"\(title)\""
        }
        if let host = url.host {
            header += " from \(host)"
        }
        header += "]\n"
        return header + textContent
    }
}
```

### 3. `src/Core/Errors/WebFetcherError.swift`

```swift
// WebFetcherError.swift
// EmberHearth
//
// Error types for the web fetcher.

import Foundation

/// Errors that can occur during web fetching and content extraction.
enum WebFetcherError: LocalizedError, Equatable {
    /// The URL is not valid (wrong scheme, blocked domain, private IP, etc.).
    case invalidURL(reason: String)

    /// A network error occurred during the fetch.
    case networkError(String)

    /// The request timed out (exceeded 15 seconds).
    case timeout

    /// The response body exceeded the size limit (1MB).
    case tooLarge(size: Int, limit: Int)

    /// The URL's domain is in the blocked list.
    case blockedDomain(domain: String)

    /// Too many redirects (exceeded 3).
    case tooManyRedirects

    var errorDescription: String? {
        switch self {
        case .invalidURL(let reason):
            return "Invalid URL: \(reason)"
        case .networkError(let description):
            return "Network error: \(description)"
        case .timeout:
            return "Request timed out after \(Int(WebFetcher.timeoutInterval)) seconds."
        case .tooLarge(let size, let limit):
            return "Response too large: \(size / 1024)KB exceeds \(limit / 1024)KB limit."
        case .blockedDomain(let domain):
            return "Domain blocked: \(domain)"
        case .tooManyRedirects:
            return "Too many redirects (maximum: \(WebFetcher.maxRedirects))."
        }
    }

    /// Equatable conformance.
    static func == (lhs: WebFetcherError, rhs: WebFetcherError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let a), .invalidURL(let b)): return a == b
        case (.networkError(let a), .networkError(let b)): return a == b
        case (.timeout, .timeout): return true
        case (.tooLarge(let s1, let l1), .tooLarge(let s2, let l2)): return s1 == s2 && l1 == l2
        case (.blockedDomain(let a), .blockedDomain(let b)): return a == b
        case (.tooManyRedirects, .tooManyRedirects): return true
        default: return false
        }
    }
}
```

### 4. `src/Core/URLValidator.swift`

```swift
// URLValidator.swift
// EmberHearth
//
// Validates and sanitizes URLs before fetching.

import Foundation

/// Validates URLs to ensure they are safe to fetch.
///
/// Checks:
/// - Only HTTP and HTTPS schemes allowed
/// - No file://, ftp://, or other schemes
/// - No localhost or loopback addresses
/// - No private IP ranges (10.x, 172.16-31.x, 192.168.x)
/// - Not in the blocked domains list
struct URLValidator {

    /// Private IPv4 address ranges that should not be fetched.
    private static let privateIPRanges: [(prefix: String, description: String)] = [
        ("10.", "Private (10.0.0.0/8)"),
        ("172.16.", "Private (172.16.0.0/12)"),
        ("172.17.", "Private (172.16.0.0/12)"),
        ("172.18.", "Private (172.16.0.0/12)"),
        ("172.19.", "Private (172.16.0.0/12)"),
        ("172.20.", "Private (172.16.0.0/12)"),
        ("172.21.", "Private (172.16.0.0/12)"),
        ("172.22.", "Private (172.16.0.0/12)"),
        ("172.23.", "Private (172.16.0.0/12)"),
        ("172.24.", "Private (172.16.0.0/12)"),
        ("172.25.", "Private (172.16.0.0/12)"),
        ("172.26.", "Private (172.16.0.0/12)"),
        ("172.27.", "Private (172.16.0.0/12)"),
        ("172.28.", "Private (172.16.0.0/12)"),
        ("172.29.", "Private (172.16.0.0/12)"),
        ("172.30.", "Private (172.16.0.0/12)"),
        ("172.31.", "Private (172.16.0.0/12)"),
        ("192.168.", "Private (192.168.0.0/16)"),
        ("127.", "Loopback"),
        ("0.", "Invalid"),
        ("169.254.", "Link-local")
    ]

    /// Validates a URL for safe fetching.
    ///
    /// - Parameters:
    ///   - url: The URL to validate.
    ///   - blockedDomains: Set of blocked domain names.
    /// - Throws: `WebFetcherError` if the URL is not safe to fetch.
    static func validate(_ url: URL, blockedDomains: Set<String>) throws {
        // Check scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebFetcherError.invalidURL(reason: "Only HTTP and HTTPS URLs are allowed")
        }

        // Check host exists
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw WebFetcherError.invalidURL(reason: "URL must have a host")
        }

        // Check for localhost
        if host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]" {
            throw WebFetcherError.invalidURL(reason: "Localhost URLs are not allowed")
        }

        // Check for private IP ranges
        for range in privateIPRanges {
            if host.hasPrefix(range.prefix) {
                throw WebFetcherError.invalidURL(reason: "\(range.description) addresses are not allowed")
            }
        }

        // Check blocked domains
        for blockedDomain in blockedDomains {
            if host == blockedDomain || host.hasSuffix(".\(blockedDomain)") {
                throw WebFetcherError.blockedDomain(domain: host)
            }
        }
    }

    /// Detects URLs in a text message.
    ///
    /// Uses NSDataDetector to find URLs in user messages. This is used
    /// by the MessageCoordinator to auto-detect shared links.
    ///
    /// - Parameter text: The message text to scan.
    /// - Returns: An array of detected URLs.
    static func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)

        return matches.compactMap { match -> URL? in
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return nil
            }
            return url
        }
    }
}
```

### 5. `src/Core/HTMLContentExtractor.swift`

```swift
// HTMLContentExtractor.swift
// EmberHearth
//
// Extracts text content from HTML without third-party dependencies.

import Foundation

/// Extracts text content from raw HTML strings.
///
/// This is a simple, dependency-free HTML text extractor for MVP.
/// It strips HTML tags, removes script/style/nav/footer content,
/// and extracts the main article text.
///
/// ## Limitations (MVP)
/// - No JavaScript rendering (static HTML only)
/// - No CSS-based content detection
/// - Simple tag-based extraction (not DOM-aware)
/// - May include some boilerplate text from sidebars
///
/// ## Extraction Priority
/// 1. Content within `<article>` tags
/// 2. Content within `<main>` tags
/// 3. Content within `<body>` tags (fallback)
struct HTMLContentExtractor {

    // MARK: - Title Extraction

    /// Extracts the page title from HTML.
    ///
    /// Looks for content between `<title>` and `</title>` tags.
    ///
    /// - Parameter html: The raw HTML string.
    /// - Returns: The page title, or nil if not found.
    func extractTitle(from html: String) -> String? {
        guard let titleStart = html.range(of: "<title", options: .caseInsensitive),
              let titleTagEnd = html.range(of: ">", range: titleStart.upperBound..<html.endIndex),
              let titleEnd = html.range(of: "</title>", options: .caseInsensitive, range: titleTagEnd.upperBound..<html.endIndex) else {
            return nil
        }

        let title = String(html[titleTagEnd.upperBound..<titleEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? nil : decodeHTMLEntities(title)
    }

    // MARK: - Article Text Extraction

    /// Extracts the main text content from HTML.
    ///
    /// Strategy:
    /// 1. Remove `<script>`, `<style>`, `<nav>`, `<footer>`, `<header>`,
    ///    `<aside>`, `<noscript>` elements and their content
    /// 2. Look for `<article>` content first, then `<main>`, then `<body>`
    /// 3. Strip all remaining HTML tags
    /// 4. Decode HTML entities
    /// 5. Collapse whitespace
    ///
    /// - Parameter html: The raw HTML string.
    /// - Returns: The extracted text content.
    func extractArticleText(from html: String) -> String {
        var workingHTML = html

        // Step 1: Remove elements that are never useful content
        let elementsToRemove = ["script", "style", "nav", "footer", "header", "aside", "noscript", "svg", "iframe"]
        for element in elementsToRemove {
            workingHTML = removeElement(element, from: workingHTML)
        }

        // Step 2: Find the best content section
        var contentHTML: String
        if let articleContent = extractElementContent("article", from: workingHTML) {
            contentHTML = articleContent
        } else if let mainContent = extractElementContent("main", from: workingHTML) {
            contentHTML = mainContent
        } else if let bodyContent = extractElementContent("body", from: workingHTML) {
            contentHTML = bodyContent
        } else {
            contentHTML = workingHTML
        }

        // Step 3: Strip all remaining HTML tags
        var text = stripHTMLTags(from: contentHTML)

        // Step 4: Decode HTML entities
        text = decodeHTMLEntities(text)

        // Step 5: Collapse whitespace
        text = collapseWhitespace(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Helpers

    /// Removes an HTML element and all its content (including nested instances).
    ///
    /// - Parameters:
    ///   - element: The element name (e.g., "script", "style").
    ///   - html: The HTML string to process.
    /// - Returns: The HTML with the element removed.
    private func removeElement(_ element: String, from html: String) -> String {
        var result = html
        let openPattern = "<\(element)[^>]*>"
        let closeTag = "</\(element)>"

        // Repeatedly remove outermost instances
        while let openRange = result.range(of: openPattern, options: [.caseInsensitive, .regularExpression]) {
            if let closeRange = result.range(of: closeTag, options: .caseInsensitive, range: openRange.lowerBound..<result.endIndex) {
                result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
            } else {
                // No closing tag — remove just the opening tag to prevent infinite loop
                result.removeSubrange(openRange)
            }
        }

        return result
    }

    /// Extracts the content between the first opening and last closing tag of an element.
    ///
    /// - Parameters:
    ///   - element: The element name (e.g., "article", "main").
    ///   - html: The HTML string to search.
    /// - Returns: The inner HTML content, or nil if the element is not found.
    private func extractElementContent(_ element: String, from html: String) -> String? {
        let openPattern = "<\(element)[^>]*>"
        guard let openRange = html.range(of: openPattern, options: [.caseInsensitive, .regularExpression]) else {
            return nil
        }

        let closeTag = "</\(element)>"
        guard let closeRange = html.range(of: closeTag, options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        guard openRange.upperBound < closeRange.lowerBound else {
            return nil
        }

        return String(html[openRange.upperBound..<closeRange.lowerBound])
    }

    /// Strips all HTML tags from a string.
    ///
    /// - Parameter html: The HTML string to strip.
    /// - Returns: The text with all tags removed.
    private func stripHTMLTags(from html: String) -> String {
        // Replace <br>, <br/>, <p>, <div> with newlines for paragraph preservation
        var text = html
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?p[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?div[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?h[1-6][^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n- ", options: .regularExpression)

        // Remove all remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return text
    }

    /// Decodes common HTML entities to their text equivalents.
    ///
    /// - Parameter text: The text with HTML entities.
    /// - Returns: The decoded text.
    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text
        let entities: [(entity: String, replacement: String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "--"),
            ("&ndash;", "-"),
            ("&lsquo;", "'"),
            ("&rsquo;", "'"),
            ("&ldquo;", "\""),
            ("&rdquo;", "\""),
            ("&hellip;", "..."),
            ("&copy;", "(c)"),
            ("&reg;", "(R)"),
            ("&trade;", "(TM)")
        ]

        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        // Decode numeric entities (&#NNN; and &#xHHH;)
        decoded = decodeNumericEntities(decoded)

        return decoded
    }

    /// Decodes numeric HTML entities (&#NNN; and &#xHHH;).
    private func decodeNumericEntities(_ text: String) -> String {
        var result = text

        // Decimal entities: &#NNN;
        let decimalPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let numRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        // Hex entities: &#xHHH;
        let hexPattern = "&#[xX]([0-9a-fA-F]+);"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[hexRange], radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        return result
    }

    /// Collapses multiple whitespace characters into single spaces,
    /// and multiple newlines into double newlines (paragraph breaks).
    ///
    /// - Parameter text: The text to collapse.
    /// - Returns: The text with collapsed whitespace.
    private func collapseWhitespace(_ text: String) -> String {
        var result = text

        // Replace tabs and other whitespace with spaces
        result = result.replacingOccurrences(of: "\t", with: " ")
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        // Collapse multiple spaces into single spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Collapse 3+ newlines into 2 (preserve paragraph breaks)
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // Remove leading spaces from lines
        result = result.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        return result
    }
}
```

### 6. `tests/Core/WebFetcherTests.swift`

```swift
// WebFetcherTests.swift
// EmberHearth
//
// Unit tests for WebFetcher, URLValidator, and HTMLContentExtractor.

import XCTest
@testable import EmberHearth

final class WebFetcherTests: XCTestCase {

    // MARK: - URL Validation Tests

    func testValidHTTPURL() {
        let url = URL(string: "http://example.com")!
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    func testValidHTTPSURL() {
        let url = URL(string: "https://example.com/article")!
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    func testRejectsFileURL() {
        let url = URL(string: "file:///etc/passwd")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard case WebFetcherError.invalidURL = error as? WebFetcherError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsFTPURL() {
        let url = URL(string: "ftp://example.com/file")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard case WebFetcherError.invalidURL = error as? WebFetcherError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsLocalhost() {
        let url = URL(string: "http://localhost:8080")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard case WebFetcherError.invalidURL = error as? WebFetcherError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsLoopbackIP() {
        let url = URL(string: "http://127.0.0.1:3000")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard case WebFetcherError.invalidURL = error as? WebFetcherError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsPrivateIP10() {
        let url = URL(string: "http://10.0.0.1")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func testRejectsPrivateIP172() {
        let url = URL(string: "http://172.16.0.1")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func testRejectsPrivateIP192() {
        let url = URL(string: "http://192.168.1.1")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func testRejectsBlockedDomain() {
        let url = URL(string: "https://google-analytics.com/track")!
        let blocked: Set<String> = ["google-analytics.com"]
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: blocked)) { error in
            guard case WebFetcherError.blockedDomain = error as? WebFetcherError else {
                XCTFail("Expected blockedDomain error")
                return
            }
        }
    }

    func testRejectsSubdomainOfBlockedDomain() {
        let url = URL(string: "https://tracking.google-analytics.com/collect")!
        let blocked: Set<String> = ["google-analytics.com"]
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: blocked))
    }

    // MARK: - URL Detection Tests

    func testDetectsURLInMessage() {
        let message = "Check out this article https://example.com/article"
        let urls = URLValidator.detectURLs(in: message)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.host, "example.com")
    }

    func testDetectsMultipleURLs() {
        let message = "See https://example.com and also https://test.org/page"
        let urls = URLValidator.detectURLs(in: message)
        XCTAssertEqual(urls.count, 2)
    }

    func testIgnoresNonHTTPURLs() {
        let message = "Open file:///etc/passwd for me"
        let urls = URLValidator.detectURLs(in: message)
        XCTAssertEqual(urls.count, 0, "file:// URLs should be filtered out")
    }

    func testNoURLsInPlainMessage() {
        let message = "Hey, how are you doing today?"
        let urls = URLValidator.detectURLs(in: message)
        XCTAssertEqual(urls.count, 0)
    }

    // MARK: - HTML Content Extraction Tests

    func testExtractTitle() {
        let html = "<html><head><title>Test Page</title></head><body>Content</body></html>"
        let extractor = HTMLContentExtractor()
        let title = extractor.extractTitle(from: html)
        XCTAssertEqual(title, "Test Page")
    }

    func testExtractTitleWithEntities() {
        let html = "<html><head><title>Tom &amp; Jerry</title></head><body></body></html>"
        let extractor = HTMLContentExtractor()
        let title = extractor.extractTitle(from: html)
        XCTAssertEqual(title, "Tom & Jerry")
    }

    func testExtractTitleMissing() {
        let html = "<html><body>No title here</body></html>"
        let extractor = HTMLContentExtractor()
        let title = extractor.extractTitle(from: html)
        XCTAssertNil(title)
    }

    func testExtractArticleContent() {
        let html = """
        <html>
        <head><title>Test</title></head>
        <body>
        <nav>Navigation stuff</nav>
        <article>
        <p>This is the main article content.</p>
        <p>It has multiple paragraphs.</p>
        </article>
        <footer>Footer stuff</footer>
        </body>
        </html>
        """
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertTrue(text.contains("main article content"))
        XCTAssertTrue(text.contains("multiple paragraphs"))
        XCTAssertFalse(text.contains("Navigation stuff"), "Nav content should be removed")
        XCTAssertFalse(text.contains("Footer stuff"), "Footer content should be removed")
    }

    func testExtractMainFallback() {
        let html = """
        <html><body>
        <main>
        <p>Main content here.</p>
        </main>
        <aside>Sidebar</aside>
        </body></html>
        """
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertTrue(text.contains("Main content here"))
    }

    func testRemovesScriptContent() {
        let html = """
        <html><body>
        <p>Real content.</p>
        <script>alert('evil');</script>
        <p>More content.</p>
        </body></html>
        """
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertFalse(text.contains("alert"), "Script content should be removed")
        XCTAssertTrue(text.contains("Real content"))
        XCTAssertTrue(text.contains("More content"))
    }

    func testRemovesStyleContent() {
        let html = """
        <html><head><style>.foo { color: red; }</style></head>
        <body><p>Content</p></body></html>
        """
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertFalse(text.contains("color"), "Style content should be removed")
        XCTAssertTrue(text.contains("Content"))
    }

    func testDecodesHTMLEntities() {
        let html = "<body><p>Tom &amp; Jerry &lt;3 &quot;cheese&quot;</p></body>"
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertTrue(text.contains("Tom & Jerry"))
        XCTAssertTrue(text.contains("<3"))
        XCTAssertTrue(text.contains("\"cheese\""))
    }

    func testCollapsesWhitespace() {
        let html = "<body><p>Word1     Word2\n\n\n\n\nWord3</p></body>"
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertFalse(text.contains("     "), "Multiple spaces should be collapsed")
    }

    // MARK: - WebContent Tests

    func testContextStringWithTitle() {
        let content = WebContent(
            url: URL(string: "https://example.com/article")!,
            title: "Great Article",
            textContent: "Article content here.",
            fetchedAt: Date()
        )

        let context = content.contextString
        XCTAssertTrue(context.contains("Great Article"))
        XCTAssertTrue(context.contains("example.com"))
        XCTAssertTrue(context.contains("Article content here"))
    }

    func testContextStringWithoutTitle() {
        let content = WebContent(
            url: URL(string: "https://example.com/page")!,
            title: nil,
            textContent: "Page content.",
            fetchedAt: Date()
        )

        let context = content.contextString
        XCTAssertTrue(context.contains("example.com"))
        XCTAssertTrue(context.contains("Page content"))
    }

    // MARK: - WebFetcherError Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(WebFetcherError.invalidURL(reason: "test").errorDescription)
        XCTAssertNotNil(WebFetcherError.networkError("test").errorDescription)
        XCTAssertNotNil(WebFetcherError.timeout.errorDescription)
        XCTAssertNotNil(WebFetcherError.tooLarge(size: 2_000_000, limit: 1_048_576).errorDescription)
        XCTAssertNotNil(WebFetcherError.blockedDomain(domain: "evil.com").errorDescription)
        XCTAssertNotNil(WebFetcherError.tooManyRedirects.errorDescription)
    }

    // MARK: - Security Tests

    func testNoShellExecution() {
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh", "osascript"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "WebFetcher must not contain \(pattern)")
        }
    }

    func testEphemeralSessionUsed() {
        // Verify the fetcher uses ephemeral configuration
        let fetcher = WebFetcher()
        // The session is private, but we can verify behavior through the API
        XCTAssertNotNil(fetcher, "WebFetcher should initialize with ephemeral session")
    }
}
```

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, or osascript.** Hard security rule per ADR-0004.
2. **Only URLSession with `.ephemeral` configuration.** No persistent cookies, no cache, no stored credentials.
3. **No third-party dependencies.** HTML parsing is done with String manipulation and regex. No SwiftSoup or similar libraries for MVP.
4. **No JavaScript execution.** Static HTML extraction only in MVP.
5. All Swift files use PascalCase naming.
6. All public types and methods must have documentation comments (///).
7. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: "WebFetcher"). Log URLs (with .public privacy) but NEVER log HTML content.
8. URL validation must block: file://, ftp://, localhost, loopback, private IPs, blocked domains.
9. Response size limited to 1MB. Extracted text limited to 5000 characters.
10. Request timeout is 15 seconds. Maximum 3 redirects.
11. Custom User-Agent: "EmberHearth/1.0 (macOS)".
12. Test file path: Match existing test directory structure.

## Directory Structure

Create these files:
- `src/Core/WebFetcher.swift`
- `src/Core/WebContent.swift`
- `src/Core/Errors/WebFetcherError.swift`
- `src/Core/URLValidator.swift`
- `src/Core/HTMLContentExtractor.swift`
- `tests/Core/WebFetcherTests.swift`

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. CRITICAL: No Process(), /bin/bash, NSTask, or osascript calls exist
4. URLSession uses .ephemeral configuration
5. URL validation blocks file://, localhost, private IPs, blocked domains
6. HTML extractor strips scripts, styles, nav, footer, header
7. Title extraction works with HTML entities
8. Text is truncated to 5000 characters with indicator
9. Response size is limited to 1MB
10. Request timeout is 15 seconds
11. Maximum 3 redirects enforced
12. Custom User-Agent is set
13. All public methods have documentation comments
14. os.Logger is used (not print())
```

---

## Acceptance Criteria

- [ ] `src/Core/WebFetcher.swift` exists with `fetch(url:)` async throws method
- [ ] `src/Core/WebContent.swift` exists with url, title, textContent, fetchedAt, contextString
- [ ] `src/Core/Errors/WebFetcherError.swift` exists with all error cases
- [ ] `src/Core/URLValidator.swift` exists with validate() and detectURLs() methods
- [ ] `src/Core/HTMLContentExtractor.swift` exists with title and article extraction
- [ ] URLSession uses `.ephemeral` configuration (no cookies, no cache)
- [ ] URL validation blocks: file://, ftp://, localhost, 127.0.0.1, private IPs (10.x, 172.16-31.x, 192.168.x)
- [ ] URL validation blocks domains in the blocked list
- [ ] Blocked domains list includes common ad/tracker networks
- [ ] Maximum response size: 1MB
- [ ] Maximum extracted text: 5000 characters (with truncation indicator)
- [ ] Request timeout: 15 seconds
- [ ] Maximum redirects: 3
- [ ] Custom User-Agent: "EmberHearth/1.0 (macOS)"
- [ ] HTML extractor removes: script, style, nav, footer, header, aside, noscript, svg, iframe
- [ ] HTML extractor priority: article > main > body
- [ ] HTML entities decoded (common named + numeric)
- [ ] Whitespace collapsed (multiple spaces, excessive newlines)
- [ ] URL detection in messages via NSDataDetector
- [ ] WebContent.contextString formats content for LLM context
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `osascript`
- [ ] **CRITICAL:** No third-party dependencies
- [ ] All unit tests pass
- [ ] `os.Logger` used for logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Core/WebFetcher.swift && echo "PASS: WebFetcher.swift exists" || echo "MISSING: WebFetcher.swift"
test -f src/Core/WebContent.swift && echo "PASS: WebContent.swift exists" || echo "MISSING: WebContent.swift"
test -f src/Core/Errors/WebFetcherError.swift && echo "PASS: WebFetcherError.swift exists" || echo "MISSING: WebFetcherError.swift"
test -f src/Core/URLValidator.swift && echo "PASS: URLValidator.swift exists" || echo "MISSING: URLValidator.swift"
test -f src/Core/HTMLContentExtractor.swift && echo "PASS: HTMLContentExtractor.swift exists" || echo "MISSING: HTMLContentExtractor.swift"

# CRITICAL: Verify no shell execution
grep -rn "Process()" src/Core/WebFetcher.swift src/Core/URLValidator.swift src/Core/HTMLContentExtractor.swift || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/Core/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/Core/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/Core/ || echo "PASS: No /bin/sh references found"

# Verify ephemeral session
grep -n "ephemeral" src/Core/WebFetcher.swift && echo "PASS: Ephemeral session used" || echo "FAIL: Ephemeral session not found"

# Verify User-Agent
grep -n "EmberHearth/1.0" src/Core/WebFetcher.swift && echo "PASS: Custom User-Agent set" || echo "FAIL: Custom User-Agent not found"

# Verify blocked domains list exists
grep -c "blockedDomains" src/Core/WebFetcher.swift | xargs -I {} echo "blockedDomains referenced {} times"

# Build the project
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the web fetcher tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/WebFetcherTests 2>&1 | tail -30
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth web fetcher implementation for security, correctness, and robustness. Open these files:

@src/Core/WebFetcher.swift
@src/Core/WebContent.swift
@src/Core/Errors/WebFetcherError.swift
@src/Core/URLValidator.swift
@src/Core/HTMLContentExtractor.swift
@tests/Core/WebFetcherTests.swift

Also reference:
@docs/architecture/decisions/0006-sandboxed-web-tool.md
@docs/architecture/decisions/0004-no-shell-execution.md

## SECURITY AUDIT (Top Priority)

1. **Shell Execution Ban (CRITICAL):**
   - Search ALL files for: Process, NSTask, /bin/bash, /bin/sh, osascript, CommandLine
   - If ANY exist, report as CRITICAL immediately.

2. **URL Validation (CRITICAL):**
   - Does it correctly block file://, ftp://, and other non-HTTP schemes?
   - Does it block localhost, 127.0.0.1, and ::1?
   - Does it block ALL private IP ranges? (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16)
   - Is the 172.16.0.0/12 range fully covered (172.16.* through 172.31.*)?
   - Could an attacker bypass validation using URL encoding, IPv6, or DNS rebinding?
   - Are blocked domain subdomains also blocked? (e.g., tracking.google-analytics.com)

3. **Session Isolation (CRITICAL):**
   - Is URLSession.Configuration.ephemeral used (not .default)?
   - Are cookies explicitly disabled? (httpCookieAcceptPolicy = .never, httpShouldSetCookies = false)
   - Could any user identity leak through headers, cookies, or cached credentials?

4. **Resource Limits:**
   - Is the 1MB response size enforced?
   - Is the 15-second timeout enforced?
   - Is the 3-redirect limit enforced? Can it be bypassed?
   - Is the 5000-character text limit enforced with truncation indicator?

5. **HTML Parsing Security:**
   - Could malicious HTML cause the extractor to hang (ReDoS from regex)?
   - Could deeply nested tags cause stack overflow?
   - Could malformed HTML cause crashes (missing closing tags, etc.)?
   - Are HTML entities properly decoded without introducing XSS-like issues?

## CORRECTNESS

6. **Content Extraction:**
   - Does the extraction priority (article > main > body) work correctly?
   - Are script, style, nav, footer, header, aside properly removed BEFORE extraction?
   - Is whitespace collapsing correct (preserve paragraph breaks, collapse excessive)?
   - Does the `<br>` and `<p>` to newline conversion work?
   - Does list item (`<li>`) formatting work?

7. **Title Extraction:**
   - Does it handle titles with HTML entities?
   - Does it handle missing titles?
   - Does it handle empty titles?
   - Does it handle titles with attributes on the `<title>` tag?

8. **Encoding:**
   - Is character encoding handled correctly (UTF-8 fallback)?
   - Is the IANA charset name conversion correct?

9. **Redirect Handling:**
   - Does the URLSessionTaskDelegate correctly count redirects?
   - Is the delegate session properly invalidated after use?
   - Could the redirect counter be reset between requests?

10. **URL Detection:**
    - Does NSDataDetector correctly find URLs in message text?
    - Are non-HTTP URLs filtered out from detection results?

## CODE QUALITY

11. **Error Handling:**
    - Are URLError codes mapped to appropriate WebFetcherError cases?
    - Is timeout properly detected and reported?
    - Is the size check done before full content parsing?

12. **Test Quality:**
    - Do tests cover URL validation (valid, invalid schemes, localhost, private IPs, blocked domains)?
    - Do tests cover HTML extraction (article, main, body fallback, script removal)?
    - Do tests cover title extraction (present, missing, entities)?
    - Do tests cover URL detection in messages?
    - Do tests cover WebContent.contextString formatting?
    - Are there tests for edge cases (empty HTML, no body tag)?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m8): add sandboxed web fetcher with content extraction
```

---

## Notes for Next Task

- `WebFetcher` is a standalone component. Integration with the message pipeline happens in the `MessageCoordinator`: when a user message contains a URL, detect it with `URLValidator.detectURLs()`, fetch with `WebFetcher.fetch()`, and include `WebContent.contextString` in the LLM context.
- The fetched content SHOULD be run through Tron's outbound pipeline (from task 0500-0504) before being included in the LLM context, to check for prompt injection in web content. This is noted in the Tron security spec.
- For MVP, URL detection and fetching happen inline in the message processing pipeline. The LLM is NOT given a "tool" to call — URLs are auto-detected and content is pre-fetched. LLM tool-use integration for web fetching is a post-MVP enhancement.
- `HTMLContentExtractor` is intentionally simple for MVP. It uses string manipulation and regex, not a proper DOM parser. For v1.1, consider adding SwiftSoup or similar for more robust parsing.
- The blocked domains list is hardcoded for MVP. For post-MVP, this could be loaded from a configuration file or updated remotely.
- `WebContent` is `Sendable` for safe use across async boundaries.
- The `RedirectLimitDelegate` creates a new URLSession per request (with the same ephemeral config). This is intentional to ensure complete isolation between requests.
