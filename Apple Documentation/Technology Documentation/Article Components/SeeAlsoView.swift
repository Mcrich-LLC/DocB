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
                                        VStack {
                                            Text(getFullTitle(reference))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            if let abstract = reference.abstract {
                                                AbstractView(abstract: abstract)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .foregroundStyle(Color.primary)
                                            }
                                        }
                                        .multilineTextAlignment(.leading)
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
    
    func getFullTitle(_ reference: Reference) -> AttributedString {
        
        var nsAttributedString: NSMutableAttributedString = .init()
        
        let fragments: String = (reference.fragments ?? []).dropLast().map({ $0.text }).joined()
        let fragmentAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.secondaryLabel]
        let fragmentAttributedString = NSAttributedString(string: fragments, attributes: fragmentAttributes)
        nsAttributedString.append(fragmentAttributedString)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.accent]
        let titleAttributedString = NSAttributedString(string: reference.title ?? "", attributes: titleAttributes)
        nsAttributedString.append(titleAttributedString)
        
        return AttributedString(nsAttributedString)
    }
}
