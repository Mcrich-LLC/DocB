//
//  Technology Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

/// Decoded DocC framework payload used to render framework landing pages and symbol lists.
struct Framework: Codable, AppleDocumentation {
    /// Grouped topic sections for framework navigation.
    let topicSections: [TopicSection]?
    /// Core framework metadata.
    let metadata: Metadata
    /// Reference lookup table keyed by identifier.
    let references: [String : Reference]
    /// Optional legal notices associated with the framework.
    let legalNotices: LegalNotices?
    /// Available language/platform variants for this framework.
    let variants: [Variant]?
    
    @CodableIgnoreInitializedProperties
    /// A topic bucket containing references for a subsection of framework content.
    struct TopicSection: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let title: String?
        let anchor: String?
        let identifiers: [String]
        
        /// Stable wrappers used by SwiftUI `ForEach` for plain identifier arrays.
        var identifiersWithIDs: [IdentifiableIdentifier] {
            identifiers.map { IdentifiableIdentifier($0) }
        }
        
        /// Identifiable wrapper for a raw documentation identifier.
        struct IdentifiableIdentifier: Identifiable, Equatable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
            let id = UUID()
            let identifier: String
            
            var description: String { identifier }
            
            init(_ identifier: String) {
                self.identifier = identifier
            }
            
            init(stringLiteral value: StringLiteralType) {
                self.identifier = String(describing: value)
            }
        }
    }

    /// Metadata for framework-level title, role, and supported assets.
    struct Metadata: Codable, Equatable, Hashable {
        let title: String
        let role: Role
        let images: [ImageStruct]?
        let platforms: [Platform]?
        let modules: [Module]?
        
        /// Module declaration included in framework metadata.
        struct Module: Codable, Equatable, Hashable {
            let name: String
            
        }
    }
}
