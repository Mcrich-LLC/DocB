// A reference that resolves to a file, giving conforming types a shared base URL and the
// logic to rewrite a source file URL to its render JSON destination URL.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/RenderReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference that has a file.
public protocol URLReference {
    /// The base URL that file URLs of the conforming type are relative to.
    static var baseURL: URL { get }
}

extension URLReference {
    /// Transforms the given URL to ensure that it is relative to the base URL of the conforming type.
    ///
    /// The converter that writes the built documentation to the file system is responsible for copying the referenced file to this destination.
    /// - Parameters:
    ///   - url: The URL of the file.
    ///   - prefixComponent: An optional path component to add before the path of the file.
    /// - Returns: The transformed URL for the given file path.
    internal func renderURL(for url: URL, prefixComponent: String?) -> URL {
        // Web URLs should be left as-is
        guard !url.isAbsoluteWebURL else {
            return url
        }

        // URLs which are already relative to the base URL should be left as-is
        guard !url.pathComponents.starts(with: Self.baseURL.pathComponents) else {
            return url
        }

        return destinationURL(for: url.lastPathComponent, prefixComponent: prefixComponent)
    }

    /// Returns the URL for a given file path relative to the base URL of the conforming type.
    ///
    /// The converter that writes the built documentation to the file system is responsible for copying the referenced file to this destination.
    ///
    /// - Parameters:
    ///   - path: The path of the file.
    ///   - prefixComponent: An optional path component to add before the path of the file.
    /// - Returns: The destination URL for the given file path.
    internal func destinationURL(for path: String, prefixComponent: String?) -> URL {
        var url = Self.baseURL
        if let bundleName = prefixComponent {
            url.appendPathComponent(bundleName, isDirectory: true)
        }
        url.appendPathComponent(path, isDirectory: false)
        return url
    }
}
