//
//  BackForwardModifier.swift
//  Anchor
//
//  Created by Morris Richman on 1/16/25.
//

import Foundation
import SwiftUI

/// Directional transition modifier used for navigation-style back/forward animations.
///
/// - Important: The transition edge is derived from `isBack` to keep motion direction consistent with history traversal.
struct BackForwardModifier: ViewModifier {
    let isBack: Bool
    func body(content: Content) -> some View {
        content
            .transition(
                isBack ?
                    .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
                :
                    .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            )
    }
}
extension View {
    /// Applies a directional back/forward transition to the receiving view.
    ///
    /// - Parameter isBack: `true` for backward motion, `false` for forward motion.
    func backForward(isBack: Bool) -> some View {
        modifier(BackForwardModifier(isBack: isBack))
    }
}
