//
//  IconTrailingLabelStyle.swift
//  Developer Documentation
//
//  Created by Morris Richman on 6/13/25.
//

import SwiftUI

/// A label style that places the icon trailing the title.
struct IconTrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == IconTrailingLabelStyle {
    /// A label style with the icon trailing the title.
    static var iconTrailing: Self {
        .init()
    }
}
