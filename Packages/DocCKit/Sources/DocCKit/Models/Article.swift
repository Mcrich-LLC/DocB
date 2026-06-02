//
//  Article Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

/// Decoded DocC article payload used to render symbol and conceptual documentation pages.
public struct Article: Codable, AppleDocumentation {
    /// Core metadata about the article, including title, role, and platform context.
    public let metadata: Metadata
    /// Preferred layout style for topic sections when provided by the payload.
    public let topicSectionsStyle: ContentSection.Content.Style?
    /// Abstract block shown near the top of an article.
    public let abstract: [ContentStruct]?
    /// Main content sections containing declarations, discussions, and supplementary blocks.
    public var primaryContentSections: [ContentSection]?
    /// Reference lookup table used to resolve related identifiers in the article.
    public let references: [String : Reference]
    /// Optional legal notices displayed at the bottom of the article.
    public let legalNotices: LegalNotices?
    /// "See Also" sections for related content.
    public let seeAlsoSections: [Framework.TopicSection]?
    /// Topic sections associated with the article.
    public let topicSections: [Framework.TopicSection]?
    /// Relationship sections that describe linked symbols or concepts.
    public let relationshipsSections: [Framework.TopicSection]?
    /// Optional sample-code download metadata for this article.
    public let sampleCodeDownload: SampleCodeDownload?
    /// Optional summary content shown when the symbol is deprecated.
    public let deprecationSummary: [ContentSection.Content]?
    /// Optional summary content shown when the symbol is in beta.
    public let betaSummary: [ContentSection.Content]?
    /// Available language/platform variants for this article.
    public let variants: [Variant]?
    /// Variant patch operations used to override article content for specific variants.
    public let variantOverrides: [VariantOverride]?
    
    /// Structured metadata describing article identity and display characteristics.
    public struct Metadata: Codable, Equatable, Hashable, Sendable {
        // Role
        public let role: Role
        public let roleHeading: String?
        public let color: Color?
        
        // Other Data
        public let images: [ImageStruct]?
        public let title: String
        
        // Platforms
        public let platforms: [Platform]?
        
        /// Role accent color metadata used for visual styling.
        public struct Color: Codable, Equatable, Hashable, Sendable {
            public let standardColorIdentifier: Colors
            
            /// Supported semantic color identifiers from DocC payloads.
            public enum Colors: String, Codable, Sendable {
                case blue, gray, green, orange, purple, red, yellow
                
                /// SwiftUI color mapped from the DocC semantic color identifier.
                public var swiftUIColor: SwiftUI.Color {
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
                
                /// Accent color adjusted for use as readable text, link, or tint color.
                public var readableAccentColor: SwiftUI.Color? {
                    switch self {
                    case .blue:
                        .blue
                    case .gray:
                        nil
                    case .green:
                        .docCReadableGreen
                    case .orange:
                        .docCReadableOrange
                    case .purple:
                        .purple
                    case .red:
                        .red
                    case .yellow:
                        .docCReadableYellow
                    }
                }
            }
            
            /// Gradient palette used for role-themed backgrounds.
            public var gradientColors: [SwiftUI.Color] {
                return [standardColorIdentifier.swiftUIColor.opacity(0.4), standardColorIdentifier.swiftUIColor.opacity(0.0)]
            }
        }
    }
    
    /// Metadata describing an article-level sample code download action.
    public struct SampleCodeDownload: Codable, Equatable, Hashable, Sendable {
        public let kind: String?
        public let action: Action
        
        /// Action payload for initiating sample-code download.
        public struct Action: Codable, Equatable, Hashable, Sendable {
            public let isActive: Bool
            public let identifier: String
            public let overridingTitle: String?
            public let type: ContentType
        }
    }
}
