//
//  DocC Index Parser.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable

@CodableIgnoreInitializedProperties
struct DocCIndex: Codable, Identifiable {
    let id = UUID()
    
    let interfaceLanguages: [String : [InterfaceLanguage]]
    
    struct InterfaceLanguage: Codable {
        let title: String
        let path: String?
        let type: String
        
        let children: [InterfaceLanguage]?
    }
}
