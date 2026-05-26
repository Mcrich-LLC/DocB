//
//  SettingsView.swift
//  DocB
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI
import DocCKit
#if os(macOS)
import AppKit
#endif

/// Renders the app settings container and organizes settings into tabs.
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
        }
        .padding()
        .frame(minWidth: 400)
    }
}

/// Shows general app preferences, including default article window behavior.
struct GeneralSettingsView: View {
    @Environment(AppSettings.self) var appSettings
    
    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Toggle("Open Article in New Window", isOn: $appSettings.openInAppDeeplinksInNewWindow)

            #if os(macOS)
            Section("Search") {
                HStack {
                    Text("Keyboard Shortcut")

                    Spacer()

                    SearchKeyboardShortcutRecorder(appSettings: appSettings)
                        .frame(width: 160)
                }

                HStack {
                    Text("Click the shortcut field, then press the key combination to use.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Restore Default") {
                        appSettings.resetSearchKeyboardShortcut()
                    }
                }
            }
            #endif
        }
    }
}

#if os(macOS)
private struct SearchKeyboardShortcutRecorder: NSViewRepresentable {
    let appSettings: AppSettings

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setAccessibilityLabel("Search Documentation keyboard shortcut")
        button.setAccessibilityHelp("Click, then press the keyboard shortcut to use for Search Documentation.")
        button.onShortcutChange = { key, modifiers in
            Task { @MainActor in
                appSettings.setSearchKeyboardShortcut(key: key, modifiers: modifiers)
            }
        }
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcutDescription = shortcutDescription
    }

    static func dismantleNSView(_ nsView: ShortcutRecorderButton, coordinator: ()) {
        nsView.stopRecording()
    }

    private var shortcutDescription: String {
        var parts: [String] = []
        if appSettings.searchKeyboardShortcutUsesControl {
            parts.append("⌃")
        }
        if appSettings.searchKeyboardShortcutUsesOption {
            parts.append("⌥")
        }
        if appSettings.searchKeyboardShortcutUsesShift {
            parts.append("⇧")
        }
        if appSettings.searchKeyboardShortcutUsesCommand {
            parts.append("⌘")
        }
        parts.append(appSettings.searchKeyboardShortcutKey.uppercased())
        return parts.joined()
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onShortcutChange: ((String, EventModifiers) -> Void)?
    private var keyEventMonitor: Any?

    var shortcutDescription = "" {
        didSet {
            guard !isRecording else { return }
            title = shortcutDescription
            setAccessibilityValue(shortcutDescription)
        }
    }

    private var isRecording = false {
        didSet {
            if isRecording {
                installKeyEventMonitor()
            } else {
                removeKeyEventMonitor()
            }
            title = isRecording ? "Type Shortcut" : shortcutDescription
            setAccessibilityValue(title)
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        captureShortcut(from: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }

        captureShortcut(from: event)
        return true
    }

    override func cancelOperation(_ sender: Any?) {
        isRecording = false
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isRecording, let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        NSColor.controlAccentColor.setStroke()
        context.setLineWidth(2)
        context.stroke(bounds.insetBy(dx: 2, dy: 2), width: 2)
        context.restoreGState()
    }

    private static let escapeKeyCode: UInt16 = 53

    func stopRecording() {
        isRecording = false
    }

    private func installKeyEventMonitor() {
        guard keyEventMonitor == nil else { return }

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else {
                return event
            }

            self.captureShortcut(from: event)
            return nil
        }
    }

    private func removeKeyEventMonitor() {
        guard let keyEventMonitor else { return }

        NSEvent.removeMonitor(keyEventMonitor)
        self.keyEventMonitor = nil
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

        onShortcutChange?(key, modifiers)
        isRecording = false
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
