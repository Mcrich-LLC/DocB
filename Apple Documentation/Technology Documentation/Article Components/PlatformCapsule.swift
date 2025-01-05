//
//  PlatformCapsule.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

struct PlatformCapsule: View {
    let platform: Platform
    
    var text: String {
        let version: String
        
        if let introducedAt = platform.introducedAt {
            if let deprecatedAt = platform.deprecatedAt {
                version = "\(introducedAt)-\(deprecatedAt)"
            } else {
                version = "\(introducedAt)+"
            }
        } else {
            version = ""
        }
        
        return "\(platform.name) \(version)"
    }
    
    var hasBadge: Bool {
        platform.beta == true || platform.deprecated == true || platform.deprecatedAt != nil
    }
    
    var body: some View {
        HStack {
            Text(text)
            
            if platform.beta == true {
                ArticleBadge(badge: .beta)
                    .padding(.vertical, 4)
            }
            
            if platform.deprecated == true || platform.deprecatedAt != nil {
                ArticleBadge(badge: .deprecated)
                    .padding(.vertical, 4)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, hasBadge ? 2: 6)
        .padding(.horizontal)
        .background(Capsule().fill(Color(PlatformColor.tertiarySystemFill)))
    }
}
