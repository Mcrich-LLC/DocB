//
//  DeclarationContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI
import HighlightSwift

struct DeclarationContentView: View {
    let content: ContentSection.Declaration
    let article: Article
    
    var code: String {
        content.tokens.map({ $0.text }).joined()
    }
    
    var body: some View {
        GroupBox {
            CodeText(code)
                .highlightLanguage(.swift)
                .codeTextColors(.theme(.xcode))
                .textSelection(.enabled)
                .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
