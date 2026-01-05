//
//  HomepageSection.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import Kingfisher

struct HomepageSection: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        VStack {
            if let body = section.body {
                switch body.kind {
                case .links:
                    Links(section: section, homepage: homepage)
                case .cards:
                    Cards(section: section, homepage: homepage)
                case .homepageLinks:
                    HomepageLinks(section: section, homepage: homepage)
                case .highlightedLinks:
                    HighlightedLinks(section: section, homepage: homepage)
                }
            }
        }
    }
}

// MARK: Highlighted Links
private struct HighlightedLinks: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.docCSite) var docCSite
    @State var cardFrame: CGSize?
    
    var isVertical: Bool {
        guard let cardFrame else { return false }
        
        return cardFrame.width < 800
    }
    
    var body: some View {
        if let highlightedLinks = section.body?.highlightedLinks {
            VStack {
                if let title = section.title {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                
                VHStack {
                    if isVertical {
                        image
                            .frame(maxWidth: 400, maxHeight: .infinity)
                    }
                    
                    VStack {
                        ForEach(highlightedLinks) { link in
                            HighlightedLinksCell(homepage: homepage, link: link)
                        }
                    }
                    .padding()
                    .frame(maxWidth: isVertical ? 400 : 500)
                    
                    if !isVertical {
                        image
                            .frame(maxWidth: 400, maxHeight: .infinity)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(platformColor: .systemBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .frame(maxWidth: 800)
                .onGeometryChange(for: CGSize.self, of: { proxy in
                    proxy.size
                }, action: { newValue in
                    self.cardFrame = newValue
                })
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    var image: some View {
        if let image = section.body?.image {
            KFImage(fetchPhotoVideoURL(for: image))
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    func fetchPhotoVideoURL(for identifier: String) -> URL? {
        guard let url = Constants.fetchPhotoVideoURL(for: identifier, references: homepage.references, colorScheme: colorScheme, docCSite: docCSite) else {
            return nil
        }
        
        return url
    }
    
    @ViewBuilder
    func VHStack<Content: View>(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) -> some View {
        switch isVertical {
        case false:
            HStack(spacing: spacing, content: content)
        case true:
            VStack(spacing: spacing, content: content)
        }
    }
}

private struct HighlightedLinksCell: View {
    let homepage: HomepageParser
    let link: HomepageParser.Body.HighlightedLinks
        
    var body: some View {
        VStack(alignment: .leading) {
            Text(link.title)
                .font(.title2)
                .bold()
            
            ForEach(link.content) { content in
                ArticleContentView(content: content, references: homepage.references)
            }
            
            if let callToActionText = link.callToActionText, let url = link.destination {
                Link(destination: url) {
                    Label {
                        Text(callToActionText)
                    } icon: {
                        Image(systemSymbol: .chevronRight)
                            .foregroundStyle(Color.secondary)
                    }
                    .labelStyle(.iconTrailing)
                }
            }
        }
    }
}

// MARK: Links
private struct Links: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
            }
            
            if let sectionContent = section.content {
                ForEach(sectionContent) { content in
                    ArticleContentView(content: content, references: homepage.references)
                }
            }
            if let links = section.body?.links {
                ForEach(links) { link in
                    LinksGridListView(identifiers: link.items, style: link.style, references: self.homepage.references, navigationViewModel: navigationViewModel)
                        .alignment(.top)
                }
            }
        }
    }
}

// MARK: Cards
private struct Cards: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
            }
            
            if let sectionContent = section.content {
                ForEach(sectionContent) { content in
                    ArticleContentView(content: content, references: homepage.references)
                }
            }
            
            WrappingHStack(alignment: .center, horizontalSpacing: 10, verticalSpacing: navigationViewModel.isUsingSplitView ? nil : 60) {
                if let outerCards = section.body?.cards {
                    ForEach(outerCards) { outerCard in
                        ForEach(outerCard.cards) { card in
                            self.card(card)
                                .frame(maxWidth: 400, maxHeight: 600)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func card(_ content: HomepageParser.Body.Card.Content) -> some View {
        if let url = URL(string: content.destination.identifier) {
            MacOSAgnosticLink(destination: url) {
                VStack {
                    if let image = content.image, let imageUrl = Constants.fetchPhotoVideoURL(for: image, references: self.homepage.references, colorScheme: colorScheme, docCSite: nil) {
                        KFImage(imageUrl)
                            .placeholder({
                                UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25)
                                    .fill(Color.clear)
                                    .stroke(Color.primary, lineWidth: 2)
                                    .scaledToFill()
                                    .overlay {
                                        ProgressView()
                                    }
                            })
                            .resizable()
                            .scaledToFill()
                            .clipShape(
                                UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25)
                            )
                    }
                    
                    VStack(alignment: .leading) {
                        if let eyebrow = content.eyebrow {
                            Text(eyebrow)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(content.title)
                            .font(.title2)
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        ForEach(content.content) { con in
                            ArticleContentView(content: con, references: homepage.references)
                                .lineLimit(2)
                        }
                        
                        if let callToAction = content.saferCallToAction?.web {
                            Label {
                                Text(callToAction)
                                    .foregroundStyle(Color.accentColor)
                            } icon: {
                                Image(systemSymbol: .chevronRight)
                                    .foregroundStyle(Color.secondary)
                            }
                            .labelStyle(.iconTrailing)
                            .padding(.vertical, 2)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding()
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(platformColor: .systemBackground))
                )
            }
            .foregroundStyle(Color.primary)
        }
    }
}

// MARK: HomepageLinks
private struct HomepageLinks: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.largeTitle)
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
            
            if (navigationViewModel.isUsingSplitView) {
                WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                    if let homepageLinks = section.body?.homepageLinks {
                        ForEach(homepageLinks) { link in
                            LinkCapsule(reference: link, references: homepage.references)
                        }
                    }
                }
            } else {
                VStack {
                    if let homepageLinks = section.body?.homepageLinks {
                        ForEach(homepageLinks) { link in
                            LinkCapsule(reference: link, references: homepage.references)
                        }
                    }
                }
            }
        }
        .padding()
        .padding(.horizontal, (navigationViewModel.isUsingSplitView) ? 30 : 15)
        .background(RoundedRectangle(cornerRadius: 25).fill(Color(platformColor: .systemBackground)))
        .padding(.horizontal)
        .padding(.horizontal, (navigationViewModel.isUsingSplitView) ? nil : 0)
    }
}

private struct LinkCapsule: View {
    @Environment(\.colorScheme) var colorScheme
    let reference: Reference
    let references: [String : Reference]
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var title: String? {
        if let title = reference.title {
            return title
        } else {
            return references[reference.identifier]?.title
        }
    }
    
    var url: URL? {
        let urlString: String
        if let title {
            let urlTitle = title.replacingOccurrences(of: "/", with: "-")
            urlString = reference.identifier.replacingOccurrences(of: "https://developer.apple.com", with: "\(Constants.deeplinkScheme)com.apple.\(urlTitle)-Release-Notes")
        } else {
            urlString = reference.identifier.replacingOccurrences(of: "https://developer.apple.com", with: "\(Constants.deeplinkScheme)com.apple.documentation")
        }
            
        return URL(string: urlString)
    }
    
    @State var isHovering = false
    
    var body: some View {
        if let title, let url {
            MacOSAgnosticLink(destination: url) {
                Text(title)
                    .foregroundStyle(Color.purple)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
                    .frame(width: (navigationViewModel.isUsingSplitView) ? nil : 150)
                    .background(
                        Capsule()
                            .fill(Color.clear)
                            .stroke(Color.purple, lineWidth: isHovering ? 4 : 2)
                    )
            }
            .clipShape(Capsule())
            .onHover { isHovering in
                withAnimation {
                    self.isHovering = isHovering
                }
            }
        }
    }
}
