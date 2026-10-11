// The navigator sidebar for one source: the tree, which nodes are expanded, a filter, and the
// selection the reader hands down. It emits an `open` delegate on a click and never navigates
// itself. Everything that walks the whole tree (indexing it, filtering it) runs in an effect
// off the main actor and lands as one assignment, so a 50,000-node tree never stalls the UI.
// Trees already loaded this session are kept, with their expansion, so switching back is instant.

import ComposableArchitecture
import DocBRender
import DocBSources
import DocBStore
import Foundation
import SwiftUI

@Reducer
struct SidebarFeature {
    @ObservableState
    struct State: Equatable {
        var source: Source?
        var language = "swift"
        var tree: [NavigatorNode] = []
        var expanded: Set<Int64> = []
        var selection: PageLocation?
        /// The one row shown selected. Apple's trees list some pages in several places, so the
        /// selection is a node, not a path: the node the reader clicked, else one already on
        /// screen, else the first, and the tree only ever opens toward that one.
        var selectedNode: Int64?
        /// The row last clicked, so the selection that follows lands on it.
        var tappedNode: Int64?
        var filter = ""
        /// Nodes the reader collapsed while this filter is up. A filter opens every node with
        /// a match under it on its own; that opening is not kept, but a node opened by hand is,
        /// through `expanded`, and one closed by hand stays closed until the filter changes.
        var collapsedWhileFiltering: Set<Int64> = []
        var isLoading = false
        var rows: [Row] = []

        /// Parent id per node id, for expanding a selection's ancestors.
        var parents: [Int64: Int64] = [:]
        /// Node ids per path, in tree order, for finding the selection.
        var nodesByPath: [String: [Int64]] = [:]
        /// Node type per path: the one vocabulary every icon in the app is drawn from.
        var typeByPath: [String: String] = [:]
        /// The badge per path, for the paths that wear one.
        var badgeByPath: [String: Badge] = [:]
        /// Trees loaded this session, by source and language.
        // ponytail: unbounded; evict least recently shown if memory ever matters.
        var loaded: [Key: Loaded] = [:]

        struct Key: Hashable { var source: Source; var language: String }
        struct Loaded: Equatable, Sendable {
            var tree: [NavigatorNode]
            var parents: [Int64: Int64]
            var nodesByPath: [String: [Int64]]
            var typeByPath: [String: String]
            var badgeByPath: [String: Badge]
            var expanded: Set<Int64>

            /// Indexes a tree, with its roots open.
            init(tree: [NavigatorNode]) {
                var parents: [Int64: Int64] = [:]
                var nodesByPath: [String: [Int64]] = [:]
                var typeByPath: [String: String] = [:]
                var badgeByPath: [String: Badge] = [:]
                func index(_ nodes: [NavigatorNode], parent: Int64?) {
                    for node in nodes {
                        if let parent { parents[node.id] = parent }
                        if let path = node.location?.path {
                            nodesByPath[path, default: []].append(node.id)
                            if typeByPath[path] == nil {
                                typeByPath[path] = node.type
                                badgeByPath[path] = Badge(isBeta: node.isBeta, isDeprecated: node.isDeprecated)
                            }
                        }
                        index(node.children, parent: node.id)
                    }
                }
                index(tree, parent: nil)
                self.tree = tree
                self.parents = parents
                self.nodesByPath = nodesByPath
                self.typeByPath = typeByPath
                self.badgeByPath = badgeByPath
                expanded = Set(tree.map(\.id))
            }
        }

        /// Installs a tree as the one on show, then expands to the selection and flattens.
        mutating func show(_ loaded: Loaded) {
            tree = loaded.tree
            parents = loaded.parents
            nodesByPath = loaded.nodesByPath
            typeByPath = loaded.typeByPath
            badgeByPath = loaded.badgeByPath
            expanded = loaded.expanded
            select(selection)
        }

        /// Picks the node to show selected for a location and opens the tree toward it.
        mutating func select(_ location: PageLocation?) {
            selection = location
            guard let location, let candidates = nodesByPath[location.path], !candidates.isEmpty else {
                selectedNode = nil
                return
            }
            if let tapped = tappedNode, candidates.contains(tapped) {
                selectedNode = tapped
            } else if let current = selectedNode, candidates.contains(current) {
                // Already on it.
            } else {
                selectedNode = candidates.first { isOnScreen($0) } ?? candidates[0]
            }
            tappedNode = nil
            if let selectedNode { expandAncestors(of: selectedNode) }
        }

        /// Whether every ancestor of a node is open.
        private func isOnScreen(_ id: Int64) -> Bool {
            var id = id
            while let parent = parents[id] {
                guard expanded.contains(parent) else { return false }
                id = parent
            }
            return true
        }

        /// The navigator's type for a path, from the tree on show or any loaded this session.
        func type(forPath path: String) -> String? {
            typeByPath[path] ?? loaded.values.lazy.compactMap { $0.typeByPath[path] }.first
        }

        /// The navigator's badge for a path, likewise.
        func badge(forPath path: String) -> Badge? {
            badgeByPath[path] ?? loaded.values.lazy.compactMap { $0.badgeByPath[path] }.first
        }

        struct Row: Equatable, Identifiable, Sendable {
            var id: Int64
            var depth: Int
            var title: String
            var location: PageLocation?
            var type: String
            var hasChildren: Bool
            var isExpanded: Bool
            var isSelected: Bool
            /// Links out to a page another source owns.
            var isExternal: Bool
            var isBeta = false
            var isDeprecated = false
            /// A module: the web's navigator shows it as a heading over its pages rather than a
            /// level above them, since nearly every source has just the one.
            var isModule = false
            /// A module after the first, set off from the one above.
            var separatorAbove = false
        }

        mutating func expandAncestors(of node: Int64) {
            var id = node
            var expanded = self.expanded
            while let parent = parents[id] {
                expanded.insert(parent)
                id = parent
            }
            self.expanded = expanded
        }

        /// The visible rows: expanded nodes, or with a filter every match under its ancestors,
        /// those ancestors open unless closed by hand. The roots are modules: always open, as
        /// headings over their pages, which sit at the top level.
        static func rows(of tree: [NavigatorNode], expanded: Set<Int64>, collapsed: Set<Int64>, selectedNode: Int64?, filter: String) -> [Row] {
            let needle = filter.trimmingCharacters(in: .whitespaces)
            var rows: [Row] = []
            func row(_ node: NavigatorNode, depth: Int, isExpanded: Bool) -> Row {
                Row(id: node.id, depth: depth, title: node.title, location: node.location, type: node.type, hasChildren: !node.children.isEmpty, isExpanded: isExpanded, isSelected: node.id == selectedNode, isExternal: node.isExternal, isBeta: node.isBeta, isDeprecated: node.isDeprecated)
            }
            func module(_ node: NavigatorNode) -> Row {
                var row = row(node, depth: 0, isExpanded: true)
                row.hasChildren = false
                row.isModule = true
                row.separatorAbove = rows.contains { $0.isModule }
                return row
            }
            func visit(_ nodes: [NavigatorNode], depth: Int) {
                for node in nodes {
                    let isExpanded = expanded.contains(node.id)
                    rows.append(row(node, depth: depth, isExpanded: isExpanded))
                    if isExpanded { visit(node.children, depth: depth + 1) }
                }
            }
            /// Appends matching nodes and the ancestors above them; returns whether anything matched.
            @discardableResult
            func visitMatching(_ nodes: [NavigatorNode], depth: Int) -> Bool {
                var any = false
                for node in nodes {
                    let mark = rows.count
                    rows.append(row(node, depth: depth, isExpanded: false))
                    let below = visitMatching(node.children, depth: depth + 1)
                    let matches = node.title.range(of: needle, options: .caseInsensitive) != nil
                    guard below || matches else { rows.removeSubrange(mark...); continue }
                    any = true
                    let isExpanded = expanded.contains(node.id) || (below && !collapsed.contains(node.id))
                    rows[mark].isExpanded = isExpanded
                    if !isExpanded { rows.removeSubrange((mark + 1)...) }
                }
                return any
            }
            for root in tree {
                let mark = rows.count
                rows.append(module(root))
                if needle.isEmpty {
                    visit(root.children, depth: 0)
                } else if !visitMatching(root.children, depth: 0), root.title.range(of: needle, options: .caseInsensitive) == nil {
                    rows.removeSubrange(mark...)
                }
            }
            return rows
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case load(Source, language: String)
        /// A sync replaced this source's navigator: its cached trees are stale.
        case navigatorUpdated(Source)
        case treeLoaded(Source, Result<State.Loaded, any Error>)
        case toggled(Int64)
        case rowTapped(State.Row)
        case openInNewWindowTapped(id: UUID, State.Row)
        case select(PageLocation?)
        case rowsBuilt([State.Row])
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case open(PageLocation)
            case openInNewWindow(id: UUID, PageLocation)
            case failed(String)
        }
    }

    @Dependency(\.library) var library

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.filter):
                state.collapsedWhileFiltering = []
                return rebuildRows(&state)

            case .binding:
                return .none

            case .load(let source, let language):
                if let current = state.source, current != source {
                    let expanded = state.expanded
                    state.loaded[State.Key(source: current, language: state.language)]?.expanded = expanded
                }
                state.source = source
                state.language = language
                if let cached = state.loaded[State.Key(source: source, language: language)] {
                    state.isLoading = false
                    state.show(cached)
                    return .merge(.cancel(id: LoadID()), rebuildRows(&state))
                }
                state.isLoading = true
                // Nothing of the old source shows while the new tree loads.
                state.tree = []
                state.rows = []
                state.parents = [:]
                state.nodesByPath = [:]
                state.typeByPath = [:]
                state.badgeByPath = [:]
                return .run { send in
                    await send(.treeLoaded(source, Result { State.Loaded(tree: try await library.navigator(source, language)) }))
                }
                .cancellable(id: LoadID(), cancelInFlight: true)

            case .navigatorUpdated(let source):
                for key in state.loaded.keys where key.source == source { state.loaded[key] = nil }
                guard source == state.source else { return .none }
                // ponytail: ids change with the swap, so expansion restarts at the roots and the selection.
                return .send(.load(source, language: state.language))

            case .treeLoaded(let source, .success(let loaded)):
                guard source == state.source else { return .none }
                state.isLoading = false
                state.loaded[State.Key(source: source, language: state.language)] = loaded
                state.show(loaded)
                return rebuildRows(&state)

            case .treeLoaded(_, .failure(let error)):
                state.isLoading = false
                return .send(.delegate(.failed(String(describing: error))))

            case .toggled(let id):
                let isShownExpanded = state.rows.first { $0.id == id }?.isExpanded ?? state.expanded.contains(id)
                if isShownExpanded {
                    state.expanded.remove(id)
                    state.collapsedWhileFiltering.insert(id)
                } else {
                    state.expanded.insert(id)
                    state.collapsedWhileFiltering.remove(id)
                }
                return rebuildRows(&state, animation: .default)

            case .rowTapped(let row):
                if let location = row.location {
                    state.tappedNode = row.id
                    return .send(.delegate(.open(location)))
                }
                return .send(.toggled(row.id))

            case .openInNewWindowTapped(let id, let row):
                guard let location = row.location else { return .none }
                return .send(.delegate(.openInNewWindow(id: id, location)))

            case .select(let location):
                state.select(location)
                return rebuildRows(&state)

            case .rowsBuilt(let rows):
                state.rows = rows
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Flattens the rows in place when only expanded nodes are visited (cheap), and in an
    /// effect off the main actor when a filter means walking the whole tree. Rows built in
    /// place animate when the view asks; rows from the effect animate when `animation` says.
    private func rebuildRows(_ state: inout State, animation: Animation? = nil) -> Effect<Action> {
        let tree = state.tree, expanded = state.expanded, collapsed = state.collapsedWhileFiltering, selectedNode = state.selectedNode, filter = state.filter
        if filter.trimmingCharacters(in: .whitespaces).isEmpty {
            state.rows = State.rows(of: tree, expanded: expanded, collapsed: collapsed, selectedNode: selectedNode, filter: filter)
            return .cancel(id: RowsID())
        }
        return .run { send in
            await send(.rowsBuilt(State.rows(of: tree, expanded: expanded, collapsed: collapsed, selectedNode: selectedNode, filter: filter)), animation: animation)
        }
        .cancellable(id: RowsID(), cancelInFlight: true)
    }

    struct LoadID: Hashable {}
    struct RowsID: Hashable {}
}
