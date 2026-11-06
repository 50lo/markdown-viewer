import ProjectDescription

let project = Project(
    name: "MarkdownViewer",
    targets: [
        .target(
            name: "MarkdownViewer",
            destinations: .macOS,
            product: .app,
            bundleId: "local.personal.MarkdownViewer",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Markdown Viewer",
                "LSApplicationCategoryType": "public.app-category.utilities",
                "CFBundleDocumentTypes": [[
                    "CFBundleTypeName": "Markdown document",
                    "CFBundleTypeRole": "Viewer",
                    "LSHandlerRank": "Alternate",
                    "CFBundleTypeExtensions": ["md", "markdown", "mdown", "mkd", "txt"]
                ]],
                "NSPrincipalClass": "NSApplication",
                "LSMinimumSystemVersion": "26.0"
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "CODE_SIGN_IDENTITY": "-",
                "CODE_SIGN_STYLE": "Manual",
                "ENABLE_APP_SANDBOX": "NO",
                "ENABLE_HARDENED_RUNTIME": "NO",
                "GENERATE_INFOPLIST_FILE": "NO"
            ])
        ),
        .target(
            name: "MarkdownViewerTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "local.personal.MarkdownViewerTests",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .default,
            sources: ["Tests/*.swift", "Sources/LocalAssets.swift", "Sources/RendererPage.swift"],
            resources: ["Resources/**", "Tests/fixture.md", "Tests/fixture.svg"],
            settings: .settings(base: ["SWIFT_VERSION": "6.0", "CODE_SIGN_IDENTITY": "-", "CODE_SIGN_STYLE": "Manual"])
        )
    ]
)
