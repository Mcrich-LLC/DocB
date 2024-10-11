//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

struct Article: Codable {
    let metadata: Metadata
    let topicSectionsStyle: ContentSection.Content.Style?
    let abstract: [ContentStruct]?
    let primaryContentSections: [ContentSection]?
    let references: [String : Reference]
    let legalNotices: LegalNotices
    let seeAlsoSections: [Framework.TopicSection]?
    let topicSections: [Framework.TopicSection]?
    let relationshipsSections: [Framework.TopicSection]?
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    func fetchPhotoVideoURL(for identifier: String, colorScheme: ColorScheme) -> URL? {
        guard let reference = self.references[identifier], let variants = reference.variants else {
            return nil
        }
        if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark, let url = URL(string: darkVariant.url) {
            return url
        } else if let lightVariant = variants.first, let url = URL(string: lightVariant.url) {
            return url
        }
        
        return nil
    }
    
    struct Metadata: Codable {
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
