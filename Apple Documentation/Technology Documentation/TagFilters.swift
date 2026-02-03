//
//  TagFilters.swift
//  Developer Documentation
//
//  Created by Morris Richman on 8/16/25.
//

import SwiftUI

/// Filters available for documentation content.
enum TagFilters: String, CaseIterable {
    /// Filters for deprecated content.
    case deprecated
    /// Filters for beta content.
    case beta
}

extension EnvironmentValues {
    @Entry var tagFilters: Set<TagFilters> = []
}
