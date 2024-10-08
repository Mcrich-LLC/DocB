//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation

struct Article: Decodable {
    let metadata: Metadata
    let abstract: [ContentStruct]?
    let primaryContentSections: [ContentSection]?
    let references: [String : Reference]
    let legalNotices: LegalNotices
    let seeAlsoSections: [Framework.TopicSection]?
    let topicSections: [Framework.TopicSection]?
    let relationshipsSections: [Framework.TopicSection]?
    
    struct Metadata: Decodable {
        // Role
        let role: String
        let roleHeading: String?
        
        // Other Data
        let images: [ImageStruct]?
        let title: String
        
        // Platforms
        let platforms: [Platform]?
    }
}
