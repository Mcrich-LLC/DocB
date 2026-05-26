@testable import DocBCore
import DocCKit
import Foundation
import SwiftUI
import Testing

@Suite("Documentation search")
struct SidebarSearchIndexTests {
    @Test
    func docCNestedMatchesAndModulesAreExcluded() {
        let site = makeDocCSource(
            title: "FreezeKit",
            children: [
                .init(title: "MainActorSearchController", path: "/documentation/freezekit/searchcontroller", type: "symbol")
            ]
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        let childResults = index.search("mainactor")
        #expect(childResults.sections.count == 1)
        #expect(childResults.sections.first?.title == "FreezeKit")
        #expect(childResults.sections.first?.rows.first?.title == "MainActorSearchController")

        let moduleResults = index.search("freezekit")
        #expect(moduleResults.isEmpty)
    }

    @Test
    func appleFrameworkTitleAndTagMatches() throws {
        let appleTechnologies = try makeAppleTechnologies()
        let index = SidebarSearchIndex(technologies: [.apple(appleTechnologies)])

        let titleResults = index.search("swiftui")
        #expect(titleResults.sections.count == 1)
        #expect(titleResults.sections.first?.title == "Apple Documentation")
        #expect(titleResults.sections.first?.rows.contains { $0.title == "SwiftUI" } == true)

        let tagResults = index.search("declarative")
        #expect(tagResults.sections.first?.rows.first?.title == "SwiftUI")

        guard case .technology(let result) = tagResults.sections.first?.rows.first else {
            Issue.record("Expected an Apple technology search result.")
            return
        }
        #expect(result.badgeReference?.beta == true)
    }

    @Test
    func resultsAreGroupedBySource() {
        let firstSite = makeDocCSource(
            title: "FirstKit",
            children: [.init(title: "SharedMatchOne", path: "/documentation/first/match", type: "symbol")],
            timestamp: 1
        )
        let secondSite = makeDocCSource(
            title: "SecondKit",
            children: [.init(title: "SharedMatchTwo", path: "/documentation/second/match", type: "symbol")],
            timestamp: 2
        )
        let index = SidebarSearchIndex(technologies: [.docC(firstSite), .docC(secondSite)])

        let results = index.search("sharedmatch")

        #expect(results.sections.map(\.title) == ["FirstKit", "SecondKit"])
        #expect(results.sections.map { $0.rows.count } == [1, 1])
    }

    @Test
    func resultLimitReportsTruncation() {
        let children = (0..<5).map { number in
            DocCIndex.InterfaceLanguage(
                title: "Item \(number)",
                path: "/documentation/limit/item-\(number)",
                type: "symbol"
            )
        }
        let site = makeDocCSource(title: "LimitKit", children: children)
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        let results = index.search("item", limit: 3)

        #expect(results.totalMatches == 5)
        #expect(results.isTruncated)
        #expect(results.sections.first?.rows.count == 3)
    }

    @Test
    func docCMultiLanguageDuplicatePathsHaveUniqueIDs() {
        let sharedPath = "/documentation/multikit/shared"
        let swiftNode = DocCIndex.InterfaceLanguage(title: "Swift Shared Symbol", path: sharedPath, type: "symbol")
        let objcNode = DocCIndex.InterfaceLanguage(title: "Objective-C Shared Symbol", path: sharedPath, type: "symbol")
        let site = makeDocCSource(
            urlSuffix: "multikit",
            index: DocCIndex(interfaceLanguages: [
                "swift": [
                    .init(title: "MultiKit", path: "/documentation/multikit", type: "module", children: [swiftNode])
                ],
                "objc": [
                    .init(title: "MultiKit", path: "/documentation/multikit", type: "module", children: [objcNode])
                ]
            ])
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        let results = index.search("shared symbol")
        let rows = results.sections.first?.rows ?? []

        #expect(rows.map(\.title) == ["Objective-C Shared Symbol", "Swift Shared Symbol"])
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test
    func docCSearchIncludesHistoricalOccIndexKey() {
        let site = makeDocCSource(
            urlSuffix: "legacykit",
            index: DocCIndex(interfaceLanguages: [
                "occ": [
                    .init(
                        title: "LegacyKit",
                        path: "/documentation/legacykit",
                        type: "module",
                        children: [
                            .init(title: "Historical Objective-C Symbol", path: "/documentation/legacykit/symbol", type: "symbol")
                        ]
                    )
                ]
            ])
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        #expect(index.search("historical").sections.first?.rows.first?.title == "Historical Objective-C Symbol")
    }

    @Test
    func docCSearchClassifiesXcodeStyleSymbolKinds() {
        let site = makeDocCSource(
            title: "SymbolKit",
            children: [
                .init(title: "UIViewController", path: "/documentation/symbolkit/uiviewcontroller", type: "symbol"),
                .init(title: "StringProtocol", path: "/documentation/symbolkit/stringprotocol", type: "symbol"),
                .init(title: "WorldRecenterPhase", path: "/documentation/symbolkit/worldrecenterphase", type: "symbol"),
                .init(title: "init(horizontalSizeClass:)", path: "/documentation/symbolkit/uiviewcontroller/init(horizontalsizeclass:)", type: "symbol"),
                .init(title: "horizontalSizeClass", path: "/documentation/symbolkit/uiviewcontroller/horizontalsizeclass", type: "symbol")
            ]
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        func symbolKind(title: String) -> SidebarSearchSymbolKind? {
            guard case .reference(let reference) = index.search(title).flattenedRows.first(where: { $0.title == title }) else {
                return nil
            }

            return reference.symbolKind
        }

        #expect(symbolKind(title: "UIViewController") == .classSymbol)
        #expect(symbolKind(title: "StringProtocol") == .protocolSymbol)
        #expect(symbolKind(title: "WorldRecenterPhase") == .enumeration)
        #expect(symbolKind(title: "init(horizontalSizeClass:)") == .initializer)
        #expect(symbolKind(title: "horizontalSizeClass") == .property)
    }

    @Test
    func articleRoleHeadingOverridesFallbackSymbolKind() {
        #expect(SidebarSearchSymbolKind(roleHeading: "Enumeration") == .enumeration)
        #expect(SidebarSearchSymbolKind(roleHeading: "Structure") == .structure)
        #expect(SidebarSearchSymbolKind(roleHeading: "Initializer") == .initializer)
        #expect(SidebarSearchSymbolKind(roleHeading: "Instance Property") == .property)
        #expect(SidebarSearchSymbolKind(roleHeading: "Type Alias") == .typeAlias)
    }

    @Test
    func frameworkReferenceFragmentsClassifySymbolKinds() throws {
        let data = """
        {
          "title": "SDKHealthStatus",
          "identifier": "doc://com.example/documentation/example/sdkhealthstatus",
          "type": "symbol",
          "role": "symbol",
          "fragments": [
            { "text": "enum", "kind": "keyword" },
            { "text": "SDKHealthStatus", "kind": "identifier" }
          ]
        }
        """.data(using: .utf8)!
        let reference = try JSONDecoder().decode(Reference.self, from: data)

        #expect(SidebarSearchSymbolKind(reference: reference, title: "SDKHealthStatus") == .enumeration)
    }

    @Test
    @MainActor
    func emptyQueryClearsResults() async {
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(makeDocCSource(
            title: "EmptyKit",
            children: [.init(title: "Clearable Result", path: "/documentation/empty/clearable", type: "symbol")]
        ))]))

        store.updateSearchText("clearable", debounce: .zero)
        await waitForSearch(store)
        #expect(!store.results.isEmpty)

        store.updateSearchText("", debounce: .zero)
        #expect(store.results.isEmpty)
        #expect(!store.isSearching)
    }

    @Test
    @MainActor
    func storeCancelsStaleQueries() async {
        let site = makeDocCSource(
            title: "AsyncKit",
            children: [
                .init(title: "First Result", path: "/documentation/async/first", type: "symbol"),
                .init(title: "Second Result", path: "/documentation/async/second", type: "symbol")
            ]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))

        store.updateSearchText("first", debounce: .milliseconds(200))
        store.updateSearchText("second", debounce: .zero)
        await waitForSearch(store)

        #expect(store.results.sections.first?.rows.map(\.title) == ["Second Result"])
    }

    @Test
    @MainActor
    func repeatedQueriesReuseInstalledIndex() async {
        let site = makeDocCSource(
            title: "ReuseKit",
            children: [.init(title: "Reusable Search Result", path: "/documentation/reuse/result", type: "symbol")]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))
        let buildCount = store.indexBuildCount

        store.updateSearchText("reusable", debounce: .zero)
        await waitForSearch(store)
        store.updateSearchText("search", debounce: .zero)
        await waitForSearch(store)

        #expect(store.indexBuildCount == buildCount)
        #expect(store.results.sections.first?.rows.first?.title == "Reusable Search Result")
    }

    @Test
    @MainActor
    func installIndexInvalidatesPendingQueryAndRerunsCurrentSearch() async {
        let firstSite = makeDocCSource(
            title: "FirstKit",
            children: [.init(title: "Old Result", path: "/documentation/install/old", type: "symbol")]
        )
        let secondSite = makeDocCSource(
            title: "SecondKit",
            children: [.init(title: "New Result", path: "/documentation/install/new", type: "symbol")]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(firstSite)]))

        store.updateSearchText("result", debounce: .milliseconds(200))
        #expect(store.isSearching)

        store.installIndex(SidebarSearchIndex(technologies: [.docC(secondSite)]))
        await waitForSearch(store)

        #expect(!store.isRebuildingIndex)
        #expect(store.results.sections.first?.rows.map(\.title) == ["New Result"])
    }

    @Test
    @MainActor
    func rebuildIndexKeepsCurrentQuery() async {
        let site = makeDocCSource(
            urlSuffix: "switchkit",
            index: DocCIndex(interfaceLanguages: [
                "swift": [
                    .init(
                        title: "SwitchKit",
                        path: "/documentation/switchkit",
                        type: "module",
                        children: [.init(title: "Swift Switch Result", path: "/documentation/switchkit/result", type: "symbol")]
                    )
                ],
                "objc": [
                    .init(
                        title: "SwitchKit",
                        path: "/documentation/switchkit",
                        type: "module",
                        children: [.init(title: "Objective-C Switch Result", path: "/documentation/switchkit/result", type: "symbol")]
                    )
                ]
            ])
        )
        let store = SidebarSearchStore()
        store.updateSearchText("switch result", debounce: .zero)
        store.rebuildIndex(technologies: [.docC(site)], searchText: "switch result")
        await waitForSearch(store)

        #expect(store.rawSearchText == "switch result")
        #expect(store.results.sections.first?.rows.map(\.title) == ["Objective-C Switch Result", "Swift Switch Result"])
    }

    @Test
    @MainActor
    func coordinatorSelectionTracksVisibleRows() async {
        let site = makeDocCSource(
            title: "PaletteKit",
            children: [
                .init(title: "Palette First", path: "/documentation/palette/first", type: "symbol"),
                .init(title: "Palette Second", path: "/documentation/palette/second", type: "symbol")
            ]
        )
        let coordinator = OpenQuicklySearchCoordinator()
        coordinator.searchStore.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))
        coordinator.updateQuery("palette", debounce: .zero)
        await waitForSearch(coordinator.searchStore)

        coordinator.selectDefaultResultIfNeeded()
        #expect(coordinator.selectedRowID == coordinator.searchStore.results.sections.first?.rows.first?.id)

        coordinator.moveSelection(by: 1)
        #expect(coordinator.selectedRowID == coordinator.searchStore.results.sections.first?.rows.last?.id)
    }

    @Test
    @MainActor
    func coordinatorDefersSelectedResultWhenNoWindowIsActive() async {
        let site = makeDocCSource(
            title: "DeferredKit",
            children: [
                .init(title: "Deferred Symbol", path: "/documentation/deferred/symbol", type: "symbol")
            ]
        )
        let coordinator = OpenQuicklySearchCoordinator()
        coordinator.searchStore.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))
        coordinator.updateQuery("deferred", debounce: .zero)
        await waitForSearch(coordinator.searchStore)
        coordinator.selectDefaultResultIfNeeded()

        var deferredRow: SidebarSearchResultRow?
        coordinator.openResultWithoutActiveWindow = { row in
            deferredRow = row
        }

        let opened = coordinator.openSelectedResult(
            documentationViewModel: DocumentationViewModel(),
            openURL: OpenURLAction { _ in .handled }
        )

        #expect(opened)
        #expect(deferredRow?.id == coordinator.searchStore.results.flattenedRows.first?.id)
    }

    @Test
    @MainActor
    func coordinatorOpensHomepageTechnologyAndReferenceRows() throws {
        let appleTechnologies = try makeAppleTechnologies()
        let navigationViewModel = NavigationViewModel()
        let coordinator = OpenQuicklySearchCoordinator()
        let documentationViewModel = DocumentationViewModel()
        let openURL = OpenURLAction { _ in .handled }
        coordinator.registerActiveNavigationViewModel(navigationViewModel)

        #expect(coordinator.open(.homepage(id: "home", title: "Discover"), documentationViewModel: documentationViewModel, openURL: openURL))
        #expect(navigationViewModel.path.last == .homepage)

        let technologyRow = SidebarSearchIndex(technologies: [.apple(appleTechnologies)])
            .search("swiftui")
            .sections
            .first?
            .rows
            .first
        guard let technologyRow else {
            Issue.record("Expected a technology row.")
            return
        }

        #expect(coordinator.open(technologyRow, documentationViewModel: documentationViewModel, openURL: openURL))
        #expect(navigationViewModel.technology?.title == "SwiftUI")
        #expect(navigationViewModel.reference?.title == "SwiftUI")

        let site = makeDocCSource(
            urlSuffix: "palettekit",
            index: DocCIndex(interfaceLanguages: [
                "swift": [
                    .init(
                        title: "PaletteKit",
                        path: "/documentation/palettekit",
                        type: "module",
                        children: [
                            .init(
                                title: "PaletteGroup",
                                path: "/documentation/palettekit/palettegroup",
                                type: "collection",
                                children: [
                                    .init(
                                        title: "PaletteSymbol",
                                        path: "/documentation/palettekit/palettegroup/palettesymbol",
                                        type: "symbol"
                                    )
                                ]
                            )
                        ]
                    )
                ]
            ])
        )
        let referenceRow = SidebarSearchIndex(technologies: [.docC(site)])
            .search("palettesymbol")
            .sections
            .first?
            .rows
            .first
        guard let referenceRow else {
            Issue.record("Expected a reference row.")
            return
        }

        #expect(coordinator.open(referenceRow, documentationViewModel: documentationViewModel, openURL: openURL))
        #expect(navigationViewModel.technology?.title == "PaletteGroup")
        #expect(navigationViewModel.reference?.title == "PaletteSymbol")
    }

    @Test
    @MainActor
    func appSettingsStoresCapturedSearchShortcut() {
        let settings = AppSettings()

        settings.setSearchKeyboardShortcut(key: "k", modifiers: [.command, .option])

        #expect(settings.searchKeyboardShortcutKey == "k")
        #expect(settings.searchKeyboardShortcutUsesCommand)
        #expect(settings.searchKeyboardShortcutUsesOption)
        #expect(!settings.searchKeyboardShortcutUsesShift)
        #expect(!settings.searchKeyboardShortcutUsesControl)
        #expect(settings.searchKeyboardShortcutIsGlobalEnabled)
        #expect(settings.searchKeyboardShortcutDescription == "⌥⌘K")
    }
}

private func makeDocCSource(title: String, children: [DocCIndex.InterfaceLanguage], timestamp: TimeInterval = 0) -> DocCSource {
    let index = DocCIndex(interfaceLanguages: [
        "swift": [
            .init(title: title, path: "/documentation/\(title.lowercased())", type: "module", children: children)
        ]
    ])

    return DocCSource(
        timestamp: Date(timeIntervalSince1970: timestamp),
        url: URL(string: "https://example.com/\(title.lowercased())")!,
        index: index
    )
}

private func makeDocCSource(urlSuffix: String, index: DocCIndex, timestamp: TimeInterval = 0) -> DocCSource {
    DocCSource(
        timestamp: Date(timeIntervalSince1970: timestamp),
        url: URL(string: "https://example.com/\(urlSuffix)")!,
        index: index
    )
}

private func makeAppleTechnologies() throws -> AppleTechnologies {
    let data = Data("""
    {
      "sections": [
        {
          "kind": "technologies",
          "groups": [
            {
              "name": "UI",
              "technologies": [
                {
                  "languages": ["swift"],
                  "title": "SwiftUI",
                  "tags": ["declarative", "interface"],
                  "destination": {
                    "type": "topic",
                    "isActive": true,
                    "identifier": "doc://com.apple.documentation/documentation/SwiftUI"
                  },
                  "legalNotices": null
                }
              ]
            }
          ]
        }
      ],
      "references": {
        "doc://com.apple.documentation/documentation/SwiftUI": {
          "title": "SwiftUI",
          "identifier": "doc://com.apple.documentation/documentation/SwiftUI",
          "type": "topic",
          "beta": true
        }
      }
    }
    """.utf8)

    return try JSONDecoder().decode(AppleTechnologies.self, from: data)
}

@MainActor
private func waitForSearch(_ store: SidebarSearchStore) async {
    for _ in 0..<20 {
        if !store.isSearching && !store.isRebuildingIndex {
            return
        }

        try? await Task.sleep(for: .milliseconds(20))
    }
}
