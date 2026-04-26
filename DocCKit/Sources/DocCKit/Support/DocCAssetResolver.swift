import SwiftUI

/// Resolves DocC media references into displayable URLs.
public enum DocCAssetResolver {
    /// Fetches variant URLs for media identifiers.
    ///
    /// Fundamentally, the URL structure is the same, which allows both photo and video URLs to be resolved here.
    ///
    /// - Parameters:
    ///   - identifier: Reference identifier to resolve.
    ///   - references: Reference lookup table from the current payload.
    ///   - colorScheme: Current color scheme used to choose dark/light variants.
    ///   - docCSite: Optional custom DocC source used to resolve relative URLs.
    /// - Returns: A media URL when one can be resolved.
    public static func fetchPhotoVideoURL(for identifier: String, references: [String : Reference], colorScheme: ColorScheme, docCSite: DocCSource?) -> URL? {
        guard let reference = references[identifier], let variants = reference.variants else {
            return nil
        }
        
        var mainURL: URL?
        
        if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark, let url = URL(string: darkVariant.url) {
            mainURL = url
        } else if let lightVariant = variants.first, let url = URL(string: lightVariant.url) {
            mainURL = url
        }
        
        if mainURL?.host() == nil, let url = mainURL, let docCSite {
            mainURL = URL(string: "\(docCSite.url)\(url.path)")
        }
        
        return mainURL
    }
}
