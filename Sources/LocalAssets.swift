import AppKit
import WebKit
import UniformTypeIdentifiers

/// Serves relative images from the open document's folder without an HTTP server.
@MainActor
final class LocalAssets: NSObject, WKURLSchemeHandler {
    var directory: URL?

    func fileURL(for url: URL) -> URL? {
        guard url.scheme == "mv-local", url.host == "document", let directory else { return nil }
        let file = directory.appendingPathComponent(url.path).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(directory.path + "/") else { return nil }
        return file
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        do {
            guard let url = urlSchemeTask.request.url, let file = fileURL(for: url) else {
                throw CocoaError(.fileReadNoPermission)
            }
            let data = try Data(contentsOf: file)
            let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            urlSchemeTask.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch { urlSchemeTask.didFailWithError(error) }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

@MainActor
final class DropWebView: WKWebView {
    var onDrop: ((URL) -> Void)?
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url = urls.first else { return false }
        onDrop?(url)
        return true
    }
}
