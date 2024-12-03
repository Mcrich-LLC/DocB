//
//  ChevronView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI

struct ChevronView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
