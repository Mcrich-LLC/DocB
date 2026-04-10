//
//  AbstractView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

/// AbstractView renders a reusable SwiftUI view.
struct AbstractView: View {
    /// Parsed abstract inline content.
    let abstract: [ContentStruct]
    
    /// Plain `Text` reconstructed from supported abstract content fragments.
    var abstractText: Text {
        var text: Text = Text("")
        
        // swiftlint:disable shorthand_operator
        for content in abstract {
            switch content.type {
            case .text:
                text = text + Text(content.text ?? "")
            case .code, .codeVoice:
                text = text + Text(content.code ?? "").applyCodeFont()
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
