//
//  FillAllSpaceModifier.swift
//  Anchor
//
//  Created by Morris Richman on 1/16/25.
//

import Foundation
import SwiftUI

/// Centers content by surrounding it with spacers so it expands to fill the available area.
struct FillAllSpaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                content
                Spacer()
            }
            Spacer()
        }
    }
}

extension View {
    /// Wraps the view in a full-space centering layout.
    func fillSpaceAvailable() -> some View {
        modifier(FillAllSpaceModifier())
    }
}
