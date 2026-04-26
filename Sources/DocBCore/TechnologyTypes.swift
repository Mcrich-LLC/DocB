import Foundation

/// Unified technology source type representing Apple-hosted and custom DocC providers in the DocB app.
public enum TechnologyTypes: Identifiable, Equatable {
    case apple(AppleTechnologies)
    case docC(DocCSiteDTO)
    
    /// Stable identifier for the underlying technology payload.
    public var id: UUID {
        switch self {
        case .apple(let apple):
            return apple.id
        case .docC(let docC):
            return docC.id
        }
    }
    
    /// Base URL for this technology source.
    public var url: URL {
        switch self {
        case .apple:
            return URL(string: Constants.aDeveloperURLBase)!
        case .docC(let docCSiteDTO):
            return docCSiteDTO.url
        }
    }
    
    /// Whether this value represents a custom DocC site.
    public var isDocC: Bool {
        switch self {
        case .apple:
            return false
        case .docC:
            return true
        }
    }
    
    /// Whether this value represents Apple Developer Documentation.
    public var isApple: Bool {
        switch self {
        case .apple:
            return true
        case .docC:
            return false
        }
    }
    
    /// Display names for technology grouping in the UI.
    @MainActor
    public var names: [String] {
        switch self {
        case .apple:
            return ["Apple Developer Documentation"]
        case .docC(let docC):
            return docC.groups.map(\.title)
        }
    }
    
    /// Preferred primary display name for this technology source.
    @MainActor
    public var primaryName: String {
        switch self {
        case .apple:
            return "Apple Developer Documentation"
        case .docC(let docC):
            return docC.overrideName ?? docC.groups.filter { $0.type.lowercased() == "module" }.map(\.title).first ?? "Unknown"
        }
    }
}

extension [TechnologyTypes] {
    /// Custom DocC site values extracted from mixed technology arrays.
    public var docCSites: [DocCSiteDTO] {
        compactMap { tech in
            switch tech {
            case .apple:
                nil
            case .docC(let docC):
                docC
            }
        }
    }
    
    /// Apple technology values extracted from mixed technology arrays.
    public var appleTechnologies: [AppleTechnologies] {
        compactMap { tech in
            switch tech {
            case .apple(let apple):
                apple
            case .docC:
                nil
            }
        }
    }
}
