//
//  TopicsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct TopicsView: View {
    let article: Article
    
    var body: some View {
        if let topicSections = article.topicSections {
            VStack {
                Text("Topics")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(topicSections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.identifiers, id: \.self) { identifier in
                            if let reference = article.references[identifier], reference.title != nil {
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
        
        let nsAttributedString: NSMutableAttributedString = .init()
        
        let fragments: String = (reference.fragments ?? []).dropLast().map({ $0.text }).joined()
        let fragmentAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.secondaryLabel]
        let fragmentAttributedString = NSAttributedString(string: fragments, attributes: fragmentAttributes)
        nsAttributedString.append(fragmentAttributedString)
        
        if !nsAttributedString.string.contains(reference.title ?? "") {
            let titleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.accent]
            let titleAttributedString = NSAttributedString(string: reference.title ?? "", attributes: titleAttributes)
            nsAttributedString.append(titleAttributedString)
        } else {
            let string = nsAttributedString.string
            let range: NSRange = string.range(of: reference.title ?? "")!.nsRange(in: string)
            
            let titleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.accent]
            nsAttributedString.addAttributes(titleAttributes, range: range)
        }
        
        return AttributedString(nsAttributedString)
    }
}

extension RangeExpression where Bound == String.Index  {
    func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}
