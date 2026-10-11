// Indexing and filtering a big navigator tree stays linear; a quadratic slip here froze the
// app for 25 seconds on a 55,000-node tree.

import Foundation
import Testing
import DocBSources
import DocBStore
@testable import DocB

@Suite struct SidebarTreeTests {
    private func tree(depth: Int, fanOut: Int = 10) -> [NavigatorNode] {
        var id: Int64 = 0
        func make(_ depth: Int) -> NavigatorNode {
            id += 1
            let me = id
            let children = depth == 0 ? [] : (0..<fanOut).map { _ in make(depth - 1) }
            return NavigatorNode(id: me, title: "Node \(me) someThing", location: PageLocation(base: URL(string: "https://x")!, path: "documentation/x/\(me)"), type: "struct", isDeprecated: false, isBeta: false, isExternal: false, icon: nil, children: children)
        }
        return (0..<5).map { _ in make(depth) }
    }

    @Test func indexingAndFilteringABigTreeIsFast() {
        let big = tree(depth: 4)   // 55,555 nodes
        let clock = ContinuousClock()
        var loaded: SidebarFeature.State.Loaded?
        let indexing = clock.measure { loaded = SidebarFeature.State.Loaded(tree: big) }
        #expect(indexing < .milliseconds(500), "indexing took \(indexing)")
        #expect(loaded?.parents.count == 55550 && loaded?.nodesByPath.count == 55555)
        var rows: [SidebarFeature.State.Row] = []
        let filtering = clock.measure { rows = SidebarFeature.State.rows(of: big, expanded: [], collapsed: [], selectedNode: nil, filter: "9999") }
        #expect(filtering < .milliseconds(500), "filtering took \(filtering)")
        // Every match, under its ancestors and nothing else: ids containing 9999 plus their
        // chains, and the module headings over them.
        #expect(rows.contains { $0.title.contains("9999") } && rows.allSatisfy { $0.title.contains("9999") || $0.hasChildren || $0.isModule })
    }
}

/// Apple's trees list some pages in several places; selecting one must not open the others.
@Suite struct SidebarDuplicateTests {
    private func location(_ path: String) -> PageLocation { PageLocation(base: URL(string: "https://x")!, path: path) }

    private var state: SidebarFeature.State {
        var state = SidebarFeature.State()
        state.show(SidebarFeature.State.Loaded(tree: [
            NavigatorNode(id: 1, title: "A", location: location("a"), type: "module", children: [
                NavigatorNode(id: 2, title: "Shared", location: location("shared"), type: "class"),
                NavigatorNode(id: 3, title: "Group", location: location("group"), type: "collection", children: [
                    NavigatorNode(id: 4, title: "Shared", location: location("shared"), type: "class"),
                ]),
            ]),
            NavigatorNode(id: 5, title: "B", location: location("b"), type: "module", children: [
                NavigatorNode(id: 6, title: "Shared", location: location("shared"), type: "class"),
            ]),
        ]))
        return state
    }

    @Test func theClickedRowIsTheOneSelected() {
        var state = state
        state.tappedNode = 6
        state.select(location("shared"))
        #expect(state.selectedNode == 6)
        #expect(state.expanded == [1, 5])
    }

    @Test func aLinkPicksARowAlreadyOnScreenBeforeOpeningAnything() {
        var state = state
        state.expanded = [5]
        state.select(location("shared"))
        #expect(state.selectedNode == 6)
        #expect(state.expanded == [5])
        // Nothing on screen: the first one, opened toward.
        state.expanded = []
        state.selectedNode = nil
        state.select(location("group"))
        #expect(state.selectedNode == 3)
        #expect(state.expanded == [1])
    }

    @Test func theSelectionStaysPutWhenReselected() {
        var state = state
        state.tappedNode = 4
        state.select(location("shared"))
        state.select(location("shared"))
        #expect(state.selectedNode == 4)
        #expect(SidebarFeature.State.rows(of: state.tree, expanded: state.expanded, collapsed: [], selectedNode: state.selectedNode, filter: "").filter(\.isSelected).map(\.id) == [4])
    }
}

@Suite struct SidebarModuleTests {
    @Test func modulesAreHeadingsOverTheirPagesAndSeparated() {
        let tree = [
            NavigatorNode(id: 1, title: "Accelerate", location: nil, type: "module", children: [NavigatorNode(id: 2, title: "vDSP", location: nil, type: "struct", children: [NavigatorNode(id: 3, title: "add", location: nil, type: "func")])]),
            NavigatorNode(id: 4, title: "vecLib", location: nil, type: "module", children: [NavigatorNode(id: 5, title: "Old", location: nil, type: "article")]),
        ]
        let rows = SidebarFeature.State.rows(of: tree, expanded: [2], collapsed: [], selectedNode: nil, filter: "")
        #expect(rows.map(\.title) == ["Accelerate", "vDSP", "add", "vecLib", "Old"])
        #expect(rows.map(\.depth) == [0, 0, 1, 0, 0])
        #expect(rows.map(\.isModule) == [true, false, false, true, false])
        #expect(rows.map(\.separatorAbove) == [false, false, false, true, false])
        #expect(!rows[0].hasChildren && rows[1].hasChildren)
        // A filter keeps the heading over its matches and drops a module with none.
        let filtered = SidebarFeature.State.rows(of: tree, expanded: [], collapsed: [], selectedNode: nil, filter: "add")
        #expect(filtered.map(\.title) == ["Accelerate", "vDSP", "add"])
    }
}
