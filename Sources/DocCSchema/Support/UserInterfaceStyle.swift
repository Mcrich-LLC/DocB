// The interface style (light or dark) for a rendering context, used by ``DataTraitCollection``.
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

/// The interface style for a rendering context.
public enum UserInterfaceStyle: String, CaseIterable, Codable, Sendable {
    /// The light interface style.
    case light = "light"
    
    /// The dark interface style.
    case dark = "dark"
}
