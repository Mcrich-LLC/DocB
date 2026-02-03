//
//  LinksGridListView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI
import Kingfisher

/// A view that displays a list of links in either a grid or list layout.
struct LinksGridListView: View {
    /// The list of reference identifiers to display.
    let identifiers: [String]
    /// The display style (e.g., compact grid, detailed grid, list).
    let style: ContentSection.Content.Style
    /// A dictionary of references for resolving link data.
    let references: [String : Reference]
    private var alignment: Alignment
    private var textAlignment: TextAlignment = .leading
     
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
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    init(identifiers: [String], style: ContentSection.Content.Style, references: [String : Reference], navigationViewModel: NavigationViewModel) {
        self.identifiers = identifiers
        self.style = style
        self.references = references
        self.alignment = !navigationViewModel.isUsingSplitView ? .top : .topLeading
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    func alignment(_ alignment: Alignment) -> Self {
        var view = self
        view.alignment = alignment
        
        return view
    }
    
    func multilineTextAlignment(_ textAlignment: TextAlignment) -> Self {
        var view = self
        view.textAlignment = textAlignment
        
        return view
    }
    
    @Environment(\.docCSite) var docCSite
    func conditionReference(_ reference: Reference?) -> Reference? {
        guard var reference = reference else { return nil }
        
        if reference.docCSite == nil {
            reference.docCSite = self.docCSite
        }
        
        return reference
    }
    
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
