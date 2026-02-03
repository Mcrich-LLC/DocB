//
//  ArticleBadges.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

/// A view that displays a stylized badge (e.g., "Beta" or "Deprecated").
struct ArticleBadge: View {
    @Environment(\.colorScheme) var colorScheme
    /// The type of badge to display.
    let badge: Badge
    
    /// The supported badge types.
    enum Badge: String, CaseIterable {
        /// A badge indicating beta status.
        case beta
        /// A badge indicating deprecated status.
        case deprecated
        
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
