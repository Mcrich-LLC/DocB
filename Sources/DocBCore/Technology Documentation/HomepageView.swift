//
//  HomepageView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import DocCKit

/// HomepageView coordinates DocB app state for a DocC homepage renderer.
struct HomepageView: View {
    /// Parsed homepage payload.
    let homepage: HomepageParser
    
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    var body: some View {
        DocCHomepageView(homepage: homepage, navigator: navigationViewModel)
    }
}
