//
//  MentionsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct MentionsView: View {
    let mentions: [String]
    let article: Article
    
    var body: some View {
        VStack {
            Text("Mentioned In")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(mentions, id: \.self) { identifier in
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
    }
}
