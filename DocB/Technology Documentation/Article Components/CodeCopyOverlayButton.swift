//
//  CopyOverlayButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import SwiftUI

/// CodeCopyOverlayButton renders a reusable SwiftUI view.
struct CodeCopyOverlayButton: View {
    /// Text payload copied to the system pasteboard.
    let string: String
    /// Tracks whether copy feedback should show a checkmark icon.
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
        #if os(visionOS)
        .backgroundStyle(.clear)
        #else
        .background(.regularMaterial)
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(string.contains("\n") ? 1 : 0.75)
        #if os(visionOS)
        .offset(y: -12)
        #endif
        #else
        EmptyView()
            .frame(width: 0, height: 0)
        #endif
    }
}
