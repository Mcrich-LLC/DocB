//
//  PlatformCapsule.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI

/// PlatformCapsule renders a reusable SwiftUI view.
struct PlatformCapsule: View {
    /// Platform metadata rendered in capsule form.
    let platform: Platform
    
    /// Human-readable platform/version label assembled from introduction/deprecation metadata.
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
    
    /// Whether beta/deprecation badge chips should be displayed.
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
        .textSelection(.enabled)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, hasBadge ? 2: 6)
        .padding(.horizontal)
        .background(Capsule().fill(Color(PlatformColor.tertiarySystemFill)))
    }
}
