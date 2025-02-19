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
        
        let children: [InterfaceLanguage]?
        
        func allFrameworkSections(for site: DocCSite) -> [AppleTechnologies.FrameworkSection] {
            children?.compactMap { frameworkSection(for: $0, site: site) } ?? []
        }
        
        func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSite) -> AppleTechnologies.FrameworkSection? {
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

@Model
class DocCSite: Identifiable, Codable, Equatable, Hashable {
    @Attribute(.unique)
    var id: UUID = UUID()
    var title: String
    var url: URL
    
//    @Attribute(.externalStorage)
    var index: DocCIndex
    
    init(title: String, url: URL, index: DocCIndex) {
        self.title = title
        self.url = url
        self.index = index
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case index
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        index = try container.decode(DocCIndex.self, forKey: .index)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encode(index, forKey: .index)
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
}

// Make Environment Value
extension EnvironmentValues {
    @Entry var docCSite: DocCSite?
}
