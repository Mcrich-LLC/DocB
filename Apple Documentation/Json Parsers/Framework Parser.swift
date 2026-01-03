//
//  Technology Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

struct Framework: Codable, AppleDocumentation {
    let topicSections: [TopicSection]?
    let metadata: Metadata
    let references: [String : Reference]
    let legalNotices: LegalNotices?
    let variants: [Variant]?
    
    @CodableIgnoreInitializedProperties
    struct TopicSection: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let title: String?
        let anchor: String?
        let identifiers: [String]
        
        var identifiersWithIDs: [IdentifiableIdentifier] {
            identifiers.map { IdentifiableIdentifier($0) }
        }
        
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

    struct Metadata: Codable, Equatable, Hashable {
        let title: String
        let role: Role
        let images: [ImageStruct]?
        let platforms: [Platform]?
        let modules: [Module]?
        
        struct Module: Codable, Equatable, Hashable {
            let name: String
            
        }
    }
}
