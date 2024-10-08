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
        VStack {
            CodeText(code)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .secondarySystemBackground)))
        }
    }
}
