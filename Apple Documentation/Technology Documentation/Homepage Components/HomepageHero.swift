//
//  HomepageHero.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import Kingfisher

/// A view that displays a hero section on the homepage, typically featuring a large image or video with a title.
struct HomepageHero: View {
    /// The section data containing the hero content.
    let section: HomepageParser.Section
    /// The full homepage parser object, used for reference resolution.
    let homepage: HomepageParser
    
    @Environment(\.colorScheme) var colorScheme
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    func fetchPhotoVideoURL() -> URL? {
        let identifier = if let video = section.video { video } else { section.image }
        
        guard let identifier,
              let url = Constants.fetchPhotoVideoURL(for: identifier, references: homepage.references, colorScheme: colorScheme, docCSite: nil)
        else {
            return nil
        }
        
        return url
    }
    
    var body: some View {
        ZStack {
            if let heroContentURL = fetchPhotoVideoURL() {
                KFImage(heroContentURL)
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
                    .scaledToFit()
            }
            VStack {
                if let text = section.title {
                    Text(text)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                }
                
                if let content = section.content {
                    ForEach(content) { con in
                        ArticleContentView(content: con, references: homepage.references, alignment: .center)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxHeight: 500)
    }
}
