//
//  DocC Index Parser.swift
//  DocB
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable
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

extension DocCSiteDTO {
    var nonSampleCodeGroups: [DocCIndex.InterfaceLanguage] {
        let groups = groups.filter({ $0.type != "sampleCode" }).map({ group in
            var group = group
            group.children = group.children?.filter({ $0.type != "sampleCode" })
            return group
        }).filter({ $0.children?.isEmpty == false })
        
        return groups
    }
}
