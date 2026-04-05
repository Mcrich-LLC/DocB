//
//  WebEndpointRestAttributesView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/16/24.
//

import SwiftUI

/// WebEndpointRestAttributesView renders a reusable SwiftUI view.
struct WebEndpointRestAttributesView: View {
    /// REST attributes content section payload.
    let contentSection: ContentSection
    /// Reference map for linked identifiers.
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
