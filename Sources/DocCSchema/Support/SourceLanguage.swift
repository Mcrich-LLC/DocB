// A programming language identifier (for example "Swift" or "Objective-C") used to tag
// render JSON content and topic references by source language.
//
// Copied from swift-docc `Sources/DocCCommon/SourceLanguage.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the private interned `_id` representation and its `Mutex`-protected registry of
// dynamically-created "unknown" languages are removed; `SourceLanguage` now stores its
// `name`, `id`, `idAliases`, and `linkDisambiguationID` directly as stored properties. The
// `SmallSourceLanguageSet` type (which required `_FixedSizeBitSet`) is also removed.
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A programming language, for example "Swift" or "Objective-C".
public struct SourceLanguage: Hashable, Codable, Comparable, Sendable, CustomDebugStringConvertible {
    /// The display name of the programming language.
    public var name: String
    /// A globally unique identifier for the language.
    public var id: String
    /// Aliases for the language's identifier.
    public var idAliases: [String]
    /// The identifier to use for link disambiguation purposes.
    public var linkDisambiguationID: String

    // MARK: Known Languages

    /// The Swift programming language.
    public static let swift = SourceLanguage(name: "Swift", id: "swift")

    /// Miscellaneous data, that's not a programming language.
    ///
    /// For example, use this to represent JSON or XML content.
    public static let data = SourceLanguage(name: "Data", id: "data")
    /// The JavaScript programming language or another language that conforms to the ECMAScript specification.
    public static let javaScript = SourceLanguage(name: "JavaScript", id: "javascript")
    /// The Metal programming language.
    public static let metal = SourceLanguage(name: "Metal", id: "metal")

    /// The Objective-C programming language.
    public static let objectiveC = SourceLanguage(
        name: "Objective-C",
        id: "occ",
        idAliases: [
            "objective-c",
            "objc",
            "c",   // FIXME: DocC should display C as its own language (https://github.com/swiftlang/swift-docc/issues/169).
            "c++", // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
            "objective-c++",
            "objc++",
            "occ++",
        ],
        linkDisambiguationID: "c"
    )

    /// The list of programming languages that are known to DocC.
    public static let knownLanguages: [SourceLanguage] = [.swift, .objectiveC, .javaScript, .data, .metal]

    // MARK: Creating languages

    /// Creates a new language with a given name and identifier.
    /// - Parameters:
    ///   - name: The display name of the programming language.
    ///   - id: A globally unique identifier for the language.
    ///   - idAliases: Aliases for the language's identifier.
    ///   - linkDisambiguationID: The identifier to use for link disambiguation purposes.
    public init(name: String, id: String, idAliases: [String] = [], linkDisambiguationID: String? = nil) {
        self.name = name
        self.id = id
        self.idAliases = idAliases
        self.linkDisambiguationID = linkDisambiguationID ?? id
    }

    /// Finds the programming language that matches a given identifier, or creates a new one if it finds no existing language.
    /// - Parameter id: The identifier of the programming language.
    public init(id: String) {
        if let known = Self._knownLanguage(withIdentifier: id) {
            self = known
        } else {
            self.init(name: id, id: id)
        }
    }

    /// Finds the programming language that matches a given display name, or creates a new one if it finds no existing language.
    ///
    /// - Parameter name: The display name of the programming language.
    public init(name: String) {
        let id = name.lowercased()
        if let knownLanguage = Self.knownLanguage(withName: name) ?? Self._knownLanguage(withIdentifier: id) {
            self = knownLanguage
        } else {
            self.init(name: name, id: id)
        }
    }

    /// Finds the programming language that matches a given display name.
    ///
    /// If the language name doesn't match any known language, this initializer returns `nil`.
    ///
    /// - Parameter knownLanguageName: The display name of the programming language.
    public init?(knownLanguageName: String) {
        if let knownLanguage = Self.knownLanguage(withName: knownLanguageName) {
            self = knownLanguage
        } else {
            return nil
        }
    }

    /// Finds the programming language that matches a given identifier.
    ///
    /// If the language identifier doesn't match any known language, this initializer returns `nil`.
    ///
    /// - Parameter knownLanguageIdentifier: The identifier name of the programming language.
    public init?(knownLanguageIdentifier: String) {
        if let knownLanguage = Self._knownLanguage(withIdentifier: knownLanguageIdentifier) {
            self = knownLanguage
        } else {
            return nil
        }
    }

    private static func knownLanguage(withName name: String) -> SourceLanguage? {
        switch name.lowercased() {
            case "swift":       .swift
            case "objective-c": .objectiveC
            case "javascript":  .javaScript
            case "data":        .data
            case "metal":       .metal
            default:            nil
        }
    }

    private static func _knownLanguage(withIdentifier id: String) -> SourceLanguage? {
        switch id.lowercased() {
            case "swift":      .swift
            case "occ", "objc", "objective-c",
                 "c", // FIXME: DocC should display C as its own language (https://github.com/swiftlang/swift-docc/issues/169).
                 "occ++", "objc++", "objective-c++", "c++": // FIXME: DocC should display C++ and Objective-C++ as their own languages (https://github.com/swiftlang/swift-docc/issues/767)
                                .objectiveC
            case "javascript":  .javaScript
            case "data":        .data
            case "metal":       .metal
            default:            nil
        }
    }
}

// MARK: Conformances

extension SourceLanguage {
    private enum CodingKeys: CodingKey {
        case name, id, idAliases, linkDisambiguationID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let id = try container.decode(String.self, forKey: .id)
        let idAliases = try container.decodeIfPresent([String].self, forKey: .idAliases) ?? []
        let linkDisambiguationID = try container.decodeIfPresent(String.self, forKey: .linkDisambiguationID)

        self.init(name: name, id: id, idAliases: idAliases, linkDisambiguationID: linkDisambiguationID)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(id, forKey: .id)
        if !idAliases.isEmpty {
            try container.encode(idAliases, forKey: .idAliases)
        }
        try container.encode(linkDisambiguationID, forKey: .linkDisambiguationID)
    }
}

extension SourceLanguage {
    public static func < (lhs: SourceLanguage, rhs: SourceLanguage) -> Bool {
        if let lhsIndex = knownLanguages.firstIndex(of: lhs), let rhsIndex = knownLanguages.firstIndex(of: rhs) {
            // If both languages are known, their position in `knownLanguages` is also their sort order.
            lhsIndex < rhsIndex
        }

        // Sort Swift before other languages.
        else if lhs == .swift {
            true
        } else if rhs == .swift {
            false
        } else {
            // Otherwise, sort by ID (a string) for a stable order.
            lhs.id < rhs.id
        }
    }
}

// Among other things; parameterized tests with language parameters display this value.
extension SourceLanguage {
    public var debugDescription: String {
        "\(name) (\(id))"
    }
}
