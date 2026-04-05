//
//  BookmarkCollection.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
/// BookmarkCollectionDTO encapsulates app behavior and state.
final class BookmarkCollectionDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    nonisolated static func == (lhs: BookmarkCollectionDTO, rhs: BookmarkCollectionDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes collection identity and key display content.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(bookmarks)
    }
    
    /// Stable identifier for the DTO instance.
    let id: UUID
    /// Display title of the bookmark collection.
    var title: String
    /// Last update timestamp used for sorting and recency.
    var lastUpdatedDate: Date
    /// Flattened bookmark DTOs contained by this collection.
    var bookmarks: [BookmarkDTO]
    /// Persistent SwiftData identifier used for delete-by-dto operations.
    fileprivate var persistentModelID: PersistentIdentifier?
    
    /// Creates a collection DTO from explicit fields.
    init(title: String, lastUpdatedDate: Date = .now, bookmarks: [BookmarkDTO]) {
        self.id = UUID()
        self.title = title
        self.lastUpdatedDate = lastUpdatedDate
        self.bookmarks = bookmarks
        self.persistentModelID = nil
    }
    
    /// Creates a collection DTO from a persisted `BookmarkCollection` model.
    init(_ model: BookmarkCollection) throws {
        guard let title = model.title, let lastUpdatedDate = model.lastUpdatedDate else {
            throw SwiftDataErrors.invalidShape
        }
        
        // Get all bookmarks and convert them to DTO objects
        let bookmarks = (model.bookmarks ?? []).compactMap({ try? $0.dto })
        
        self.id = model.id
        self.title = title
        self.bookmarks = bookmarks
        self.lastUpdatedDate = lastUpdatedDate
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.lastUpdatedDate = try container.decode(Date.self, forKey: .lastUpdatedDate)
        self.bookmarks = try container.decode([BookmarkDTO].self, forKey: .bookmarks)
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case bookmarks
        case lastUpdatedDate
    }
    
    /// Deletes the underlying persisted collection if this DTO is backed by SwiftData.
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

@Model
/// BookmarkCollection encapsulates app behavior and state.
final class BookmarkCollection: Identifiable {
    /// Stable identifier for the persisted collection.
    var id = UUID()
    /// Optional display title for the collection.
    var title: String?
    /// Optional timestamp used to sort collections by recency.
    var lastUpdatedDate: Date?
    /// Bookmark members belonging to the collection.
    var bookmarks: [Bookmark]?
    
    /// Creates a new bookmark collection model.
    init(title: String, bookmarks: [Bookmark], lastUpdatedDate: Date = .now) {
        self.title = title
        self.lastUpdatedDate = lastUpdatedDate
        self.bookmarks = bookmarks
    }
    
    @MainActor
    var dto: BookmarkCollectionDTO {
        get throws {
            try BookmarkCollectionDTO(self)
        }
    }
    
    /// Groups bookmarks by their source base URL for sectioned presentation.
    var bookmarksWithinUrls: [URL : [Bookmark]] {
        (bookmarks ?? []).reduce(into: [:]) { result, bookmark in
            guard let siteBaseURL = bookmark.siteBaseURL else { return }
            
            result[siteBaseURL, default: []].append(bookmark)
        }
    }
}
