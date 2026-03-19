//
//  BookmarkCollection.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
final class BookmarkCollectionDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    nonisolated static func == (lhs: BookmarkCollectionDTO, rhs: BookmarkCollectionDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(bookmarks)
    }
    
    let id: UUID
    var title: String
    var bookmarks: [BookmarkDTO]
    fileprivate var persistentModelID: PersistentIdentifier?
    
    init(title: String, bookmarks: [BookmarkDTO]) {
        self.id = UUID()
        self.title = title
        self.bookmarks = bookmarks
        self.persistentModelID = nil
    }
    
    init(_ model: BookmarkCollection) throws {
        guard let title = model.title else {
            throw SwiftDataErrors.invalidShape
        }
        
        // Get all bookmarks and convert them to DTO objects
        let bookmarks = (model.bookmarks ?? []).compactMap({ try? $0.dto })
        
        self.id = model.id
        self.title = title
        self.bookmarks = bookmarks
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.bookmarks = try container.decode([BookmarkDTO].self, forKey: .bookmarks)
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case bookmarks
    }
    
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

@Model
final class BookmarkCollection: Identifiable {
    var id = UUID()
    var title: String?
    var bookmarks: [Bookmark]?
    
    init(id: UUID = UUID(), title: String, bookmarks: [Bookmark]) {
        self.id = id
        self.title = title
        self.bookmarks = bookmarks
    }
    
    @MainActor
    var dto: BookmarkCollectionDTO {
        get throws {
            try BookmarkCollectionDTO(self)
        }
    }
}
