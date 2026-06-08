import Foundation

/// Constants used for resolving Apple-hosted and custom DocC resources.
public enum DocCConstants {
    // Encode as base64 to avoid App Review getting mad. It decodes to https://developer.apple.com
    public static let appleDeveloperBaseURLString = base64Decoded("aHR0cHM6Ly9kZXZlbG9wZXIuYXBwbGUuY29t")!
    /// Base URL for Apple Developer Documentation.
    public static let aDeveloperURLBase = appleDeveloperBaseURLString
    /// Legacy tutorials data endpoint used by older Apple payloads.
    public static let basePath = URL(string: "\(appleDeveloperBaseURLString)/tutorials/data")!
    /// Default DocC identifier scheme used when a host app has not supplied an app-specific route.
    public static let defaultDeepLinkScheme = "doc://"
}

/// Describes the URL scheme DocCKit should use when it synthesizes in-app documentation links.
public struct DocCDeepLinkScheme: Hashable, Sendable {
    private static let explicitInfoDictionaryKeys = [
        "DocCKitDeepLinkScheme",
        "DocCDeepLinkScheme"
    ]
    
    /// Normalized URL prefix including the `://` separator.
    public let urlPrefix: String
    
    /// Creates a deep-link scheme from either a bare scheme name or a full URL prefix.
    ///
    /// - Parameter value: Bare scheme such as `my-docs` or URL prefix such as `my-docs://`.
    public init(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedValue.isEmpty {
            self.urlPrefix = DocCConstants.defaultDeepLinkScheme
        } else if trimmedValue.hasSuffix("://") {
            self.urlPrefix = trimmedValue
        } else if let separatorRange = trimmedValue.range(of: "://") {
            self.urlPrefix = String(trimmedValue[..<separatorRange.upperBound])
        } else {
            self.urlPrefix = "\(trimmedValue)://"
        }
    }
    
    /// Default DocC scheme used for unresolved documentation identifiers.
    public static let doc = DocCDeepLinkScheme(DocCConstants.defaultDeepLinkScheme)
    /// Scheme resolved from the main app bundle's Info.plist.
    public static var mainBundle: DocCDeepLinkScheme? {
        DocCDeepLinkScheme(bundle: .main)
    }
    
    /// Creates a deep-link scheme by inspecting a bundle's Info.plist.
    ///
    /// - Parameter bundle: Bundle whose Info.plist should be searched for a DocCKit scheme.
    public init?(bundle: Bundle) {
        guard let scheme = Self.preferredScheme(in: bundle.infoDictionary ?? [:], bundleIdentifier: bundle.bundleIdentifier) else {
            return nil
        }
        self.init(scheme)
    }
    
    /// Converts a DocC identifier into a URL string routed through this scheme.
    ///
    /// - Parameter identifier: DocC identifier such as `doc://com.example/documentation/MyType`.
    /// - Returns: A URL string using this deep-link scheme.
    public func urlString(forDocIdentifier identifier: String) -> String {
        identifier.replacingOccurrences(of: DocCConstants.defaultDeepLinkScheme, with: urlPrefix)
    }
    
    static func preferredScheme(in infoDictionary: [String: Any], bundleIdentifier: String?) -> String? {
        for key in explicitInfoDictionaryKeys {
            if let scheme = infoDictionary[key] as? String, !scheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return scheme
            }
        }
        
        let urlTypes = infoDictionary["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let registeredSchemes = urlTypes.flatMap { urlType -> [(name: String?, scheme: String)] in
            let name = urlType["CFBundleURLName"] as? String
            let schemes = urlType["CFBundleURLSchemes"] as? [String] ?? []
            
            return schemes.map { (name, $0) }
        }
        
        if let bundleIdentifier,
           let matchingScheme = registeredSchemes.first(where: { scheme in
               guard let name = scheme.name else { return false }
               return bundleIdentifier == name || bundleIdentifier.hasPrefix("\(name).")
           })?.scheme {
            return matchingScheme
        }
        
        return registeredSchemes.first(where: { $0.scheme != "doc" })?.scheme ?? registeredSchemes.first?.scheme
    }
}

private func base64Decoded(_ string: String) -> String? {
    guard let data = Data(base64Encoded: string) else {
        return nil
    }
    
    return String(data: data, encoding: .utf8)
}
