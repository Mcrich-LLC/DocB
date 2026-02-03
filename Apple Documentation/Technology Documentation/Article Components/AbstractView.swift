//
//  AbstractView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

/// A view that renders the abstract of an article, concatenating text and code elements.
struct AbstractView: View {
    /// The abstract content to display.
    let abstract: [ContentStruct]
    
    var abstractText: Text {
        var text: Text = Text("")
        
        // swiftlint:disable shorthand_operator
        for content in abstract {
            switch content.type {
            case .text:
                text = text + Text(content.text ?? "")
            case .code:
                text = text + Text(content.code ?? "")
            default: break
            }
        }
        // swiftlint:enable shorthand_operator
        
        return text
    }
    
    var body: some View {
        abstractText
    }
}
