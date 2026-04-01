//
//  AppSettings.swift
//  DevDocs
//
//  Created by Morris Richman on 1/28/26.
//
import SwiftUI
import Foundation

@Observable
@MainActor
class AppSettings {
    var openInAppDeeplinksInNewWindow: Bool = UserDefaults.standard.bool(forKey: "openInAppDeeplinksInNewWindow") {
        didSet {
            UserDefaults.standard.set(openInAppDeeplinksInNewWindow, forKey: "openInAppDeeplinksInNewWindow")
        }
    }
}
