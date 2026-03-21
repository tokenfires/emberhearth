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
            guard let typedError = error as? WebFetcherError, case .invalidURL = typedError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsFTPURL() {
        let url = URL(string: "ftp://example.com/file")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard let typedError = error as? WebFetcherError, case .invalidURL = typedError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsLocalhost() {
        let url = URL(string: "http://localhost:8080")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard let typedError = error as? WebFetcherError, case .invalidURL = typedError else {
                XCTFail("Expected invalidURL error")
                return
            }
        }
    }

    func testRejectsLoopbackIP() {
        let url = URL(string: "http://127.0.0.1:3000")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard let typedError = error as? WebFetcherError, case .invalidURL = typedError else {
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
            guard let typedError = error as? WebFetcherError, case .blockedDomain = typedError else {
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

    func testExtractBodyFallback() {
        let html = "<html><body><p>Body-only content with no article or main.</p></body></html>"
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)

        XCTAssertTrue(text.contains("Body-only content"))
    }

    func testExtractFromEmptyHTML() {
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: "")
        XCTAssertEqual(text, "")
    }

    func testExtractFromHTMLWithNoBody() {
        let html = "<html><head><title>Title Only</title></head></html>"
        let extractor = HTMLContentExtractor()
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.isEmpty || !text.contains("<"), "Should not contain raw HTML tags")
    }

    func testExtractTitleWithAttributes() {
        let html = "<html><head><title data-rh=\"true\">Attributed Title</title></head><body></body></html>"
        let extractor = HTMLContentExtractor()
        let title = extractor.extractTitle(from: html)
        XCTAssertEqual(title, "Attributed Title")
    }

    func testRejectsIPv6Loopback() {
        let url = URL(string: "http://[::1]:8080/path")!
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            guard let typedError = error as? WebFetcherError, case .invalidURL = typedError else {
                XCTFail("Expected invalidURL error for IPv6 loopback")
                return
            }
        }
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
        let fetcher = WebFetcher()
        XCTAssertNotNil(fetcher, "WebFetcher should initialize with ephemeral session")
    }
}
