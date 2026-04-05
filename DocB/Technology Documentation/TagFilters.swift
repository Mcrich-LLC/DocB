//
//  TagFilters.swift
//  DocB
//
//  Created by Morris Richman on 8/16/25.
//

import SwiftUI

/// TagFilters defines a constrained set of related values.
enum TagFilters: String, CaseIterable {
    case deprecated
    case beta
}

/// Environment storage for active homepage/technology tag filter selections.
extension EnvironmentValues {
    /// Active sidebar tag filters applied to technology listings.
    @Entry var tagFilters: Set<TagFilters> = []
}
