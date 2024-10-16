//
//  WebEndpointRestPropertiesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI

struct WebEndpointRestPropertiesView: View {
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
            
            if let items = contentSection.items {
                Grid(verticalSpacing: 0) {
                    ForEach(items) { item in
                        GridRow {
                            VStack {
                                if let name = item.name {
                                    Text("\(name)")
                                        .bold()
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                ForEach(item.type) { type in
                                    if let identifier = type.identifier, let url = URL(string: identifier) {
                                        Link(type.text, destination: url)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    } else {
                                        Text(type.text)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .foregroundStyle(.secondary)
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
                                ForEach(item.content) { content in
                                    ArticleContentView(content: content, references: references, alignment: .leading)
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
}
