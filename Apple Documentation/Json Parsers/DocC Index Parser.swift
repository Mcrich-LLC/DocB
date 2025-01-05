//
//  DocC Index Parser.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable
import SwiftUI

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
            
            return AppleTechnologies.FrameworkSection(languages: [], title: interfaceLanguage.title, tags: [], destination: .init(type: "", isActive: true, identifier: path), legalNotices: nil, docCSite: site)
        }
    }
}

@CodableIgnoreInitializedProperties
struct DocCSite: Identifiable, Codable, Equatable, Hashable {
    let id: UUID = UUID()
    let title: String
    let url: URL
    let index: DocCIndex
    
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
        
        return AppleTechnologies.FrameworkSection(languages: languages, title: interfaceLanguage.title, tags: [], destination: .init(type: "", isActive: true, identifier: path), legalNotices: nil, docCSite: self)
    }
}

// Make Environment Value
extension EnvironmentValues {
    @Entry var docCSite: DocCSite?
}
