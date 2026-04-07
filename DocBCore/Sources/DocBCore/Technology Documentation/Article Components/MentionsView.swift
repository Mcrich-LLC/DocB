//
//  MentionsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

/// MentionsView renders a reusable SwiftUI view.
struct MentionsView: View {
    /// Reference identifiers that mention the current symbol/article.
    let mentions: [String]
    /// Parent article containing reference metadata.
    let article: Article
    /// Active DocC site used to fill missing reference site context.
    @Environment(\.docCSite) var docCSite
    /// Ensures mention references include the current DocC site context when absent.
    func conditionReference(_ reference: Reference?) -> Reference? {
        guard var reference = reference else { return nil }
        
        if reference.docCSite == nil {
            reference.docCSite = self.docCSite
        }
        
        return reference
    }
    
    var body: some View {
        VStack {
            Text("Mentioned In")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(mentions, id: \.self) { identifier in
                if let reference = conditionReference(article.references[identifier]), let title = reference.title {
                    ReferenceNavigationLinkButton(reference: reference) {
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
