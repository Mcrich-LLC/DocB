//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

/// A structure representing an article or documentation page.
///
/// `Article` is the top-level structure for parsing JSON documentation files.
struct Article: Codable, AppleDocumentation {
    /// Metadata associated with the article.
    let metadata: Metadata
    /// The style of the topic sections (e.g., list, grid).
    let topicSectionsStyle: ContentSection.Content.Style?
    /// An abstract or summary of the article content.
    let abstract: [ContentStruct]?
    /// The primary content sections of the article.
    var primaryContentSections: [ContentSection]?
    /// A dictionary of references used within the article, keyed by their identifier.
    let references: [String : Reference]
    /// Legal notices associated with the article.
    let legalNotices: LegalNotices?
    /// "See also" sections, usually containing related links.
    let seeAlsoSections: [Framework.TopicSection]?
    /// Topic sections, organizing the content into logical groups.
    let topicSections: [Framework.TopicSection]?
    /// Relationships sections, showing how this article relates to other symbols.
    let relationshipsSections: [Framework.TopicSection]?
    /// Information about available sample code downloads.
    let sampleCodeDownload: SampleCodeDownload?
    /// A summary of deprecation information.
    let deprecationSummary: [ContentSection.Content]?
    /// A summary of beta information.
    let betaSummary: [ContentSection.Content]?
    /// Variants of the article (e.g., for different languages).
    let variants: [Variant]?
    /// Overrides used to patch the article content based on variants.
    let variantOverrides: [VariantOverride]?
    
    /// Metadata containing information about the article's role, title, and appearance.
    struct Metadata: Codable, Equatable, Hashable {
        // MARK: Role
        /// The role of the article (e.g., article, symbol).
        let role: Role
        /// The heading to display for the role.
        let roleHeading: String?
        /// The color associated with the article.
        let color: Color?
        
        // MARK: Other Data
        /// Images associated with the article metadata.
        let images: [ImageStruct]?
        /// The title of the article.
        let title: String
        
        // MARK: Platforms
        /// Supported platforms for this article.
        let platforms: [Platform]?
        
        /// A color structure used in metadata.
        struct Color: Codable, Equatable, Hashable {
            /// The standard color identifier.
            let standardColorIdentifier: Colors
            
            /// Enum representing supported standard colors.
            enum Colors: String, Codable {
                case blue, gray, green, orange, purple, red, yellow
                
                /// The corresponding SwiftUI `Color`.
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
            
            /// The gradient colors derived from the standard color.
            var gradientColors: [SwiftUI.Color] {
                return [standardColorIdentifier.swiftUIColor.opacity(0.4), standardColorIdentifier.swiftUIColor.opacity(0.0)]
            }
        }
    }
    
    /// Information about sample code available for download.
    struct SampleCodeDownload: Codable, Equatable, Hashable {
        /// The kind of download.
        let kind: String?
        /// The action associated with the download.
        let action: Action
        
        /// The action details for the download.
        struct Action: Codable, Equatable, Hashable {
            /// Indicates if the action is active.
            let isActive: Bool
            /// The identifier for the action.
            let identifier: String
            /// An optional overriding title for the action.
            let overridingTitle: String?
            /// The type of content associated with the action.
            let type: ContentType
        }
    }
}
