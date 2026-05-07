@testable import DocBCore
import DocCKit
import Foundation
import XCTest

final class SidebarSearchIndexTests: XCTestCase {
    func testDocCNestedMatchesAndModulesAreExcluded() {
        let site = makeDocCSource(
            title: "FreezeKit",
            children: [
                .init(title: "MainActorSearchController", path: "/documentation/freezekit/searchcontroller", type: "symbol")
            ]
        )
        let index = SidebarSearchIndex(technologies: [.docC(site)])
        
        let childResults = index.search("mainactor")
        XCTAssertEqual(childResults.sections.count, 1)
        XCTAssertEqual(childResults.sections.first?.title, "FreezeKit")
        XCTAssertEqual(childResults.sections.first?.rows.first?.title, "MainActorSearchController")
        
        let moduleResults = index.search("freezekit")
        XCTAssertTrue(moduleResults.isEmpty)
    }
    
    func testAppleFrameworkTitleAndTagMatches() throws {
        let appleTechnologies = try makeAppleTechnologies()
        let index = SidebarSearchIndex(technologies: [.apple(appleTechnologies)])
        
        let titleResults = index.search("swiftui")
        XCTAssertEqual(titleResults.sections.count, 1)
        XCTAssertEqual(titleResults.sections.first?.title, "Apple Documentation")
        XCTAssertTrue(titleResults.sections.first?.rows.contains { $0.title == "SwiftUI" } == true)
        
        let tagResults = index.search("declarative")
        XCTAssertEqual(tagResults.sections.first?.rows.first?.title, "SwiftUI")
        
        guard case .technology(let result) = tagResults.sections.first?.rows.first else {
            return XCTFail("Expected an Apple technology search result.")
        }
        XCTAssertEqual(result.badgeReference?.beta, true)
    }
    
    func testResultsAreGroupedBySource() {
        let firstSite = makeDocCSource(
            title: "FirstKit",
            children: [
                .init(title: "SharedMatchOne", path: "/documentation/first/match", type: "symbol")
            ],
            timestamp: 1
        )
        let secondSite = makeDocCSource(
            title: "SecondKit",
            children: [
                .init(title: "SharedMatchTwo", path: "/documentation/second/match", type: "symbol")
            ],
            timestamp: 2
        )
        let index = SidebarSearchIndex(technologies: [.docC(firstSite), .docC(secondSite)])
        
        let results = index.search("sharedmatch")
        
        XCTAssertEqual(results.sections.map(\.title), ["FirstKit", "SecondKit"])
        XCTAssertEqual(results.sections.map { $0.rows.count }, [1, 1])
    }
    
    func testResultLimitReportsTruncation() {
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
        
        XCTAssertEqual(results.totalMatches, 5)
        XCTAssertTrue(results.isTruncated)
        XCTAssertEqual(results.sections.first?.rows.count, 3)
    }
    
    func testDocCMultiLanguageDuplicatePathsHaveUniqueIDs() {
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
        
        XCTAssertEqual(rows.map(\.title), ["Objective-C Shared Symbol", "Swift Shared Symbol"])
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }
    
    func testDocCSearchIncludesHistoricalOccIndexKey() {
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
        
        XCTAssertEqual(index.search("historical").sections.first?.rows.first?.title, "Historical Objective-C Symbol")
    }
    
    @MainActor
    func testStoreCancelsStaleQueries() async {
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
        
        XCTAssertEqual(store.results.sections.first?.rows.map(\.title), ["Second Result"])
    }
    
    @MainActor
    func testRepeatedQueriesReuseInstalledIndex() async {
        let site = makeDocCSource(
            title: "ReuseKit",
            children: [
                .init(title: "Reusable Search Result", path: "/documentation/reuse/result", type: "symbol")
            ]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(site)]))
        let buildCount = store.indexBuildCount
        
        store.updateSearchText("reusable", debounce: .zero)
        await waitForSearch(store)
        store.updateSearchText("search", debounce: .zero)
        await waitForSearch(store)
        
        XCTAssertEqual(store.indexBuildCount, buildCount)
        XCTAssertEqual(store.results.sections.first?.rows.first?.title, "Reusable Search Result")
    }
    
    @MainActor
    func testInstallIndexInvalidatesPendingQueryAndRerunsCurrentSearch() async {
        let firstSite = makeDocCSource(
            title: "FirstKit",
            children: [
                .init(title: "Old Result", path: "/documentation/install/old", type: "symbol")
            ]
        )
        let secondSite = makeDocCSource(
            title: "SecondKit",
            children: [
                .init(title: "New Result", path: "/documentation/install/new", type: "symbol")
            ]
        )
        let store = SidebarSearchStore()
        store.installIndex(SidebarSearchIndex(technologies: [.docC(firstSite)]))
        
        store.updateSearchText("result", debounce: .milliseconds(200))
        XCTAssertTrue(store.isSearching)
        
        store.installIndex(SidebarSearchIndex(technologies: [.docC(secondSite)]))
        await waitForSearch(store)
        
        XCTAssertFalse(store.isRebuildingIndex)
        XCTAssertEqual(store.results.sections.first?.rows.map(\.title), ["New Result"])
    }
    
    @MainActor
    func testRebuildIndexKeepsAllAvailableLanguageBuckets() async {
        let site = makeDocCSource(
            urlSuffix: "switchkit",
            index: DocCIndex(interfaceLanguages: [
                "swift": [
                    .init(
                        title: "SwitchKit",
                        path: "/documentation/switchkit",
                        type: "module",
                        children: [
                            .init(title: "Swift Switch Result", path: "/documentation/switchkit/result", type: "symbol")
                        ]
                    )
                ],
                "objc": [
                    .init(
                        title: "SwitchKit",
                        path: "/documentation/switchkit",
                        type: "module",
                        children: [
                            .init(title: "Objective-C Switch Result", path: "/documentation/switchkit/result", type: "symbol")
                        ]
                    )
                ]
            ])
        )
        let store = SidebarSearchStore()
        store.updateSearchText("switch result", debounce: .zero)
        store.rebuildIndex(technologies: [.docC(site)], searchText: "switch result")
        await waitForSearch(store)
        XCTAssertEqual(store.results.sections.first?.rows.map(\.title), ["Objective-C Switch Result", "Swift Switch Result"])
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
}
