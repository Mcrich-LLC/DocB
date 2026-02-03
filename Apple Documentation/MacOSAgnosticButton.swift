//
//  MacOSAgnosticButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI

/// A button that adapts its behavior based on the operating system.
///
/// On macOS, it treats the content as a clickable view (using `onTapGesture`), while on other platforms it uses a standard `Button`.
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

/// A navigation link that adapts its behavior based on the operating system.
///
/// On macOS, it opens the URL using the environment's `openURL` action when tapped, while on other platforms it uses a standard `Link`.
struct MacOSAgnosticLink<Content: View>: View {
    let destination: URL
    @ViewBuilder let label: Content
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
