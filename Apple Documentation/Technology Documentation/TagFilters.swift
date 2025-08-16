//
//  TagFilters.swift
//  Developer Documentation
//
//  Created by Morris Richman on 8/16/25.
//

import SwiftUI

enum TagFilters: String, CaseIterable {
    case deprecated
    case beta
}

extension EnvironmentValues {
    @Entry var tagFilters: Set<TagFilters> = []
}
