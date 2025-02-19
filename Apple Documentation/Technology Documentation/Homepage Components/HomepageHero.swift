//
//  HomepageHero.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import Kingfisher

struct HomepageHero: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            if let imageString = section.video, let imageReferenceURL = Constants.fetchPhotoVideoURL(for: imageString, references: homepage.references, colorScheme: colorScheme) {
                KFImage(imageReferenceURL)
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
    }
}
