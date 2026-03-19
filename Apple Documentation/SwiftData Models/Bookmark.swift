//
//  Bookmark.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
final class BookmarkDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    nonisolated static func == (lhs: BookmarkDTO, rhs: BookmarkDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(reference)
        hasher.combine(siteBaseURL)
    }
    
    let id: UUID
    var title: String
    var reference: Reference
    var siteBaseURL: URL
    fileprivate var persistentModelID: PersistentIdentifier?
    
    init(title: String, reference: Reference, siteBaseURL: URL) {
        self.id = UUID()
        self.title = title
        self.reference = reference
        self.siteBaseURL = siteBaseURL
        self.persistentModelID = nil
    }
    
    init(_ model: Bookmark) throws {
        guard let title = model.title, let reference = model.reference, let siteBaseURL = model.siteBaseURL else {
            throw SwiftDataErrors.invalidShape
        }
        
        self.id = model.id
        self.title = title
        self.reference = reference
        self.siteBaseURL = siteBaseURL
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.reference = try container.decode(Reference.self, forKey: .reference)
        self.siteBaseURL = try container.decode(URL.self, forKey: .siteBaseURL)
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case reference
        case siteBaseURL
    }
    
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

@Model
final class Bookmark: Identifiable {
    var id = UUID()
    var title: String?
    var reference: Reference?
    var siteBaseURL: URL?
    
    @Relationship(deleteRule: .cascade, inverse: \BookmarkCollection.bookmarks)
    var collection: BookmarkCollection?
    
    init(id: UUID = UUID(), title: String, reference: Reference, siteBaseURL: URL) {
        self.id = id
        self.title = title
        self.reference = reference
        self.siteBaseURL = siteBaseURL
    }
    
    @MainActor
    var dto: BookmarkDTO {
        get throws {
            try BookmarkDTO(self)
        }
    }
}
