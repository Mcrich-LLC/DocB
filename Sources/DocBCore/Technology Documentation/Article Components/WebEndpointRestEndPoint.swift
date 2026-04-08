//
//  WebEndpointRestEndPoint.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI
import HighlightSwift

/// WebEndpointRestEndPoint renders a reusable SwiftUI view.
struct WebEndpointRestEndPoint: View {
    /// REST endpoint content section payload.
    let contentSection: ContentSection
    /// Reference map for endpoint-related links.
    let references: [String : Reference]
    
    /// JavaScript snippet reconstructed from endpoint token stream.
    var code: String? {
        contentSection.tokens?.compactMap({ token in
            if let text = token.text {
                return text
            }
            
            if let code = token.code {
                return code
            }
            
            return nil
        }).joined()
    }
    
    var body: some View {
        VStack {
            if let title = contentSection.title {
                Text(title)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let code {
                GroupBox {
                    CodeText(code)
                        .highlightLanguage(.javaScript)
                        .codeTextColors(.theme(.xcode))
                        .textSelection(.enabled)
                        .tintColor(Color(platformColor: .systemBlue))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
