//
//  LegalNoticesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import SwiftUI

/// Displays legal notice text and links to privacy policy and terms of use.
struct LegalNoticesView: View {
    let legalNotices: LegalNotices
    @State private var text: AttributedString?
    
    var body: some View {
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
        .onAppear {
            guard let data = legalNotices.copyright.data(using: .utf8) else {
                return
            }
            
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            guard let attributedString = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
                return
            }
            
            attributedString.addAttributes([
                .font: PlatformFont.preferredFont(forTextStyle: .body),
                .foregroundColor: PlatformColor(Color.primary)
            ], range: NSRange(location: 0, length: attributedString.length))
            
            text = AttributedString(attributedString)
        }
    }
}
