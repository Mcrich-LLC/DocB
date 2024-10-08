//
//  PlatformCapsule.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

struct PlatformCapsule: View {
    @Environment(\.colorScheme) var colorScheme
    let platform: Platform
    
    var text: String {
        let version: String
        
        if let deprecatedAt = platform.deprecatedAt {
            version = "\(platform.introducedAt)-\(deprecatedAt)"
        } else {
            version = "\(platform.introducedAt)+"
        }
        
        return "\(platform.name.rawValue) \(version)"
    }
    
    var hasTags: Bool {
        platform.beta == true || platform.deprecated == true
    }
    
    var body: some View {
        HStack {
            Text(text)
            
            if platform.beta == true {
                Text("Beta")
                    .foregroundStyle(colorScheme == .light ? Color.white : Color.black)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.mint))
                    .padding(.vertical, 4)
            }
            
            if platform.deprecated == true {
                Text("Deprecated")
                    .foregroundStyle(colorScheme == .light ? Color.white : Color.black)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.orange))
                    .padding(.vertical, 4)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, hasTags ? 2: 6)
        .padding(.horizontal)
        .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
    }
}
