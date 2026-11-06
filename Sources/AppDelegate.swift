import AppKit
import WebKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSToolbarDelegate {
    private var window: NSWindow!
    private var webView: DropWebView!
    private let assets = LocalAssets()
    private let searchField = NSSearchField()
    private var fileURL: URL?
    private var markdown = "# Markdown Viewer\n\nOpen a Markdown file with **⌘O**, or drop one here.\n\n- **⌘R** reloads after editing in your favorite editor.\n- **⌘F** searches the rendered document.\n- **⌘+ / ⌘−** changes the reading size.\n\nTables, fenced code blocks, links, and local images are supported."
    private var ready = false
    private lazy var rendererPage = Result { try RendererPage(bundle: .main) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeWindow()
        makeMenu()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if window == nil { makeWindow(); makeMenu() }
        if let url = urls.first { open(url) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private func makeWindow() {
        guard window == nil else { return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(assets, forURLScheme: "mv-local")
        webView = DropWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.onDrop = { [weak self] in self?.open($0) }
        webView.registerForDraggedTypes([.fileURL])
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Markdown Viewer"
        window.minSize = NSSize(width: 420, height: 320)
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MarkdownViewer")
        searchField.placeholderString = "Find in document"
        searchField.target = self
        searchField.action = #selector(findNext)
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = true
        let toolbar = NSToolbar(identifier: "Main")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        loadPage()
    }

    private func makeMenu() {
        let menu = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let result = NSMenu(title: title)
            item.submenu = result
            menu.addItem(item)
            return result
        }
        func item(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            if responds(to: action) { entry.target = self }
            menu.addItem(entry)
        }
        let application = submenu("Markdown Viewer")
        item(application, "About Markdown Viewer", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), "")
        application.addItem(.separator())
        item(application, "Quit Markdown Viewer", #selector(NSApplication.terminate(_:)), "q")
        let file = submenu("File")
        item(file, "Open…", #selector(openPanel), "o")
        item(file, "Reload", #selector(reload), "r")
        item(file, "Reveal in Finder", #selector(reveal), "")
        file.addItem(.separator())
        item(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = submenu("Edit")
        item(edit, "Copy", #selector(NSText.copy(_:)), "c")
        item(edit, "Paste", #selector(NSText.paste(_:)), "v")
        item(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        item(edit, "Find…", #selector(focusFind), "f")
        item(edit, "Find Next", #selector(findNext), "g")
        let view = submenu("View")
        item(view, "Zoom In", #selector(zoomIn), "+")
        item(view, "Zoom Out", #selector(zoomOut), "-")
        item(view, "Actual Size", #selector(resetZoom), "0")
        let windowMenu = submenu("Window")
        item(windowMenu, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }

    @objc private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["md", "markdown", "mdown", "mkd", "txt"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = panel.url { self?.open(url) }
        }
    }

    private func open(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            fileURL = url.standardizedFileURL
            markdown = text
            assets.directory = url.deletingLastPathComponent().resolvingSymlinksInPath()
            window.title = url.lastPathComponent
            window.representedURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            loadPage()
            window.makeKeyAndOrderFront(nil)
        } catch { show(error) }
    }

    @objc private func reload() {
        guard let url = fileURL else { return }
        do {
            markdown = try String(contentsOf: url, encoding: .utf8)
            render(resetScroll: false)
        } catch { show(error) }
    }

    private func loadPage() {
        ready = false
        do {
            let page = try rendererPage.get()
            webView.loadHTMLString(page.html,
                                  baseURL: URL(string: "mv-local://document/"))
        } catch { show(error) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        render(resetScroll: true)
    }

    private func render(resetScroll: Bool) {
        guard ready else { return }
        webView.callAsyncJavaScript("window.renderMarkdown(markdown, resetScroll)",
                                    arguments: ["markdown": markdown, "resetScroll": resetScroll],
                                    in: nil, in: .page) { [weak self] result in
            if case let .failure(error) = result { self?.show(error) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "mv-local" {
            if url.path == "/", url.fragment != nil { decisionHandler(.allow); return }
            if let local = assets.fileURL(for: url) { open(local) }
        } else if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    @objc private func reveal() {
        if let fileURL { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) }
    }
    @objc private func focusFind() { window.makeFirstResponder(searchField) }
    @objc private func findNext() {
        guard !searchField.stringValue.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.wraps = true
        webView.find(searchField.stringValue, configuration: configuration) { result in
            if !result.matchFound { NSSound.beep() }
        }
    }
    @objc private func zoomIn() { webView.pageZoom = min(2.5, webView.pageZoom + 0.1) }
    @objc private func zoomOut() { webView.pageZoom = max(0.5, webView.pageZoom - 0.1) }
    @objc private func resetZoom() { webView.pageZoom = 1 }
    private func show(_ error: Error) { NSAlert(error: error).beginSheetModal(for: window) }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.init("open"), .init("reload"), .flexibleSpace, .init("find"), .init("smaller"), .init("larger")]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier.rawValue == "find" {
            item.label = "Find"
            searchField.frame.size = NSSize(width: 210, height: 24)
            item.view = searchField
        } else {
            let values: (String, String, Selector)
            switch identifier.rawValue {
            case "open": values = ("Open…", "folder", #selector(openPanel))
            case "reload": values = ("Reload", "arrow.clockwise", #selector(reload))
            case "smaller": values = ("Zoom Out", "textformat.size.smaller", #selector(zoomOut))
            default: values = ("Zoom In", "textformat.size.larger", #selector(zoomIn))
            }
            item.label = values.0
            item.toolTip = values.0
            item.image = NSImage(systemSymbolName: values.1, accessibilityDescription: values.0)
            item.target = self
            item.action = values.2
        }
        return item
    }
}
