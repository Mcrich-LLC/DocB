//
//  DocC Index Parser.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable
import SwiftUI
import SwiftData

/// A structure representing the index of a DocC documentation site.
@CodableIgnoreInitializedProperties
struct DocCIndex: Codable, Identifiable, Equatable, Hashable {
    /// A unique identifier for the index.
    let id = UUID()
    
    /// A dictionary mapping languages to their interface languages.
    let interfaceLanguages: [String : [InterfaceLanguage]]
    
    /// A structure representing an interface language node in the index.
    @CodableIgnoreInitializedProperties
    struct InterfaceLanguage: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let title: String
        let path: String?
        let type: String
        
        let children: [InterfaceLanguage]?
        
        func allFrameworkSections(for site: DocCSiteDTO) -> [AppleTechnologies.FrameworkSection] {
            children?.compactMap { frameworkSection(for: $0, site: site) } ?? []
        }
        
        func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSiteDTO) -> AppleTechnologies.FrameworkSection? {
//            let languages = self.index.interfaceLanguages.filter({
//                $0.value.contains(where: { $0.path == interfaceLanguage.path ?? "" }) || $0.value.flatMap { $0.children ?? [] }.contains(where: { $0.path == interfaceLanguage.path ?? "" })
//            }).map(\.key)
            
            guard let path = interfaceLanguage.path else { return nil }
            
            return AppleTechnologies.FrameworkSection(
                languages: [],
                title: interfaceLanguage.title,
                tags: [],
                destination: .init(type: "",
                isActive: true,
                identifier: path),
                legalNotices: nil,
                docCSite: site
            )
        }
    }
}

/// A Data Transfer Object (DTO) for `DocCSite`, used for app-level logic and state management.
@MainActor
final class DocCSiteDTO: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    /// Checks for equality between two `DocCSiteDTO` instances based on their ID.
    nonisolated static func == (lhs: DocCSiteDTO, rhs: DocCSiteDTO) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(url)
        hasher.combine(index)
    }
    
    /// The unique identifier for the site.
    let id: UUID
    /// The timestamp when the site was added or last updated.
    let timestamp: Date
    /// The base URL of the DocC site.
    let url: URL
    /// The parsed index of the DocC site.
    private(set) var index: DocCIndex
    /// The persistent model ID used for SwiftData integration.
    fileprivate var persistentModelID: PersistentIdentifier?
    
    /// Initializes a new `DocCSiteDTO`.
    ///
    /// - Parameters:
    ///   - timestamp: The creation timestamp.
    ///   - url: The base URL of the site.
    ///   - index: The parsed `DocCIndex`.
    init(timestamp: Date = .init(), url: URL, index: DocCIndex) {
        self.id = UUID()
        self.timestamp = timestamp
        self.url = url
        self.index = index
        self.persistentModelID = nil
    }
    
    init(_ model: DocCSite) {
        self.id = model.id
        self.timestamp = model.timestamp
        self.url = model.url
        self.index = model.index
        self.persistentModelID = model.persistentModelID
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.url = try container.decode(URL.self, forKey: .url)
        self.index = try container.decode(DocCIndex.self, forKey: .index)
    }
    
    func setIndex(_ index: DocCIndex) {
        self.index = index
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case url
        case index
    }
    
    var groups: [DocCIndex.InterfaceLanguage] {
        index.interfaceLanguages.flatMap({ $0.value })
    }
    
    var allFrameworkSections: [AppleTechnologies.FrameworkSection] {
        groups.compactMap(frameworkSection)
    }
    
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
    
    func deleteSite(modelContext: ModelContext) {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
    }
}

/// A SwiftData model representing a stored DocC site.
@Model
final class DocCSite: Identifiable {
    /// The unique identifier for the stored site.
    @Attribute(.unique)
    var id: UUID = UUID()
    /// The timestamp when the site was stored.
    var timestamp: Date
    /// The base URL of the stored site.
    var url: URL
    
    /// The stored index of the site.
//    @Attribute(.externalStorage)
    var index: DocCIndex
    
    /// Initializes a new `DocCSite`.
    ///
    /// - Parameters:
    ///   - timestamp: The creation timestamp.
    ///   - url: The base URL.
    ///   - index: The `DocCIndex` data.
    init(timestamp: Date = .init(), url: URL, index: DocCIndex) {
        self.timestamp = timestamp
        self.url = url
        self.index = index
    }
    
    init(_ dto: DocCSiteDTO) async {
        self.timestamp = dto.timestamp
        self.url = dto.url
        self.index = await dto.index
    }
    
    @MainActor var dto: DocCSiteDTO {
        .init(self)
    }
}

extension [DocCSite] {
    @MainActor var asDTOs: [DocCSiteDTO] {
        map({ DocCSiteDTO($0) })
    }
}

// Make Environment Value
extension EnvironmentValues {
    @Entry var docCSite: DocCSiteDTO?
}
