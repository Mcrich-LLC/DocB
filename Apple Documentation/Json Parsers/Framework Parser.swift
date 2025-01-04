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
