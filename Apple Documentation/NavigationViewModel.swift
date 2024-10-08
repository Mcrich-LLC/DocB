//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//

import Foundation

class NavigationViewModel: ObservableObject, Equatable {
     
    // TODO: Implement url handling for doc://com.apple.documentation
    
    @Published var technology: Technologies.FrameworkSection?
    @Published var reference: Reference?
    
    static func == (lhs: NavigationViewModel, rhs: NavigationViewModel) -> Bool {
        lhs.technology == rhs.technology && lhs.reference == rhs.reference
    }
    
}
