// Library management: the sources in the library, adding by URL sheet or paste, removing,
// toggling offline, and syncing with live progress.

import ComposableArchitecture
import DocBSources
import DocBStore
import Foundation

@Reducer
struct LibraryFeature {
    @ObservableState
    struct State: Equatable {
        var sources: [SourceRecord] = []
        var isDiscovering = false
        /// The iOS add prompt: an alert with a URL field rather than a sheet.
        var isAddPromptPresented = false
        var addPromptText = ""
        var syncing: Set<Source> = []
        var progress: [Source: String] = [:]
        @Presents var detail: SourceDetailFeature.State?
        @Presents var addURL: AddURLFeature.State?
        /// The picker for a pasted catalog URL; the add-URL sheet nests its own.
        @Presents var picker: SourcePickerFeature.State?
        @Presents var alert: AlertState<Never>?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case reload
        case sourcesLoaded([SourceRecord])
        case plusTapped
        case addPromptSubmitted
        case pasted(String)
        case discovered(Result<[Source], any Error>)
        case addSources([Source])
        case duplicatesSkipped([Source])
        case editTapped(Source)
        case removeTapped(Source)
        case offlineToggled(Source, Bool)
        /// `force` re-downloads the navigator even if it is fresh: the detail sheet's Refresh.
        case syncTapped(Source?, force: Bool = false)
        case syncEvent(Source?, SyncEvent)
        /// Coalesced page progress: how many pages the drain has handled at a base.
        case syncProgress(only: Source?, base: URL, pages: Int)
        case syncFinished(Source?)
        case failed(String)
        case detail(PresentationAction<SourceDetailFeature.Action>)
        case addURL(PresentationAction<AddURLFeature.Action>)
        case picker(PresentationAction<SourcePickerFeature.Action>)
        case alert(PresentationAction<Never>)
    }

    @Dependency(\.library) var library

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task, .reload:
                return .run { send in
                    await send(.sourcesLoaded(try await library.sources()))
                } catch: { error, send in
                    await send(.failed(String(describing: error)))
                }

            case .sourcesLoaded(let sources):
                state.sources = sources
                refreshDetail(&state)
                return .none

            case .editTapped(let source):
                guard let record = state.sources.first(where: { $0.source == source }) else { return .none }
                state.detail = SourceDetailFeature.State(record: record, isSyncing: state.syncing.contains(source), progress: state.progress[source])
                return .none

            case .plusTapped:
                #if os(macOS)
                state.addURL = AddURLFeature.State()
                #else
                state.addPromptText = ""
                state.isAddPromptPresented = true
                #endif
                return .none

            case .addPromptSubmitted:
                state.isAddPromptPresented = false
                let text = state.addPromptText
                state.addPromptText = ""
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .none : .send(.pasted(text))

            case .pasted(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: trimmed.contains("://") ? trimmed : "https://" + trimmed), url.host() != nil else {
                    state.alert = AlertState { TextState("Not a URL") } message: { TextState("The clipboard does not contain a documentation URL.") }
                    return .none
                }
                state.isDiscovering = true
                return .run { send in
                    await send(.discovered(Result { try await library.discover(url) }))
                }

            case .discovered(.success(let sources)):
                state.isDiscovering = false
                if sources.count == 1 {
                    return .send(.addSources(sources))
                }
                state.picker = SourcePickerFeature.State(candidates: sources)
                return .none

            case .discovered(.failure(let error)):
                state.isDiscovering = false
                state.alert = discoveryAlert(for: error)
                return .none

            case .addSources(let sources):
                return .run { send in
                    var added: [Source] = []
                    var duplicates: [Source] = []
                    for source in sources {
                        do {
                            try await library.add(source, false)
                            added.append(source)
                        } catch StoreError.duplicateSource {
                            duplicates.append(source)
                        }
                    }
                    await send(.reload)
                    for source in added {
                        await send(.syncTapped(source))
                    }
                    if !duplicates.isEmpty {
                        await send(.duplicatesSkipped(duplicates))
                    }
                } catch: { error, send in
                    await send(.failed(String(describing: error)))
                }

            case .duplicatesSkipped(let duplicates):
                let names = duplicates.map(\.title).joined(separator: ", ")
                state.alert = AlertState {
                    TextState(duplicates.count == 1 ? "Already in your library" : "\(duplicates.count) already in your library")
                } message: {
                    TextState(duplicates.count == 1 ? "\(names) was not added again." : "\(names) were not added again.")
                }
                return .none

            case .removeTapped(let source):
                state.sources.removeAll { $0.source == source }
                state.progress[source] = nil
                if state.detail?.record.source == source { state.detail = nil }
                return .concatenate(
                    .cancel(id: SyncID(source: source)),
                    .run { send in
                        try await library.remove(source)
                        await send(.reload)
                    } catch: { error, send in
                        await send(.failed(String(describing: error)))
                    }
                )

            case .offlineToggled(let source, let offline):
                return .run { send in
                    try await library.setOffline(source, offline)
                    await send(.reload)
                    await send(.syncTapped(source))
                } catch: { error, send in
                    await send(.failed(String(describing: error)))
                }

            case .syncTapped(let only, let force):
                if let only { state.syncing.insert(only) } else { state.syncing = Set(state.sources.map(\.source)) }
                refreshDetail(&state)
                return syncEffect(only: only, force: force)

            case .syncEvent(let only, let event):
                switch event {
                case .navigatorUpdated(let source): state.progress[source] = "Navigator updated"
                case .navigatorUnchanged(let source): state.progress[source] = "Up to date"
                case .navigatorFailed(let source, let error): state.progress[source] = "Failed: \(error)"
                case .pageFetched, .pageUpdated, .pageUnchanged, .pageMissing, .pageFailed, .remaining, .finished: break
                }
                refreshDetail(&state)
                return .none

            case .syncProgress(let only, let base, let pages):
                let targets = only.map { [$0] } ?? state.sources.map(\.source).filter { $0.base == base }
                for source in targets {
                    state.progress[source] = "\(pages) pages synced"
                }
                refreshDetail(&state)
                return .none

            case .syncFinished(let only):
                if let only { state.syncing.remove(only) } else { state.syncing = [] }
                for source in state.progress.keys where !state.syncing.contains(source) {
                    state.progress[source] = nil
                }
                refreshDetail(&state)
                return .send(.reload)

            case .failed(let message):
                state.alert = AlertState { TextState("Something went wrong") } message: { TextState(message) }
                return .none

            case .addURL(.presented(.delegate(.add(let sources)))):
                state.addURL = nil
                return .send(.addSources(sources))

            case .addURL(.presented(.delegate(.cancel))):
                state.addURL = nil
                return .none

            case .picker(.presented(.delegate(.add(let sources)))):
                state.picker = nil
                return .send(.addSources(sources))

            case .picker(.presented(.delegate(.cancel))):
                state.picker = nil
                return .none

            case .detail(.presented(.delegate(let delegate))):
                switch delegate {
                case .refresh(let source): return .send(.syncTapped(source, force: true))
                case .setOffline(let source, let offline): return .send(.offlineToggled(source, offline))
                case .delete(let source):
                    state.detail = nil
                    return .send(.removeTapped(source))
                case .close:
                    state.detail = nil
                    return .none
                }

            case .detail, .addURL, .picker, .alert:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { SourceDetailFeature() }
        .ifLet(\.$addURL, action: \.addURL) { AddURLFeature() }
        .ifLet(\.$picker, action: \.picker) { SourcePickerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Keeps the open detail in step with the list: its record, sync state, and progress.
    private func refreshDetail(_ state: inout State) {
        guard let source = state.detail?.record.source else { return }
        guard let record = state.sources.first(where: { $0.source == source }) else {
            state.detail = nil
            return
        }
        let isSyncing = state.syncing.contains(source)
        let progress = state.progress[source]
        state.detail?.record = record
        state.detail?.isSyncing = isSyncing
        state.detail?.progress = progress
    }

    /// Runs a sync, forwarding navigator events as they come and page events coalesced ten at a time per base.
    private func syncEffect(only: Source?, force: Bool) -> Effect<Action> {
        .run { send in
            var pages: [URL: Int] = [:]
            var unreported = 0
            for try await event in library.sync(only, force) {
                switch event {
                case .pageFetched(let location), .pageUpdated(let location), .pageUnchanged(let location), .pageMissing(let location), .pageFailed(let location, _):
                    pages[location.base, default: 0] += 1
                    unreported += 1
                    if unreported >= 10 {
                        unreported = 0
                        for (base, count) in pages { await send(.syncProgress(only: only, base: base, pages: count)) }
                    }
                default:
                    await send(.syncEvent(only, event))
                }
            }
            if unreported > 0 {
                for (base, count) in pages { await send(.syncProgress(only: only, base: base, pages: count)) }
            }
            await send(.syncFinished(only))
        } catch: { error, send in
            await send(.failed(String(describing: error)))
            await send(.syncFinished(only))
        }
        .cancellable(id: SyncID(source: only), cancelInFlight: true)
    }

    struct SyncID: Hashable { var source: Source? }
}
