import XCTest
import WebKit

@MainActor
final class RendererTests: XCTestCase, WKNavigationDelegate {
    private var loaded: XCTestExpectation?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?.fulfill() }

    func testRenderingAndLocalImage() async throws {
        let bundle = Bundle(for: Self.self)
        let fixture = try XCTUnwrap(bundle.url(forResource: "fixture", withExtension: "md"))
        let assets = LocalAssets()
        assets.directory = fixture.deletingLastPathComponent()
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(assets, forURLScheme: "mv-local")
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        web.navigationDelegate = self
        let page = try RendererPage(bundle: bundle)
        loaded = expectation(description: "WebKit template loaded")
        web.loadHTMLString(page.html, baseURL: URL(string: "mv-local://document/"))
        await fulfillment(of: [try XCTUnwrap(loaded)], timeout: 10)
        let markdown = try String(contentsOf: fixture, encoding: .utf8)
        let result = try await web.callAsyncJavaScript("""
            window.renderMarkdown(markdown, true);
            const image = document.querySelector('img');
            await new Promise(resolve => {
              if (image.complete) return resolve();
              image.onload = image.onerror = resolve;
              setTimeout(resolve, 3000);
            });
            return {
              heading: document.querySelector('h1').textContent,
              table: document.querySelectorAll('table').length,
              checked: document.querySelectorAll('input:checked').length,
              image: image.naturalWidth,
              anchor: !!document.getElementById('details'),
              unicode: document.body.textContent.includes('日本語 🐈'),
              safe: !window.untrustedExecuted && !document.querySelector('#content script') &&
                    !document.querySelector('a[href^="javascript:"]')
            };
            """, arguments: ["markdown": markdown], in: nil, contentWorld: .page) as? [String: Any]
        let values = try XCTUnwrap(result)
        XCTAssertEqual(values["heading"] as? String, "Markdown Viewer smoke test")
        XCTAssertEqual(values["table"] as? Int, 1)
        XCTAssertEqual(values["checked"] as? Int, 1)
        XCTAssertEqual(values["image"] as? Int, 360)
        XCTAssertEqual(values["anchor"] as? Bool, true)
        XCTAssertEqual(values["unicode"] as? Bool, true)
        XCTAssertEqual(values["safe"] as? Bool, true)
        let replacement = "# Replacement\n\nQuotes: ' \" ` ${value} \\ and </script>"
        let text = try await web.callAsyncJavaScript("window.renderMarkdown(markdown, false); return document.getElementById('content').textContent;", arguments: ["markdown": replacement], in: nil, contentWorld: .page) as? String
        XCTAssertTrue(try XCTUnwrap(text).contains("Replacement"))
        XCTAssertFalse(try XCTUnwrap(text).contains("smoke test"))
        let found = try await web.find("Replacement", configuration: WKFindConfiguration())
        XCTAssertTrue(found.matchFound)
    }

    func testRendererSurvivesBundleMove() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let original = root.appendingPathComponent("Original.bundle")
        let moved = root.appendingPathComponent("Moved.bundle")
        try manager.copyItem(at: Bundle(for: Self.self).bundleURL, to: original)
        let bundle = try XCTUnwrap(Bundle(url: original))
        let page = try RendererPage(bundle: bundle)
        let oldTemplate = try XCTUnwrap(bundle.url(forResource: "viewer", withExtension: "html"))
        try manager.moveItem(at: original, to: moved)
        XCTAssertFalse(manager.fileExists(atPath: oldTemplate.path))
        // The running app retains this HTML; a fresh launch reads the relocated bundle.
        let relaunched = try RendererPage(bundle: XCTUnwrap(Bundle(url: moved)))
        XCTAssertEqual(page.html, relaunched.html)
        XCTAssertTrue(page.html.contains("window.renderMarkdown"))
        XCTAssertFalse(page.html.contains("/* MARKDOWN_PARSER */"))
    }

    func testLocalAssetBoundaries() throws {
        let assets = LocalAssets()
        assets.directory = URL(fileURLWithPath: "/tmp/mv-assets").resolvingSymlinksInPath()
        XCTAssertNotNil(assets.fileURL(for: URL(string: "mv-local://document/image.png")!))
        XCTAssertNil(assets.fileURL(for: URL(string: "mv-local://document/../secret.txt")!))
        XCTAssertNil(assets.fileURL(for: URL(string: "mv-local://other/image.png")!))
        XCTAssertNil(assets.fileURL(for: URL(string: "file:///etc/passwd")!))
    }
}
