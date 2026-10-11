// The root feature. Every window scopes into this one store; child features compose here.
// There is one reader per window: the main one from launch, and one for each page opened in
// its own window. The library's fresh source list is handed to every reader, so home and
// sidebars follow adds, removes, and syncs without a second query, and a synced navigator
// drops the sidebars' cached tree for it.

import ComposableArchitecture
import DocBSources
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var library = LibraryFeature.State()
        var readers: IdentifiedArrayOf<ReaderFeature.State> = [ReaderFeature.State()]
    }

    enum Action {
        case library(LibraryFeature.Action)
        case readers(IdentifiedActionOf<ReaderFeature>)
        case readerClosed(UUID)
        /// A window came back at launch with the reader it had; the reader is made again for it.
        case windowRestored(ReaderWindow)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) { LibraryFeature() }
        Reduce { state, action in
            switch action {
            case .library(.sourcesLoaded(let sources)):
                return .merge(state.readers.ids.map { .send(.readers(.element(id: $0, action: .sourcesLoaded(sources)))) })
            case .library(.syncEvent(_, .navigatorUpdated(let source))):
                return .merge(state.readers.ids.map { .send(.readers(.element(id: $0, action: .sidebar(.navigatorUpdated(source))))) })
            case .readers(.element(id: let opener, action: .delegate(.openInNewWindow(let id, let location)))):
                let sources = state.readers[id: opener]?.sources ?? []
                state.readers.append(ReaderFeature.State(id: id, route: .page(location), sources: sources, showsSidebar: false))
                return .none
            case .readerClosed(let id) where id != ReaderFeature.mainID:
                state.readers.remove(id: id)
                return .none
            case .windowRestored(let window):
                guard state.readers[id: window.id] == nil else {
                    // The main reader exists from launch; it only takes the location.
                    return window.location.map { .send(.readers(.element(id: window.id, action: .navigate(.page($0))))) } ?? .none
                }
                state.readers.append(ReaderFeature.State(id: window.id, route: window.location.map { .page($0) } ?? .home, sources: state.library.sources, showsSidebar: false))
                return .none
            default:
                return .none
            }
        }
        .forEach(\.readers, action: \.readers) { ReaderFeature() }
    }
}

/// What a window is opened for and restored with: its reader, and where that reader is.
struct ReaderWindow: Hashable, Codable, Sendable {
    var id: UUID
    var location: PageLocation?
}
