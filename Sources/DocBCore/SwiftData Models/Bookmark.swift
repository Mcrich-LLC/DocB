//
//  Bookmark.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData
import DocCKit
import MYCloudKit

/// BookmarkDTO encapsulates app behavior and state.
@MainActor
public final class BookmarkDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    public nonisolated static func == (lhs: BookmarkDTO, rhs: BookmarkDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes bookmark identity and content fields for set/dictionary usage.
    public func hash(into hasher: inout Hasher) {
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
    public let id: UUID
    /// Display title shown in bookmark lists.
    public var title: String
    /// Canonical documentation identifier (for example `doc://...`).
    public var identifier: String
    /// Optional kind metadata from the source reference.
    public var kind: String?
    /// Reference type metadata (article, symbol, etc.).
    public var type: String
    /// Optional role used for UI iconography and formatting.
    public var role: Role?
    /// Whether the referenced symbol/content is deprecated.
    public var deprecated: Bool
    /// Whether the referenced symbol/content is marked beta.
    public var beta: Bool
    /// Base source URL for the documentation site hosting this reference.
    public var siteBaseURL: URL
    /// Persistent SwiftData identifier used for delete-by-dto operations.
    public fileprivate(set) var persistentModelID: PersistentIdentifier?
    
    /// Creates a DTO from explicit bookmark fields.
    public init(title: String, identifier: String, kind: String?, type: String, role: Role?, deprecated: Bool, beta: Bool, siteBaseURL: URL) {
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
    public init(reference: Reference) throws {
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
    public init(_ model: Bookmark) throws {
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
    public init(from decoder: any Decoder) throws {
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
    public enum CodingKeys: String, CodingKey {
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
    public func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

/// BookmarkErrors defines a constrained set of related values.
public enum BookmarkErrors: Error {
    case invalidReference
}

/// Bookmark encapsulates app behavior and state.
@Model
public final class Bookmark: Identifiable {
    /// Stable identifier for this persisted bookmark.
    public var id = UUID()
    /// Optional display title of the bookmark target.
    public var title: String?
    /// Canonical documentation identifier for deep linking.
    public var identifier: String?
    /// Optional kind metadata from source reference payload.
    public var kind: String?
    /// Reference type metadata (article, symbol, etc.).
    public var type: String?
    /// Optional role metadata used for rendering semantics.
    public var role: Role?
    /// Optional deprecation state mirrored from reference payload.
    public var deprecated: Bool?
    /// Optional beta state mirrored from reference payload.
    public var beta: Bool?
    /// Base URL for the source documentation site.
    public var siteBaseURL: URL?
    /// Stable identifier of the owning collection used by CloudKit sync.
    public var collectionID: UUID?
    
    /// Owning collection relationship.
    public var collection: BookmarkCollection?
    
    /// Creates a bookmark model from explicit persisted fields.
    public init(
        title: String? = nil,
        identifier: String,
        kind: String? = nil,
        type: String,
        role: Role? = nil,
        deprecated: Bool? = nil,
        beta: Bool? = nil,
        siteBaseURL: URL? = nil,
        collection: BookmarkCollection? = nil,
        collectionID: UUID? = nil
    ) {
        self.title = title
        self.identifier = identifier
        self.kind = kind
        self.type = type
        self.role = role
        self.deprecated = deprecated
        self.beta = beta
        self.siteBaseURL = siteBaseURL
        self.collection = collection
        self.collectionID = collectionID ?? collection?.id
    }
    
    /// Creates a bookmark model from a parsed `Reference`.
    public init(reference: Reference) throws {
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
    
    /// Updates the owning collection and sync identifier together.
    public func setCollection(_ collection: BookmarkCollection?) {
        self.collection = collection
        self.collectionID = collection?.id
    }
    
    @MainActor
    public var dto: BookmarkDTO {
        get throws {
            try BookmarkDTO(self)
        }
    }
    
    /// Reconstructs a reference object from stored bookmark fields.
    public var asReference: Reference? {
        guard let identifier, let type else { return nil }
        
        return Reference(title: title, identifier: identifier, kind: kind, type: type, role: role, deprecated: deprecated, beta: beta)
    }
    
    /// Reconstructs a reference and attaches a resolved DocC site from known technologies.
    @MainActor
    public func asReferenceWithDocCSite(from technologies: [TechnologyTypes]) -> Reference? {
        guard let identifier, let type, let siteBaseURL else { return nil }
        
        return Reference(
            title: title,
            identifier: identifier,
            kind: kind,
            type: type,
            role: role,
            deprecated: deprecated,
            beta: beta,
            docCSite: technologies.docCSites.first { $0.url.absoluteString.contains(siteBaseURL.absoluteString) }
        )
    }
}

extension Bookmark: MYRecordConvertible {
    /// Unique CloudKit record identifier for this bookmark.
    public var myRecordID: String { id.uuidString }
    
    /// CloudKit record type used for bookmarks.
    public var myRecordType: String { DocBCloudRecordTypes.bookmark }
    
    /// Root CloudKit group matching the owning collection, when available.
    public var myRootGroupID: String? { (collectionID ?? collection?.id)?.uuidString }
    
    /// CloudKit-compatible properties for this bookmark.
    public var myProperties: [String : MYRecordValue] {
        [
            "title": .string(title),
            "identifier": .string(identifier),
            "kind": .string(kind),
            "type": .string(type),
            "role": .string(role?.rawValue),
            "deprecated": .bool(deprecated),
            "beta": .bool(beta),
            "siteBaseURL": .string(siteBaseURL?.absoluteString),
            "collectionID": .string((collectionID ?? collection?.id)?.uuidString),
            "collection": .reference(collection, deleteRule: .deleteSelf)
        ]
    }
}
