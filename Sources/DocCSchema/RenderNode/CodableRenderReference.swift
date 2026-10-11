// A Codable container that type-erases a RenderReference value, dispatching decode to the
// correct concrete reference type based on its `type`.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderNode/CodableRenderReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: unknown values are preserved instead of failing to decode.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A Codable container for a render node reference.
internal struct CodableRenderReference: Codable {
    internal var reference: any RenderReference

    internal init(_ reference: any RenderReference) {
        self.reference = reference
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RenderReferenceType.self, forKey: .type)

        switch type {
        case .image:
            reference = try ImageReference(from: decoder)
        case .video:
            reference = try VideoReference(from: decoder)
        case .file:
            reference = try FileReference(from: decoder)
        case .fileType:
            reference = try FileTypeReference(from: decoder)
        case .xcodeRequirement:
            reference = try XcodeRequirementReference(from: decoder)
        case .topic:
            reference = try TopicRenderReference(from: decoder)
        case .section:
            reference = try TopicRenderReference(from: decoder)
        case .download, .externalLocation:
            reference = try DownloadReference(from: decoder)
        case .unresolvable:
            reference = try UnresolvedRenderReference(from: decoder)
        case .link:
            reference = try LinkReference(from: decoder)
        case .unknown:
            reference = try UnknownRenderReference(from: decoder)
        }
    }

    private enum CodingKeys: CodingKey {
        case type
    }

    internal func encode(to encoder: any Encoder) throws {
        try reference.encode(to: encoder)
    }
}
