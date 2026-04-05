//
//  backgroundExtensionEffectIfAvailable.swift
//  DocB
//
//  Created by Morris Richman on 3/25/26.
//

import SwiftUI

/// Compatibility helpers for applying background extension effects only on supported OS versions.
extension View {
    /// Applies `backgroundExtensionEffect()` on supported OS versions and otherwise returns the view unchanged.
    @inlinable @ViewBuilder
    public func backgroundExtensionEffectIfAvailable() -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
    }
}
