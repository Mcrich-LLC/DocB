//
//  AppleDocumentation Protocol.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import Foundation

protocol AppleDocumentation: Decodable, Equatable, Hashable {
    var legalNotices: LegalNotices? { get }
}
