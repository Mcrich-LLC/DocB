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
    let article: Article
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch style {
        case .compactGrid, .detailedGrid:
            WrappingHStack(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(identifiers, id: \.self) { identifier in
                    if let reference = article.references[identifier],
                        let title = reference.title,
                        let imageId = reference.images?.first?.identifier,
                       let openUrl = URL(string: reference.identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
                        
                        let imageUrl = article.fetchPhotoVideoURL(for: imageId, colorScheme: colorScheme)
                        
                        MacOSAgnosticLink(destination: openUrl) {
                            VStack(alignment: .leading) {
                                KFImage(imageUrl)
                                    .placeholder({
                                        Image(systemSymbol: .photo)
                                            .resizable()
                                            .scaledToFit()
                                    })
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                                
                                Text(title)
                                    .foregroundStyle(Color.primary)
                                    .bold()
                                    .multilineTextAlignment(.leading)
                                
                                if let abstract = reference.abstract, style == .detailedGrid {
                                    AbstractView(abstract: abstract)
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: 300)
                        }
                    }
                }
            }
        case .list:
            ForEach(identifiers, id: \.self) { identifier in
                if let reference = article.references[identifier], reference.title != nil {
                    ReferenceNavigationLinkButton(reference: reference) {
                        HStack(spacing: 15) {
                            Image(systemSymbol: reference.role?.labelIcon ?? .docText)
                                .resizable()
                                .foregroundStyle(.secondary)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            
                            VStack {
                                Text(getFullTitle(reference))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(.primary)
                                
                                if let abstract = reference.abstract {
                                    AbstractView(abstract: abstract)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .multilineTextAlignment(.leading)
                        }
                    }
                    .tint(.primary)
                }
            }
        default:
            Text("Links grid style not supported yet: \(style.rawValue)")
        }
    }
    
    func getFullTitle(_ reference: Reference) -> AttributedString {
        
        if reference.role == .symbol {
            let nsAttributedString: NSMutableAttributedString = .init()
            
            let fragments: String = (reference.fragments ?? []).dropLast().map({ $0.text }).joined()
            let fragmentAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.accent,
                .font: UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .medium)
            ]
            let fragmentAttributedString = NSAttributedString(string: fragments, attributes: fragmentAttributes)
            nsAttributedString.append(fragmentAttributedString)
            
            return AttributedString(nsAttributedString)
        } else {
            let nsAttributedString: NSMutableAttributedString = .init()
            
            let fragments: String = (reference.fragments ?? []).dropLast().map({ $0.text }).joined()
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
