@testable import DocBCore
import Foundation
import MYCloudKit
import SwiftData
import SwiftUI
import XCTest

@MainActor
final class DocBCloudSyncEngineTests: XCTestCase {
    func testBookmarkKeepsCollectionIDWhenRelationshipIsMissing() {
        let collectionID = UUID()
        let bookmark = Bookmark(title: "Article", identifier: "doc://article", type: "article", collectionID: collectionID)
        
        XCTAssertEqual(bookmark.myRootGroupID, collectionID.uuidString)
        XCTAssertEqual(bookmark.myProperties["collectionID"]?.stringValue, collectionID.uuidString)
    }
    
    func testLocalCollectionDeleteRemovesBookmarks() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let collection = BookmarkCollection(title: "Saved", color: .accentColor, bookmarks: [])
        let bookmark = Bookmark(title: "Article", identifier: "doc://article", type: "article", collection: collection)
        
        context.insert(collection)
        context.insert(bookmark)
        try context.save()
        
        context.delete(collection)
        try context.save()
        
        XCTAssertTrue(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BookmarkCollection>()).isEmpty)
    }

    func testDocCSiteSyncPayloadStaysMetadataOnly() {
        let site = DocCSite(
            url: URL(string: "https://example.com")!,
            overrideName: "Example",
            index: .init(interfaceLanguages: [:])
        )
        
        XCTAssertEqual(Set(site.myProperties.keys), ["timestamp", "url", "overrideName"])
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DocCSite.self,
            Bookmark.self,
            BookmarkCollection.self,
            configurations: configuration
        )
    }
}

private extension MYRecordValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        
        return nil
    }
}
