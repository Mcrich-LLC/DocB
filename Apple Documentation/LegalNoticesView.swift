//
//  LegalNoticesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/23/24.
//

import SwiftUI

struct LegalNoticesView: View {
    let legalNotices: LegalNotices
    
    var text: AttributedString? {
        guard let data = legalNotices.copyright.data(using: .utf8) else {
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
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(Color.primary)
        ], range: NSRange(location: 0, length: attributedString.length))
        
        return AttributedString(attributedString)
    }
    
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
    }
}
