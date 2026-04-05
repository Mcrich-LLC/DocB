//
//  DownloadButtonView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

/// DownloadButtonView renders a reusable SwiftUI view.
struct DownloadButtonView: View {
    let sampleCodeDownload: Article.SampleCodeDownload
    let references: [String : Reference]
    
    var reference: Reference? {
        references[sampleCodeDownload.action.identifier]
    }
    
    var url: URL? {
        guard let reference, let urlString = reference.url else { return nil }
        
        return URL(string: urlString)
    }
    
    var title: String {
        if let title = sampleCodeDownload.action.overridingTitle {
            return title
        }
        
        guard let reference, let title = reference.title else {
            return "Download"
        }
        
        return title
    }
    
    var body: some View {
        if let url {
            Link(title, destination: url)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }
}
