//
//  Technology Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

/// Decoded DocC framework payload used to render framework landing pages and symbol lists.
public struct Framework: Codable, AppleDocumentation {
    /// Grouped topic sections for framework navigation.
    public let topicSections: [TopicSection]?
    /// Core framework metadata.
    public let metadata: Metadata
    /// Reference lookup table keyed by identifier.
    public let references: [String : Reference]
    /// Optional legal notices associated with the framework.
    public let legalNotices: LegalNotices?
    /// Available language/platform variants for this framework.
    public let variants: [Variant]?
    
    /// A topic bucket containing references for a subsection of framework content.
    @CodableIgnoreInitializedProperties
    public struct TopicSection: Codable, Identifiable, Equatable, Hashable, Sendable {
        public let id = UUID()
        
        public let title: String?
        public let anchor: String?
        public let identifiers: [String]
        
        /// Stable wrappers used by SwiftUI `ForEach` for plain identifier arrays.
        public var identifiersWithIDs: [IdentifiableIdentifier] {
            identifiers.map { IdentifiableIdentifier($0) }
        }
        
        /// Identifiable wrapper for a raw documentation identifier.
        public struct IdentifiableIdentifier: Identifiable, Equatable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible, Sendable {
            public let id = UUID()
            public let identifier: String
            
            public var description: String { identifier }
            
            public init(_ identifier: String) {
                self.identifier = identifier
            }
            
            public init(stringLiteral value: StringLiteralType) {
                self.identifier = String(describing: value)
            }
        }
    }

    /// Metadata for framework-level title, role, and supported assets.
    public struct Metadata: Codable, Equatable, Hashable, Sendable {
        public let title: String
        public let role: Role
        public let images: [ImageStruct]?
        public let platforms: [Platform]?
        public let modules: [Module]?
        
        /// Module declaration included in framework metadata.
        public struct Module: Codable, Equatable, Hashable, Sendable {
            public let name: String
            
        }
    }
}
