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
    @Environment(\.colorScheme) var colorScheme
    
    var code: String {
        content.tokens.compactMap({ token in
            if let text = token.text {
                return text
            }
            
            if let code = token.code {
                return code
            }
            
            return nil
        }).joined()
    }
    
    var body: some View {
        GroupBox {
            CodeText(code)
                .highlightLanguage(.swift)
                .codeTextColors(.theme(.xcode))
                .textSelection(.enabled)
                .tint(Color(uiColor: .systemBlue))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
#if os(visionOS)
            .backgroundStyle(colorScheme == .dark ? .black : .white)
#endif
            .overlay(alignment: .topTrailing) {
                CopyOverlayButton(string: code)
            }
    }
}
