// HTMLContentExtractorTests.swift
// EmberHearth
//
// Unit tests for HTMLContentExtractor.

import XCTest
@testable import EmberHearth

final class HTMLContentExtractorTests: XCTestCase {

    private var extractor: HTMLContentExtractor!

    override func setUp() {
        super.setUp()
        extractor = HTMLContentExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - Title Extraction Tests

    func test_extractTitle_simpleTitle() {
        let html = "<html><head><title>My Page Title</title></head><body></body></html>"
        XCTAssertEqual(extractor.extractTitle(from: html), "My Page Title")
    }

    func test_extractTitle_titleWithAttributes() {
        let html = "<html><head><title lang=\"en\">Page With Attributes</title></head></html>"
        XCTAssertEqual(extractor.extractTitle(from: html), "Page With Attributes")
    }

    func test_extractTitle_titleWithHTMLEntities() {
        let html = "<html><head><title>Tom &amp; Jerry&#39;s Page</title></head></html>"
        let title = extractor.extractTitle(from: html)
        XCTAssertEqual(title, "Tom & Jerry's Page")
    }

    func test_extractTitle_noTitle_returnsNil() {
        let html = "<html><head></head><body>Content</body></html>"
        XCTAssertNil(extractor.extractTitle(from: html))
    }

    func test_extractTitle_emptyTitle_returnsNil() {
        let html = "<html><head><title></title></head><body></body></html>"
        XCTAssertNil(extractor.extractTitle(from: html))
    }

    func test_extractTitle_titleCaseInsensitive() {
        let html = "<HTML><HEAD><TITLE>Upper Case Title</TITLE></HEAD></HTML>"
        XCTAssertEqual(extractor.extractTitle(from: html), "Upper Case Title")
    }

    func test_extractTitle_titleWithWhitespace_trims() {
        let html = "<html><head><title>  Padded Title  </title></head></html>"
        XCTAssertEqual(extractor.extractTitle(from: html), "Padded Title")
    }

    func test_extractTitle_emptyString_returnsNil() {
        XCTAssertNil(extractor.extractTitle(from: ""))
    }

    // MARK: - Article Text Extraction Tests

    func test_extractArticleText_basicBody() {
        let html = "<html><body><p>Hello World</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Hello World"), "Should extract body text")
    }

    func test_extractArticleText_prefersArticleOverBody() {
        let html = """
        <html><body>
            <div class="sidebar">Sidebar content</div>
            <article>Main article content goes here</article>
        </body></html>
        """
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Main article content"), "Should prefer article tag")
    }

    func test_extractArticleText_prefersMainOverBody() {
        let html = """
        <html><body>
            <nav>Navigation links</nav>
            <main>Primary page content</main>
            <footer>Footer text</footer>
        </body></html>
        """
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Primary page content"), "Should prefer main tag")
        XCTAssertFalse(text.contains("Navigation links"), "Should not include nav content")
        XCTAssertFalse(text.contains("Footer text"), "Should not include footer content")
    }

    func test_extractArticleText_removesScriptTags() {
        let html = """
        <html><body>
            <p>Visible content</p>
            <script>var x = "hidden script code";</script>
        </body></html>
        """
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Visible content"))
        XCTAssertFalse(text.contains("hidden script code"), "Should remove script content")
    }

    func test_extractArticleText_removesStyleTags() {
        let html = """
        <html><head><style>.class { color: red; }</style></head>
        <body><p>Styled content</p></body></html>
        """
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Styled content"))
        XCTAssertFalse(text.contains("color: red"), "Should remove style content")
    }

    func test_extractArticleText_removesNavTags() {
        let html = "<html><body><nav>Home About Contact</nav><main>Page body</main></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertFalse(text.contains("Home About Contact"), "Should remove nav content")
    }

    func test_extractArticleText_removesFooterTags() {
        let html = "<html><body><article>Article text</article><footer>Copyright 2024</footer></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertFalse(text.contains("Copyright 2024"), "Should remove footer content")
    }

    func test_extractArticleText_decodesHTMLEntities() {
        let html = "<html><body><p>Tom &amp; Jerry &lt;3 pizza &gt; sushi</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Tom & Jerry"), "Should decode &amp;")
        XCTAssertTrue(text.contains("<3"), "Should decode &lt;")
        XCTAssertTrue(text.contains("> sushi"), "Should decode &gt;")
    }

    func test_extractArticleText_decodesNBSP() {
        let html = "<html><body><p>Word1&nbsp;Word2</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Word1 Word2"), "Should decode &nbsp; to space")
    }

    func test_extractArticleText_decodesQuotes() {
        let html = "<html><body><p>She said &quot;hello&quot;</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("\"hello\""), "Should decode &quot;")
    }

    func test_extractArticleText_decodesNumericEntities() {
        let html = "<html><body><p>&#65;&#66;&#67;</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("ABC"), "Should decode &#65; (A), &#66; (B), &#67; (C)")
    }

    func test_extractArticleText_decodesHexEntities() {
        let html = "<html><body><p>&#x41;&#x42;&#x43;</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("ABC"), "Should decode hex entities &#x41; (A) etc.")
    }

    func test_extractArticleText_collapsesMulipleSpaces() {
        let html = "<html><body><p>Word1     Word2</p></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertFalse(text.contains("     "), "Should collapse multiple spaces")
    }

    func test_extractArticleText_emptyHTML_returnsEmpty() {
        let text = extractor.extractArticleText(from: "")
        XCTAssertTrue(text.isEmpty)
    }

    func test_extractArticleText_stripsAllTags() {
        let html = "<div><h1>Title</h1><p>Paragraph <strong>with bold</strong> text</p></div>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertFalse(text.contains("<"), "Should not contain any HTML tags")
        XCTAssertFalse(text.contains(">"), "Should not contain any HTML tags")
        XCTAssertTrue(text.contains("Title"))
        XCTAssertTrue(text.contains("Paragraph"))
        XCTAssertTrue(text.contains("with bold"))
    }

    func test_extractArticleText_listItemsOnNewLines() {
        let html = "<html><body><ul><li>Item 1</li><li>Item 2</li></ul></body></html>"
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Item 1"))
        XCTAssertTrue(text.contains("Item 2"))
    }

    func test_extractArticleText_realWorldLikeHTML() {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <title>Breaking News Article</title>
            <style>body { font-family: Arial; }</style>
        </head>
        <body>
            <nav><a href="/">Home</a> | <a href="/news">News</a></nav>
            <header><h1>Breaking News</h1></header>
            <article>
                <h2>Scientists Discover New Species</h2>
                <p>Researchers announced today that they have discovered a remarkable new species in the Amazon rainforest.</p>
                <p>The discovery was made during a routine expedition.</p>
            </article>
            <aside>Related: Other news stories here</aside>
            <footer>Copyright 2024 Example News</footer>
            <script>window.analytics = {};</script>
        </body>
        </html>
        """
        let text = extractor.extractArticleText(from: html)
        XCTAssertTrue(text.contains("Scientists Discover New Species"), "Should include article heading")
        XCTAssertTrue(text.contains("remarkable new species"), "Should include article body")
        XCTAssertFalse(text.contains("Copyright"), "Should exclude footer")
        XCTAssertFalse(text.contains("window.analytics"), "Should exclude scripts")
    }
}
