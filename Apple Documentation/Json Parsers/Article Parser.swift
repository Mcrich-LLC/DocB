//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

struct Article: Codable, AppleDocumentation {
    let metadata: Metadata
    let topicSectionsStyle: ContentSection.Content.Style?
    let abstract: [ContentStruct]?
    let primaryContentSections: [ContentSection]?
    let references: [String : Reference]
    let legalNotices: LegalNotices?
    let seeAlsoSections: [Framework.TopicSection]?
    let topicSections: [Framework.TopicSection]?
    let relationshipsSections: [Framework.TopicSection]?
    let sampleCodeDownload: SampleCodeDownload?
    let deprecationSummary: [ContentSection.Content]?
    let betaSummary: [ContentSection.Content]?
    let variants: [Variant]?
    
    struct Metadata: Codable, Equatable, Hashable {
        // Role
        let role: Role
        let roleHeading: String?
        
        // Other Data
        let images: [ImageStruct]?
        let title: String
        
        // Platforms
        let platforms: [Platform]?
    }
    
    struct SampleCodeDownload: Codable, Equatable, Hashable {
        let kind: String
        let action: Action
        
        struct Action: Codable, Equatable, Hashable {
            let isActive: Bool
            let identifier: String
            let overridingTitle: String?
            let type: ContentType
        }
    }
}
