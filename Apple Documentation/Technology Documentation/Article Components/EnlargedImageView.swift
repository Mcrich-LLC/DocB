//
//  EnlargedImageView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 2/19/25.
//

import SwiftUI
import Kingfisher

struct EnlargedImageSheetIdentifier: Identifiable {
    let id = UUID()
    let identifier: String
    let url: URL
}

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
            Button {
                dismiss()
            } label: {
                Label("Close", systemSymbol: .xCircle)
                    .labelStyle(.iconOnly)
#if !os(macOS)
                    .background(Color(platformColor: .systemBackground))
                    .clipShape(.circle)
                    .font(.title3)
#endif
            }
            .buttonBorderShape(.circle)
        })
        .padding()
    }
}
