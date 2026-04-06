//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

/// Decoded DocC article payload used to render symbol and conceptual documentation pages.
struct Article: Codable, AppleDocumentation {
    /// Core metadata about the article, including title, role, and platform context.
    let metadata: Metadata
    /// Preferred layout style for topic sections when provided by the payload.
    let topicSectionsStyle: ContentSection.Content.Style?
    /// Abstract block shown near the top of an article.
    let abstract: [ContentStruct]?
    /// Main content sections containing declarations, discussions, and supplementary blocks.
    var primaryContentSections: [ContentSection]?
    /// Reference lookup table used to resolve related identifiers in the article.
    let references: [String : Reference]
    /// Optional legal notices displayed at the bottom of the article.
    let legalNotices: LegalNotices?
    /// "See Also" sections for related content.
    let seeAlsoSections: [Framework.TopicSection]?
    /// Topic sections associated with the article.
    let topicSections: [Framework.TopicSection]?
    /// Relationship sections that describe linked symbols or concepts.
    let relationshipsSections: [Framework.TopicSection]?
    /// Optional sample-code download metadata for this article.
    let sampleCodeDownload: SampleCodeDownload?
    /// Optional summary content shown when the symbol is deprecated.
    let deprecationSummary: [ContentSection.Content]?
    /// Optional summary content shown when the symbol is in beta.
    let betaSummary: [ContentSection.Content]?
    /// Available language/platform variants for this article.
    let variants: [Variant]?
    /// Variant patch operations used to override article content for specific variants.
    let variantOverrides: [VariantOverride]?
    
    /// Structured metadata describing article identity and display characteristics.
    struct Metadata: Codable, Equatable, Hashable {
        // Role
        let role: Role
        let roleHeading: String?
        let color: Color?
        
        // Other Data
        let images: [ImageStruct]?
        let title: String
        
        // Platforms
        let platforms: [Platform]?
        
        /// Role accent color metadata used for visual styling.
        struct Color: Codable, Equatable, Hashable {
            let standardColorIdentifier: Colors
            
            /// Supported semantic color identifiers from DocC payloads.
            enum Colors: String, Codable {
                case blue, gray, green, orange, purple, red, yellow
                
                /// SwiftUI color mapped from the DocC semantic color identifier.
                var swiftUIColor: SwiftUI.Color {
                    switch self {
                    case .blue: return .blue
                    case .gray: return .gray
                    case .green: return .green
                    case .orange: return .orange
                    case .purple: return .purple
                    case .red: return .red
                    case .yellow: return .yellow
                    }
                }
            }
            
            /// Gradient palette used for role-themed backgrounds.
            var gradientColors: [SwiftUI.Color] {
                return [standardColorIdentifier.swiftUIColor.opacity(0.4), standardColorIdentifier.swiftUIColor.opacity(0.0)]
            }
        }
    }
    
    /// Metadata describing an article-level sample code download action.
    struct SampleCodeDownload: Codable, Equatable, Hashable {
        let kind: String?
        let action: Action
        
        /// Action payload for initiating sample-code download.
        struct Action: Codable, Equatable, Hashable {
            let isActive: Bool
            let identifier: String
            let overridingTitle: String?
            let type: ContentType
        }
    }
}
