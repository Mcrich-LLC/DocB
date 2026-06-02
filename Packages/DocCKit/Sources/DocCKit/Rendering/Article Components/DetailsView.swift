//
//  DetailsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

/// DetailsView renders a reusable SwiftUI view.
struct DetailsView: View {
    /// Details payload rendered in the section.
    let details: ContentSection.Details
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Details")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack {
                Text("Name")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(details.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack {
                Text("Type")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(details.value, id: \.baseType) { value in
                    Text(value.baseType.capitalized)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
