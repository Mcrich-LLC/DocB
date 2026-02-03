//
//  WebEndpointRestAttributesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/16/24.
//

import SwiftUI

/// A view that displays the attributes of a REST endpoint.
struct WebEndpointRestAttributesView: View {
    /// The content section containing attributes data.
    let contentSection: ContentSection
    /// A dictionary of references for resolving links.
    let references: [String : Reference]
    
    var body: some View {
        VStack {
            if let title = contentSection.title {
                Text(title)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text("Possible types:")
                .frame(maxWidth: .infinity, alignment: .leading)
//            if let attributes = contentSection.attributes {
//                ForEach(attributes) { attribute in
//                    EmptyView()
//                }
//            }
        }
    }
}
