//
//  GlobalSearchHotKeyController.swift
//  DocB
//
//  Created by Codex on 5/25/26.
//

#if os(macOS)
import Carbon.HIToolbox
import DocBCore
import AppKit
import SwiftUI

/// Registers the Search Documentation shortcut as a macOS-wide hot key.
@MainActor
final class GlobalSearchHotKeyController {
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var registeredShortcut: RegisteredShortcut?
    private var action: (@MainActor @Sendable () -> Void)?

    /// Registers or updates the global Search Documentation hot key.
    /// - Parameters:
    ///   - appSettings: Settings that provide the shortcut key and modifiers.
    ///   - action: Action to perform when the global hot key is pressed.
    func register(
        appSettings: AppSettings,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        self.action = action

        guard let shortcut = RegisteredShortcut(appSettings: appSettings) else {
            unregisterHotKey()
            return
        }

        guard shortcut != registeredShortcut else {
            return
        }

        unregisterHotKey()
        installEventHandlerIfNeeded()

        var hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyID
        )
        var newHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKey
        )

        guard status == noErr, let newHotKey else {
            registeredShortcut = nil
            return
        }

        hotKey = newHotKey
        registeredShortcut = shortcut
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
    }

    private func unregister() {
        unregisterHotKey()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    private func unregisterHotKey() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }

        registeredShortcut = nil
    }

    private func presentSearchPalette() {
        NSApplication.shared.activate()
        action?()
    }

    private static let hotKeySignature: OSType = 0x444F4342
    private static let hotKeyID: UInt32 = 1

    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, userData in
        guard let event,
              let userData,
              isSearchHotKeyEvent(event)
        else {
            return noErr
        }

        let controller = Unmanaged<GlobalSearchHotKeyController>
            .fromOpaque(userData)
            .takeUnretainedValue()
        Task { @MainActor in
            controller.presentSearchPalette()
        }
        return noErr
    }

    private static func isSearchHotKeyEvent(_ event: EventRef) -> Bool {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        return status == noErr
            && hotKeyID.signature == hotKeySignature
            && hotKeyID.id == Self.hotKeyID
    }
}

private struct RegisteredShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    @MainActor
    init?(appSettings: AppSettings) {
        guard let keyCode = KeyCode.carbonKeyCode(for: appSettings.searchKeyboardShortcutKey) else {
            return nil
        }

        self.keyCode = keyCode
        modifiers = CarbonModifiers.modifiers(for: appSettings.searchKeyboardShortcutModifiers)
    }
}

private enum CarbonModifiers {
    static func modifiers(for eventModifiers: SwiftUI.EventModifiers) -> UInt32 {
        var modifiers: UInt32 = 0
        if eventModifiers.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if eventModifiers.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if eventModifiers.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if eventModifiers.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        return modifiers
    }
}

private enum KeyCode {
    static func carbonKeyCode(for key: String) -> UInt32? {
        guard let character = key.lowercased().first else {
            return nil
        }

        return keyCodes[character].map(UInt32.init)
    }

    private static let keyCodes: [Character: Int] = [
        "a": kVK_ANSI_A,
        "b": kVK_ANSI_B,
        "c": kVK_ANSI_C,
        "d": kVK_ANSI_D,
        "e": kVK_ANSI_E,
        "f": kVK_ANSI_F,
        "g": kVK_ANSI_G,
        "h": kVK_ANSI_H,
        "i": kVK_ANSI_I,
        "j": kVK_ANSI_J,
        "k": kVK_ANSI_K,
        "l": kVK_ANSI_L,
        "m": kVK_ANSI_M,
        "n": kVK_ANSI_N,
        "o": kVK_ANSI_O,
        "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q,
        "r": kVK_ANSI_R,
        "s": kVK_ANSI_S,
        "t": kVK_ANSI_T,
        "u": kVK_ANSI_U,
        "v": kVK_ANSI_V,
        "w": kVK_ANSI_W,
        "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0,
        "1": kVK_ANSI_1,
        "2": kVK_ANSI_2,
        "3": kVK_ANSI_3,
        "4": kVK_ANSI_4,
        "5": kVK_ANSI_5,
        "6": kVK_ANSI_6,
        "7": kVK_ANSI_7,
        "8": kVK_ANSI_8,
        "9": kVK_ANSI_9
    ]
}
#endif
