//
//  WebEndpointRestResponse.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/15/24.
//

import SwiftUI
import DocCKit

/// WebEndpointRestResponse renders a reusable SwiftUI view.
struct WebEndpointRestResponse: View {
    /// REST responses content section payload.
    let contentSection: ContentSection
    /// Reference map for linked response type identifiers.
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
                            VStack(alignment: .trailing) {
                                if let status = item.status {
                                    Text("\(status)")
                                }
                                HStack(spacing: 0) {
                                    ForEach(item.type) { type in
                                        if let identifier = type.identifier, let url = URL(string: identifier) {
                                            Link(type.text, destination: url)
                                        }
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
                                if let reason = item.reason {
                                    Text(reason)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
}
