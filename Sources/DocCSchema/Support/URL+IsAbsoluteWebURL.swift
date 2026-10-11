// Tells absolute web URLs apart from file URLs and `doc:` topic references, which
// decides whether a `URLReference` destination is rewritten with an asset prefix.
//
// Copied from swift-docc `Sources/SwiftDocC/Utility/FoundationExtensions/URL+IsAbsoluteWebURL.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

extension URL {
    /// Returns true if the scheme is not `nil` , not `file:`, not `ResolvedTopicReference.urlScheme`.
    ///
    /// - Returns: A Boolean value indicating whether the url is an absolute web URL.
    internal var isAbsoluteWebURL: Bool {
        guard !isFileURL,
              let scheme ,
              !scheme.isEmpty,
              scheme != ResolvedTopicReference.urlScheme else {
            return false
        }
        return true
    }
}
