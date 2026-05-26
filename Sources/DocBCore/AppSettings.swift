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
    private static let searchShortcutKeyKey = "searchKeyboardShortcutKey"
    private static let searchShortcutUsesCommandKey = "searchKeyboardShortcutUsesCommand"
    private static let searchShortcutUsesShiftKey = "searchKeyboardShortcutUsesShift"
    private static let searchShortcutUsesOptionKey = "searchKeyboardShortcutUsesOption"
    private static let searchShortcutUsesControlKey = "searchKeyboardShortcutUsesControl"
    private static let searchShortcutIsGlobalEnabledKey = "searchKeyboardShortcutIsGlobalEnabled"
    private var isUpdatingSearchKeyboardShortcut = false
    public init() {}
    
    /// Whether in-app deep links should open in a separate window when supported.
    public var openInAppDeeplinksInNewWindow: Bool = UserDefaults.standard.bool(forKey: "openInAppDeeplinksInNewWindow") {
        didSet {
            UserDefaults.standard.set(openInAppDeeplinksInNewWindow, forKey: "openInAppDeeplinksInNewWindow")
        }
    }

    /// Letter or number used by the Search Documentation keyboard shortcut.
    public var searchKeyboardShortcutKey: String = AppSettings.normalizedShortcutKey(UserDefaults.standard.string(forKey: searchShortcutKeyKey) ?? "d") {
        didSet {
            UserDefaults.standard.set(searchKeyboardShortcutKey, forKey: Self.searchShortcutKeyKey)
        }
    }

    /// Whether the Search Documentation keyboard shortcut includes Command.
    public var searchKeyboardShortcutUsesCommand: Bool = AppSettings.bool(forKey: searchShortcutUsesCommandKey, defaultValue: true) {
        didSet {
            if !isUpdatingSearchKeyboardShortcut {
                ensureSearchKeyboardShortcutHasModifier()
            }
            UserDefaults.standard.set(searchKeyboardShortcutUsesCommand, forKey: Self.searchShortcutUsesCommandKey)
        }
    }

    /// Whether the Search Documentation keyboard shortcut includes Shift.
    public var searchKeyboardShortcutUsesShift: Bool = AppSettings.bool(forKey: searchShortcutUsesShiftKey, defaultValue: true) {
        didSet {
            if !isUpdatingSearchKeyboardShortcut {
                ensureSearchKeyboardShortcutHasModifier()
            }
            UserDefaults.standard.set(searchKeyboardShortcutUsesShift, forKey: Self.searchShortcutUsesShiftKey)
        }
    }

    /// Whether the Search Documentation keyboard shortcut includes Option.
    public var searchKeyboardShortcutUsesOption: Bool = AppSettings.bool(forKey: searchShortcutUsesOptionKey, defaultValue: false) {
        didSet {
            if !isUpdatingSearchKeyboardShortcut {
                ensureSearchKeyboardShortcutHasModifier()
            }
            UserDefaults.standard.set(searchKeyboardShortcutUsesOption, forKey: Self.searchShortcutUsesOptionKey)
        }
    }

    /// Whether the Search Documentation keyboard shortcut includes Control.
    public var searchKeyboardShortcutUsesControl: Bool = AppSettings.bool(forKey: searchShortcutUsesControlKey, defaultValue: false) {
        didSet {
            if !isUpdatingSearchKeyboardShortcut {
                ensureSearchKeyboardShortcutHasModifier()
            }
            UserDefaults.standard.set(searchKeyboardShortcutUsesControl, forKey: Self.searchShortcutUsesControlKey)
        }
    }

    /// Whether the Search Documentation keyboard shortcut should work while DocB is in the background.
    public var searchKeyboardShortcutIsGlobalEnabled: Bool = AppSettings.bool(forKey: searchShortcutIsGlobalEnabledKey, defaultValue: true) {
        didSet {
            UserDefaults.standard.set(searchKeyboardShortcutIsGlobalEnabled, forKey: Self.searchShortcutIsGlobalEnabledKey)
        }
    }

    /// SwiftUI keyboard shortcut used to present Search Documentation.
    public var searchKeyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(.init(Character(searchKeyboardShortcutKey)), modifiers: searchKeyboardShortcutModifiers)
    }

    /// Modifier set used to present Search Documentation.
    public var searchKeyboardShortcutModifiers: EventModifiers {
        var modifiers: EventModifiers = []
        if searchKeyboardShortcutUsesCommand {
            modifiers.insert(.command)
        }
        if searchKeyboardShortcutUsesShift {
            modifiers.insert(.shift)
        }
        if searchKeyboardShortcutUsesOption {
            modifiers.insert(.option)
        }
        if searchKeyboardShortcutUsesControl {
            modifiers.insert(.control)
        }

        return modifiers
    }

    /// Human-readable symbol string for the Search Documentation keyboard shortcut.
    public var searchKeyboardShortcutDescription: String {
        Self.searchKeyboardShortcutDescription(
            key: searchKeyboardShortcutKey,
            modifiers: searchKeyboardShortcutModifiers
        )
    }

    /// Restores the default Search Documentation keyboard shortcut.
    public func resetSearchKeyboardShortcut() {
        isUpdatingSearchKeyboardShortcut = true
        searchKeyboardShortcutKey = "d"
        searchKeyboardShortcutUsesCommand = true
        searchKeyboardShortcutUsesShift = true
        searchKeyboardShortcutUsesOption = false
        searchKeyboardShortcutUsesControl = false
        isUpdatingSearchKeyboardShortcut = false
        ensureSearchKeyboardShortcutHasModifier()
    }

    /// Updates the Search Documentation keyboard shortcut from a captured key event.
    /// - Parameters:
    ///   - key: Single-character key equivalent to use for the shortcut.
    ///   - modifiers: Modifier keys required to trigger the shortcut.
    public func setSearchKeyboardShortcut(key: String, modifiers: EventModifiers) {
        isUpdatingSearchKeyboardShortcut = true
        searchKeyboardShortcutKey = Self.normalizedShortcutKey(key)
        searchKeyboardShortcutUsesCommand = modifiers.contains(.command)
        searchKeyboardShortcutUsesShift = modifiers.contains(.shift)
        searchKeyboardShortcutUsesOption = modifiers.contains(.option)
        searchKeyboardShortcutUsesControl = modifiers.contains(.control)
        isUpdatingSearchKeyboardShortcut = false
        ensureSearchKeyboardShortcutHasModifier()
    }

    /// Returns a human-readable symbol string for a keyboard shortcut.
    ///
    /// - Parameters:
    ///   - key: Single-character key equivalent for the shortcut.
    ///   - modifiers: Modifier keys required to trigger the shortcut.
    /// - Returns: A compact shortcut string that matches macOS keyboard shortcut labels.
    public static func searchKeyboardShortcutDescription(key: String, modifiers: EventModifiers) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        parts.append(normalizedShortcutKey(key).uppercased())
        return parts.joined()
    }

    private static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private static func normalizedShortcutKey(_ value: String) -> String {
        value.first(where: { $0.isLetter || $0.isNumber })
            .map { String($0).lowercased() } ?? "d"
    }

    private func ensureSearchKeyboardShortcutHasModifier() {
        guard !searchKeyboardShortcutUsesCommand,
              !searchKeyboardShortcutUsesShift,
              !searchKeyboardShortcutUsesOption,
              !searchKeyboardShortcutUsesControl
        else {
            return
        }

        searchKeyboardShortcutUsesCommand = true
    }
}
