//
//  AppSettings.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/28/26.
//
import SwiftUI
import Foundation

@Observable
@MainActor
/// Manages application-wide settings and preferences.
class AppSettings {
    /// Determines whether deep links triggered within the app should open in a new window.
    ///
    /// Persisted in `UserDefaults` under the key "openInAppDeeplinksInNewWindow".
    var openInAppDeeplinksInNewWindow: Bool = UserDefaults.standard.bool(forKey: "openInAppDeeplinksInNewWindow") {
        didSet {
            UserDefaults.standard.set(openInAppDeeplinksInNewWindow, forKey: "openInAppDeeplinksInNewWindow")
        }
    }
}
