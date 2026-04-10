//
//  ChevronView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI

/// Renders a platform-styled chevron indicator used in list rows and navigation affordances.
public struct ChevronView: View {
    public init() {}
    @Environment(\.colorScheme) var colorScheme
    
    public var body: some View {
        Image(systemSymbol: .chevronRight)
            .resizable()
            .frame(width: 8, height: 12)
        #if os(visionOS)
            .foregroundStyle(colorScheme == .dark ? Color.primary : Color(platformColor: .systemGray3))
        #elseif os(macOS)
            .foregroundStyle(Color(platformColor: .systemGray).secondary)
        #else
            .foregroundStyle(Color(platformColor: .systemGray3))
        #endif
    }
}

#Preview {
    ChevronView()
}
