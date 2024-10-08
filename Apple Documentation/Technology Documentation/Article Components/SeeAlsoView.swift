//
//  SeeAlsoView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct SeeAlsoView: View {
    let article: Article
    
    var body: some View {
        if let seeAlsoSections = article.seeAlsoSections {
            VStack {
                Text("See Also")
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(seeAlsoSections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.identifiers, id: \.self) { identifier in
                            if let reference = article.references[identifier], let title = reference.title {
                                NavigationLink(value: reference) {
                                    GroupBox {
                                        Text(title)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
