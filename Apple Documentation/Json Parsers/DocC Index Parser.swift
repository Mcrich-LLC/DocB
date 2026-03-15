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

@CodableIgnoreInitializedProperties
struct DocCIndex: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let interfaceLanguages: [String : [InterfaceLanguage]]
    
    @CodableIgnoreInitializedProperties
    struct InterfaceLanguage: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let title: String
        let path: String?
        let type: String
        
        fileprivate(set) var children: [InterfaceLanguage]?
        
        var allChildren: [InterfaceLanguage] {
            (children ?? []) + (children?.flatMap(\.allChildren) ?? [])
        }
        
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

@MainActor
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
    
    let id: UUID
    let timestamp: Date
    let overrideName: String?
    let url: URL
    private(set) var index: DocCIndex
    fileprivate var persistentModelID: PersistentIdentifier?
    
    init(timestamp: Date = .init(), url: URL, overrideName: String? = nil, index: DocCIndex) {
        self.id = UUID()
        self.timestamp = timestamp
        self.url = url
        self.overrideName = overrideName
        self.index = index
        self.persistentModelID = nil
    }
    
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
    
    func setIndex(_ index: DocCIndex) {
        self.index = index
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case url
        case overrideName
        case index
    }
    
    var groups: [DocCIndex.InterfaceLanguage] {
        index.interfaceLanguages.flatMap({ $0.value })
    }
    
    var nonSampleCodeGroups: [DocCIndex.InterfaceLanguage] {
        let groups = groups.filter({ $0.type != "sampleCode" }).map({ group in
            var group = group
            group.children = group.children?.filter({ $0.type != "sampleCode" })
            return group
        }).filter({ $0.children?.isEmpty == false })
        
        return groups
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
    
    func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
}

enum SwiftDataErrors: Error {
    case invalidShape
}

@Model
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
    
    @MainActor var dto: DocCSiteDTO {
        get throws {
            try .init(self)
        }
    }
    
    var groups: [InterfaceLanguageModel] {
        indexV2?.interfaceLanguages?.flatMap({ $0.languages ?? [] }) ?? []
    }
    
    func hasResultsForSearch(_ query: String) -> Bool {
        guard let indexV2 else { return false }
        
        for interfaceLanguage in indexV2.interfaceLanguages ?? [] {
            return (interfaceLanguage.languages ?? []).first(where: { $0.hasResultsForSearch(query) }) != nil
        }
        
        return false
    }
}

extension [DocCSite] {
    @MainActor var asDTOs: [DocCSiteDTO] {
        compactMap({ try? DocCSiteDTO($0) })
    }
}

// Make Environment Value
extension EnvironmentValues {
    @Entry var docCSite: DocCSiteDTO?
}

extension DocCSite {
    @Model
    final class DocCIndexModel: Identifiable {
        var id: UUID = UUID()
        
        @Relationship(deleteRule: .cascade, inverse: \DocCSite.indexV2)
        var site: DocCSite?
        
        var interfaceLanguages: [InterfaceLanguageSetModel]?
        
        init(interfaceLanguages: [InterfaceLanguageSetModel]) {
            self.interfaceLanguages = interfaceLanguages
        }
        
        init(_ index: DocCIndex) {
            self.interfaceLanguages = index.interfaceLanguages.map({ InterfaceLanguageSetModel(name: $0.key, languages: $0.value) })
        }
        
        var asIndex: DocCIndex {
            let interfaceLanguages = (interfaceLanguages ?? []).reduce(into: [String: [DocCIndex.InterfaceLanguage]]()) { acc, set in
                guard let name = set.name, let languages = set.languages else { return }
                acc[name] = languages.map({ $0.asInterfaceLanguage })
            }
            
            return DocCIndex(interfaceLanguages: interfaceLanguages)
        }
    }
    
    @Model
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
        
        var asInterfaceLanguage: DocCIndex.InterfaceLanguage {
            let children: [DocCIndex.InterfaceLanguage]? = self.children?.map({ $0.asInterfaceLanguage })
            
            return DocCIndex.InterfaceLanguage(title: title ?? "Unknonwn", path: path, type: type ?? "Unknown", children: children)
        }
        
        func hasResultsForSearch(_ query: String) -> Bool {
            if title?.lowercased().contains(query.lowercased()) == true && type?.lowercased() != "module" {
                return true
            }
            
            guard let children else { return false }
            
            return children.first(where: { $0.hasResultsForSearch(query) }) != nil
        }
        
        @MainActor
        func getSet() throws -> InterfaceLanguageSetModel? {
            if let set {
                return set
            }
            
            return try self.parent?.getSet()
        }
    }
}
