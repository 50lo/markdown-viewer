#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
tuist generate --no-open
xcodebuild -workspace MarkdownViewer.xcworkspace -scheme MarkdownViewer \
  -configuration Release -destination "generic/platform=macOS" -derivedDataPath build build
print "App: $PWD/build/Build/Products/Release/MarkdownViewer.app"
