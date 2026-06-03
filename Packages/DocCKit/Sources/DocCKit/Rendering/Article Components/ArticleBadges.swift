//
//  ArticleBadges.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

/// ArticleBadge renders a reusable SwiftUI view.
public struct ArticleBadge: View {
    @Environment(\.colorScheme) var colorScheme
    /// Badge type rendered by this capsule.
    let badge: Badge
    
    /// Supported article badge styles.
    public enum Badge: String, CaseIterable {
        case beta, deprecated
        
        var backgroundColor: Color {
            switch self {
            case .beta: return .mint
            case .deprecated: return .orange
            }
        }
    }
    
    /// Creates an article status badge.
    ///
    /// - Parameter badge: Badge style to render.
    public init(badge: Badge) {
        self.badge = badge
    }
    
    public var body: some View {
        Text(badge.rawValue.capitalized)
            .textSelection(.enabled)
            .font(.footnote)
            .foregroundStyle(colorScheme == .light ? Color.white : Color.black)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(badge.backgroundColor))
    }
}
