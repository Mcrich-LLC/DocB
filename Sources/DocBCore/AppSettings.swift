//
//  AppSettings.swift
//  DocB
//
//  Created by Morris Richman on 1/28/26.
//
import SwiftUI
import Foundation

/// App-wide persisted preferences used to control runtime behavior.
@Observable
@MainActor
public class AppSettings {
    public init() {}
    
    /// Whether in-app deep links should open in a separate window when supported.
    public var openInAppDeeplinksInNewWindow: Bool = UserDefaults.standard.bool(forKey: "openInAppDeeplinksInNewWindow") {
        didSet {
            UserDefaults.standard.set(openInAppDeeplinksInNewWindow, forKey: "openInAppDeeplinksInNewWindow")
        }
    }
}
