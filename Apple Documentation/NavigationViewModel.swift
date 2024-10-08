//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//

import Foundation
import SwiftUI

class NavigationViewModel: ObservableObject, Equatable {
     
    // TODO: Implement url handling for doc://com.apple.documentation
    
    @Published var technology: Technologies.FrameworkSection?
    @Published var reference: Reference?

    var iphoneArticleDestinationBinding: Binding<Reference?> {
        Binding {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                return nil
            }
            return self.reference
        } set: { reference in
            self.reference = reference
        }
    }
    
    static func == (lhs: NavigationViewModel, rhs: NavigationViewModel) -> Bool {
        lhs.technology == rhs.technology && lhs.reference == rhs.reference
    }
    
}
