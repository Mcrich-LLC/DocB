// One source's details: what it is, when it synced, what it holds, and the actions on it.
// Presented as a sheet on macOS and pushed on iOS; the library feature keeps its record fresh.

import ComposableArchitecture
import DocBSources
import DocBStore

@Reducer
struct SourceDetailFeature {
    @ObservableState
    struct State: Equatable {
        var record: SourceRecord
        var isSyncing = false
        var progress: String?
    }

    enum Action {
        case refreshTapped
        case offlineToggled(Bool)
        case deleteTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case refresh(Source)
            case setOffline(Source, Bool)
            case delete(Source)
            case close
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshTapped: .send(.delegate(.refresh(state.record.source)))
            case .offlineToggled(let offline): .send(.delegate(.setOffline(state.record.source, offline)))
            case .deleteTapped: .send(.delegate(.delete(state.record.source)))
            case .closeTapped: .send(.delegate(.close))
            case .delegate: .none
            }
        }
    }
}
