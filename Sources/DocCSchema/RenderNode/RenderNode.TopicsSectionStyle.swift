// The rendering style of a render node's Topics section.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/TopicsSectionStyle.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

extension RenderNode {
    /// The rendering style of the topics section.
    public enum TopicsSectionStyle: TolerantStringEnum {
        /// A list of the page's topics, including their full declaration and abstract.
        case list

        /// A grid of items based on the card image for each page.
        ///
        /// Includes each page’s title and card image but excludes their abstracts.
        case compactGrid

        /// A grid of items based on the card image for each page.
        ///
        /// Unlike ``compactGrid``, this style includes the abstract for each page.
        case detailedGrid

        /// Do not show child pages anywhere on the page.
        case hidden

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "list": self = .list
            case "compactGrid": self = .compactGrid
            case "detailedGrid": self = .detailedGrid
            case "hidden": self = .hidden
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .list: "list"
            case .compactGrid: "compactGrid"
            case .detailedGrid: "detailedGrid"
            case .hidden: "hidden"
            case .unknown(let rawValue): rawValue
            }
        }
    }
}
