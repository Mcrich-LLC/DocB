//
//  backgroundExtensionEffectIfAvailable.swift
//  DevDocs
//
//  Created by Morris Richman on 3/25/26.
//

import SwiftUI

extension View {
    @inlinable @ViewBuilder
    public func backgroundExtensionEffectIfAvailable() -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
    }
}
