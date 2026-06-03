import SwiftUI

/// Displays legal notice text and links to privacy policy and terms of use.
public struct DocCLegalNoticesView: View {
    private let legalNotices: LegalNotices
    private let text: AttributedString?
    
    /// Creates a legal notices panel from parsed documentation metadata.
    ///
    /// - Parameter legalNotices: Legal notice URLs and copyright HTML to render.
    public init(legalNotices: LegalNotices) {
        self.legalNotices = legalNotices
        self.text = Self.attributedString(for: legalNotices.copyright)
    }
    
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
    
    private static func attributedString(for html: String) -> AttributedString? {
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
        
        return AttributedString(attributedString)
    }
}
