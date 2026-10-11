// A namespace for creating `JSONDecoder` instances for decoding ``RenderNode`` values.
//
// Copied from swift-docc `Sources/SwiftDocC/Converter/RenderNode+Coding.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A namespace for decoders for render node JSON.
public enum RenderJSONDecoder {
    /// Creates a new JSON decoder for render node values.
    ///
    /// - Returns: The new JSON decoder.
    public static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
