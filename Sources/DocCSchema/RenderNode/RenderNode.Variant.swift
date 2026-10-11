// A render node variant based on a collection of pre-defined traits, such as interface language.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderNodeVariant.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `Trait.Error` conformed to `DescribedError`; it now conforms to `Swift.Error` with
// its `errorDescription` renamed to `description`.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
import Foundation

extension RenderNode {
    /// A render node variant based on a collection of pre-defined traits.
    ///
    /// A variant features a collection of traits and a path where the variant can be found.
    /// When rendered as JSON, the data looks like this:
    /// ```json
    /// {
    ///   "traits" : [
    ///     { "interfaceLanguage": "swift" }
    ///   ],
    ///   "paths" : ["/path/to/variant"]
    /// }
    /// ```
    public struct Variant: Codable, Equatable {

        /// A trait describing an aspect of the render variant.
        public enum Trait: Codable, Hashable {
            /// Presentation language (e.g. Swift or Obj-C).
            case interfaceLanguage(String)

            /// A trait this version of the schema does not know, preserved verbatim.
            case unknown(JSON)

            internal enum CodingKeys: String, CodingKey, CaseIterable {
                case interfaceLanguage
            }

            public enum Error: Swift.Error {
                case invalidTrait
                public var description: String {
                    switch self {
                    case .invalidTrait: return "None of expected trait keys \(CodingKeys.allCases) was found."
                    }
                }
            }

            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let language = try container.decodeIfPresent(String.self, forKey: .interfaceLanguage) {
                    self = .interfaceLanguage(language)
                    return
                }

                // Tolerant:
                self = .unknown(try JSON(from: decoder))
            }

            public func encode(to encoder: any Encoder) throws {
                if case .unknown(let json) = self {
                    try json.encode(to: encoder)
                    return
                }

                var container = encoder.container(keyedBy: CodingKeys.self)

                switch self {
                case .interfaceLanguage(let language):
                    try container.encode(language, forKey: .interfaceLanguage)
                case .unknown:
                    break // Handled above.
                }
            }
        }

        /// Collection of traits identifying the variant.
        public var traits: [Trait]

        /// The paths to the variant.
        public var paths: [String]

        internal enum CodingKeys: String, CodingKey {
            case traits, paths
        }

        public init(traits: [Trait], paths: [String]) {
            self.traits = traits
            self.paths = paths
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            traits = try container.decode([Trait].self, forKey: .traits)
            paths = try container.decode([String].self, forKey: .paths)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(traits, forKey: .traits)
            try container.encode(paths, forKey: .paths)
        }
    }
}
