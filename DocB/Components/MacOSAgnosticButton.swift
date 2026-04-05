//
//  MacOSAgnosticButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI

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
