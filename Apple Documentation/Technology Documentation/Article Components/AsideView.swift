//
//  AsideView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

/// A view that displays an aside (e.g., note, warning, experiment) with a styled background and title.
struct AsideView: View {
    /// The style of the aside (e.g., tip, warning).
    let style: ContentSection.Content.Style
    /// The content within the aside.
    let content: [ContentSection.Content]
    /// A dictionary of references for resolving links.
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
