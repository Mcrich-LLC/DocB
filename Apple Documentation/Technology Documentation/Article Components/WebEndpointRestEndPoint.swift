//
//  WebEndpointRestEndPoint.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI
import HighlightSwift

/// A view that displays the endpoint URL and method for a REST API.
struct WebEndpointRestEndPoint: View {
    /// The content section containing endpoint data.
    let contentSection: ContentSection
    /// A dictionary of references for resolving links.
    let references: [String : Reference]
    
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
                        .tint(Color(platformColor: .systemBlue))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
