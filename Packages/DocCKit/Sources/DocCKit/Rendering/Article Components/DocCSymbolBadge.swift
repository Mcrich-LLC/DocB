import SFSafeSymbols
import Foundation
import NukeUI
import SwiftUI

/// Xcode documentation-style symbol categories used by DocC badges.
public enum SidebarSearchSymbolKind: String, Codable, Sendable {
    case article
    case classSymbol
    case collection
    case collectionGroup
    case enumeration
    case enumerationCase
    case framework
    case function
    case initializer
    case macro
    case method
    case property
    case protocolSymbol
    case structure
    case typeAlias
    case variable
    case unknown

    /// Whether this best-effort kind benefits from full article metadata refinement.
    public var needsRoleHeadingRefinement: Bool {
        self == .structure
    }

    /// Creates a symbol kind from a DocC index node.
    ///
    /// - Parameter interfaceLanguage: DocC index node to classify.
    public init(interfaceLanguage: DocCIndex.InterfaceLanguage) {
        self.init(
            title: interfaceLanguage.title,
            path: interfaceLanguage.path,
            type: interfaceLanguage.type
        )
    }

    /// Creates a symbol kind from framework reference metadata.
    ///
    /// - Parameters:
    ///   - reference: DocC reference to classify.
    ///   - title: Display title used as a fallback when metadata is incomplete.
    public init(reference: Reference, title: String) {
        if let roleHeadingSymbolKind = Self(roleHeading: reference.roleHeading) {
            self = roleHeadingSymbolKind
            return
        }

        if let roleSymbolKind = Self.symbolKind(for: reference.role) {
            self = roleSymbolKind
            return
        }

        let path = URL(string: reference.identifier)?.path()
        if let fragmentSymbolKind = Self.symbolKind(forFragments: reference.fragments, path: path) {
            self = fragmentSymbolKind
            return
        }

        self.init(title: title, path: path, type: reference.type)
    }

    /// Creates a symbol kind from the metadata available in DocC indexes.
    /// Falls back to title and path shape only when no role or type metadata identifies the symbol.
    ///
    /// - Parameters:
    ///   - title: Display title.
    ///   - path: Optional documentation path.
    ///   - type: DocC node type.
    public init(title: String, path: String?, type: String) {
        self = Self.symbolKind(forRole: Role(rawValue: type))
            ?? Self.symbolKind(forType: type)
            ?? Self.symbolKind(forTitle: title, path: path)
    }

    /// Creates a symbol kind from article metadata when a full DocC page is available.
    ///
    /// - Parameter roleHeading: Human-readable DocC role heading, such as `Enumeration` or `Initializer`.
    public init?(roleHeading: String?) {
        guard let normalizedRoleHeading = Self.normalizedRoleHeading(roleHeading),
              let symbolKind = Self.symbolKindByRoleHeading[normalizedRoleHeading]
        else {
            return nil
        }

        self = symbolKind
    }

    /// Returns a human-readable role title for subtitles and accessibility.
    ///
    /// - Parameters:
    ///   - symbolKind: Symbol kind to describe.
    ///   - fallback: Raw role string used when `symbolKind` is unknown.
    /// - Returns: A display title for the role.
    public static func title(for symbolKind: SidebarSearchSymbolKind, fallback: String) -> String {
        switch symbolKind {
        case .article:
            "Article"
        case .classSymbol:
            "Class"
        case .collection:
            "Collection"
        case .collectionGroup:
            "Collection Group"
        case .framework:
            "Framework"
        case .enumeration:
            "Enumeration"
        case .enumerationCase:
            "Enumeration Case"
        case .function:
            "Function"
        case .initializer:
            "Initializer"
        case .macro:
            "Macro"
        case .method:
            "Method"
        case .property:
            "Property"
        case .protocolSymbol:
            "Protocol"
        case .structure:
            "Structure"
        case .typeAlias:
            "Type Alias"
        case .variable:
            "Variable"
        case .unknown:
            fallback.isEmpty ? "Documentation" : fallback.capitalized
        }
    }
    
    /// Returns the visual treatment used to render a symbol kind badge.
    ///
    /// - Returns: Text, icon, and color values used by `DocCSymbolBadge`.
    public var appearance: BadgeAppearance {
        switch self {
        case .article:
            BadgeAppearance(text: "", symbol: .textDocument, foreground: .secondary, background: nil)
        case .classSymbol:
            BadgeAppearance(text: "C", symbol: nil, foreground: .white, background: .xcodeProtocolPurple)
        case .collection, .collectionGroup:
            BadgeAppearance(text: "", symbol: .listBullet, foreground: .secondary, background: nil)
        case .enumeration, .enumerationCase:
            BadgeAppearance(text: "E", symbol: nil, foreground: .white, background: .xcodeObjCOrange)
        case .framework:
            BadgeAppearance(text: "", symbol: .squareStack3dUp, foreground: .secondary, background: nil)
        case .function:
            BadgeAppearance(text: "", symbol: .fCursive, foreground: .white, background: .xcodeMemberGreen)
        case .initializer, .method:
            BadgeAppearance(text: "M", symbol: nil, foreground: .white, background: .xcodeSwiftBlue)
        case .macro:
            BadgeAppearance(text: "#", symbol: nil, foreground: .white, background: .xcodeMacroRed)
        case .property:
            BadgeAppearance(text: "P", symbol: nil, foreground: .white, background: .xcodeMemberTeal)
        case .protocolSymbol:
            BadgeAppearance(text: "Pr", symbol: nil, foreground: .white, background: .xcodeProtocolPurple)
        case .structure:
            BadgeAppearance(text: "S", symbol: nil, foreground: .white, background: .xcodeProtocolPurple)
        case .typeAlias:
            BadgeAppearance(text: "T", symbol: nil, foreground: .white, background: .xcodeObjCOrange)
        case .variable:
            BadgeAppearance(text: "V", symbol: nil, foreground: .white, background: .xcodeMemberGreen)
        case .unknown:
            BadgeAppearance(text: "", symbol: .textDocument, foreground: .secondary, background: nil)
        }
    }

    /// Describes the text, icon, and colors used to render a DocC symbol badge.
    public struct BadgeAppearance {
        /// Short badge text displayed when no SF Symbol is provided.
        public let text: String
        /// Optional SF Symbol displayed instead of text.
        public let symbol: SFSymbol?
        /// Foreground color applied to the text or SF Symbol.
        public let foreground: Color
        /// Optional badge fill color.
        public let background: Color?
        /// Optional custom image identifier used instead of text or an SF Symbol.
        public let customImageIdentifier: String?

        /// Creates a symbol badge appearance.
        ///
        /// - Parameters:
        ///   - text: Short badge text displayed when no SF Symbol is provided.
        ///   - symbol: Optional SF Symbol displayed instead of text.
        ///   - foreground: Foreground color applied to the text or SF Symbol.
        ///   - background: Optional badge fill color.
        ///   - customImageIdentifier: Optional custom image identifier used instead of text or an SF Symbol.
        public init(text: String, symbol: SFSymbol?, foreground: Color, background: Color?, customImageIdentifier: String? = nil) {
            self.text = text
            self.symbol = symbol
            self.foreground = foreground
            self.background = background
            self.customImageIdentifier = customImageIdentifier
        }

        /// Returns the corner radius for a badge of the supplied size.
        ///
        /// - Parameter size: Square badge size.
        /// - Returns: Corner radius scaled for the badge size.
        public func cornerRadius(for size: CGFloat) -> CGFloat {
            max(3.5, size * 0.22)
        }

        /// Returns the text font size for a badge of the supplied size.
        ///
        /// - Parameter size: Square badge size.
        /// - Returns: Font size scaled to fit the badge text.
        public func fontSize(for size: CGFloat) -> CGFloat {
            switch text.count {
            case 0...1:
                size * 0.76
            case 2:
                size * 0.62
            default:
                size * 0.52
            }
        }
    }
    
    private static func symbolKind(for role: Role?) -> SidebarSearchSymbolKind? {
        switch role {
        case .collection:
            .collection
        case .collectionGroup:
            .collectionGroup
        case .framework:
            .framework
        case .article, .overview, .sampleCode, .task, .subsection, .codeListing, .link, .pseudoSymbol:
            .article
        case .dictionarySymbol:
            .typeAlias
        default:
            nil
        }
    }

    private static func symbolKind(forRole role: Role?) -> SidebarSearchSymbolKind? {
        switch role {
        case .collection:
            .collection
        case .collectionGroup:
            .collectionGroup
        case .framework:
            .framework
        case .article, .overview, .sampleCode, .task, .subsection, .codeListing, .link, .pseudoSymbol:
            .article
        case .dictionarySymbol:
            .typeAlias
        default:
            nil
        }
    }

    private static func symbolKind(forType type: String) -> SidebarSearchSymbolKind? {
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let typeMappings: [String: SidebarSearchSymbolKind] = [
            "article": .article,
            "associated type": .typeAlias,
            "associatedtype": .typeAlias,
            "case": .enumerationCase,
            "class": .classSymbol,
            "constant": .variable,
            "enum": .enumeration,
            "enumeration": .enumeration,
            "extension": .structure,
            "func": .function,
            "function": .function,
            "init": .initializer,
            "initializer": .initializer,
            "instance method": .method,
            "instance property": .property,
            "let": .variable,
            "macro": .macro,
            "method": .method,
            "module": .framework,
            "op": .function,
            "operator": .function,
            "property": .property,
            "protocol": .protocolSymbol,
            "static method": .method,
            "static property": .property,
            "struct": .structure,
            "structure": .structure,
            "subscript": .method,
            "type alias": .typeAlias,
            "type method": .method,
            "type property": .property,
            "typealias": .typeAlias,
            "var": .variable,
            "variable": .variable
        ]

        return typeMappings[normalizedType]
    }

    private static let symbolKindByRoleHeading: [String: SidebarSearchSymbolKind] = [
        "article": .article,
        "articles": .article,
        "overview": .article,
        "guide": .article,
        "tutorial": .article,
        "sample code": .article,
        "sample codes": .article,
        "project": .article,
        "task": .article,
        "task group": .article,
        "section": .article,
        "class": .classSymbol,
        "classes": .classSymbol,
        "collection": .collection,
        "collections": .collection,
        "collection group": .collectionGroup,
        "collection groups": .collectionGroup,
        "dictionary": .typeAlias,
        "dictionary symbol": .typeAlias,
        "enumeration": .enumeration,
        "enumerations": .enumeration,
        "enum": .enumeration,
        "enums": .enumeration,
        "case": .enumerationCase,
        "cases": .enumerationCase,
        "enumeration case": .enumerationCase,
        "enumeration cases": .enumerationCase,
        "enum case": .enumerationCase,
        "enum cases": .enumerationCase,
        "framework": .framework,
        "frameworks": .framework,
        "module": .framework,
        "modules": .framework,
        "technology": .framework,
        "technologies": .framework,
        "function": .function,
        "functions": .function,
        "func": .function,
        "operator": .function,
        "operators": .function,
        "initializer": .initializer,
        "initializers": .initializer,
        "init": .initializer,
        "macro": .macro,
        "macros": .macro,
        "method": .method,
        "methods": .method,
        "instance method": .method,
        "instance methods": .method,
        "type method": .method,
        "type methods": .method,
        "static method": .method,
        "static methods": .method,
        "class method": .method,
        "class methods": .method,
        "property": .property,
        "properties": .property,
        "instance property": .property,
        "instance properties": .property,
        "type property": .property,
        "type properties": .property,
        "static property": .property,
        "static properties": .property,
        "class property": .property,
        "class properties": .property,
        "protocol": .protocolSymbol,
        "protocols": .protocolSymbol,
        "structure": .structure,
        "structures": .structure,
        "struct": .structure,
        "structs": .structure,
        "type alias": .typeAlias,
        "type aliases": .typeAlias,
        "typealias": .typeAlias,
        "associated type": .typeAlias,
        "associated types": .typeAlias,
        "associatedtype": .typeAlias,
        "variable": .variable,
        "variables": .variable,
        "constant": .variable,
        "constants": .variable,
        "global variable": .variable,
        "global variables": .variable,
        "global constant": .variable,
        "global constants": .variable,
        "http request": .method,
        "http requests": .method,
        "rest request": .method,
        "rest requests": .method,
        "request": .method,
        "requests": .method,
        "endpoint": .method,
        "endpoints": .method,
        "web service endpoint": .method,
        "web service endpoints": .method
    ]

    private static func normalizedRoleHeading(_ roleHeading: String?) -> String? {
        guard let roleHeading else {
            return nil
        }

        let normalizedRoleHeading = roleHeading
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()

        return normalizedRoleHeading.isEmpty ? nil : normalizedRoleHeading
    }

    private static func symbolKind(forTitle title: String, path: String?) -> SidebarSearchSymbolKind {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = trimmedTitle.lowercased()
        let pathComponents = path?.split(separator: "/").map(String.init) ?? []
        let lastPathComponent = pathComponents.last?.lowercased() ?? ""

        if lowercasedTitle.hasPrefix("init(") || lowercasedTitle == "init" {
            return .initializer
        } else if lowercasedTitle.hasSuffix("protocol") {
            return .protocolSymbol
        } else {
            return .article
        }
    }

    private static func symbolKind(forFragments fragments: [Fragment]?, path: String?) -> SidebarSearchSymbolKind? {
        let declarationWords = fragments?
            .filter { $0.kind == "keyword" || $0.kind == "identifier" || $0.kind == "text" }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty } ?? []

        guard !declarationWords.isEmpty else {
            return nil
        }

        if declarationWords.contains("init") {
            return .initializer
        } else if declarationWords.contains("class") {
            return .classSymbol
        } else if declarationWords.contains("enum") || declarationWords.contains("enumeration") {
            return .enumeration
        } else if declarationWords.contains("protocol") {
            return .protocolSymbol
        } else if declarationWords.contains("struct") {
            return .structure
        } else if declarationWords.contains("typealias") || declarationWords.contains("associatedtype") {
            return .typeAlias
        } else if declarationWords.contains("func") || declarationWords.contains("operator") {
            let pathComponents = path?.split(separator: "/") ?? []
            return pathComponents.count <= 3 ? .function : .method
        } else if declarationWords.contains("macro") {
            return .macro
        } else if declarationWords.contains("case") {
            return .enumerationCase
        } else if declarationWords.contains("let") || declarationWords.contains("var") {
            return .property
        }

        return nil
    }
}

/// Renders an Xcode documentation-style badge for a DocC symbol kind.
public struct DocCSymbolBadge: View {
    private let symbolKind: SidebarSearchSymbolKind
    private let size: CGFloat
    /// Accounts for background vs non-background icon sizing
    private let normalizedSize: CGFloat
    private let customImageIdentifier: String?
    private let references: [String: Reference]
    private let docCSite: DocCSource?
    private let archiveIdentifier: String?
    @Environment(\.colorScheme) private var colorScheme
    
    /// Get the default size based on device
    private static func getDefaultSize() -> CGFloat {
        #if os(macOS) || targetEnvironment(macCatalyst)
        16
        #else
        24
        #endif
    }
    
    /// Creates a symbol badge.
    ///
    /// - Parameters:
    ///   - symbolKind: Symbol kind to represent.
    ///   - size: Square badge size.
    ///   - customImageIdentifier: Optional custom image identifier used instead of the default badge artwork.
    ///   - references: Reference lookup table used to resolve custom image variants.
    ///   - docCSite: Optional custom DocC source used to resolve relative custom images.
    ///   - archiveIdentifier: Optional archive identifier used to resolve custom index icons.
    public init(
        symbolKind: SidebarSearchSymbolKind,
        size: CGFloat? = nil,
        customImageIdentifier: String? = nil,
        references: [String: Reference] = [:],
        docCSite: DocCSource? = nil,
        archiveIdentifier: String? = nil
    ) {
        self.symbolKind = symbolKind
        let size = size ?? Self.getDefaultSize()
        self.size = size
        self.normalizedSize = symbolKind.appearance.background == nil ? size+6 : size
        self.customImageIdentifier = customImageIdentifier
        self.references = references
        self.docCSite = docCSite
        self.archiveIdentifier = archiveIdentifier
    }

    public var body: some View {
        let appearance = symbolKind.appearance

        ZStack {
            if let customImageURL {
                LazyImage(url: customImageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius(for: size), style: .continuous))
                            .frame(width: size+6, height: size)
                            .padding(.horizontal, 3)
                    } else {
                        fallbackContent(appearance: appearance)
                            .frame(width: size+6)
                    }
                }
            } else {
                fallbackContent(appearance: appearance)
                    .frame(width: size+6)
            }
        }
        .dynamicTypeSize(.medium)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func fallbackContent(appearance: SidebarSearchSymbolKind.BadgeAppearance) -> some View {
        ZStack {
            if let background = appearance.background {
                RoundedRectangle(cornerRadius: appearance.cornerRadius(for: normalizedSize), style: .continuous)
                    .fill(background)
                    .frame(width: normalizedSize, height: normalizedSize)
            }

            if let symbol = appearance.symbol {
                Image(systemSymbol: symbol)
                    .font(.system(size: normalizedSize * 0.58, weight: appearance.background == nil ? .semibold : .bold))
                    .foregroundStyle(appearance.foreground)
            } else {
                Text(appearance.text)
                    .font(.system(size: appearance.fontSize(for: normalizedSize), weight: .semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(appearance.foreground)
                    .lineLimit(1)
                    .allowsTightening(true)
            }
        }
        .frame(width: normalizedSize, height: normalizedSize)
    }

    private var customImageURL: URL? {
        let identifier = customImageIdentifier ?? symbolKind.appearance.customImageIdentifier
        guard let identifier else {
            return nil
        }

        if let referencedURL = DocCAssetResolver.fetchPhotoVideoURL(for: identifier, references: references, colorScheme: colorScheme, docCSite: docCSite) {
            return referencedURL
        }

        guard let docCSite else {
            return nil
        }

        if let archiveIdentifier {
            return docCSite.url.appending(path: "images/\(archiveIdentifier)/\(identifier)")
        }

        return docCSite.url.appending(path: identifier)
    }
}

private extension Color {
    static let xcodeMemberGreen = Color(red: 0.1176470588, green: 0.7647058824, blue: 0.2156862745)
    static let xcodeMemberTeal = Color(red: 0.1803921569, green: 0.6549019608, blue: 0.7411764706)
    static let xcodeObjCOrange = Color(red: 0.9607843137, green: 0.5450980392, blue: 0)
    static let xcodeProtocolPurple = Color(red: 0.6235294118, green: 0.2941176471, blue: 0.7882352941)
    static let xcodeSwiftBlue = Color(red: 0, green: 0.4392156863, blue: 0.9607843137)
    static let xcodeMacroRed = Color(red: 0.9607843137, green: 0.1921568627, blue: 0.1490196078)
}
