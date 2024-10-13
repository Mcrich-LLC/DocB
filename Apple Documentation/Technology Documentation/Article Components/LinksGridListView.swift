//
//  LinksGridListView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/10/24.
//

import SwiftUI
import Kingfisher

struct LinksGridListView: View {
    let identifiers: [String]
    let style: ContentSection.Content.Style
    let references: [String : Reference]
    var alignment: Alignment
    var textAlignment: TextAlignment = .leading
    
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
    
    var body: some View {
        switch style {
        case .compactGrid, .detailedGrid:
            WrappingHStack(alignment: alignment, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(identifiers, id: \.self) { identifier in
                    if let reference = references[identifier],
                        let title = reference.title,
                       let imageId = reference.images?.first(where: { $0.type == .card })?.identifier,
                       let openUrl = URL(string: reference.identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
                        
                        let imageUrl = Constants.fetchPhotoVideoURL(for: imageId, references: references, colorScheme: colorScheme)
                        
                        MacOSAgnosticLink(destination: openUrl) {
                            VStack(alignment: .leading) {
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
                            .frame(maxWidth: 300)
                        }
                        .contentShape(UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
                        .hoverEffect()
                    }
                }
            }
        case .list:
            ForEach(identifiers, id: \.self) { identifier in
                if let reference = references[identifier], reference.title != nil {
                    ReferenceNavigationLinkButton(reference: reference) {
                        HStack(spacing: 15) {
                            Image(systemSymbol: reference.role?.labelIcon ?? .docText)
                                .resizable()
                                .foregroundStyle(.secondary)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            
                            VStack {
                                Text(getFullTitle(reference))
                                    .frame(maxWidth: .infinity, alignment: alignment)
                                    .foregroundStyle(.primary)
                                
                                if let abstract = reference.abstract {
                                    AbstractView(abstract: abstract)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: alignment)
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
                            .foregroundColor: UIColor.accent,
                            .font: UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .medium)
                        ]
                    default:
                        [
                            .foregroundColor: UIColor.secondaryLabel,
                            .font: UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .medium)
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
            let fragmentAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]
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
}
