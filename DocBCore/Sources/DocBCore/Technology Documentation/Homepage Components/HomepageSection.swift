//
//  HomepageSection.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import Kingfisher

/// HomepageSection renders a reusable SwiftUI view.
struct HomepageSection: View {
    /// Section payload being rendered.
    let section: HomepageParser.Section
    /// Parsed homepage data containing shared references.
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
/// Section renderer for featured highlighted links with responsive media/text layout.
private struct HighlightedLinks: View {
    /// Section data for highlighted links content.
    let section: HomepageParser.Section
    /// Parsed homepage data used for references and media.
    let homepage: HomepageParser
    /// Current color scheme used to choose media variants.
    @Environment(\.colorScheme) var colorScheme
    /// Active DocC site used to expand relative media URLs when needed.
    @Environment(\.docCSite) var docCSite
    /// Runtime measured card frame used to switch between horizontal and vertical layouts.
    @State var cardFrame: CGSize?
    
    /// Whether highlighted content should stack vertically based on available width.
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
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 25))
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
    /// Shared image view used in the highlighted links layout.
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
    /// Conditionally renders `HStack` or `VStack` for highlighted links composition.
    func VHStack<Content: View>(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) -> some View {
        switch isVertical {
        case false:
            HStack(spacing: spacing, content: content)
        case true:
            VStack(spacing: spacing, content: content)
        }
    }
}

/// Single highlighted-link cell containing rich text and optional call to action.
private struct HighlightedLinksCell: View {
    /// Parsed homepage data containing shared references.
    let homepage: HomepageParser
    /// Single highlighted link payload for this row.
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
/// Section renderer for standard link groups.
private struct Links: View {
    /// Section data for links presentation.
    let section: HomepageParser.Section
    /// Parsed homepage data containing shared references.
    let homepage: HomepageParser
    /// Navigation state used for list/grid behavior in links view.
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
/// Section renderer for card-based homepage content.
private struct Cards: View {
    /// Section data for card presentation.
    let section: HomepageParser.Section
    /// Parsed homepage data containing shared references.
    let homepage: HomepageParser
    /// Current color scheme used when loading media variants.
    @Environment(\.colorScheme) var colorScheme
    /// Navigation state used for spacing and split-view sizing.
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    /// Per-card measured text heights used to align card body heights.
    @State var cardHeights: [UUID : CGFloat] = [:]
    /// Measured container size used to adjust card max width.
    @State var viewSize: CGSize?
    
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
            
            WrappingHStack(alignment: .center, horizontalSpacing: 10, verticalSpacing: navigationViewModel.isUsingSplitView ? 20 : 30) {
                if let outerCards = section.body?.cards {
                    ForEach(outerCards) { outerCard in
                        ForEach(outerCard.cards) { card in
                            self.card(card)
                                .frame(maxWidth: (viewSize?.width ?? 0) > 1300 ? 400 : 300, maxHeight: 600)
                        }
                    }
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            viewSize = newValue
        }
    }
    
    @ViewBuilder
    /// Placeholder shown while a card hero image is loading.
    var cardImagePlaceholder: some View {
        UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25)
            .fill(Color.clear)
            .stroke(Color.primary, lineWidth: 2)
            .scaledToFit()
            .overlay {
                ProgressView()
            }
    }
    
    @ViewBuilder
    /// Renders a single homepage card including image, content, and call to action.
    func card(_ content: HomepageParser.Body.Card.Content) -> some View {
        if let url = URL(string: content.destination.identifier) {
            MacOSAgnosticLink(destination: url) {
                VStack {
                    if let image = content.image, let imageUrl = Constants.fetchPhotoVideoURL(for: image, references: self.homepage.references, colorScheme: colorScheme, docCSite: nil) {
                        KFImage(imageUrl)
                            .placeholder({
                                cardImagePlaceholder
                            })
                            .resizable()
                            .scaledToFit()
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Set(cardHeights.values).sorted(by: >).first, alignment: .top)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newValue in
                        cardHeights[content.id] = newValue
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 25))
            }
            .foregroundStyle(Color.primary)
        }
    }
}

// MARK: HomepageLinks
/// Section renderer for capsule-style homepage links.
private struct HomepageLinks: View {
    /// Section data for capsule-style homepage links.
    let section: HomepageParser.Section
    /// Parsed homepage data containing shared references.
    let homepage: HomepageParser
    /// Navigation state used to choose wrapped vs stacked layout.
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
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 25))
        .padding(.horizontal)
        .padding(.horizontal, (navigationViewModel.isUsingSplitView) ? nil : 0)
    }
}

/// Capsule-style link control used by homepage links sections.
private struct LinkCapsule: View {
    /// Current color scheme used by capsule styling.
    @Environment(\.colorScheme) var colorScheme
    /// Primary reference driving title and URL generation.
    let reference: Reference
    /// Reference lookup table for fallback title resolution.
    let references: [String : Reference]
    /// Navigation state used for width behavior in compact layouts.
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    /// Best-effort title resolved from the primary or fallback reference map.
    var title: String? {
        if let title = reference.title {
            return title
        } else {
            return references[reference.identifier]?.title
        }
    }
    
    /// Deep-link URL generated for the capsule destination.
    var url: URL? {
        let urlString: String
        if let title {
            let urlTitle = title.replacingOccurrences(of: "/", with: "-")
            urlString = reference.identifier.replacingOccurrences(of: "\(Constants.aDeveloperURLBase)", with: "\(Constants.deeplinkScheme)com.apple.\(urlTitle)-Release-Notes")
        } else {
            urlString = reference.identifier.replacingOccurrences(of: "\(Constants.aDeveloperURLBase)", with: "\(Constants.deeplinkScheme)com.apple.documentation")
        }
            
        return URL(string: urlString)
    }
    
    /// Hover state used to animate capsule border thickness.
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
