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
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemSymbol: .xCircle)
                        .labelStyle(.iconOnly)
                }
                .buttonBorderShape(.circle)
            }
            KFImage(identifier.url)
                .placeholder({
                    Image(systemSymbol: .photo)
                        .resizable()
                        .scaledToFit()
                })
                .resizable()
                .scaledToFit()
                .zoomable()
        }
        .padding()
    }
}
