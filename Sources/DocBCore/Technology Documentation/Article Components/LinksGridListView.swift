//
//  LinksGridListView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI
import Kingfisher

/// LinksGridListView renders a reusable SwiftUI view.
struct LinksGridListView: View {
    /// Ordered reference identifiers to render.
    let identifiers: [String]
    /// Link presentation style from content payload.
    let style: ContentSection.Content.Style
    /// Reference lookup table for identifiers.
    let references: [String : Reference]
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
    
    /// Shared navigation state for split-view dependent layout behavior.
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    /// Creates a links renderer with style/reference payload and initial alignment from navigation mode.
    init(identifiers: [String], style: ContentSection.Content.Style, references: [String : Reference], navigationViewModel: NavigationViewModel) {
        self.identifiers = identifiers
        self.style = style
        self.references = references
        self.alignment = !navigationViewModel.isUsingSplitView ? .top : .topLeading
    }
    
    /// Current color scheme used for image variant resolution.
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
    
    /// Active DocC site used to fill in missing reference site context.
    @Environment(\.docCSite) var docCSite
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
        
        return URL(string: reference.identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme))
    }
    
    var body: some View {
        switch style {
        case .compactGrid, .detailedGrid:
            WrappingHStack(alignment: alignment, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(identifiers, id: \.self) { identifier in
                    if let reference = conditionReference(references[identifier]),
                        let title = reference.title,
                       let openUrl = referenceOpenURL(reference) {
                        
                        MacOSAgnosticLink(destination: openUrl) {
                            VStack(alignment: textFrameAlignment) {
                                if let imageId = reference.images?.first(where: { $0.type == .card || $0.type == .icon })?.identifier,
                                   let imageUrl = Constants.fetchPhotoVideoURL(for: imageId, references: references, colorScheme: colorScheme, docCSite: docCSite) {
                                    KFImage(imageUrl)
                                        .placeholder({
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.clear)
                                                .stroke(Color.primary, lineWidth: 2)
                                                .scaledToFit()
                                                .overlay {
                                                    ProgressView()
                                                }
                                        })
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 25))
                                } else {
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(.background.secondary)
                                        .scaledToFit()
                                        .overlay {
                                            Image(systemSymbol: reference.role?.labelIcon ?? .docText)
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
                            .frame(maxWidth: navigationViewModel.isUsingSplitView ? 300 : 400)
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
                if let reference = conditionReference(references[identifier]), reference.title != nil {
                    ReferenceNavigationLinkButton(reference: reference) {
                        HStack(spacing: 15) {
                            Image(systemSymbol: reference.role?.labelIcon ?? .docText)
                                .resizable()
                                .foregroundStyle(.secondary)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            
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
                }
            }
        default:
            Text("Links grid style not supported yet: \(style.rawValue)")
        }
    }
    
    /// Builds title text with fragment-aware styling (especially for symbols).
    func getFullTitle(_ reference: Reference) -> AttributedString {
        
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
