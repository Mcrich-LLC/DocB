//
//  Technology Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

/// A structure representing a framework or library documentation.
struct Framework: Codable, AppleDocumentation {
    /// The sections of topics within the framework documentation.
    let topicSections: [TopicSection]?
    /// Metadata describing the framework.
    let metadata: Metadata
    /// References used within the framework documentation.
    let references: [String : Reference]
    /// Legal notices associated with the documentation.
    let legalNotices: LegalNotices?
    /// Variants of the documentation (e.g., for different languages).
    let variants: [Variant]?
    
    @CodableIgnoreInitializedProperties
    /// A section containing a group of related topics.
    struct TopicSection: Codable, Identifiable, Equatable, Hashable {
        /// A unique identifier for the topic section.
        let id = UUID()
        
        /// The title of the section.
        let title: String?
        /// The anchor used for linking to this section.
        let anchor: String?
        /// The identifiers of the topics included in this section.
        let identifiers: [String]
        
        /// Retrieves the identifiers wrapped in an `Identifiable` container.
        var identifiersWithIDs: [IdentifiableIdentifier] {
            identifiers.map { IdentifiableIdentifier($0) }
        }
        
        /// A wrapper for identifiers to make them identifiable.
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
        
        enum CodingKeys: CodingKey {
            case id
            case title
            case anchor
            case identifiers
        }
    }

    /// Metadata providing details about the framework.
    struct Metadata: Codable, Equatable, Hashable {
        /// The title of the framework.
        let title: String
        /// The role of the documented entity.
        let role: Role
        /// Images associated with the framework metadata.
        let images: [ImageStruct]?
        /// Supported platforms for the framework.
        let platforms: [Platform]?
        /// Modules contained within the framework.
        let modules: [Module]?
        
        /// A structure representing a module within the framework.
        struct Module: Codable, Equatable, Hashable {
            /// The name of the module.
            let name: String
            
        }
    }
}
