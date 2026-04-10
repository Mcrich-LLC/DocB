//
//  HomepageHero.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import NukeUI

/// HomepageHero renders a reusable SwiftUI view.
struct HomepageHero: View {
    /// Homepage section payload used to render hero media and text.
    let section: HomepageParser.Section
    /// Parsed homepage document containing shared references.
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
                LazyImage(url: heroContentURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                            .stroke(Color.primary, lineWidth: 2)
                            .scaledToFit()
                            .overlay {
                                ProgressView()
                            }
                    }
                }
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
