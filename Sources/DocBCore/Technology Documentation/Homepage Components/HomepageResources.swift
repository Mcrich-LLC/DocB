//
//  HomepageResources.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import NukeUI

/// HomepageResources renders a reusable SwiftUI view.
struct HomepageResources: View {
    /// Homepage section payload for this resources block.
    let section: HomepageParser.Section
    /// Parsed homepage data containing shared references.
    let homepage: HomepageParser
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let resources = section.resources {
            WrappingHStack(alignment: .top, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(resources) { resource in
                    item(resource)
                        .frame(maxWidth: 300)
                }
            }
        }
    }
    
    /// Renders a single resource card with optional image, content, and destination link.
    @ViewBuilder
    func item(_ item: HomepageParser.Resource) -> some View {
        VStack {
            if let imageId = item.image, let imageUrl = Constants.fetchPhotoVideoURL(for: imageId, references: homepage.references, colorScheme: colorScheme, docCSite: nil) {
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                            .stroke(Color.primary, lineWidth: 2)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(maxHeight: 50)
            }
            
            Text(item.title)
                .font(.headline)
            
            ForEach(item.content) { item in
                ArticleContentView(content: item, references: homepage.references, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            
            if let reference = homepage.references[item.destination.identifier], let url = URL(string: reference.identifier), let title = reference.title {
                MacOSAgnosticLink(destination: url) {
                    HStack {
                        Text(title) + Text(" ") + Text(Image(systemSymbol: .chevronRight))
                    }
                }
            }
        }
    }
}
