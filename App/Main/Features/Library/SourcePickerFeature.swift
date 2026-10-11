// Picking sources from a catalog: multi-select over the candidates a URL offered, with
// select all, unselect all, cancel, and "Add n". Presented from the add-URL sheet or directly
// after a paste.

import ComposableArchitecture
import DocBSources

@Reducer
struct SourcePickerFeature {
    @ObservableState
    struct State: Equatable {
        var candidates: [Source]
        var selected: Set<Source> = []
        var filter = ""
        /// Candidates matching `filter`, kept in state so the list never filters during a body pass.
        var filtered: [Source]

        init(candidates: [Source]) {
            self.candidates = candidates
            self.filtered = candidates
        }

        var allSelected: Bool { selected.count == candidates.count }

        mutating func applyFilter() {
            let needle = filter.trimmingCharacters(in: .whitespaces).lowercased()
            filtered = needle.isEmpty ? candidates : candidates.filter { $0.title.lowercased().contains(needle) || $0.tags.contains { $0.lowercased().contains(needle) } }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggled(Source)
        case selectAllTapped
        case cancelTapped
        case addTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case add([Source])
            case cancel
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.filter):
                state.applyFilter()
                return .none
            case .binding:
                return .none
            case .toggled(let source):
                if state.selected.contains(source) { state.selected.remove(source) } else { state.selected.insert(source) }
                return .none
            case .selectAllTapped:
                state.selected = state.allSelected ? [] : Set(state.candidates)
                return .none
            case .cancelTapped:
                return .send(.delegate(.cancel))
            case .addTapped:
                let chosen = state.candidates.filter { state.selected.contains($0) }
                return .send(.delegate(.add(chosen)))
            case .delegate:
                return .none
            }
        }
    }
}
