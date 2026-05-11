import AppKit
import ApplicationServices

enum Paster {
    /// Returns true if the system reports we have (or just granted) Accessibility trust.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user (one-time per app launch). After clicking Allow in System Settings
    /// they typically need to relaunch Mnemo for the new trust to take effect.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Synthesizes ⌘V to the frontmost app. No-op (returns false) if Accessibility not granted.
    @discardableResult
    static func pasteCommandV() -> Bool {
        guard isAccessibilityTrusted else { return false }
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return false }
        let vKey: CGKeyCode = 9 // ANSI V
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
