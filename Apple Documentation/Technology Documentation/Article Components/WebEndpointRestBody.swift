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
                Grid(verticalSpacing: 0) {
                        GridRow {
                            VStack(alignment: .trailing) {
                                ForEach(bodyContentType) { body in
                                    if let identifier = body.identifier, let url = URL(string: identifier) {
                                        Link(body.text, destination: url)
                                    }
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            .padding(.trailing)
                            .padding(.vertical)
                            
                            HStack {
                                Divider()
                            }
                            
                            VStack {
                                ForEach(content) { item in
                                    ArticleContentView(content: item, references: references, alignment: .trailing)
                                }
                                if let mimeType = contentSection.mimeType {
                                    Text(mimeType)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .multilineTextAlignment(.leading)
                            .padding(.leading)
                            .padding(.vertical)
                        }
                }
            }
        }
    }
}
