//
//  LegalNoticesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import SwiftUI
import DocCKit

/// Displays legal notice text and links to privacy policy and terms of use.
public struct LegalNoticesView: View {
    /// Creates a legal notices panel from parsed documentation metadata.
    ///
    /// - Parameter legalNotices: Legal notice URLs and copyright HTML to render.
    public init(legalNotices: LegalNotices) {
        self.legalNotices = legalNotices
        self.text = LegalNoticeTextCache.shared.attributedString(for: legalNotices.copyright)
    }
    
    let legalNotices: LegalNotices
    let text: AttributedString?
    
    public var body: some View {
        GroupBox {
            VStack(alignment: .center) {
                if let text {
                    Text(text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                }
                HStack {
                    if let privacyPolicy = URL(string: legalNotices.privacyPolicy) {
                        Link("Privacy Policy", destination: privacyPolicy)
                            .buttonStyle(.bordered)
                            .frame(maxWidth: 150)
                    }
                    if let termsOfUse = URL(string: legalNotices.termsOfUse) {
                        Link("Terms of Use", destination: termsOfUse)
                            .buttonStyle(.bordered)
                            .frame(maxWidth: 150)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
}

/// Caches parsed legal notice copyright HTML to avoid repeated work during list and article redraws.
private final class LegalNoticeTextCache: @unchecked Sendable {
    /// Shared cache used by all legal notice views.
    static let shared = LegalNoticeTextCache()
    
    private let cache = NSCache<NSString, CacheBox>()
    
    /// Returns a formatted attributed string for legal notice HTML.
    ///
    /// - Parameter html: The copyright HTML string to parse.
    /// - Returns: A display-ready attributed string, or `nil` when parsing fails.
    func attributedString(for html: String) -> AttributedString? {
        let key = html as NSString
        
        if let cached = cache.object(forKey: key) {
            return cached.value
        }
        
        guard let data = html.data(using: .utf8) else {
            return nil
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        attributedString.addAttributes([
            .font: PlatformFont.preferredFont(forTextStyle: .body),
            .foregroundColor: PlatformColor(Color.primary)
        ], range: NSRange(location: 0, length: attributedString.length))
        
        let text = AttributedString(attributedString)
        cache.setObject(CacheBox(text), forKey: key)
        
        return text
    }
    
    /// Sendable wrapper for cached attributed strings stored in `NSCache`.
    private final class CacheBox: @unchecked Sendable {
        /// Cached attributed string value.
        let value: AttributedString
        
        /// Creates a cache box.
        ///
        /// - Parameter value: The attributed string to store.
        init(_ value: AttributedString) {
            self.value = value
        }
    }
}
