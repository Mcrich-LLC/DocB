// The app's door to the store: a TCA dependency wrapping `Library` and `Discovery`, so reducers
// can be tested with canned data and the live app opens the shared library file.

import ComposableArchitecture
import DocBPage
import DocBRender
import DocBSources
import DocBStore
import DocCSchema
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A page ready for display, with what the window needs around it.
struct RenderedPage: Equatable, Sendable {
    var page: Page
    /// The symbol kind, or the role for non-symbols; drives `TopicIcon`.
    var kind: String
    /// The page as a browser would open it.
    var webURL: URL
    /// The canonical breadcrumb from the landing page down to this page's parent.
    var parents: [PageParent] = []
    /// The languages the page can be shown in, its own first.
    var languages: [String] = []

    var title: String { page.title }
}

struct PageParent: Equatable, Sendable {
    var title: String
    var kind: String
    var location: PageLocation
}

struct LibraryClient: Sendable {
    var sources: @Sendable () async throws -> [SourceRecord]
    var discover: @Sendable (URL) async throws -> [Source]
    var add: @Sendable (Source, _ offline: Bool) async throws -> Void
    var remove: @Sendable (Source) async throws -> Void
    var setOffline: @Sendable (Source, Bool) async throws -> Void
    var sync: @Sendable (_ only: Source?, _ force: Bool) -> AsyncThrowingStream<SyncEvent, any Error>
    var navigator: @Sendable (Source, _ language: String) async throws -> [NavigatorNode]
    var page: @Sendable (PageLocation, _ language: String) async throws -> RenderedPage
    /// An image's bytes by the reference a page wrote, resolved against the page's base.
    var asset: @Sendable (_ reference: String, _ base: URL) async throws -> Data
    var sourcesContaining: @Sendable (_ path: String) async throws -> [Source]
}

extension LibraryClient: DependencyKey {
    static let liveValue: LibraryClient = {
        let library = Result { try Library(path: try Library.defaultLocation()) }
        return LibraryClient(
            sources: { try await library.get().sources() },
            discover: { try await Discovery.discover($0) },
            add: { try await library.get().add($0, offline: $1) },
            remove: { try await library.get().remove($0) },
            setOffline: { try await library.get().setOffline($0, $1) },
            sync: { only, force in
                switch library {
                case .success(let library): library.sync(only: only, force: force)
                case .failure(let error): AsyncThrowingStream { $0.finish(throwing: error) }
                }
            },
            navigator: { try await library.get().navigator(for: $0, language: $1) },
            page: { location, language in
                let node = try await library.get().page(at: location, language: language)
                // Reference and web URL resolution only depend on the base, so any kind will do here.
                let resolver = Source(base: location.base, kind: .docc, title: "", languages: [])
                var parents: [PageParent] = []
                if case .reference(let hierarchy)? = node.hierarchyVariants.defaultValue, let path = hierarchy.paths.first {
                    for identifier in path {
                        guard let reference = node.references[identifier] as? TopicRenderReference,
                              let parent = resolver.location(for: reference.url) else { continue }
                        parents.append(PageParent(title: reference.title, kind: reference.role ?? reference.kind.rawValue, location: parent))
                    }
                }
                var page = Page(node: node)
                // The download's URL is relative to where the source's kind keeps its assets.
                if let download = page.download, let source = try await library.get().source(base: location.base) {
                    page.download?.url = source.assetURL(for: download.url).absoluteString
                }
                return RenderedPage(
                    page: page,
                    kind: page.symbolKind ?? page.role ?? "article",
                    webURL: resolver.webURL(for: location),
                    parents: parents,
                    languages: node.availableLanguages
                )
            },
            asset: { try await library.get().asset($0, base: $1) },
            sourcesContaining: { try await library.get().sources(containing: $0) }
        )
    }()

    static let testValue = LibraryClient(
        sources: unimplemented("LibraryClient.sources", placeholder: []),
        discover: unimplemented("LibraryClient.discover", placeholder: []),
        add: unimplemented("LibraryClient.add"),
        remove: unimplemented("LibraryClient.remove"),
        setOffline: unimplemented("LibraryClient.setOffline"),
        sync: unimplemented("LibraryClient.sync", placeholder: .finished()),
        navigator: unimplemented("LibraryClient.navigator", placeholder: []),
        page: unimplemented("LibraryClient.page", placeholder: RenderedPage(page: Page(title: ""), kind: "article", webURL: URL(string: "https://example.com")!)),
        asset: unimplemented("LibraryClient.asset", placeholder: Data()),
        sourcesContaining: unimplemented("LibraryClient.sourcesContaining", placeholder: [])
    )
}

extension DependencyValues {
    var library: LibraryClient {
        get { self[LibraryClient.self] }
        set { self[LibraryClient.self] = newValue }
    }
}

/// Opens a URL in the user's browser. Not the library's `openURL`: that one wraps SwiftUI's
/// completion handler, which LaunchServices calls off the main thread, in a main-actor closure,
/// and Swift 6's isolation check traps on it.
extension DependencyValues {
    var openExternalURL: @Sendable (URL) async -> Void {
        get { self[OpenExternalURLKey.self] }
        set { self[OpenExternalURLKey.self] = newValue }
    }
}

private enum OpenExternalURLKey: DependencyKey {
    static let liveValue: @Sendable (URL) async -> Void = { url in
        await MainActor.run { () -> Void in
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
    static let testValue: @Sendable (URL) async -> Void = { _ in
        reportIssue(#"Unimplemented: @Dependency(\.openExternalURL)"#)
    }
}
