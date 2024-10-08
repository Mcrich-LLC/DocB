//
//  AbstractView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

struct AbstractView: View {
    let abstract: [ContentStruct]
    
    var abstractText: Text {
        var text: Text = Text("")
        
        for content in abstract {
            switch content.type {
                case .text:
                text = text + Text(content.text ?? "")
            case .code:
                text = text + Text(content.code ?? "")
            default: break
            }
        }
        
        return text
    }
    
    var body: some View {
        abstractText
    }
}
