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
        hasher.combine(identifier)
        hasher.combine(kind)
        hasher.combine(type)
        hasher.combine(role)
        hasher.combine(deprecated)
        hasher.combine(beta)
        hasher.combine(siteBaseURL)
    }
    
    let id: UUID
    var title: String
    var identifier: String
    var kind: String?
    var type: String
    var role: Role?
    var deprecated: Bool
    var beta: Bool
    var siteBaseURL: URL
    fileprivate var persistentModelID: PersistentIdentifier?
    
    init(title: String, identifier: String, kind: String?, type: String, role: Role?, deprecated: Bool, beta: Bool, siteBaseURL: URL) {
        self.id = UUID()
        self.title = title
        self.identifier = identifier
        self.kind = kind
        self.type = type
        self.role = role
        self.deprecated = deprecated
        self.beta = beta
        self.siteBaseURL = siteBaseURL
        self.persistentModelID = nil
    }
    
    init(reference: Reference) throws {
        guard let title = reference.title, !title.isEmpty, let externalURLHost = reference.externalURL?.host(), let siteBaseURL = URL(string: externalURLHost) else {
            throw BookmarkErrors.invalidReference
        }
        
        self.id = UUID()
        self.title = title
        self.identifier = reference.identifier
        self.kind = reference.kind
        self.type = reference.type
        self.role = reference.role
        self.deprecated = reference.deprecated ?? false
        self.beta = reference.beta ?? false
        
        self.siteBaseURL = siteBaseURL
        self.persistentModelID = nil
    }
    
    init(_ model: Bookmark) throws {
        guard let title = model.title, let siteBaseURL = model.siteBaseURL, let identifier = model.identifier, let type = model.type else {
            throw SwiftDataErrors.invalidShape
        }
        
        self.id = model.id
        self.title = title
        self.identifier = identifier
        self.kind = model.kind
        self.type = type
        self.role = model.role
        self.deprecated = model.deprecated ?? false
        self.beta = model.beta ?? false
        self.siteBaseURL = siteBaseURL
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.type = try container.decode(String.self, forKey: .type)
        self.role = try container.decodeIfPresent(Role.self, forKey: .role)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        self.beta = try container.decodeIfPresent(Bool.self, forKey: .beta) ?? false
        self.siteBaseURL = try container.decode(URL.self, forKey: .siteBaseURL)
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case identifier
        case kind
        case type
        case role
        case deprecated
        case beta
        case siteBaseURL
    }
    
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

enum BookmarkErrors: Error {
    case invalidReference
}

@Model
final class Bookmark: Identifiable {
    var id = UUID()
    var title: String?
    var identifier: String?
    var kind: String?
    var type: String?
    var role: Role?
    var deprecated: Bool?
    var beta: Bool?
    var siteBaseURL: URL?
    
    @Relationship(deleteRule: .cascade, inverse: \BookmarkCollection.bookmarks)
    var collection: BookmarkCollection?
    
    init(title: String? = nil, identifier: String, kind: String? = nil, type: String, role: Role? = nil, deprecated: Bool? = nil, beta: Bool? = nil, siteBaseURL: URL? = nil) {
        self.title = title
        self.identifier = identifier
        self.kind = kind
        self.type = type
        self.role = role
        self.deprecated = deprecated
        self.beta = beta
        self.siteBaseURL = siteBaseURL
        self.collection = collection
    }
    
    init(reference: Reference) throws {
        guard let title = reference.title, !title.isEmpty, let externalURLHost = reference.externalURL?.host(), let siteBaseURL = URL(string: externalURLHost) else {
            throw BookmarkErrors.invalidReference
        }
        
        self.title = title
        self.identifier = reference.identifier
        self.kind = reference.kind
        self.type = reference.type
        self.role = reference.role
        self.deprecated = reference.deprecated ?? false
        self.beta = reference.beta ?? false
        self.siteBaseURL = siteBaseURL
    }
    
    @MainActor
    var dto: BookmarkDTO {
        get throws {
            try BookmarkDTO(self)
        }
    }
    
    var asReference: Reference? {
        guard let identifier, let type else { return nil }
        
        return Reference(title: title, identifier: identifier, kind: kind, type: type, role: role, deprecated: deprecated, beta: beta)
    }
    
    func asReferenceWithDocCSite(from technologies: [TechnologyTypes]) -> Reference? {
        guard let identifier, let type, let siteBaseURL else { return nil }
        
        return Reference(title: title, identifier: identifier, kind: kind, type: type, role: role, deprecated: deprecated, beta: beta, docCSite: technologies.docCSites.first(where: { $0.url.absoluteString.contains(siteBaseURL.absoluteString) }))
    }
}
