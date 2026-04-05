//
//  AppSettings.swift
//  DocB
//
//  Created by Morris Richman on 1/28/26.
//
import SwiftUI
import Foundation

@Observable
@MainActor
/// App-wide persisted preferences used to control runtime behavior.
class AppSettings {
    /// Whether in-app deep links should open in a separate window when supported.
    var openInAppDeeplinksInNewWindow: Bool = UserDefaults.standard.bool(forKey: "openInAppDeeplinksInNewWindow") {
        didSet {
            UserDefaults.standard.set(openInAppDeeplinksInNewWindow, forKey: "openInAppDeeplinksInNewWindow")
        }
    }
}
