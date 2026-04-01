//
//  CodeFontModifier.swift
//  DevDocs
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
    @ViewBuilder
    func applyCodeFont() -> some View {
        self.modifier(CodeFontModifier())
    }
}

private struct CodeFontModifier: ViewModifier {
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
