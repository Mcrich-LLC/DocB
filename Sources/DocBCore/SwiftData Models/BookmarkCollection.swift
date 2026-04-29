//
//  BookmarkCollection.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftData
import SwiftUI

/// BookmarkCollectionDTO encapsulates app behavior and state.
@MainActor
public final class BookmarkCollectionDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    public nonisolated static func == (lhs: BookmarkCollectionDTO, rhs: BookmarkCollectionDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes collection identity and key display content.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(bookmarks)
    }
    
    /// Stable identifier for the DTO instance.
    public let id: UUID
    /// Display title of the bookmark collection.
    public var title: String
    /// String of an SFSymbol treated as an icon for the collection
    public var sfSymbolName: String
    /// A codable structure representing a chosen color.
    private var colorComponents: ColorComponents
    /// The user's chosen accent color
    public var color: Color {
        get {
            colorComponents.toColor()
        }
        set {
            colorComponents = newValue.components()
        }
    }
    /// Last update timestamp used for sorting and recency.
    public var lastUpdatedDate: Date
    /// Flattened bookmark DTOs contained by this collection.
    public var bookmarks: [BookmarkDTO]
    /// Persistent SwiftData identifier used for delete-by-dto operations.
    public fileprivate(set) var persistentModelID: PersistentIdentifier?
    
    /// Creates a collection DTO from explicit fields.
    public init(title: String, sfSymbolName: String = "folder", color: Color, lastUpdatedDate: Date = .now, bookmarks: [BookmarkDTO]) {
        self.id = UUID()
        self.title = title
        self.sfSymbolName = sfSymbolName
        self.colorComponents = color.components()
        self.lastUpdatedDate = lastUpdatedDate
        self.bookmarks = bookmarks
        self.persistentModelID = nil
    }
    
    /// Creates a collection DTO from a persisted `BookmarkCollection` model.
    public init(_ model: BookmarkCollection) throws {
        guard let title = model.title, let lastUpdatedDate = model.lastUpdatedDate else {
            throw SwiftDataErrors.invalidShape
        }
        
        // Get all bookmarks and convert them to DTO objects
        let bookmarks = (model.bookmarks ?? []).compactMap({ try? $0.dto })
        
        self.id = model.id
        self.title = title
        self.sfSymbolName = model.sfSymbolName ?? "folder"
        self.colorComponents = model.colorComponents ?? Color.accentColor.components()
        self.bookmarks = bookmarks
        self.lastUpdatedDate = lastUpdatedDate
        self.persistentModelID = model.persistentModelID
    }
    
    /// Decodes a bookmark-collection DTO from persisted JSON payload data.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.sfSymbolName = try container.decode(String.self, forKey: .sfSymbolName)
        self.colorComponents = try container.decode(ColorComponents.self, forKey: .colorComponents)
        self.lastUpdatedDate = try container.decode(Date.self, forKey: .lastUpdatedDate)
        self.bookmarks = try container.decode([BookmarkDTO].self, forKey: .bookmarks)
    }
    
    /// Coding keys for bookmark-collection DTO serialization.
    public enum CodingKeys: String, CodingKey {
        case title
        case sfSymbolName
        case colorComponents
        case bookmarks
        case lastUpdatedDate
    }
    
    /// Deletes the underlying persisted collection if this DTO is backed by SwiftData.
    public func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

/// BookmarkCollection encapsulates app behavior and state.
@Model
public final class BookmarkCollection: Identifiable {
    /// Stable identifier for the persisted collection.
    public var id = UUID()
    /// Optional display title for the collection.
    public var title: String?
    /// Optional string of an SFSymbol treated as an icon for the collection
    public var sfSymbolName: String?
    /// Optional codable structure representing a chosen color.
    fileprivate var colorComponents: ColorComponents?
    /// The accent color for the collection
    public var color: Color {
        get {
            colorComponents?.toColor() ?? .accentColor
        }
        set {
            colorComponents = newValue.components()
        }
    }
    
    /// Optional timestamp used to sort collections by recency.
    public var lastUpdatedDate: Date?
    /// CloudKit record type last imported by the explicit MYCloudKit sync engine.
    public var cloudKitRecordType: String?
    /// CloudKit root group or zone identifier used by the explicit sync engine.
    public var cloudKitRootGroupID: String?
    /// CloudKit parent record identifier used for hierarchical sync, when present.
    public var cloudKitParentID: String?
    /// Date when this model was last merged from CloudKit by the explicit sync engine.
    public var cloudKitLastImportedAt: Date?
    /// Bookmark members belonging to the collection.
    public var bookmarks: [Bookmark]?
    
    /// Creates a new bookmark collection model.
    public init(title: String, sfSymbolName: String = "folder", color: Color, bookmarks: [Bookmark], lastUpdatedDate: Date = .now) {
        self.title = title
        self.sfSymbolName = sfSymbolName
        self.colorComponents = color.components()
        self.lastUpdatedDate = lastUpdatedDate
        self.bookmarks = bookmarks
    }
    
    @MainActor
    public var dto: BookmarkCollectionDTO {
        get throws {
            try BookmarkCollectionDTO(self)
        }
    }
    
    /// Groups bookmarks by their source base URL for sectioned presentation.
    public var bookmarksWithinUrls: [URL : [Bookmark]] {
        (bookmarks ?? []).reduce(into: [:]) { result, bookmark in
            guard let siteBaseURL = bookmark.siteBaseURL else { return }
            
            result[siteBaseURL, default: []].append(bookmark)
        }
    }
}
