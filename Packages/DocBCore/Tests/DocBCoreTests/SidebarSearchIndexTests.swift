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
    func applePersistedIndexMatchesSymbolsAsAppleReferences() throws {
        let appleIndex = DocCIndex(interfaceLanguages: [
            "swift": [
                .init(
                    title: "SwiftUI",
                    path: "/documentation/swiftui",
                    type: "module",
                    children: [
                        .init(
                            title: "View",
                            path: "/documentation/swiftui/view",
                            type: "protocol"
                        )
                    ]
                )
            ]
        ])
        let appleTechnologies = try makeAppleTechnologies().withIndex(appleIndex)
        let index = SidebarSearchIndex(technologies: [.apple(appleTechnologies)])

        guard case .reference(let reference) = index.search("view").flattenedRows.first else {
            Issue.record("Expected an Apple reference search result.")
            return
        }

        #expect(reference.site == nil)
        #expect(reference.symbolKind == .protocolSymbol)
        #expect(reference.reference(deepLinkScheme: .doc).identifier == "doc://com.apple.documentation/documentation/swiftui/view")
    }

    @Test
    func appleStreamingIndexCollapsesDuplicateLanguageSymbols() throws {
        let duplicatedSymbol = DocCIndex.InterfaceLanguage(
            title: "UILabel",
            path: "/documentation/uikit/uilabel",
            type: "class"
        )
        let appleIndex = DocCIndex(interfaceLanguages: [
            "swift": [
                .init(
                    title: "UIKit",
                    path: "/documentation/uikit",
                    type: "module",
                    children: [duplicatedSymbol]
                )
            ],
            "objc": [
                .init(
                    title: "UIKit",
                    path: "/documentation/uikit",
                    type: "module",
                    children: [duplicatedSymbol]
                )
            ]
        ])
        let appleTechnologies = try makeAppleTechnologies().withIndex(appleIndex)
        let index = SidebarSearchIndex(technologies: [.apple(appleTechnologies)])

        let rows = index.search("uilabel").flattenedRows

        #expect(rows.map(\.title) == ["UILabel"])
        #expect(Set(rows.map(\.id)).count == rows.count)
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

        #expect(results.totalMatches == 4)
        #expect(results.isTruncated)
        #expect(results.sections.first?.rows.count == 3)
    }

    @Test
    func resultLimitStopsAfterTruncationIsKnown() {
        let children = (0..<500).map { number in
            DocCIndex.InterfaceLanguage(
                title: "Common Item \(number)",
                path: "/documentation/limit/common-\(number)",
                type: "symbol"
            )
        }
        let site = makeDocCSource(title: "BoundedKit", children: children)
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        let results = index.search("common", limit: 10)

        #expect(results.totalMatches == 11)
        #expect(results.isTruncated)
        #expect(results.sections.first?.rows.count == 10)
    }

    @Test
    func asciiCandidateLookupPreservesSymbolMatches() {
        let site = makeDocCSource(
            title: "UIKit",
            children: [
                .init(title: "UILabel", path: "/documentation/uikit/uilabel", type: "class"),
                .init(title: "CGSize", path: "/documentation/corefoundation/cgsize", type: "structure"),
                .init(title: "Button", path: "/documentation/uikit/button", type: "structure")
            ]
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        #expect(index.search("UILabel").flattenedRows.map(\.title) == ["UILabel"])
        #expect(index.search("CGSize").flattenedRows.map(\.title) == ["CGSize"])
    }

    @Test
    func searchRanksTypesBeforePropertiesAndMethodsMentioningTheType() {
        let site = makeDocCSource(
            title: "UIKit",
            children: [
                .init(title: "preferredContentSize: CGSize", path: "/documentation/uikit/view/preferredcontentsize", type: "property"),
                .init(title: "sizeThatFits(_:) -> CGSize", path: "/documentation/uikit/view/sizethatfits(_:)", type: "method"),
                .init(title: "CGSize", path: "/documentation/corefoundation/cgsize", type: "structure"),
                .init(title: "CGSizeProtocol", path: "/documentation/corefoundation/cgsizeprotocol", type: "protocol")
            ]
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        #expect(index.search("CGSize").flattenedRows.map(\.title) == [
            "CGSize",
            "CGSizeProtocol",
            "sizeThatFits(_:) -> CGSize",
            "preferredContentSize: CGSize"
        ])
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

        #expect(rows.map(\.title) == ["Swift Shared Symbol", "Objective-C Shared Symbol"])
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test
    func duplicateDocCIndexRowsAreCollapsed() {
        let duplicate = DocCIndex.InterfaceLanguage(
            title: "Repeated Symbol",
            path: "/documentation/repeatkit/repeatedsymbol",
            type: "symbol"
        )
        let site = makeDocCSource(
            urlSuffix: "repeatkit",
            index: DocCIndex(interfaceLanguages: [
                "swift": [
                    .init(
                        title: "RepeatKit",
                        path: "/documentation/repeatkit",
                        type: "module",
                        children: [duplicate, duplicate]
                    )
                ],
                "objc": [
                    .init(
                        title: "RepeatKit",
                        path: "/documentation/repeatkit",
                        type: "module",
                        children: [duplicate]
                    )
                ]
            ])
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        let rows = index.search("repeated").flattenedRows

        #expect(rows.map(\.title) == ["Repeated Symbol"])
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
                .init(title: "PurchasesDiagnostics.SDKHealthError", path: "/documentation/symbolkit/purchasesdiagnostics/sdkhealtherror", type: "enum"),
                .init(title: "init(horizontalSizeClass:)", path: "/documentation/symbolkit/uiviewcontroller/init(horizontalsizeclass:)", type: "symbol"),
                .init(title: "case invalidAPIKey", path: "/documentation/symbolkit/purchasesdiagnostics/sdkhealtherror/invalidapikey", type: "case"),
                .init(title: "horizontalSizeClass", path: "/documentation/symbolkit/uiviewcontroller/horizontalsizeclass", type: "symbol"),
                .init(title: "static func != (Self, Self) -> Bool", path: "/documentation/symbolkit/value/!=(_:_:)", type: "op"),
                .init(title: "subscript(String) -> Offering?", path: "/documentation/symbolkit/offerings/subscript(_:)", type: "subscript"),
                .init(title: "Content", path: "/documentation/symbolkit/rawdatacontainer/content", type: "associatedtype"),
                .init(title: "RevenueCat 4.x to 5.x Migration Guide", path: "/documentation/symbolkit/v5_api_migration_guide", type: "article"),
                .init(title: "Foundation", path: "/documentation/symbolkit/foundation", type: "extension")
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
        #expect(symbolKind(title: "PurchasesDiagnostics.SDKHealthError") == .enumeration)
        #expect(symbolKind(title: "init(horizontalSizeClass:)") == .initializer)
        #expect(symbolKind(title: "case invalidAPIKey") == .enumerationCase)
        #expect(symbolKind(title: "horizontalSizeClass") == .property)
        #expect(symbolKind(title: "static func != (Self, Self) -> Bool") == .function)
        #expect(symbolKind(title: "subscript(String) -> Offering?") == .method)
        #expect(symbolKind(title: "Content") == .typeAlias)
        #expect(symbolKind(title: "RevenueCat 4.x to 5.x Migration Guide") == .article)
        #expect(symbolKind(title: "Foundation") == .structure)
    }

    @Test
    func docCSearchPreservesCustomIndexIcons() {
        let indexPayload = DocCIndex(
            interfaceLanguages: [
                "swift": [
                    .init(
                        title: "WWDC Notes",
                        path: "/documentation/wwdcnotes",
                        type: "module",
                        icon: "WWDCNotes.png",
                        children: [
                            .init(
                                title: "WWDC25",
                                path: "/documentation/wwdcnotes/wwdc25",
                                type: "symbol",
                                icon: "WWDC25-Icon.png"
                            )
                        ]
                    )
                ]
            ],
            includedArchiveIdentifiers: ["WWDCNotes"]
        )
        let site = makeDocCSource(urlSuffix: "wwdcnotes", index: indexPayload)
        let index = SidebarSearchIndex(technologies: [.docC(site)])

        guard case .reference(let reference) = index.search("wwdc25").flattenedRows.first else {
            Issue.record("Expected a DocC reference search result.")
            return
        }

        #expect(reference.customIconIdentifier == "WWDC25-Icon.png")
        #expect(reference.site?.index.includedArchiveIdentifiers == ["WWDCNotes"])
        #expect(reference.symbolKind == .article)
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
    func sourceIndexClassifiesReferenceBeforeReferenceFallbacks() throws {
        let site = makeDocCSource(
            title: "RevenueCat",
            children: [
                .init(
                    title: "PurchasesDiagnostics.SDKHealthError",
                    path: "/documentation/revenuecat/purchasesdiagnostics/sdkhealtherror",
                    type: "enum"
                )
            ]
        )
        let data = """
        {
          "title": "PurchasesDiagnostics.SDKHealthError",
          "identifier": "doc://com.example/documentation/revenuecat/purchasesdiagnostics/sdkhealtherror",
          "type": "symbol",
          "role": "symbol"
        }
        """.data(using: .utf8)!
        var reference = try JSONDecoder().decode(Reference.self, from: data)
        reference.docCSite = site

        #expect(SearchSymbolResolver.symbolKind(for: reference, title: "PurchasesDiagnostics.SDKHealthError", site: site) == .enumeration)
    }

    @Test
    func appleReferenceContextClassifiesBareFunctionSymbols() throws {
        let bareData = """
        {
          "title": "NSApplicationMain",
          "identifier": "doc://com.apple.appkit/documentation/AppKit/NSApplicationMain",
          "url": "/documentation/appkit/nsapplicationmain",
          "type": "topic",
          "role": "symbol",
          "fragments": [
            { "text": "NSApplicationMain", "kind": "identifier" }
          ]
        }
        """.data(using: .utf8)!
        let overloadData = """
        {
          "title": "NSApplicationMain(_:_:)",
          "identifier": "doc://com.apple.appkit/documentation/AppKit/NSApplicationMain(_:_:)",
          "url": "/documentation/appkit/nsapplicationmain(_:_:)",
          "type": "topic",
          "role": "symbol",
          "fragments": [
            { "text": "func", "kind": "keyword" },
            { "text": " ", "kind": "text" },
            { "text": "NSApplicationMain", "kind": "identifier" }
          ]
        }
        """.data(using: .utf8)!
        let bareReference = try JSONDecoder().decode(Reference.self, from: bareData)
        let overloadReference = try JSONDecoder().decode(Reference.self, from: overloadData)

        let symbolKind = SearchSymbolResolver.symbolKind(
            for: bareReference,
            title: "NSApplicationMain",
            site: nil,
            referenceContext: [overloadReference.identifier: overloadReference]
        )

        #expect(symbolKind == .function)
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
    func nonEmptyQueryClearsStaleResultsBeforeSearching() async {
        let site = makeDocCSource(
            title: "FreshKit",
            children: [
                .init(title: "First Result", path: "/documentation/fresh/first", type: "symbol"),
                .init(title: "Second Result", path: "/documentation/fresh/second", type: "symbol")
            ]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))

        store.updateSearchText("first", debounce: .zero)
        await waitForSearch(store)
        #expect(store.results.sections.first?.rows.map(\.title) == ["First Result"])

        store.updateSearchText("second", debounce: .milliseconds(200))
        #expect(store.results.isEmpty)
        #expect(store.isSearching)

        await waitForSearch(store)
        #expect(store.results.sections.first?.rows.map(\.title) == ["Second Result"])
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
    func replacementIndexInstallPreservesVisibleResultsWhileSearching() async {
        let firstSite = makeDocCSource(
            title: "FirstKit",
            children: [.init(title: "Shared Result Old", path: "/documentation/preserve/old", type: "symbol")]
        )
        let secondSite = makeDocCSource(
            title: "SecondKit",
            children: [.init(title: "Shared Result New", path: "/documentation/preserve/new", type: "symbol")]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(firstSite)]))
        store.updateSearchText("shared result", debounce: .zero)
        await waitForSearch(store)
        #expect(store.results.sections.first?.rows.map(\.title) == ["Shared Result Old"])

        store.installIndex(
            SidebarSearchIndex(technologies: [.docC(secondSite)]),
            searchDebounce: .milliseconds(200),
            preserveExistingResults: true
        )

        #expect(store.isSearching)
        #expect(store.results.sections.first?.rows.map(\.title) == ["Shared Result Old"])

        await waitForSearch(store)
        #expect(store.results.sections.first?.rows.map(\.title) == ["Shared Result New"])
    }

    @Test
    @MainActor
    func rebuildIndexReportsUpdatingWhenExistingIndexIsInstalled() async {
        let initialSite = makeDocCSource(
            title: "InitialKit",
            children: [.init(title: "Initial Result", path: "/documentation/update/initial", type: "symbol")]
        )
        let updatedSite = makeDocCSource(
            title: "UpdatedKit",
            children: [.init(title: "Updated Result", path: "/documentation/update/updated", type: "symbol")]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(initialSite)]))

        store.rebuildIndex(
            technologies: [.docC(updatedSite)],
            searchText: "updated",
            sourceFingerprint: "updated-fingerprint"
        )

        #expect(store.indexBuildTitle == "Updating Index")
        await waitForSearch(store)
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

        #expect(coordinator.open(.homepage(id: "home", title: "Discover"), openURL: openURL))
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

        #expect(coordinator.open(technologyRow, openURL: openURL))
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

        #expect(coordinator.open(referenceRow, openURL: openURL))
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

    @Test
    func storingNewCachePrunesStaleCacheFiles() async throws {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("DocBCoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: applicationSupportDirectory)
        }

        let cache = SidebarSearchIndexCache(applicationSupportDirectory: applicationSupportDirectory)
        let firstIndex = SidebarSearchIndex(technologies: [.docC(makeDocCSource(
            title: "FirstKit",
            children: [.init(title: "FirstSymbol", path: "/documentation/firstkit/firstsymbol", type: "symbol")]
        ))])
        let secondIndex = SidebarSearchIndex(technologies: [.docC(makeDocCSource(
            title: "SecondKit",
            children: [.init(title: "SecondSymbol", path: "/documentation/secondkit/secondsymbol", type: "symbol")]
        ))])

        await cache.store(firstIndex, for: "first-fingerprint")
        await cache.store(secondIndex, for: "second-fingerprint")

        #expect(await cache.index(for: "first-fingerprint") == nil)
        #expect(await cache.index(for: "second-fingerprint") != nil)

        let cacheDirectory = applicationSupportDirectory
            .appendingPathComponent("DocB", isDirectory: true)
            .appendingPathComponent("SearchIndexCache", isDirectory: true)
        let cacheFiles = try fileManager.contentsOfDirectory(atPath: cacheDirectory.path)
            .filter { $0.hasSuffix(".bin") }
        #expect(cacheFiles.count == 1)
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
