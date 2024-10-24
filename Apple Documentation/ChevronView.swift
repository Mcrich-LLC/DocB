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
            .foregroundStyle(colorScheme == .dark ? Color.primary : Color(uiColor: .systemGray3))
        #else
            .foregroundStyle(Color(uiColor: .systemGray3))
        #endif
    }
}

#Preview {
    ChevronView()
}
