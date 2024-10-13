//
//  AsideView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

struct AsideView: View {
    let style: ContentSection.Content.Style
    let content: [ContentSection.Content]
    let references: [String : Reference]
    
    var title: String {
        style.rawValue.capitalized
    }
    
    var body: some View {
        switch style {
        case .tip:
            asideView(color: .mint)
        case .experiment:
            asideView(color: .mint)
        case .warning:
            asideView(color: .yellow)
        case .important:
            asideView(color: .red)
        case .deprecated:
            asideView(color: .orange)
        default:
            asideView(color: .gray)
        }
    }
        
    @ViewBuilder
    func asideView(color: Color) -> some View {
        VStack {
            Text(title.capitalized)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)
            
            ForEach(content) { item in
                ArticleContentView(content: item, references: references)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}
