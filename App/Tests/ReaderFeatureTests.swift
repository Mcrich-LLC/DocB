// Reducer tests for the reader: history and cursor, link resolution, which tree the sidebar
// shows, the missing-module case, and sidebar row flattening with expansion and filter.

import ComposableArchitecture
import DocBSources
import DocBStore
import DocBPage
import Foundation
import Testing
@testable import DocB

@Suite @MainActor struct ReaderFeatureTests {
    let base = URL(string: "https://example.com")!
    var foundation: Source { Source(base: base, kind: .appleDeveloper(module: "foundation"), title: "Foundation", languages: ["swift"]) }
    var objc: Source { Source(base: base, kind: .appleDeveloper(module: "objectivec"), title: "ObjectiveC", languages: ["swift"]) }
    nonisolated func record(_ source: Source) -> SourceRecord { SourceRecord(source: source, offline: false, indexSyncedAt: nil, addedAt: .distantPast, fetchedPages: 0, pendingPages: 0) }
    nonisolated func location(_ path: String) -> PageLocation { PageLocation(base: base, path: path) }
    nonisolated func page(_ title: String) -> RenderedPage { RenderedPage(page: Page(title: title), kind: "article", webURL: base) }

    nonisolated func tree() -> [NavigatorNode] {
        [NavigatorNode(id: 1, title: "Foundation", location: location("documentation/foundation"), type: "module", children: [
            NavigatorNode(id: 2, title: "Essentials", location: nil, type: "groupMarker"),
            NavigatorNode(id: 3, title: "URLSession", location: location("documentation/foundation/urlsession"), type: "class", children: [
                NavigatorNode(id: 4, title: "dataTask(with:)", location: location("documentation/foundation/urlsession/datatask(with:)"), type: "method"),
            ]),
            NavigatorNode(id: 5, title: "NSInteger", location: location("documentation/objectivec/nsinteger"), type: "typealias"),
        ])]
    }

    @Test func launchLandsAtHomeAndPickingASourceOpensItsRoot() async {
        let foundation = foundation
        let tree = tree()
        let store = TestStore(initialState: ReaderFeature.State()) {
            ReaderFeature()
        } withDependencies: {
            $0.library.sources = { [self.record(foundation)] }
            $0.library.page = { location, _ in self.page(location.path) }
            $0.library.sourcesContaining = { _ in [foundation] }
            $0.library.navigator = { _, _ in tree }
        }
        await store.send(.task)
        await store.receive(\.sourcesLoaded) { $0.sources = [self.record(foundation)] }
        #expect(store.state.current == .home && store.state.page == .home)
        store.exhaustivity = .off
        await store.send(.sourcePicked(foundation))
        await store.receive(\.navigate) {
            $0.history = [.home, .page(self.location("documentation/foundation"))]
            $0.index = 1
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.page == .loaded(location("documentation/foundation"), page("documentation/foundation")))
        #expect(store.state.sidebar.source == foundation)
        #expect(store.state.sidebar.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "NSInteger"])
        #expect(store.state.sidebar.rows[0].isSelected)
    }

    @Test func pickingALanguageShowsThePageAndTheTreeInIt() async {
        let foundation = foundation
        let tree = tree()
        let requested = LockIsolated<[String]>([])
        let store = TestStore(initialState: ReaderFeature.State(sources: [record(foundation)], sidebar: SidebarFeature.State(source: foundation))) {
            ReaderFeature()
        } withDependencies: {
            $0.library.page = { location, language in
                requested.withValue { $0.append(language) }
                var page = self.page(location.path)
                page.languages = ["occ", "swift"]
                page.page.title = language
                return page
            }
            $0.library.sourcesContaining = { _ in [foundation] }
            $0.library.navigator = { _, language in
                requested.withValue { $0.append("tree:" + language) }
                return tree
            }
        }
        store.exhaustivity = .off
        await store.send(.navigate(.page(location("documentation/foundation"))))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.languages == ["occ", "swift"] && store.state.shownLanguage == "swift")
        let history = store.state.history
        await store.send(.binding(.set(\.language, "occ"))) { $0.language = "occ" }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.shownLanguage == "occ")
        if case .loaded(_, let page) = store.state.page { #expect(page.page.title == "occ") } else { Issue.record("no page") }
        #expect(store.state.history == history, "a language change is not a navigation")
        #expect(requested.value.contains("occ") && requested.value.contains("tree:occ"))
    }

    @Test func backAndForwardMoveTheCursorWithoutGrowingHistory() async {
        let foundation = foundation
        let store = TestStore(initialState: ReaderFeature.State(sources: [record(foundation)], sidebar: SidebarFeature.State(source: foundation))) {
            ReaderFeature()
        } withDependencies: {
            $0.library.page = { location, _ in self.page(location.path) }
            $0.library.sourcesContaining = { _ in [foundation] }
        }
        store.exhaustivity = .off
        await store.send(.navigate(.page(location("a")))) { $0.history = [.home, .page(self.location("a"))]; $0.index = 1 }
        await store.send(.navigate(.page(location("b")))) { $0.history = [.home, .page(self.location("a")), .page(self.location("b"))]; $0.index = 2 }
        await store.send(.back) { $0.index = 1 }
        await store.send(.forward) { $0.index = 2 }
        await store.send(.back) { $0.index = 1 }
        await store.send(.navigate(.page(location("c")))) { $0.history = [.home, .page(self.location("a")), .page(self.location("c"))]; $0.index = 2 }
        await store.send(.forward)
        await store.send(.navigate(.home)) { $0.history = [.home, .page(self.location("a")), .page(self.location("c")), .home]; $0.index = 3; $0.page = .home }
        await store.send(.back) { $0.index = 2 }
        await store.send(.jump(0)) { $0.index = 0; $0.page = .home }
        await store.send(.jump(9))
        await store.send(.jump(2)) { $0.index = 2 }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.page == .loaded(location("c"), page("c")))
        #expect(store.state.history.map { store.state.heading(for: $0).title } == ["Home", "a", "c", "Home"])
        #expect(store.state.heading(for: .home).kind == "home" && store.state.heading(for: .page(location("c"))).kind == "article")
    }

    @Test func linksResolveOnTheCurrentBaseAndExternalOnesOpenOutside() async {
        let foundation = foundation
        let opened = LockIsolated<[URL]>([])
        var initial = ReaderFeature.State(sources: [record(foundation)], sidebar: SidebarFeature.State(source: foundation))
        initial.history = [.home, .page(location("documentation/foundation"))]
        initial.index = 1
        let store = TestStore(initialState: initial) {
            ReaderFeature()
        } withDependencies: {
            $0.library.page = { location, _ in self.page(location.path) }
            $0.library.sourcesContaining = { _ in [foundation] }
            $0.openExternalURL = { url in opened.withValue { $0.append(url) } }
        }
        store.exhaustivity = .off
        await store.send(.linkTapped("doc://com.example/documentation/Foundation/URLSession#Overview"))
        await store.receive(\.navigate) {
            $0.history = [.home, .page(self.location("documentation/foundation")), .page(PageLocation(base: self.base, path: "documentation/foundation/urlsession", fragment: "Overview"))]
            $0.index = 2
        }
        await store.send(.linkTapped("https://elsewhere.example.com/x"))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(opened.value == [URL(string: "https://elsewhere.example.com/x")!])
    }

    @Test func sidebarSwitchesToTheSourceThatListsThePageOrReportsAMissingModule() async {
        let (foundation, objc) = (foundation, objc)
        let store = TestStore(initialState: ReaderFeature.State(sources: [record(foundation), record(objc)], sidebar: SidebarFeature.State(source: foundation))) {
            ReaderFeature()
        } withDependencies: {
            $0.library.page = { location, _ in self.page(location.path) }
            $0.library.sourcesContaining = { path in path.hasPrefix("documentation/objectivec") ? [objc] : [] }
            $0.library.navigator = { _, _ in [] }
        }
        store.exhaustivity = .off
        await store.send(.navigate(.page(location("documentation/objectivec/nsobject"))))
        await store.receive(\.sidebarSourceResolved)
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.sidebar.source == objc)
        #expect(store.state.missingModule == nil)

        await store.send(.navigate(.page(location("documentation/uikit/uiview"))))
        await store.receive(\.sidebarSourceResolved) {
            $0.missingModule = "uikit"
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.sidebar.source == objc)
    }

    @Test func rowsFollowExpansionSelectionAndFilter() async {
        let foundation = foundation
        let tree = tree()
        let store = TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature()
        } withDependencies: {
            $0.library.navigator = { _, _ in tree }
        }
        await store.send(.load(foundation, language: "swift")) {
            $0.source = foundation
            $0.isLoading = true
        }
        store.exhaustivity = .off
        await store.receive(\.treeLoaded)
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "NSInteger"])

        await store.send(.toggled(3))
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "dataTask(with:)", "NSInteger"])
        #expect(store.state.rows[2].isExpanded)

        await store.send(.toggled(3))
        await store.send(.select(location("documentation/foundation/urlsession/datatask(with:)")))
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "dataTask(with:)", "NSInteger"])
        #expect(store.state.rows.first { $0.isSelected }?.title == "dataTask(with:)")

        // A filter walks the whole tree, so it is built off the main actor and lands as an action.
        await store.send(\.binding.filter, "task")
        await store.receive(\.rowsBuilt)
        #expect(store.state.rows.map(\.title) == ["Foundation", "URLSession", "dataTask(with:)"])

        await store.send(.rowTapped(store.state.rows[2]))
        await store.receive(\.delegate.open)
    }

    @Test func pickingASourceSwitchesTheSidebarBeforeItsTreeArrives() async {
        // A DocC archive's root is its tree's first page, so the sidebar's load resolves it.
        let foundation = Source(base: base, kind: .docc, title: "Foundation", languages: ["swift"])
        let objc = objc
        let tree = tree()
        let store = TestStore(initialState: ReaderFeature.State(sources: [record(foundation), record(objc)], sidebar: SidebarFeature.State(source: objc, tree: tree, rows: [SidebarFeature.State.Row(id: 9, depth: 0, title: "Old", location: nil, type: "module", hasChildren: false, isExpanded: false, isSelected: false, isExternal: false)]))) {
            ReaderFeature()
        } withDependencies: {
            $0.library.page = { location, _ in self.page(location.path) }
            $0.library.sourcesContaining = { _ in [foundation] }
            $0.library.navigator = { _, _ in tree }
        }
        store.exhaustivity = .off
        await store.send(.sourcePicked(foundation)) { $0.pendingRoot = foundation }
        // The sidebar is already the new source's, empty while loading; nothing of the old tree shows.
        await store.receive(\.sidebar.load) {
            $0.sidebar.source = foundation
            $0.sidebar.isLoading = true
            $0.sidebar.tree = []
            $0.sidebar.rows = []
        }
        await store.receive(\.sidebar.treeLoaded)
        await store.receive(\.rootResolved) { $0.pendingRoot = nil }
        await store.receive(\.navigate) { $0.history = [.home, .page(self.location("documentation/foundation"))]; $0.index = 1 }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.sidebar.rows.first?.title == "Foundation")
    }

    @Test func historyAndPathIconsComeFromTheNavigator() {
        var state = ReaderFeature.State()
        state.sidebar.show(SidebarFeature.State.Loaded(tree: tree()))
        let session = location("documentation/foundation/urlsession")
        let elsewhere = location("documentation/uikit/uiview")
        // A page's own metadata says "symbol" for its parents and "collection" for the module;
        // the navigator knows better, and stands in only for pages no loaded tree lists.
        state.headings[session] = .init(title: "URLSession", kind: "symbol")
        state.headings[elsewhere] = .init(title: "UIView", kind: "symbol")
        #expect(state.heading(for: .page(session)).kind == "class")
        #expect(state.heading(for: .page(elsewhere)).kind == "symbol")
        state.page = .loaded(session, RenderedPage(page: Page(title: "URLSession"), kind: "symbol", webURL: URL(string: "https://x")!, parents: [PageParent(title: "Foundation", kind: "collection", location: location("documentation/foundation"))]))
        #expect(state.pathEntries.map(\.kind) == ["class", "module"])
    }

    @Test func filterOpensMatchesOnItsOwnButKeepsWhatWasDoneByHand() async {
        let foundation = foundation
        let tree = tree()
        let store = TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature()
        } withDependencies: {
            $0.library.navigator = { _, _ in tree }
        }
        store.exhaustivity = .off
        await store.send(.load(foundation, language: "swift"))
        await store.receive(\.treeLoaded)
        // URLSession is closed; a filter opens it to show the match, and closing it by hand sticks.
        await store.send(\.binding.filter, "task")
        await store.receive(\.rowsBuilt)
        #expect(store.state.rows.map(\.title) == ["Foundation", "URLSession", "dataTask(with:)"])
        await store.send(.toggled(3))
        await store.receive(\.rowsBuilt)
        #expect(store.state.rows.map(\.title) == ["Foundation", "URLSession"])
        // Clearing the filter leaves the tree as it was: the filter's opening was never kept.
        await store.send(\.binding.filter, "")
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "NSInteger"])
        // A new filter opens it again; closing and then opening it by hand is kept once the filter goes.
        await store.send(\.binding.filter, "task")
        await store.receive(\.rowsBuilt)
        #expect(store.state.rows.map(\.title) == ["Foundation", "URLSession", "dataTask(with:)"])
        await store.send(.toggled(3))
        await store.receive(\.rowsBuilt)
        await store.send(.toggled(3))
        await store.receive(\.rowsBuilt)
        #expect(store.state.rows.map(\.title) == ["Foundation", "URLSession", "dataTask(with:)"])
        await store.send(\.binding.filter, "")
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "dataTask(with:)", "NSInteger"])
    }

    @Test func aSyncedNavigatorIsReloadedInsteadOfServedFromTheCache() async {
        let foundation = foundation
        let loads = LockIsolated(0)
        let store = TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature()
        } withDependencies: {
            $0.library.navigator = { [tree = tree()] _, _ in loads.withValue { $0 += 1 }; return tree }
        }
        store.exhaustivity = .off
        await store.send(.load(foundation, language: "swift"))
        await store.receive(\.treeLoaded)
        await store.send(.load(foundation, language: "swift"))
        #expect(loads.value == 1)
        await store.send(.navigatorUpdated(foundation))
        await store.receive(\.load)
        await store.receive(\.treeLoaded)
        #expect(loads.value == 2)
        #expect(store.state.rows.map(\.title) == ["Foundation", "Essentials", "URLSession", "NSInteger"])
    }
}

@Suite @MainActor struct SidebarCacheTests {
    let base = URL(string: "https://example.com")!

    @Test func switchingBackToALoadedSourceSkipsTheQueryAndKeepsExpansion() async {
        let a = Source(base: base, kind: .appleDeveloper(module: "a"), title: "A", languages: ["swift"])
        let b = Source(base: base, kind: .appleDeveloper(module: "b"), title: "B", languages: ["swift"])
        let loads = LockIsolated(0)
        let store = TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature()
        } withDependencies: {
            $0.library.navigator = { source, _ in
                loads.withValue { $0 += 1 }
                let root = source == a ? 1 : Int64(10)
                return [NavigatorNode(id: root, title: source.title, location: nil, type: "module", children: [
                    NavigatorNode(id: root + 1, title: "Group", location: nil, type: "groupMarker", children: [
                        NavigatorNode(id: root + 2, title: "Leaf", location: nil, type: "article"),
                    ]),
                ])]
            }
        }
        store.exhaustivity = .off
        await store.send(.load(a, language: "swift"))
        await store.receive(\.treeLoaded)
        await store.send(.toggled(2))
        #expect(store.state.rows.map(\.title) == ["A", "Group", "Leaf"])

        await store.send(.load(b, language: "swift"))
        await store.receive(\.treeLoaded)
        #expect(store.state.rows.map(\.title) == ["B", "Group"])

        await store.send(.load(a, language: "swift")) {
            $0.source = a
            $0.isLoading = false
        }
        #expect(store.state.rows.map(\.title) == ["A", "Group", "Leaf"])
        #expect(loads.value == 2)
    }
}
