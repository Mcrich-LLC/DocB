//
//  CodeFontModifier.swift
//  DocB
//
//  Created by Marquis Kurt on 28-02-2026.
//

import SwiftUI

#if canImport(UIKit)
    typealias FontType = UIFont
#elseif canImport(AppKit)
    typealias FontType = NSFont
#endif

extension View {
    /// Applies the app's monospaced code-style font at a platform-appropriate headline size.
    @ViewBuilder
    public func applyCodeFont() -> some View {
        self.modifier(CodeFontModifier())
    }
}

extension Text {
    public func applyCodeFont() -> Text {
        self
            .font(
                .system(
                    size: FontType.preferredFont(forTextStyle: .headline).pointSize,
                    weight: .regular,
                    design: .monospaced
                )
            )
    }
}

/// View modifier that applies monospaced code typography at headline-equivalent size.
private struct CodeFontModifier: ViewModifier {
    /// Renders content using a monospaced system font sized to match headline typography.
    func body(content: Content) -> some View {
        content
            .font(
                .system(
                    size: FontType.preferredFont(forTextStyle: .headline).pointSize,
                    weight: .regular,
                    design: .monospaced
                )
            )
    }
}
