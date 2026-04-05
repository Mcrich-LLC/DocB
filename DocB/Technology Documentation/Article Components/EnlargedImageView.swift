//
//  EnlargedImageView.swift
//  DocB
//
//  Created by Morris Richman on 2/19/25.
//

import SwiftUI
import Kingfisher

/// EnlargedImageSheetIdentifier represents reusable app data or behavior.
struct EnlargedImageSheetIdentifier: Identifiable {
    let id = UUID()
    let identifier: String
    let url: URL
}

/// EnlargedImageView renders a reusable SwiftUI view.
struct EnlargedImageView: View {
    let identifier: EnlargedImageSheetIdentifier
    @Environment(\.dismiss) var dismiss
    
    var isPhone: Bool {
#if os(macOS)
        return false
#else
        return UIDevice.current.userInterfaceIdiom == .phone
#endif
    }
    
    var body: some View {
        VStack {
            KFImage(identifier.url)
                .placeholder({
                    Image(systemSymbol: .photo)
                        .resizable()
                        .scaledToFit()
                })
                .resizable()
                .scaledToFit()
                .zoomable()
                .padding(.top, isPhone ? 0 : nil)
        }
        .frame(minWidth: isPhone ? nil : 600, maxWidth: .infinity, minHeight: isPhone ? nil : 300, maxHeight: .infinity)
        .overlay(alignment: .topTrailing, content: {
            ToolbarCloseButton()
        })
        .padding()
    }
}
