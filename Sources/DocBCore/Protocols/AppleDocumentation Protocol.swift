//
//  AppleDocumentation Protocol.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import Foundation

/// Shared protocol adopted by decoded DocC payload models in the app.
///
/// Conforming types provide legal notice information and common decoding/equality semantics.
public protocol AppleDocumentation: Decodable, Equatable, Hashable, Sendable {
    /// Optional legal notices associated with the decoded documentation payload.
    var legalNotices: LegalNotices? { get }
}
