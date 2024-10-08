//
//  DetailsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct DetailsView: View {
    let details: ContentSection.Details
    
    var body: some View {
        VStack {
            Text("Details")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                VStack {
                    Text("Name")
                        .bold()
                    Text(details.name.capitalized)
                }
                VStack {
                    Text("Type")
                        .bold()
                    ForEach(details.value, id: \.baseType) { value in
                        Text(value.baseType.capitalized)
                    }
                }
            }
        }
    }
}
