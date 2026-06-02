import SwiftUI

/// Renders a DocC homepage payload.
public struct DocCHomepageView<Navigator: DocCNavigator>: View {
    /// Homepage payload to render.
    private let homepage: HomepageParser
    /// Host-app navigation coordinator.
    @State private var navigator: Navigator
    
    /// Creates a homepage renderer.
    ///
    /// - Parameters:
    ///   - homepage: Homepage payload to render.
    ///   - navigator: Host-app navigation coordinator.
    public init(homepage: HomepageParser, navigator: Navigator) {
        self.homepage = homepage
        self.navigator = navigator
    }
    
    public var body: some View {
        ScrollView {
            verticalStacker(spacing: 60) {
                ForEach(homepage.sections) { section in
                    HomepageSectionContent(section: section, homepage: homepage)
                }
                
                if let legalNotices = homepage.legalNotices {
                    DocCLegalNoticesView(legalNotices: legalNotices)
                        .padding(.horizontal, 25)
                }
            }
            .padding([.bottom], 25)
        }
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .background(Color.homepageBackground)
        .environment(\.docCIsUsingSplitView, navigator.isUsingSplitView)
        .environment(\.docCDeepLinkScheme, navigator.deepLinkScheme)
        .environment(\.docCNavigateToReference, DocCReferenceNavigationAction { reference in
            navigator.setReference(reference, forceHistory: false)
        })
    }
    
    @ViewBuilder
    private func verticalStacker(spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View {
        if navigator.isUsingSplitView {
            LazyVStack(spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing, content: content)
        }
    }
}

private struct HomepageSectionContent: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        switch section.kind {
        case .hero:
            HomepageHero(section: section, homepage: homepage)
        case .homepageResources:
            HomepageResources(section: section, homepage: homepage)
                .padding(.horizontal, 25)
        case .section:
            HomepageSection(section: section, homepage: homepage)
                .padding(.horizontal, 25)
        }
    }
}
