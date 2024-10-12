//
//  HomepageSection.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI

struct HomepageSection: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        VStack {
            if let body = section.body {
                switch body.kind {
                case .links:
                    Links(section: section, homepage: homepage)
                case .cards: EmptyView()
                case .homepageLinks:
                    HomepageLinks(section: section, homepage: homepage)
                }
            }
        }
    }
}

// MARK: Links
private struct Links: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.title2)
                    .bold()
            }
            
            if let sectionContent = section.content {
                ForEach(sectionContent) { content in
                    ArticleContentView(content: content, references: homepage.references)
                }
            }
            if let links = section.body?.links {
                ForEach(links) { link in
                    LinksGridListView(identifiers: link.items, style: link.style, references: self.homepage.references, alignment: .center)
                }
            }
        }
    }
}

// MARK: HomepageLinks
private struct HomepageLinks: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.title2)
                    .foregroundStyle(Color.purple)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let sectionContent = section.content {
                ForEach(sectionContent) { content in
                    ArticleContentView(content: content, references: homepage.references)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                if let homepageLinks = section.body?.homepageLinks {
                    ForEach(homepageLinks) { link in
                        LinkCapsule(reference: link, references: homepage.references)
                    }
                }
            }
        }
        .padding()
        .padding(.horizontal, 50)
        .background(RoundedRectangle(cornerRadius: 25).fill(Color(uiColor: .systemBackground)))
    }
}

private struct LinkCapsule: View {
    @Environment(\.colorScheme) var colorScheme
    let reference: Reference
    let references: [String : Reference]
    
    var title: String? {
        if let title = reference.title {
            return title
        } else {
            return references[reference.identifier]?.title
        }
    }
    
    var url: URL? {
        let urlString = reference.identifier.replacingOccurrences(of: "https://developer.apple.com", with: "\(Constants.deeplinkScheme)com.apple.documentation")
        
        return URL(string: urlString)
    }
    
    var body: some View {
        if let title, let url {
            Link(destination: url) {
                Text(title)
                    .foregroundStyle(Color.purple)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.clear)
                            .stroke(Color.purple, lineWidth: 2)
                    )
            }
        }
    }
}
