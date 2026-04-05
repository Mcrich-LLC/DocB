//
//  DocCSite.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
/// Transfer object that bridges persisted `DocCSite` models and runtime-only DocC site state.
///
/// DTO identity and equality are based on `id`, while hashing also includes timestamp, URL, and index.
final class DocCSiteDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    nonisolated static func == (lhs: DocCSiteDTO, rhs: DocCSiteDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(url)
        hasher.combine(index)
    }
    
    /// Stable identifier used for equality and identity in collections.
    let id: UUID
    /// Timestamp indicating when the site was added.
    let timestamp: Date
    /// Optional override display name for the site.
    let overrideName: String?
    /// Root URL for the DocC site.
    let url: URL
    /// Parsed index describing available interface-language groups and entries.
    private(set) var index: DocCIndex
    fileprivate var persistentModelID: PersistentIdentifier?
    
    /// Creates an in-memory DocC site DTO.
    init(timestamp: Date = .init(), url: URL, overrideName: String? = nil, index: DocCIndex) {
        self.id = UUID()
        self.timestamp = timestamp
        self.url = url
        self.overrideName = overrideName
        self.index = index
        self.persistentModelID = nil
    }
    
    /// Creates a DTO from a persisted `DocCSite` model.
    ///
    /// - Warning: This initializer fails when persisted records are partially populated.
    ///
    /// - Parameter model: A persisted SwiftData model.
    /// - Throws: `SwiftDataErrors.invalidShape` when required fields are missing.
    init(_ model: DocCSite) throws {
        guard let timestamp = model.timestamp, let url = model.url, let index = model.indexV2 else {
            throw SwiftDataErrors.invalidShape
        }
        
        self.id = model.id
        self.timestamp = timestamp
        self.url = url
        self.overrideName = model.overrideName
        self.index = index.asIndex
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.url = try container.decode(URL.self, forKey: .url)
        self.overrideName = try container.decodeIfPresent(String.self, forKey: .overrideName)
        self.index = try container.decode(DocCIndex.self, forKey: .index)
    }
    
    /// Updates the DTO index when a fresh remote index payload is loaded.
    ///
    /// - Parameter index: New index payload for the site.
    func setIndex(_ index: DocCIndex) {
        self.index = index
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case url
        case overrideName
        case index
    }
    
    /// Top-level interface-language groups flattened from the site index.
    var groups: [DocCIndex.InterfaceLanguage] {
        index.interfaceLanguages.flatMap({ $0.value })
    }
    
    /// Framework sections derived from all index groups.
    var allFrameworkSections: [AppleTechnologies.FrameworkSection] {
        groups.compactMap(frameworkSection)
    }
    
    /// Converts an interface-language entry into a framework section model for UI navigation.
    ///
    /// - Parameter interfaceLanguage: Source index item.
    /// - Returns: A framework section when a valid path is present; otherwise `nil`.
    func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage) -> AppleTechnologies.FrameworkSection? {
        guard let path = interfaceLanguage.path else { return nil }
        
        let languages = self.index.interfaceLanguages.filter({
            $0.value.contains(where: { $0.path == path }) || $0.value.flatMap { $0.children ?? [] }.contains(where: { $0.path == interfaceLanguage.path ?? "" })
        }).map(\.key)
        
        return AppleTechnologies.FrameworkSection(
            languages: languages,
            title: interfaceLanguage.title,
            tags: [],
            destination: .init(type: "",
            isActive: true,
            identifier: path),
            legalNotices: nil,
            docCSite: self
        )
    }
    
    /// Deletes the associated persisted site when this DTO is backed by SwiftData.
    ///
    /// - Parameter modelContext: SwiftData context used to locate and remove the model.
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

/// SwiftDataErrors defines a constrained set of related values.
enum SwiftDataErrors: Error {
    /// Indicates persisted model data is missing required fields or has an unexpected shape.
    case invalidShape
}

@Model
/// Persisted SwiftData model representing a DocC site source.
///
/// Persisted properties are optional to tolerate schema evolution, and `dto` provides validated access for app-layer usage.
final class DocCSite: Identifiable {
    var id: UUID = UUID()
    var timestamp: Date?
    var url: URL?
    var overrideName: String?
    var indexV2: DocCIndexModel?
    
    init(timestamp: Date = .init(), url: URL, overrideName: String? = nil, index: DocCIndex) {
        self.timestamp = timestamp
        self.url = url
        self.overrideName = overrideName
        self.indexV2 = DocCIndexModel(index)
    }
    
    fileprivate init(timestamp: Date = .init(), url: URL, overrideName: String? = nil, index: DocCIndexModel) {
        self.timestamp = timestamp
        self.url = url
        self.overrideName = overrideName
        self.indexV2 = index
    }
    
    init(_ dto: DocCSiteDTO) async {
        self.timestamp = dto.timestamp
        self.url = dto.url
        self.indexV2 = await DocCIndexModel(dto.index)
    }
    
    /// Converts the persisted model into a DTO used by app logic and UI layers.
    ///
    /// This accessor throws when persisted data is malformed or required fields are missing.
    @MainActor var dto: DocCSiteDTO {
        get throws {
            try .init(self)
        }
    }
    
    /// Top-level grouped interface-language entries from the persisted index.
    var groups: [InterfaceLanguageModel] {
        indexV2?.interfaceLanguages?.flatMap({ $0.languages ?? [] }) ?? []
    }
    
    /// Performs a recursive title-based search across persisted interface-language entries.
    ///
    /// - Parameter query: Search text to match against entry titles.
    /// - Returns: `true` when any nested item matches.
    func hasResultsForSearch(_ query: String) -> Bool {
        guard let indexV2 else { return false }
        
        for interfaceLanguage in indexV2.interfaceLanguages ?? [] where (interfaceLanguage.languages ?? []).first(where: { $0.hasResultsForSearch(query) }) != nil {
            return true
        }
        
        return false
    }
}

extension [DocCSite] {
    /// Converts persisted site models to DTOs, skipping malformed records.
    @MainActor var asDTOs: [DocCSiteDTO] {
        compactMap({ try? DocCSiteDTO($0) })
    }
}

/// Exposes the currently selected custom DocC site through SwiftUI environment values.
extension EnvironmentValues {
    @Entry var docCSite: DocCSiteDTO?
}

extension DocCSite {
    @Model
    /// Persisted representation of a DocC index grouped by interface language.
    ///
    /// - Important: Child relationships use cascading deletes to keep nested index trees in sync with their parent index.
    final class DocCIndexModel: Identifiable {
        var id: UUID = UUID()
        
        @Relationship(deleteRule: .nullify, inverse: \DocCSite.indexV2)
        var site: DocCSite?
        
        var interfaceLanguages: [InterfaceLanguageSetModel]?
        
        init(interfaceLanguages: [InterfaceLanguageSetModel]) {
            self.interfaceLanguages = interfaceLanguages
        }
        
        init(_ index: DocCIndex) {
            self.interfaceLanguages = index.interfaceLanguages.map({ InterfaceLanguageSetModel(name: $0.key, languages: $0.value) })
        }
        
        /// Reconstructs the runtime `DocCIndex` value from persisted model data.
        var asIndex: DocCIndex {
            let interfaceLanguages = (interfaceLanguages ?? []).reduce(into: [String: [DocCIndex.InterfaceLanguage]]()) { acc, set in
                guard let name = set.name, let languages = set.languages else { return }
                acc[name] = languages.map({ $0.asInterfaceLanguage })
            }
            
            return DocCIndex(interfaceLanguages: interfaceLanguages)
        }
    }
    
    @Model
    /// Named set of interface-language entries for a single language key (for example, Swift).
    final class InterfaceLanguageSetModel: Identifiable {
        var id = UUID()
        var name: String?
        var languages: [InterfaceLanguageModel]?
        
        @Relationship(deleteRule: .cascade, inverse: \DocCIndexModel.interfaceLanguages)
        var index: DocCIndexModel?
        
        init(name: String? = nil, languages: [InterfaceLanguageModel]? = nil) {
            self.name = name
            self.languages = languages
        }
        
        init(name: String, languages: [DocCIndex.InterfaceLanguage]) {
            self.name = name
            self.languages = languages.map({ InterfaceLanguageModel($0) })
        }
    }
    
    @Model
    /// Persisted tree node for a DocC interface-language entry.
    final class InterfaceLanguageModel: Identifiable {
        var id = UUID()
        
        var title: String?
        var path: String?
        var type: String?
        
        @Relationship(deleteRule: .cascade, inverse: \InterfaceLanguageSetModel.languages)
        private var set: InterfaceLanguageSetModel?
        
        // parent relationship
        @Relationship(deleteRule: .cascade, inverse: \InterfaceLanguageModel.children)
        var parent: InterfaceLanguageModel?
        
        fileprivate(set) var children: [InterfaceLanguageModel]?
        
        init(title: String?, path: String? = nil, type: String?, children: [InterfaceLanguageModel]) {
            self.title = title
            self.path = path
            self.type = type
            self.children = children
        }
        
        init(_ language: DocCIndex.InterfaceLanguage) {
            self.title = language.title
            self.path = language.path
            self.type = language.type
            
            if let children = language.children {
                let models = children.map { child in
                    let model = InterfaceLanguageModel(child)
                    model.parent = self
                    
                    return model
                }
                self.children = models
            }
        }
        
        /// Reconstructs the runtime interface-language value, including recursive children.
        var asInterfaceLanguage: DocCIndex.InterfaceLanguage {
            let children: [DocCIndex.InterfaceLanguage]? = self.children?.map({ $0.asInterfaceLanguage })
            
            return DocCIndex.InterfaceLanguage(title: title ?? "Unknown", path: path, type: type ?? "Unknown", children: children)
        }
        
        /// Recursively checks whether this entry or descendants match the search query.
        ///
        /// - Parameter query: Search text to compare with entry titles.
        /// - Returns: `true` if this entry or any descendant matches.
        func hasResultsForSearch(_ query: String) -> Bool {
            if title?.lowercased().contains(query.lowercased()) == true && type?.lowercased() != "module" {
                return true
            }
            
            guard let children else { return false }
            
            return children.first(where: { $0.hasResultsForSearch(query) }) != nil
        }
        
        /// Returns the owning language set by walking parent links when needed.
        ///
        /// - Returns: The nearest `InterfaceLanguageSetModel` in the ancestry chain.
        @MainActor
        func getSet() throws -> InterfaceLanguageSetModel? {
            if let set {
                return set
            }
            
            return try self.parent?.getSet()
        }
    }
}
