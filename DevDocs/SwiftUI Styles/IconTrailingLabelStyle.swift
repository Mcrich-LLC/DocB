//
//  IconTrailingLabelStyle.swift
//  DevDocs
//
//  Created by Morris Richman on 6/13/25.
//

import SwiftUI

struct IconTrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == IconTrailingLabelStyle {
    static var iconTrailing: Self {
        .init()
    }
}
