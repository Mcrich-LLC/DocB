// The display-scale factor (1x, 2x, 3x) of a rendering environment, used by
// ``DataTraitCollection``.
//
// Copied from swift-docc `Sources/SwiftDocC/Infrastructure/Bundle Assets/DataAssetManager.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// The display-scale factor of a rendering environment.
///
/// ## See Also
///  - [Image size and resolution](https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/image-size-and-resolution/)
///  - [`UIScreen.scale` documentation](https://developer.apple.com/documentation/uikit/uiscreen/1617836-scale)
public enum DisplayScale: String, CaseIterable, Codable, Sendable {
    /// The 1x scale factor.
    case standard = "1x"
    
    /// The 2x scale factor.
    case double = "2x"
    
    /// The 3x scale factor.
    case triple = "3x"
    
    /// The scale factor as an integer.
    public var scaleFactor: Int {
        switch self {
        case .standard:
            return 1
        case .double:
            return 2
        case .triple:
            return 3
        }
    }
}
