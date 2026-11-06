# Markdown Viewer

A small native macOS 26+ Markdown reader: AppKit window, WKWebView, and a bundled markdown-it parser. No server, package installation, accounts, or runtime CDN dependencies.

## Build and run

Requires macOS 26 or later, full Xcode with the macOS SDK (not just Command Line Tools), and Tuist available on your PATH. Open Xcode once to complete its first-launch setup. Check that `xcode-select -p` points inside your Xcode installation and that `tuist version` works.

Clone the private repository using a GitHub account with access, then build:

```sh
git clone https://github.com/50lo/markdown-viewer.git
cd markdown-viewer
./build.sh
open build/Build/Products/Release/MarkdownViewer.app
```

The scripts generate the Xcode workspace from `Project.swift`; generated projects, caches, and build outputs are intentionally not committed. The parser and its license are bundled, so no QW checkout or JavaScript package installation is needed.

Or run `tuist generate` and build the MarkdownViewer scheme in Xcode. The build is locally ad-hoc signed; it requires no development team, notarization, or App Store setup. Copy the built app to Applications if desired.

## Use

- **⌘O** opens a UTF-8 Markdown/text file. Finder “Open With” and file drops work too.
- **⌘R** reloads from disk, preserving the scroll position. Changes are not watched automatically.
- **⌘F** focuses search; Return or **⌘G** finds the next match, wrapping at the end.
- **⌘+**, **⌘−**, and **⌘0** zoom in, out, and reset.
- File → Reveal in Finder locates the current document.

One document/window at a time. System appearance controls light/dark mode. Supports tables, task lists, fenced code, heading anchors, and images. Web links open in the default browser; relative document links open in this viewer. Relative assets must be inside the document's folder (or a child folder); parent-folder references and symlinks escaping that folder are blocked. Remote HTTP(S) images can load when a document references them.

Raw HTML is displayed as text. No syntax highlighting, Mermaid, math extensions, editing, or streaming logic.

## Modify

- `Sources/AppDelegate.swift`: window, toolbar, menus, file loading, WebKit bridge.
- `Sources/LocalAssets.swift`: local image loading and file drops.
- `Sources/RendererPage.swift`: loads bundled HTML and JavaScript once, so moving the running app does not invalidate its renderer.
- `Resources/viewer.html`: all document styles and rendering behavior.
- `Project.swift`: Tuist build configuration.

The QW summary viewer informed the bundled parser, light/dark styles, and native-to-web bridge. The app uses a new, smaller template and no QW app code. The vendored markdown-it 14.1.0 file is MIT licensed; see `Resources/markdown-it.LICENSE.txt`.

## Validation

```sh
./test.sh
```

The focused tests use real WKWebView rendering to check Unicode, tables, task lists, anchors, local images, content replacement, search, and inert raw HTML. They also check local asset path boundaries and moving the resource bundle after launch. `Tests/fixture.md` is a manual smoke-test document.

On this Mac, Xcode 27’s `xcodebuild test` launcher failed to load the otherwise valid test bundle. `test.sh` builds it with Xcode and runs it directly with XCTest; all three tests pass.
