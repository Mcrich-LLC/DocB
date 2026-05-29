//
//  SettingsView.swift
//  DocB
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI
import DocCKit
import SFSafeSymbols
#if os(macOS)
import AppKit
#endif

/// Renders the app settings container and organizes settings into tabs.
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            Tab("General", systemSymbol: .gear) {
                GeneralSettingsView()
            }
            #if os(macOS)
            Tab("Shortcuts", systemSymbol: .keyboard) {
                ShortcutsSettingsView()
            }
            #endif
        }
        .padding()
        .frame(minWidth: 400)
        .formStyle(.grouped)
    }
}

/// Shows general app preferences, including default article window behavior.
struct GeneralSettingsView: View {
    @Environment(AppSettings.self) var appSettings
    
    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Toggle("Open Article in New Window", isOn: $appSettings.openInAppDeeplinksInNewWindow)
        }
    }
}

#if os(macOS)
/// Shows keyboard shortcut preferences.
struct ShortcutsSettingsView: View {
    @Environment(AppSettings.self) var appSettings

    var body: some View {
        Form {
            Section {
                LabeledContent("Keyboard Shortcut") {
                    SearchKeyboardShortcutRecorder(appSettings: appSettings)
                }

                Toggle("Enable search while DocB is in the background", isOn: Bindable(appSettings).searchKeyboardShortcutIsGlobalEnabled)
            } header: {
                Text("Search Documentation")
                    .font(.headline)
            }
            
            Section {
                Button("Restore to Default") {
                    appSettings.resetSearchKeyboardShortcut()
                }
            }
        }
    }
}
private struct SearchKeyboardShortcutRecorder: View {
    let appSettings: AppSettings

    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var capturedShortcutDescription: String?

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(displayedShortcutDescription)
                .monospacedDigit()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Search Documentation keyboard shortcut")
        .accessibilityValue(displayedShortcutDescription)
        .accessibilityHint("Click, then press the keyboard shortcut to use for Search Documentation.")
        .onChange(of: isRecording) { _, isRecording in
            if isRecording {
                installEventMonitor()
            } else {
                removeEventMonitor()
            }
        }
        .onDisappear {
            isRecording = false
            removeEventMonitor()
        }
    }

    private var displayedShortcutDescription: String {
        isRecording ? "Type Shortcut" : capturedShortcutDescription ?? settingsShortcutDescription
    }

    private var settingsShortcutDescription: String {
        appSettings.searchKeyboardShortcutDescription
    }

    private static let escapeKeyCode: UInt16 = 53

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else {
                return event
            }

            captureShortcut(from: event)
            return nil
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else { return }

        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func captureShortcut(from event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            isRecording = false
            return
        }

        guard let key = Self.shortcutKey(from: event) else {
            NSSound.beep()
            return
        }

        let modifiers = Self.shortcutModifiers(from: event)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        capturedShortcutDescription = AppSettings.searchKeyboardShortcutDescription(key: key, modifiers: modifiers)
        appSettings.setSearchKeyboardShortcut(key: key, modifiers: modifiers)
        isRecording = false
        capturedShortcutDescription = nil
    }

    private static func shortcutKey(from event: NSEvent) -> String? {
        guard let character = event.charactersIgnoringModifiers?.first,
              character.isLetter || character.isNumber
        else {
            return nil
        }

        return String(character).lowercased()
    }

    private static func shortcutModifiers(from event: NSEvent) -> EventModifiers {
        var modifiers: EventModifiers = []
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        return modifiers
    }

}
#endif

#Preview {
    SettingsView()
        .environment(AppSettings())
}
