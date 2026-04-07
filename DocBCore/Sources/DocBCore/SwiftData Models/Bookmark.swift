//
//  Bookmark.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData

@MainActor
/// BookmarkDTO encapsulates app behavior and state.
final class BookmarkDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    nonisolated static func == (lhs: BookmarkDTO, rhs: BookmarkDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes bookmark identity and content fields for set/dictionary usage.
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
    
    /// Stable identifier for the DTO instance.
    let id: UUID
    /// Display title shown in bookmark lists.
    var title: String
    /// Canonical documentation identifier (for example `doc://...`).
    var identifier: String
    /// Optional kind metadata from the source reference.
    var kind: String?
    /// Reference type metadata (article, symbol, etc.).
    var type: String
    /// Optional role used for UI iconography and formatting.
    var role: Role?
    /// Whether the referenced symbol/content is deprecated.
    var deprecated: Bool
    /// Whether the referenced symbol/content is marked beta.
    var beta: Bool
    /// Base source URL for the documentation site hosting this reference.
    var siteBaseURL: URL
    /// Persistent SwiftData identifier used for delete-by-dto operations.
    fileprivate var persistentModelID: PersistentIdentifier?
    
    /// Creates a DTO from explicit bookmark fields.
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
    
    /// Creates a DTO from a `Reference`, validating required values for bookmarking.
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
    
    /// Creates a DTO from a persisted `Bookmark` model.
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
    
    /// Decodes a bookmark DTO from persisted JSON payload data.
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
    
    /// Coding keys for bookmark DTO serialization.
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
    
    /// Deletes the underlying persisted bookmark when this DTO is backed by SwiftData.
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

/// BookmarkErrors defines a constrained set of related values.
enum BookmarkErrors: Error {
    case invalidReference
}

@Model
/// Bookmark encapsulates app behavior and state.
public final class Bookmark: Identifiable {
    /// Stable identifier for this persisted bookmark.
    public var id = UUID()
    /// Optional display title of the bookmark target.
    var title: String?
    /// Canonical documentation identifier for deep linking.
    var identifier: String?
    /// Optional kind metadata from source reference payload.
    var kind: String?
    /// Reference type metadata (article, symbol, etc.).
    var type: String?
    /// Optional role metadata used for rendering semantics.
    var role: Role?
    /// Optional deprecation state mirrored from reference payload.
    var deprecated: Bool?
    /// Optional beta state mirrored from reference payload.
    var beta: Bool?
    /// Base URL for the source documentation site.
    var siteBaseURL: URL?
    
    @Relationship(deleteRule: .nullify, inverse: \BookmarkCollection.bookmarks)
    /// Owning collection relationship; nullified if the collection is removed.
    var collection: BookmarkCollection?
    
    /// Creates a bookmark model from explicit persisted fields.
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
    
    /// Creates a bookmark model from a parsed `Reference`.
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
    
    /// Reconstructs a reference object from stored bookmark fields.
    var asReference: Reference? {
        guard let identifier, let type else { return nil }
        
        return Reference(title: title, identifier: identifier, kind: kind, type: type, role: role, deprecated: deprecated, beta: beta)
    }
    
    /// Reconstructs a reference and attaches a resolved DocC site from known technologies.
    func asReferenceWithDocCSite(from technologies: [TechnologyTypes]) -> Reference? {
        guard let identifier, let type, let siteBaseURL else { return nil }
        
        return Reference(title: title, identifier: identifier, kind: kind, type: type, role: role, deprecated: deprecated, beta: beta, docCSite: technologies.docCSites.first(where: { $0.url.absoluteString.contains(siteBaseURL.absoluteString) }))
    }
}
