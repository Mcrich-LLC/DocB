// The reader: a history of routes (home or a page) with a cursor, the page at the cursor, and
// the sidebar, which lists sources at home and one source's tree on a page. Every way of
// navigating (sidebar, link, back, forward, home) reduces to `navigate`. Each window has its
// own reader; the first one shows its sidebar, one opened for a link starts without.

import ComposableArchitecture
import DocBRender
import DocBSources
import DocBStore
import Foundation
import OSLog
import SwiftUI

/// Where the reader can be.
enum Route: Equatable, Hashable {
    case home
    case page(PageLocation)

    var location: PageLocation? {
        if case .page(let location) = self { return location }
        return nil
    }
}

@Reducer
struct ReaderFeature {
    /// The reader of the window that opens at launch.
    static let mainID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        var sources: [SourceRecord] = []
        var history: [Route] = [.home]
        var index = 0
        var page: Page = .home
        /// The interface language, for the page and the sidebar; a page without it shows as authored.
        var language = "swift"
        /// The languages the page on show can be read in; the picker offers these.
        var languages: [String] {
            if case .loaded(_, let page) = page, !page.languages.isEmpty { return page.languages }
            return [language]
        }

        /// The language the page is actually shown in: the chosen one when the page has it,
        /// else the page's own.
        var shownLanguage: String {
            if languages.contains(language) { return language }
            if case .loaded(_, let page) = page { return page.page.language ?? languages[0] }
            return languages[0]
        }
        var sidebar = SidebarFeature.State()
        var columnVisibility: NavigationSplitViewVisibility = .all
        /// Set when the current page belongs to a module no library source lists.
        var missingModule: String?
        /// A source picked at home whose root is found once the sidebar has its tree.
        var pendingRoot: Source?
        @Presents var alert: AlertState<Never>?

        init(id: UUID = ReaderFeature.mainID, route: Route = .home, sources: [SourceRecord] = [], showsSidebar: Bool = true, sidebar: SidebarFeature.State = SidebarFeature.State()) {
            self.id = id
            self.sources = sources
            self.sidebar = sidebar
            history = [route]
            page = route.location.map { .loading($0) } ?? .home
            columnVisibility = showsSidebar ? .all : .detailOnly
        }

        /// Title and kind of every page seen this session, for labeling history entries.
        var headings: [PageLocation: Heading] = [:]

        struct Heading: Equatable {
            var title: String
            var kind: String
            var badge: Badge? = nil
        }

        var current: Route { history[index] }
        var canGoBack: Bool { index > 0 }
        var canGoForward: Bool { index < history.count - 1 }

        func heading(for route: Route) -> Heading {
            guard let location = route.location else { return Heading(title: "Home", kind: "home") }
            let heading = headings[location] ?? Heading(title: String(location.path.split(separator: "/").last ?? ""), kind: "article")
            return Heading(title: heading.title, kind: kind(of: location, fallback: heading.kind), badge: sidebar.badge(forPath: location.path) ?? heading.badge)
        }

        /// The icon type for a page: the navigator's, so every context shows the sidebar's
        /// icon; a page's own metadata only stands in when no loaded tree lists the page.
        func kind(of location: PageLocation, fallback: String) -> String {
            sidebar.type(forPath: location.path) ?? fallback
        }

        /// The current page and its ancestors, for the title bar's path menu.
        var pathEntries: [PathEntry] {
            guard case .loaded(let location, let page) = self.page else { return [] }
            return [PathEntry(title: page.title, kind: kind(of: location, fallback: page.kind), location: nil)]
                + page.parents.reversed().map { PathEntry(title: $0.title, kind: kind(of: $0.location, fallback: $0.kind), location: $0.location) }
        }

        struct PathEntry: Equatable {
            var title: String
            var kind: String
            var location: PageLocation?
        }

        enum Page: Equatable {
            case home
            case loading(PageLocation)
            case loaded(PageLocation, RenderedPage)
            case failed(PageLocation, String)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case sourcesLoaded([SourceRecord])
        case sourcePicked(Source)
        case rootResolved(Source, PageLocation?)
        case navigate(Route)
        case back
        case forward
        /// Moves the cursor to a history entry, from the back or forward jump lists.
        case jump(Int)
        /// A link in the page: the reference as the payload wrote it, for `Source.location(for:)`.
        case linkTapped(String)
        case pageLoaded(PageLocation, Result<RenderedPage, any Error>)
        case sidebarSourceResolved(PageLocation, [Source])
        case sidebar(SidebarFeature.Action)
        case alert(PresentationAction<Never>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            /// Asks for a new window, with this id, showing the page.
            case openInNewWindow(id: UUID, PageLocation)
        }
    }

    @Dependency(\.library) var library
    @Dependency(\.openExternalURL) var openURL

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.sidebar, action: \.sidebar) { SidebarFeature() }
        Reduce { state, action in
            switch action {
            case .binding(\.language):
                // The page again in the new language, and the tree to match; history stays as it is.
                guard let source = state.sidebar.source else { return show(state.current, state: &state) }
                return .merge(show(state.current, state: &state), .send(.sidebar(.load(source, language: state.language))))

            case .binding:
                return .none

            case .task:
                let load: Effect<Action> = .run { send in
                    await send(.sourcesLoaded(try await library.sources()))
                } catch: { error, send in
                    await send(.sidebar(.delegate(.failed(String(describing: error)))))
                }
                // A window opened for a page starts on it.
                if case .loading = state.page { return .merge(load, show(state.current, state: &state)) }
                return load

            case .sourcesLoaded(let sources):
                state.sources = sources
                return .none

            case .sourcePicked(let source):
                // The sidebar switches to the source at once, so the old tree never shows on the way.
                let load: Effect<Action> = .send(.sidebar(.load(source, language: state.language)))
                switch source.kind {
                case .appleDeveloper(let module):
                    return .merge(load, .send(.rootResolved(source, PageLocation(base: source.base, path: "documentation/\(module)"))))
                case .doccWithoutIndex(let root):
                    return .merge(load, .send(.rootResolved(source, PageLocation(base: source.base, path: root))))
                case .docc:
                    // The root is the tree's first page; the sidebar's own load finds it.
                    state.pendingRoot = source
                    return load
                }

            case .sidebar(.treeLoaded(let source, .success(let loaded))) where source == state.pendingRoot:
                state.pendingRoot = nil
                return .send(.rootResolved(source, firstLocation(in: loaded.tree)))

            case .sidebar(.treeLoaded(let source, .failure)) where source == state.pendingRoot:
                state.pendingRoot = nil
                return .none

            case .rootResolved(let source, let location):
                guard let location else {
                    state.alert = AlertState { TextState("Nothing to show") } message: { TextState("\(source.title) has no pages in its navigator.") }
                    return .none
                }
                return .send(.navigate(.page(location)))

            case .navigate(let route):
                if state.current == route { return .none }
                state.history.removeSubrange((state.index + 1)...)
                state.history.append(route)
                state.index = state.history.count - 1
                return show(route, state: &state)

            case .back:
                guard state.canGoBack else { return .none }
                state.index -= 1
                return show(state.current, state: &state)

            case .forward:
                guard state.canGoForward else { return .none }
                state.index += 1
                return show(state.current, state: &state)

            case .jump(let index):
                guard state.history.indices.contains(index), index != state.index else { return .none }
                state.index = index
                return show(state.current, state: &state)

            case .linkTapped(let reference):
                let current = String(describing: state.current)
                Logger(subsystem: "DocB", category: "click").notice("linkTapped \(reference, privacy: .public) current=\(current, privacy: .public)")
                guard let current = state.current.location,
                      let source = state.sources.first(where: { $0.source.base == current.base })?.source else { return .none }
                if let location = source.location(for: reference) {
                    return .send(.navigate(.page(location)))
                }
                return .run { _ in
                    if let external = URL(string: reference) { await openURL(external) }
                }

            case .pageLoaded(let location, .success(let page)):
                state.headings[location] = State.Heading(title: page.title, kind: page.kind, badge: page.page.badge)
                guard state.current.location == location else { return .none }
                state.page = .loaded(location, page)
                return .none

            case .pageLoaded(let location, .failure(let error)):
                guard state.current.location == location else { return .none }
                state.page = .failed(location, String(describing: error))
                return .none

            case .sidebarSourceResolved(let location, let listing):
                guard state.current.location == location else { return .none }
                state.missingModule = nil
                if let current = state.sidebar.source, listing.contains(current) {
                    return .send(.sidebar(.select(location)))
                }
                if let source = listing.first {
                    return .concatenate(
                        .send(.sidebar(.select(location))),
                        .send(.sidebar(.load(source, language: state.language)))
                    )
                }
                // Reachable through a link but not in the library: keep the current tree, say so.
                let components = location.path.split(separator: "/")
                if components.count >= 2, components[0] == "documentation" {
                    state.missingModule = String(components[1])
                }
                return .send(.sidebar(.select(nil)))

            case .sidebar(.delegate(.open(let location))):
                return .send(.navigate(.page(location)))

            case .sidebar(.delegate(.openInNewWindow(let id, let location))):
                return .send(.delegate(.openInNewWindow(id: id, location)))

            case .sidebar(.delegate(.failed(let message))):
                state.alert = AlertState { TextState("Something went wrong") } message: { TextState(message) }
                return .none

            case .sidebar, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Shows a route: home, or a page plus whichever source's tree the sidebar should show.
    private func show(_ route: Route, state: inout State) -> Effect<Action> {
        switch route {
        case .home:
            state.page = .home
            state.missingModule = nil
            return .send(.sidebar(.select(nil)))
        case .page(let location):
            state.page = .loading(location)
            let language = state.language
            return .merge(
                .run { send in
                    await send(.pageLoaded(location, Result { try await library.page(location, language) }))
                },
                .run { send in
                    let listing = try await library.sourcesContaining(location.path)
                    await send(.sidebarSourceResolved(location, listing.filter { $0.base == location.base }))
                } catch: { _, send in
                    await send(.sidebarSourceResolved(location, []))
                }
            )
        }
    }
}

/// The first node with a location, depth first.
func firstLocation(in nodes: [NavigatorNode]) -> PageLocation? {
    for node in nodes {
        if let location = node.location { return location }
        if let location = firstLocation(in: node.children) { return location }
    }
    return nil
}
