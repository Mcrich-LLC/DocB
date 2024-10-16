//
//  WebEndpointRestResponse.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI

struct WebEndpointRestResponse: View {
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
                ForEach(items) { item in
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(item.status)")
                                ForEach(item.type) { type in
                                    if let url = URL(string: type.identifier) {
                                        Link(type.text, destination: url)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Divider()
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(item.reason)
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
    }
}
