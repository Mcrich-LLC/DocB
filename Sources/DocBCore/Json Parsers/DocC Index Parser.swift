//
//  DocC Index Parser.swift
//  DocB
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable
import SwiftData

/// Top-level DocC index payload describing available interface-language trees.
@CodableIgnoreInitializedProperties
public struct DocCIndex: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// Stable identifier for diffable/UI usage.
    public let id = UUID()
    
    /// Interface-language entries keyed by language token (for example, `swift`).
    public let interfaceLanguages: [String : [InterfaceLanguage]]
    
    public static func == (lhs: DocCIndex, rhs: DocCIndex) -> Bool {
        lhs.interfaceLanguages == rhs.interfaceLanguages
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(interfaceLanguages)
    }
    
    /// A node in a DocC index tree representing modules, frameworks, and related groups.
    @CodableIgnoreInitializedProperties
    public struct InterfaceLanguage: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Display title for this index node.
        public let title: String
        /// Relative documentation path for this node.
        public let path: String?
        /// Node type discriminator (for example `module`, `framework`, `sampleCode`).
        public let type: String
        
        /// Child index nodes nested under this node.
        public fileprivate(set) var children: [InterfaceLanguage]?
        
        /// Recursively flattened descendant nodes.
        public var allChildren: [InterfaceLanguage] {
            (children ?? []) + (children?.flatMap(\.allChildren) ?? [])
        }
        
        public static func == (lhs: InterfaceLanguage, rhs: InterfaceLanguage) -> Bool {
            lhs.title == rhs.title &&
            lhs.path == rhs.path &&
            lhs.type == rhs.type &&
            lhs.children == rhs.children
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(path)
            hasher.combine(type)
            hasher.combine(children)
        }
        
        /// Converts immediate children into framework sections.
        ///
        /// - Parameter site: Site context used to associate generated sections.
        /// - Returns: Framework sections for child entries that contain valid paths.
        public func allFrameworkSections(for site: DocCSiteDTO) -> [AppleTechnologies.FrameworkSection] {
            children?.compactMap { frameworkSection(for: $0, site: site) } ?? []
        }
        
        /// Converts an index entry into a framework section for navigation.
        ///
        /// - Parameters:
        ///   - interfaceLanguage: Source index entry.
        ///   - site: Site context to attach to the section.
        /// - Returns: A framework section if the source has a path; otherwise `nil`.
        public func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSiteDTO) -> AppleTechnologies.FrameworkSection? {
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
    /// Returns grouped entries excluding sample code containers and sample code children.
    public var nonSampleCodeGroups: [DocCIndex.InterfaceLanguage] {
        let groups = groups.filter({ $0.type != "sampleCode" }).map({ group in
            var group = group
            group.children = group.children?.filter({ $0.type != "sampleCode" })
            return group
        }).filter({ $0.children?.isEmpty == false })
        
        return groups
    }
}
