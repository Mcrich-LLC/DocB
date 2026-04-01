//
//  ToolbarCloseButton.swift
//  DevDocs
//
//  Created by Morris Richman on 3/11/26.
//

import SwiftUI

struct ToolbarCloseButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            Button(role: .close, action: dismiss.callAsFunction)
        } else {
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
        }
    }
}

#Preview {
    ToolbarCloseButton()
}
