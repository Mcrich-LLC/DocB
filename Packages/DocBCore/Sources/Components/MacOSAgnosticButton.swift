//
//  MacOSAgnosticButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI

/// Cross-platform tappable control that behaves like a button on all supported platforms.
public struct MacOSAgnosticButton<Content: View>: View {
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.label = label()
    }
    
    let action: () -> Void
    @ViewBuilder let label: Content
    
    public var body: some View {
#if os(macOS) || targetEnvironment(macCatalyst)
        Button(action: action, label: { label.contentShape(Rectangle()) })
            .buttonStyle(.plain)
        #else
        Button(action: action, label: {label})
        #endif
    }
}

/// Cross-platform link wrapper that opens URLs via gesture on macOS/Catalyst and `Link` elsewhere.
public struct MacOSAgnosticLink<Content: View>: View {
    public init(destination: URL, @ViewBuilder label: () -> Content) {
        self.destination = destination
        self.label = label()
    }
    
    /// Destination URL opened when the link is activated.
    let destination: URL
    /// Link label content.
    @ViewBuilder let label: Content
    @Environment(\.openURL) var openURL
    
    public var body: some View {
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
