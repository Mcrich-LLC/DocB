//
//  CancelButton.swift
//  DocB
//
//  Created by Morris Richman on 3/11/26.
//

import SwiftUI

/// Platform-aware cancel button that uses role-based styling on newer OS versions.
struct CancelButton: View {
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            Button(role: .cancel, action: action)
        } else {
            Button("Cancel", role: .destructive, action: action)
        }
    }
}

#Preview {
    ToolbarCloseButton()
}
