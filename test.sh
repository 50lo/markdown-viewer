#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
tuist generate --no-open
xcodebuild -quiet -workspace MarkdownViewer.xcworkspace -scheme MarkdownViewer \
  -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath build build-for-testing
# Run directly: this also avoids an Xcode 27 test-launcher issue on this Mac.
"$(xcode-select -p)/usr/bin/xctest" build/Build/Products/Debug/MarkdownViewerTests.xctest
