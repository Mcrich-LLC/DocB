//
//  AsideView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

/// AsideView renders a reusable SwiftUI view.
struct AsideView: View {
    /// Aside style controlling title and accent color.
    let style: ContentSection.Content.Style
    /// Content blocks rendered inside the aside container.
    let content: [ContentSection.Content]
    /// Reference lookup table used by nested article content.
    let references: [String : Reference]
    
    /// Derived aside title from the style enum raw value.
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
    /// Shared renderer for aside content with a style-specific accent color.
    func asideView(color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(title.capitalized)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .padding(.bottom, 5)
            
            ForEach(content) { item in
                ArticleContentView(content: item, references: references)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12.5)
                .fill(color.opacity(0.1))
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}
