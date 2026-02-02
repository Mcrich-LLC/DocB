//
//  AppleDocumentation Protocol.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import Foundation

/// A protocol defining the core requirements for an Apple documentation entity.
///
/// Types conforming to this protocol are expected to be decodable and provide legal notices.
protocol AppleDocumentation: Decodable, Equatable, Hashable, Sendable {
    /// The legal notices associated with the documentation entity, if any.
    var legalNotices: LegalNotices? { get }
}
