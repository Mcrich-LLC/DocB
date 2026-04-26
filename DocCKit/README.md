# DocCKit

DocCKit is a SwiftUI package for loading, parsing, and rendering DocC-style JSON.

DocCKit is the backbone of [DocB](https://github.com/Mcrich-LLC/DocB). DocB uses it for the heavy lifting around DocC loading, parsing, navigation handoff, and SwiftUI rendering, while the app keeps the things that make it an app, like bookmarks, persistence, settings, and window behavior.

If you want to see a full app built on top of DocCKit, DocB is the best example. If you want the package by itself, you can use it for full DocC archives, Apple Developer Documentation, or just a single JSON file that happens to use the DocC article structure.

## Requirements
- Xcode 16 or newer
- Swift 6.2 or newer

### Minimum Targets:
- iOS 18
- macOS 15
- visionOS 2

## Installing The Package

### Xcode

Go to **File** > **Add Package Dependencies...** and paste in:

```
https://github.com/Mcrich-LLC/DocCKit.git
```

Then add the `DocCKit` product to your app target.

### Swift Package Manager

Add this to the `dependencies` section of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Mcrich-LLC/DocCKit.git", branch: "main")
]
```

Then add `DocCKit` to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            "DocCKit"
        ]
    )
]
```

## Basic Setup

DocCKit renderers need a navigator. This is where you keep your selected article, selected framework, split-view state, and deep link scheme.

Here is a small example:

```swift
import SwiftUI
import DocCKit

@Observable
@MainActor
final class DocumentationNavigator: DocCNavigator {
    var reference: Reference?
    var technology: AppleTechnologies.FrameworkSection?
    var isUsingSplitView = false

    // By default this tries to read the app's Info.plist URL schemes.
    // You can also make it explicit:
    var deepLinkScheme = DocCDeepLinkScheme("my-app-docs")

    func setReference(_ reference: Reference?, forceHistory: Bool) {
        self.reference = reference
    }

    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?, noHistory: Bool) {
        self.technology = technology
    }

    func showHomepage() {
        reference = nil
        technology = nil
    }
}
```

> Note: `DocCNavigator` does not include bookmarks, window management, SwiftData, onboarding, or any of DocB's app-specific history internals. That part belongs in your app, either in this class or a different one.

## Deep Links

DocCKit creates local documentation links from DocC identifiers such as:

```
doc://example/documentation/MyKit/MyType
```

For those links to loop back into your app, your app should register a URL scheme in its Info.plist.

DocCKit will try to find a scheme in this order:

1. `DocCKitDeepLinkScheme` in your Info.plist.
2. `DocCDeepLinkScheme` in your Info.plist.
3. A `CFBundleURLTypes` entry matching your bundle identifier.
4. The first registered URL scheme that is not `doc`.
5. `doc://` as a fallback.

You can also configure it manually in your navigator:

```swift
var deepLinkScheme = DocCDeepLinkScheme("my-app-docs")
```

If your app's URL scheme is `my-app-docs`, DocCKit will turn:

```
doc://example/documentation/MyKit/MyType
```

into:

```
my-app-docs://example/documentation/MyKit/MyType
```

## Rendering Apple Developer Documentation

If you want to render Apple docs, use `AppleDocsClient`.

```swift
import SwiftUI
import DocCKit

struct AppleArticleExample: View {
    @State private var article: Article?
    @State private var navigator = DocumentationNavigator()

    let identifier = "doc://com.apple.documentation/documentation/swift/string"

    var body: some View {
        Group {
            if let article {
                DocCArticleView(article: article, navigator: navigator, identifier: identifier)
            } else {
                ProgressView("Loading")
            }
        }
        .task {
            do {
                article = try await AppleDocsClient().fetchArticle(for: identifier)
            } catch {
                print(error)
            }
        }
    }
}
```

If you want Objective-C variants where Apple provides them:

```swift
let client = AppleDocsClient(preferredLanguage: .objectivec)
let article = try await client.fetchArticle(for: identifier)
```

## Rendering A Custom DocC Archive

For a normal DocC archive or static DocC website, use `DocCClient`.

```swift
let baseURL = URL(string: "https://example.com/MyDocs")!
let client = try await DocCClient(baseURL: baseURL)
let page = try await client.fetchArticlePage(
    for: "doc://example/documentation/MyKit/MyType"
)
```

Then render it:

```swift
DocCArticleView(page: page, navigator: navigator)
```

`DocCClient` keeps the resolved `DocCSource` on `client.source`, so if your app wants to persist the index or build custom navigation around it, you can still grab the source directly:

```swift
let source = client.source
let frameworkSections = source.allFrameworkSections
```

If you already have a stored `DocCSource`, rebuild the client from that:

```swift
let client = DocCClient(source: storedSource)
let article = try await client.fetchArticle(
    for: "doc://example/documentation/MyKit/MyType"
)
```

The low-level helpers are still available without creating a client:

```swift
let index = try await DocCClient.fetchIndex(baseURL: baseURL)
let jsonURL = DocCClient.jsonURL(
    for: "doc://example/documentation/MyKit/MyType",
    source: source
)
```

You can still pass a full `Reference` if your app already has one from a DocC index or wants to preserve extra reference metadata:

```swift
DocCArticleView(article: article, reference: reference, navigator: navigator)
```

## Pulling One File

You do not need a full DocC archive to use DocCKit.

If you just want a nice rich article view in your app, you can host or bundle a single JSON file that matches DocC's `Article` shape. This is useful for things like:

- Release notes
- Help pages
- "What's New" screens
- App guides
- Terms written as structured content
- Any non-documentation content where DocC's article layout happens to be useful

### Remote JSON

```swift
struct RemoteArticleView: View {
    @State private var article: Article?
    @State private var navigator = DocumentationNavigator()

    let articleURL = URL(string: "https://example.com/app-guide.json")!

    var body: some View {
        Group {
            if let article {
                DocCArticleView(
                    article: article,
                    navigator: navigator,
                    identifier: "doc://my-app/app-guide"
                )
            } else {
                ProgressView("Loading")
            }
        }
        .task {
            do {
                let (data, _) = try await URLSession.shared.data(from: articleURL)
                article = try JSONDecoder().decode(Article.self, from: data)
            } catch {
                print(error)
            }
        }
    }
}
```

### Bundled JSON

Add `app-guide.json` to your app target, then decode it:

```swift
func bundledArticle(named name: String) throws -> Article {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
        throw URLError(.fileDoesNotExist)
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Article.self, from: data)
}
```

Then render it the same way:

```swift
let article = try bundledArticle(named: "app-guide")

DocCArticleView(
    article: article,
    navigator: navigator,
    identifier: "doc://my-app/app-guide"
)
```

### A Small Article JSON Example

This is intentionally small. Real DocC JSON can be much larger, but this is enough to render a simple page.

```json
{
    "metadata": {
        "role": "article",
        "roleHeading": "Guide",
        "title": "Using My App"
    },
    "references": {},
    "primaryContentSections": [
        {
            "kind": "content",
            "content": [
                {
                    "type": "heading",
                    "level": 2,
                    "text": "Getting Started"
                },
                {
                    "type": "paragraph",
                    "inlineContent": [
                        {
                            "type": "text",
                            "text": "This screen is powered by DocCKit, but the content does not have to be about documentation."
                        }
                    ]
                }
            ]
        }
    ]
}
```

## Rendering A Homepage

If you would like Apple's Documentation homepage payload:

```swift
let homepage = try await AppleDocsClient().fetchHomepage()

DocCHomepageView(homepage: homepage, navigator: navigator)
```

For a manually hosted homepage JSON file:

```swift
let (data, _) = try await URLSession.shared.data(from: homepageURL)
let homepage = try JSONDecoder().decode(HomepageParser.self, from: data)
```

## Rendering A Framework Page

Framework pages need both a decoded `Framework` and the `AppleTechnologies.FrameworkSection` that represents it in navigation.

For a custom DocC source, the page API builds that context for you:

```swift
let client = try await DocCClient(baseURL: baseURL)
let page = try await client.fetchFrameworkPage(
    for: "doc://example/documentation/MyKit"
)

DocCFrameworkView(page: page, navigator: navigator)
```

For Apple docs, fetch the framework and pass the section your app selected from the technologies payload:

```swift
let framework = try await AppleDocsClient().fetchFramework(
    for: "doc://com.apple.documentation/documentation/swiftui"
)

DocCFrameworkView(
    framework: framework,
    frameworkSection: frameworkSection,
    navigator: navigator
)
```

If you are rendering a single article or app guide, you probably do not need framework pages.

## Using DocCClientBridge

If your app can open both Apple docs and custom DocC sources, `DocCClientBridge` lets you avoid branching all over your code.

```swift
let client: DocCClientBridge

if let source {
    client = .docC(source)
} else {
    client = .apple(preferredLanguage: .swift)
}

let article = try await client.fetchArticle(for: reference.identifier)
```

## What DocCKit Does Not Do

DocCKit is not trying to be a full app.

It does not provide:

- Bookmark persistence
- SwiftData models
- Window management
- Search UI
- App settings
- Onboarding
- A full browser-style navigation history

It gives you the loading/parsing/rendering pieces. Your app decides how those pieces are presented and stored.
