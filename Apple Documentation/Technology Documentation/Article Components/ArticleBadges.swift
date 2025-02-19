//
//  ArticleBadges.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

struct ArticleBadge: View {
    @Environment(\.colorScheme) var colorScheme
    let badge: Badge
    
    enum Badge: String, CaseIterable {
        case beta, deprecated
        
        var backgroundColor: Color {
            switch self {
            case .beta: return .mint
            case .deprecated: return .orange
            }
        }
    }
    
    var body: some View {
        Text(badge.rawValue.capitalized)
            .textSelection(.enabled)
            .font(.footnote)
            .foregroundStyle(colorScheme == .light ? Color.white : Color.black)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(badge.backgroundColor))
    }
}
