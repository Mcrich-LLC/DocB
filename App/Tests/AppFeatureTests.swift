// Reducer tests for the library flows: loading, the add-URL sheet, the paste path, the
// catalog picker, and discovery failures. The library dependency is replaced throughout.

import ComposableArchitecture
import DocBSources
import DocBStore
import DocBPage
import Foundation
import Testing
@testable import DocB

@Suite @MainActor struct LibraryFeatureTests {
    let source = Source(base: URL(string: "https://example.com/docs")!, kind: .docc, title: "Example Kit", languages: ["swift"])
    let a = Source(base: URL(string: "https://example.com")!, kind: .appleDeveloper(module: "a"), title: "A", languages: [])
    let b = Source(base: URL(string: "https://example.com")!, kind: .appleDeveloper(module: "b"), title: "B", languages: [])
    var record: SourceRecord { SourceRecord(source: source, offline: false, indexSyncedAt: nil, addedAt: Date(timeIntervalSince1970: 0), fetchedPages: 0, pendingPages: 0) }

    @Test func loadsSourcesOnAppear() async {
        let record = record
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.library.sources = { [record] }
        }
        await store.send(.task)
        await store.receive(\.sourcesLoaded) {
            $0.sources = [record]
        }
    }

    @Test func plusOpensTheSheetAndASingleSourceIsAddedAndSynced() async {
        let record = record
        let source = source
        let added = LockIsolated<[Source]>([])
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.library.discover = { _ in [source] }
            $0.library.add = { source, _ in added.withValue { $0.append(source) } }
            $0.library.sources = { [record] }
            $0.library.sync = { _, _ in AsyncThrowingStream { $0.yield(.navigatorUpdated(source)); $0.finish() } }
        }
        await store.send(.plusTapped) { $0.addURL = AddURLFeature.State() }
        await store.send(\.addURL.binding.urlText, "example.com/docs") { $0.addURL?.urlText = "example.com/docs" }
        await store.send(\.addURL.submitTapped) { $0.addURL?.isDiscovering = true }
        // The reload and sync effects interleave, so assert on the outcome rather than the order.
        store.exhaustivity = .off
        await store.receive(\.addURL.presented.discovered.success)
        await store.receive(\.addSources) { $0.addURL = nil }
        await store.receive(\.syncFinished)
        await store.finish()
        #expect(added.value == [source])
        #expect(store.state.sources == [record])
        #expect(store.state.syncing.isEmpty && store.state.progress.isEmpty)
    }

    @Test func aCatalogFromTheSheetNestsThePickerAndAddsTheSelection() async {
        let (a, b) = (a, b)
        let added = LockIsolated<[Source]>([])
        let store = TestStore(initialState: LibraryFeature.State(addURL: AddURLFeature.State(urlText: "https://example.com"))) {
            LibraryFeature()
        } withDependencies: {
            $0.library.discover = { _ in [a, b] }
            $0.library.add = { source, _ in added.withValue { $0.append(source) } }
            $0.library.sources = { [] }
            $0.library.sync = { _, _ in .finished() }
        }
        await store.send(\.addURL.submitTapped) { $0.addURL?.isDiscovering = true }
        await store.receive(\.addURL.presented.discovered.success) {
            $0.addURL?.isDiscovering = false
            $0.addURL?.picker = SourcePickerFeature.State(candidates: [a, b])
        }
        await store.send(\.addURL.picker.selectAllTapped) { $0.addURL?.picker?.selected = [a, b] }
        await store.send(\.addURL.picker.toggled, b) { $0.addURL?.picker?.selected = [a] }
        store.exhaustivity = .off
        await store.send(\.addURL.picker.addTapped)
        await store.receive(\.addSources) { $0.addURL = nil }
        await store.finish()
        #expect(added.value == [a])
    }

    @Test func pastingACatalogURLPresentsThePickerDirectly() async {
        let (a, b) = (a, b)
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.library.discover = { _ in [a, b] }
        }
        await store.send(.pasted("https://example.com")) { $0.isDiscovering = true }
        await store.receive(\.discovered.success) {
            $0.isDiscovering = false
            $0.picker = SourcePickerFeature.State(candidates: [a, b])
        }
        await store.send(\.picker.cancelTapped)
        await store.receive(\.picker.presented.delegate) { $0.picker = nil }
    }

    @Test func pastingSomethingThatIsNotAURLAlerts() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }
        await store.send(.pasted("not a url at all")) {
            $0.alert = AlertState { TextState("Not a URL") } message: { TextState("The clipboard does not contain a documentation URL.") }
        }
    }

    @Test func discoveryFailureAlertsWithTheURLsTried() async {
        let tried = URL(string: "https://example.com/index/index.json")!
        let store = TestStore(initialState: LibraryFeature.State(addURL: AddURLFeature.State(urlText: "https://example.com"))) {
            LibraryFeature()
        } withDependencies: {
            $0.library.discover = { _ in throw DiscoveryError(tried: [tried]) }
        }
        await store.send(\.addURL.submitTapped) { $0.addURL?.isDiscovering = true }
        await store.receive(\.addURL.presented.discovered.failure) {
            $0.addURL?.isDiscovering = false
            $0.addURL?.alert = AlertState { TextState("No documentation found") } message: { TextState("Tried:\n\(tried.absoluteString)") }
        }
    }

    @Test func duplicatesAreSkippedAndReported() async {
        let (a, b) = (a, b)
        let added = LockIsolated<[Source]>([])
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.library.add = { source, _ in
                if source == a { throw StoreError.duplicateSource(source) }
                added.withValue { $0.append(source) }
            }
            $0.library.sources = { [] }
            $0.library.sync = { _, _ in .finished() }
        }
        store.exhaustivity = .off
        await store.send(.addSources([a, b]))
        await store.receive(\.duplicatesSkipped) {
            $0.alert = AlertState { TextState("Already in your library") } message: { TextState("A was not added again.") }
        }
        await store.finish()
        #expect(added.value == [b])
    }

    @Test func pageEventsAreCoalescedIntoProgress() async {
        let record = record
        let source = source
        let location = PageLocation(base: source.base, path: "documentation/examplekit/thing")
        let store = TestStore(initialState: LibraryFeature.State(sources: [record])) {
            LibraryFeature()
        } withDependencies: {
            $0.library.sources = { [record] }
            $0.library.sync = { _, _ in AsyncThrowingStream { c in
                c.yield(.navigatorUpdated(source))
                for _ in 0..<50 { c.yield(.pageFetched(location)) }
                c.finish()
            } }
        }
        await store.send(.syncTapped(source)) { $0.syncing = [source] }
        await store.receive(\.syncEvent) { $0.progress[source] = "Navigator updated" }
        for count in stride(from: 10, through: 50, by: 10) {
            await store.receive(\.syncProgress) { $0.progress[source] = "\(count) pages synced" }
        }
        await store.receive(\.syncFinished) { $0.syncing = []; $0.progress = [:] }
        await store.receive(\.reload)
        await store.receive(\.sourcesLoaded)
    }

    @Test func editOpensDetailAndDeleteFromItRemoves() async {
        let record = record
        let source = source
        let removed = LockIsolated<[Source]>([])
        let store = TestStore(initialState: LibraryFeature.State(sources: [record])) {
            LibraryFeature()
        } withDependencies: {
            $0.library.remove = { source in removed.withValue { $0.append(source) } }
            $0.library.sources = { [] }
        }
        await store.send(.editTapped(source)) {
            $0.detail = SourceDetailFeature.State(record: record)
        }
        await store.send(\.detail.deleteTapped)
        await store.receive(\.detail.presented.delegate) {
            $0.detail = nil
        }
        await store.receive(\.removeTapped) { $0.sources = [] }
        await store.receive(\.reload)
        await store.receive(\.sourcesLoaded)
        #expect(removed.value == [source])
    }

    @Test func detailTracksSyncStateOfItsSourceAndRefreshForcesTheSync() async {
        let record = record
        let source = source
        let forced = LockIsolated(false)
        let store = TestStore(initialState: LibraryFeature.State(sources: [record], detail: SourceDetailFeature.State(record: record))) {
            LibraryFeature()
        } withDependencies: {
            $0.library.sources = { [record] }
            $0.library.sync = { _, force in
                forced.setValue(force)
                return AsyncThrowingStream { $0.yield(.navigatorUpdated(source)); $0.finish() }
            }
        }
        await store.send(\.detail.refreshTapped)
        await store.receive(\.detail.presented.delegate)
        await store.receive(\.syncTapped) {
            $0.syncing = [source]
            $0.detail?.isSyncing = true
        }
        await store.receive(\.syncEvent) {
            $0.progress[source] = "Navigator updated"
            $0.detail?.progress = "Navigator updated"
        }
        await store.receive(\.syncFinished) {
            $0.syncing = []
            $0.progress = [:]
            $0.detail?.isSyncing = false
            $0.detail?.progress = nil
        }
        await store.receive(\.reload)
        await store.receive(\.sourcesLoaded)
        #expect(forced.value)
    }

    @Test func removingCancelsItsSyncAndReloads() async {
        let record = record
        let source = source
        let removed = LockIsolated<[Source]>([])
        let store = TestStore(initialState: LibraryFeature.State(sources: [record], progress: [source: "Syncing"])) {
            LibraryFeature()
        } withDependencies: {
            $0.library.remove = { source in removed.withValue { $0.append(source) } }
            $0.library.sources = { [] }
        }
        await store.send(.removeTapped(source)) {
            $0.sources = []
            $0.progress = [:]
        }
        await store.receive(\.reload)
        await store.receive(\.sourcesLoaded)
        #expect(removed.value == [source])
    }
}

@Suite @MainActor struct AppFeatureTests {
    @Test func libraryChangesReachTheReader() async {
        let source = Source(base: URL(string: "https://example.com/docs")!, kind: .docc, title: "Example Kit", languages: ["swift"])
        let record = SourceRecord(source: source, offline: false, indexSyncedAt: nil, addedAt: Date(timeIntervalSince1970: 0), fetchedPages: 0, pendingPages: 0)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.library.sources = { [record] }
        }
        await store.send(.library(.reload))
        await store.receive(\.library.sourcesLoaded) { $0.library.sources = [record] }
        await store.receive(\.readers[id: ReaderFeature.mainID].sourcesLoaded) { $0.readers[id: ReaderFeature.mainID]?.sources = [record] }
    }

    @Test func aPageOpenedInANewWindowGetsItsOwnReaderWithoutASidebar() async {
        let source = Source(base: URL(string: "https://example.com/docs")!, kind: .docc, title: "Example Kit", languages: ["swift"])
        let record = SourceRecord(source: source, offline: false, indexSyncedAt: nil, addedAt: Date(timeIntervalSince1970: 0), fetchedPages: 0, pendingPages: 0)
        let location = PageLocation(base: source.base, path: "documentation/examplekit/thing")
        let id = UUID()
        let store = TestStore(initialState: AppFeature.State(readers: [ReaderFeature.State(sources: [record])])) {
            AppFeature()
        }
        let row = SidebarFeature.State.Row(id: 1, depth: 0, title: "Thing", location: location, type: "struct", hasChildren: false, isExpanded: false, isSelected: false, isExternal: false)
        await store.send(.readers(.element(id: ReaderFeature.mainID, action: .sidebar(.openInNewWindowTapped(id: id, row)))))
        await store.receive(\.readers[id: ReaderFeature.mainID].sidebar.delegate.openInNewWindow)
        await store.receive(\.readers[id: ReaderFeature.mainID].delegate.openInNewWindow) {
            $0.readers.append(ReaderFeature.State(id: id, route: .page(location), sources: [record], showsSidebar: false))
        }
        #expect(store.state.readers[id: id]?.columnVisibility == .detailOnly)
        #expect(store.state.readers[id: id]?.page == .loading(location))
        await store.send(.readerClosed(id)) { $0.readers.remove(id: id) }
        await store.send(.readerClosed(ReaderFeature.mainID))
    }
}

@Suite @MainActor struct WindowRestoreTests {
    @Test func aRestoredWindowGetsItsReaderBackOnItsPage() async {
        let location = PageLocation(base: URL(string: "https://example.com/docs")!, path: "documentation/kit/thing")
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.library.page = { _, _ in RenderedPage(page: Page(title: "Thing"), kind: "struct", webURL: URL(string: "https://example.com")!) }
            $0.library.sourcesContaining = { _ in [] }
        }
        store.exhaustivity = .off
        let id = UUID()
        await store.send(.windowRestored(ReaderWindow(id: id, location: location))) { state in
            state.readers.append(ReaderFeature.State(id: id, route: .page(location), sources: [], showsSidebar: false))
        }
        #expect(store.state.readers[id: id]?.current == .page(location))
        // The main reader exists from launch and just goes to its page.
        await store.send(.windowRestored(ReaderWindow(id: ReaderFeature.mainID, location: location)))
        await store.receive(\.readers[id: ReaderFeature.mainID].navigate)
        #expect(store.state.readers[id: ReaderFeature.mainID]?.current == .page(location))
    }
}
