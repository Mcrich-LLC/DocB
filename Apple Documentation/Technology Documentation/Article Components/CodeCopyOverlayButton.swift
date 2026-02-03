//
//  CopyOverlayButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import SwiftUI

/// A button overlay that allows copying a string to the clipboard.
struct CodeCopyOverlayButton: View {
    /// The string to copy.
    let string: String
    @State private var hasCoppied: Bool = false
    
    var body: some View {
#if os(macOS) || targetEnvironment(macCatalyst) || os(visionOS)
        GroupBox {
            MacOSAgnosticButton {
                #if os(macOS)
                NSPasteboard.general.setString(string, forType: .string)
                #else
                UIPasteboard.general.string = string
                #endif
                
                withAnimation {
                    hasCoppied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    withAnimation {
                        hasCoppied = false
                    }
                }
            } label: {
                Label("Copy", systemSymbol: hasCoppied ? .checkmark : .listClipboard)
                    .labelStyle(.iconOnly)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(string.contains("\n") ? 1 : 0.75)
        #else
        EmptyView()
            .frame(width: 0, height: 0)
        #endif
    }
}
