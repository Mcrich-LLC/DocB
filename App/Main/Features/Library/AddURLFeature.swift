// The add-by-URL sheet: take a URL, discover what it offers, and either hand back the single
// source or present the picker for a catalog. Discovery failures surface as an alert here.

import ComposableArchitecture
import DocBSources
import Foundation

@Reducer
struct AddURLFeature {
    @ObservableState
    struct State: Equatable {
        var urlText = ""
        var isDiscovering = false
        @Presents var picker: SourcePickerFeature.State?
        @Presents var alert: AlertState<Never>?

        var url: URL? {
            let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return URL(string: text.contains("://") ? text : "https://" + text)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case cancelTapped
        case discovered(Result<[Source], any Error>)
        case picker(PresentationAction<SourcePickerFeature.Action>)
        case alert(PresentationAction<Never>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case add([Source])
            case cancel
        }
    }

    @Dependency(\.library) var library

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                guard let url = state.url, !state.isDiscovering else { return .none }
                state.isDiscovering = true
                return .run { send in
                    await send(.discovered(Result { try await library.discover(url) }))
                }
            case .cancelTapped:
                return .send(.delegate(.cancel))
            case .discovered(.success(let sources)):
                state.isDiscovering = false
                if sources.count == 1 {
                    return .send(.delegate(.add(sources)))
                }
                state.picker = SourcePickerFeature.State(candidates: sources)
                return .none
            case .discovered(.failure(let error)):
                state.isDiscovering = false
                state.alert = discoveryAlert(for: error)
                return .none
            case .picker(.presented(.delegate(.add(let sources)))):
                state.picker = nil
                return .send(.delegate(.add(sources)))
            case .picker(.presented(.delegate(.cancel))):
                state.picker = nil
                return .none
            case .picker, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$picker, action: \.picker) { SourcePickerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}

/// The alert for a failed discovery: the URLs tried, or the underlying error.
func discoveryAlert(for error: any Error) -> AlertState<Never> {
    if let error = error as? DiscoveryError {
        return AlertState { TextState("No documentation found") } message: {
            TextState("Tried:\n" + error.tried.map(\.absoluteString).joined(separator: "\n"))
        }
    }
    return AlertState { TextState("Could not add source") } message: { TextState(String(describing: error)) }
}
