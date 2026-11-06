import Foundation

/// Load once at launch. A running app's Bundle URLs can become stale if it is moved.
struct RendererPage {
    let html: String

    init(bundle: Bundle) throws {
        func read(_ name: String, extension ext: String) throws -> String {
            guard let url = bundle.url(forResource: name, withExtension: ext) else {
                throw NSError(domain: "MarkdownViewer.Resources", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "The app is missing its bundled \(name).\(ext) resource. Please rebuild or replace the app."
                ])
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
        let template = try read("viewer", extension: "html")
        let parser = try read("markdown-it.min", extension: "js")
        html = template.replacingOccurrences(of: "/* MARKDOWN_PARSER */", with: parser)
    }
}
