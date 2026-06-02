//
//  LinksGridListView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI
import NukeUI

/// LinksGridListView renders a reusable SwiftUI view.
struct LinksGridListView: View {
    /// Ordered reference identifiers to render.
    let identifiers: [String]
    /// Link presentation style from content payload.
    let style: ContentSection.Content.Style
    /// Reference lookup table for identifiers.
    let references: [String : Reference]
    /// Whether list rows should show DocC symbol kind badges.
    let showsSymbolKindBadge: Bool
    /// Container alignment used by wrapping layouts.
    private var alignment: Alignment
    /// Text alignment for titles/abstracts.
    private var textAlignment: TextAlignment = .leading
      
    /// Horizontal frame alignment derived from current text alignment.
    private var textFrameAlignment: HorizontalAlignment {
        switch textAlignment {
        case .leading:
                .leading
        case .center:
                .center
        case .trailing:
                .trailing
        }
    }
    
    @Environment(\.docCIsUsingSplitView) private var isUsingSplitView
    
    /// Creates a links renderer with style/reference payload and initial alignment from navigation mode.
    init(identifiers: [String], style: ContentSection.Content.Style, references: [String : Reference], showsSymbolKindBadge: Bool = false) {
        self.identifiers = identifiers
        self.style = style
        self.references = references
        self.showsSymbolKindBadge = showsSymbolKindBadge
        self.alignment = .topLeading
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    /// Returns a copy of this view with updated overall content alignment.
    func alignment(_ alignment: Alignment) -> Self {
        var view = self
        view.alignment = alignment
        
        return view
    }
    
    /// Returns a copy of this view with updated text alignment.
    func multilineTextAlignment(_ textAlignment: TextAlignment) -> Self {
        var view = self
        view.textAlignment = textAlignment
        
        return view
    }
    
    @Environment(\.docCSite) var docCSite
    @Environment(\.docCDeepLinkScheme) private var deepLinkScheme
    /// Ensures references inherit the current DocC site when one is not already assigned.
    func conditionReference(_ reference: Reference?) -> Reference? {
        guard var reference = reference else { return nil }
        
        if reference.docCSite == nil {
            reference.docCSite = self.docCSite
        }
        
        return reference
    }
    
    /// Resolves the destination URL for a reference, preferring explicit external URLs when applicable.
    func referenceOpenURL(_ reference: Reference) -> URL? {
        if let urlString = reference.url, !urlString.contains("/documentation") {
            return reference.externalURL
        }
        
        return URL(string: deepLinkScheme.urlString(forDocIdentifier: reference.identifier))
    }
    
    var body: some View {
        switch style {
        case .compactGrid, .detailedGrid:
            WrappingHStack(alignment: alignment, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(identifiers, id: \.self) { identifier in
                    if let reference = conditionReference(references[identifier]),
                        let title = reference.title,
                       let openUrl = referenceOpenURL(reference) {
                        
                        DocCLink(destination: openUrl) {
                            VStack(alignment: textFrameAlignment) {
                                if let imageId = reference.images?.first(where: { $0.type == .card || $0.type == .icon })?.identifier,
                                   let imageUrl = DocCAssetResolver.fetchPhotoVideoURL(for: imageId, references: references, colorScheme: colorScheme, docCSite: docCSite) {
                                    LazyImage(url: imageUrl) { state in
                                        if let image = state.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else {
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.clear)
                                                .stroke(Color.primary, lineWidth: 2)
                                                .aspectRatio(contentMode: .fit)
                                                .overlay {
                                                    ProgressView()
                                                }
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                                } else {
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(.background.secondary)
                                        .scaledToFit()
                                        .overlay {
                                            Image(systemSymbol: reference.role?.labelIcon ?? .textDocument)
                                                .resizable()
                                                .scaledToFit()
                                                .scaleEffect(0.3)
                                        }
                                }
                                
                                Text(title)
                                    .foregroundStyle(Color.primary)
                                    .font(.headline)
                                    .multilineTextAlignment(textAlignment)
                                
                                if let abstract = reference.abstract, style == .detailedGrid {
                                    AbstractView(abstract: abstract)
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(textAlignment)
                                }
                            }
                            .frame(maxWidth: isUsingSplitView ? 300 : 400)
                        }
                        .contentShape(UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
                        #if !os(macOS)
                        .hoverEffect()
                        #endif
                    }
                }
            }
        case .list:
            ForEach(identifiers, id: \.self) { identifier in
                DocCReferenceListRow(identifier: identifier, references: references, textAlignment: textAlignment, showsSymbolKindBadge: showsSymbolKindBadge)
            }
        case .hidden:
            EmptyView()
        default:
            Text("Links grid style not supported yet: \(style.rawValue)")
        }
    }
}

/// Renders one list-style DocC reference link.
struct DocCReferenceListRow: View {
    /// Reference identifier to render.
    let identifier: String
    /// Reference lookup table.
    let references: [String : Reference]
    /// Text alignment for title and abstract.
    let textAlignment: TextAlignment
    /// Whether to show a DocC symbol kind badge instead of the generic role icon.
    let showsSymbolKindBadge: Bool
    
    @Environment(\.docCSite) private var docCSite
    
    /// Horizontal frame alignment derived from current text alignment.
    private var textFrameAlignment: HorizontalAlignment {
        switch textAlignment {
        case .leading:
                .leading
        case .center:
                .center
        case .trailing:
                .trailing
        }
    }
    
    /// Creates a list-style reference row.
    ///
    /// - Parameters:
    ///   - identifier: Reference identifier to render.
    ///   - references: Reference lookup table.
    ///   - textAlignment: Text alignment for title and abstract.
    init(identifier: String, references: [String : Reference], textAlignment: TextAlignment = .leading, showsSymbolKindBadge: Bool = false) {
        self.identifier = identifier
        self.references = references
        self.textAlignment = textAlignment
        self.showsSymbolKindBadge = showsSymbolKindBadge
    }
    
    var body: some View {
        if let reference = conditionReference(references[identifier]), reference.title != nil {
            DocCReferenceNavigationLink(reference: reference) {
                HStack(spacing: 15) {
                    if showsSymbolKindBadge {
                        DocCSymbolBadge(
                            symbolKind: SidebarSearchSymbolKind(reference: reference, title: reference.title ?? ""),
                            size: 22,
                            customImageIdentifier: reference.images?.first(where: { $0.type == .icon })?.identifier,
                            references: references,
                            docCSite: docCSite
                        )
                    } else {
                        Image(systemSymbol: reference.role?.labelIcon ?? .textDocument)
                            .resizable()
                            .foregroundStyle(.secondary)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: textFrameAlignment) {
                        (Text(getFullTitle(reference)) + (reference.isExternalReference ? Text(" \(Image(systemSymbol: .arrowUpRight))") : Text("")))
                            .foregroundStyle(.tint)
                        
                        if let abstract = reference.abstract {
                            AbstractView(abstract: abstract)
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .multilineTextAlignment(textAlignment)
                }
            }
            .disabled(reference.type == "unresolvable")
            .docCTintColor(reference.type == "unresolvable" ? Color.primary : nil)
        }
    }
    
    /// Ensures references inherit the current DocC site when one is not already assigned.
    private func conditionReference(_ reference: Reference?) -> Reference? {
        guard var reference else { return nil }
        
        if reference.docCSite == nil {
            reference.docCSite = docCSite
        }
        
        return reference
    }

    /// Builds title text with fragment-aware styling (especially for symbols).
    private func getFullTitle(_ reference: Reference) -> AttributedString {
        
        if reference.role == .symbol {
            let nsAttributedString: NSMutableAttributedString = .init()
            
            if let fragments = reference.fragments {
                for fragment in fragments {
                    
                    let fragmentAttributes: [NSAttributedString.Key: Any] = switch fragment.kind {
                    case "identifier":
                        [
                            .foregroundColor: PlatformColor.accent,
                            .font: PlatformFont.monospacedSystemFont(ofSize: PlatformFont.labelFontSize, weight: .medium)
                        ]
                    default:
                        [
                            .foregroundColor: PlatformColor(Color.secondary),
                            .font: PlatformFont.monospacedSystemFont(ofSize: PlatformFont.labelFontSize, weight: .medium)
                        ]
                    }
                    let fragmentAttributedString = NSAttributedString(string: fragment.text, attributes: fragmentAttributes)
                    
                    nsAttributedString.append(fragmentAttributedString)
                }
            }
            
            return AttributedString(nsAttributedString)
        } else {
            let nsAttributedString: NSMutableAttributedString = .init()
            
            let fragments: String = (reference.fragments ?? []).map({ $0.text }).joined()
            let fragmentAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: PlatformColor(Color.primary)]
            let fragmentAttributedString = NSAttributedString(string: fragments, attributes: fragmentAttributes)
            nsAttributedString.append(fragmentAttributedString)
            
            if !nsAttributedString.string.contains(reference.title ?? "") {
                let titleAttributes: [NSAttributedString.Key: Any] = [:]
                let titleAttributedString = NSAttributedString(string: reference.title ?? "", attributes: titleAttributes)
                nsAttributedString.append(titleAttributedString)
            } else {
                let string = nsAttributedString.string
                let range: NSRange = string.range(of: reference.title ?? "")!.nsRange(in: string)
                
                let titleAttributes: [NSAttributedString.Key: Any] = [:]
                nsAttributedString.addAttributes(titleAttributes, range: range)
            }
            
            return AttributedString(nsAttributedString)
        }
    }
}
