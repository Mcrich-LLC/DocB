/// A DocC interface language used when loading language-specific payload variants.
public enum PreferredProgrammingLanguage: String, Codable, CaseIterable, Sendable {
    case swift
    case objectivec = "objc"
    case data
    
    /// A user-facing language label used in UI surfaces.
    public var humanReadable: String? {
        switch self {
        case .swift:
            "Swift"
        case .objectivec:
            "Objective-C"
        case .data:
            nil
        }
    }
    
    /// The language token expected in certain DocC variant payloads.
    public var jsonCodingValue: String {
        switch self {
        case .swift:
            "swift"
        case .objectivec:
            "occ"
        case .data:
            "data"
        }
    }
    
    /// Creates a language from current and historical DocC raw values.
    ///
    /// - Parameter rawValue: The raw language token.
    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "swift":
            self = .swift
        case "objc", "occ":
            self = .objectivec
        case "data":
            self = .data
        default:
            return nil
        }
    }
}
