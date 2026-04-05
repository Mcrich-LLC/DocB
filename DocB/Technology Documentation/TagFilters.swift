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

extension EnvironmentValues {
    @Entry var tagFilters: Set<TagFilters> = []
}
