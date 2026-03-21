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
        config.timeoutIntervalForResource = Self.timeoutInterval + 5.0
        config.httpMaximumConnectionsPerHost = 2
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept": "text/html,application/xhtml+xml,text/plain",
            "Accept-Language": "en-US,en;q=0.9"
        ]
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
        try URLValidator.validate(url, blockedDomains: Self.blockedDomains)
        logger.info("Fetching URL: \(url.absoluteString, privacy: .public)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.timeoutInterval

        let (data, response) = try await fetchWithRedirectLimit(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebFetcherError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw WebFetcherError.networkError("HTTP \(httpResponse.statusCode)")
        }

        guard data.count <= Self.maxResponseSize else {
            throw WebFetcherError.tooLarge(size: data.count, limit: Self.maxResponseSize)
        }

        let encoding = httpResponse.textEncodingName.flatMap { String.Encoding(ianaCharSetName: $0) } ?? .utf8
        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
            throw WebFetcherError.networkError("Unable to decode response as text")
        }

        let title = extractor.extractTitle(from: html)
        var textContent = extractor.extractArticleText(from: html)

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
            case .cancelled where delegate.redirectLimitExceeded:
                throw WebFetcherError.tooManyRedirects
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
            completionHandler(nil)
        } else {
            completionHandler(request)
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
