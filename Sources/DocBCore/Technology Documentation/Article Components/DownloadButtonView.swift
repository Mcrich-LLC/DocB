//
//  DownloadButtonView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI
import DocCKit

/// DownloadButtonView renders a reusable SwiftUI view.
struct DownloadButtonView: View {
    /// Download action metadata from the article payload.
    let sampleCodeDownload: Article.SampleCodeDownload
    /// Reference lookup table used to resolve destination URLs and titles.
    let references: [String : Reference]
    
    /// Reference resolved from the sample download action identifier.
    var reference: Reference? {
        references[sampleCodeDownload.action.identifier]
    }
    
    /// URL extracted from the resolved reference.
    var url: URL? {
        guard let reference, let urlString = reference.url else { return nil }
        
        return URL(string: urlString)
    }
    
    /// Button title favoring explicit override, then reference title, then a default fallback.
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
