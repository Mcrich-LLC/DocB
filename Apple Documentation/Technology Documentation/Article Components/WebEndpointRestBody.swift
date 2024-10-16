//
//  WebEndpointRestBody.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI

struct WebEndpointRestBody: View {
    let contentSection: ContentSection
    let references: [String : Reference]
    
    var body: some View {
        VStack {
            if let title = contentSection.title {
                Text(title)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let bodyContentType = contentSection.bodyContentType,
               let content = contentSection.content {
                HStack {
                    VStack(alignment: .leading) {
                        ForEach(bodyContentType) { body in
                            if let url = URL(string: body.identifier) {
                                Link(body.text, destination: url)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Divider()
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        ForEach(content) { item in
                            ArticleContentView(content: item, references: references, alignment: .trailing)
                        }
                        if let mimeType = contentSection.mimeType {
                            Text(mimeType)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
