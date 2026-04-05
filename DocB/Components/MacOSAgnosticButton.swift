//
//  MacOSAgnosticButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI

/// Cross-platform tappable control that behaves like a button on all supported platforms.
///
/// - Important: On macOS/Catalyst this uses `onTapGesture` to keep list-like row interactions visually consistent.
struct MacOSAgnosticButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Content
    
    var body: some View {
#if os(macOS) || targetEnvironment(macCatalyst)
        label
            .onTapGesture(perform: action)
        #else
        Button(action: action, label: {label})
        #endif
    }
}

/// Cross-platform link wrapper that opens URLs via gesture on macOS/Catalyst and `Link` elsewhere.
struct MacOSAgnosticLink<Content: View>: View {
    /// Destination URL opened when the link is activated.
    let destination: URL
    /// Link label content.
    @ViewBuilder let label: Content
    /// Environment URL opener used on macOS/Catalyst gesture activation.
    @Environment(\.openURL) var openURL
    
    var body: some View {
#if os(macOS) || targetEnvironment(macCatalyst)
        label
            .onTapGesture {
                openURL(destination)
            }
        #else
        Link(destination: destination, label: {label})
        #endif
    }
}
