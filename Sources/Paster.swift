import AppKit
import ApplicationServices
import Carbon.HIToolbox

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
        let vKey = KeycodeLookup.virtualKeyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
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

/// Resolves a Unicode character to the current keyboard layout's virtual keycode.
///
/// The synthesized ⌘V shortcut for auto-paste (`Paster.pasteCommandV`) previously
/// used a hardcoded `CGKeyCode(9)` — the ANSI position of "V" on a US QWERTY
/// keyboard. On AZERTY, Dvorak, Colemak, and every other non-QWERTY layout,
/// keycode 9 lands on a different character, so ⌘+that-key fires the wrong
/// shortcut in the frontmost app (or silently pastes nothing).
///
/// This resolver walks every keycode against the *current* keyboard layout via
/// `UCKeyTranslate` (from TIS / Core Services) and finds the one that produces
/// the requested character. Result is cached; the cache invalidates when the
/// user changes input source via
/// `kTISNotifySelectedKeyboardInputSourceChanged`.
enum KeycodeLookup {

    private static let lock = NSLock()
    private static var cache: [Character: CGKeyCode] = [:]
    private static var observerInstalled = false

    /// Returns the virtual keycode that produces `character` on the current
    /// keyboard layout, or `nil` if no keycode maps to it (which means auto-paste
    /// should fall back to the hardcoded ANSI keycode).
    static func virtualKeyCode(for character: Character) -> CGKeyCode? {
        installObserverIfNeeded()

        lock.lock()
        if let cached = cache[character] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let resolved = resolveUncached(character) else { return nil }

        lock.lock()
        cache[character] = resolved
        lock.unlock()
        return resolved
    }

    /// Drop the cache — called when the active keyboard input source changes.
    static func invalidateCache() {
        lock.lock()
        cache.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    // MARK: - Internals

    /// Walk every keycode 0..<128 through UCKeyTranslate; return the first one
    /// that produces `character` with no modifiers.
    private static func resolveUncached(_ character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        let target = String(character)

        return layoutData.withUnsafeBytes { rawBuf -> CGKeyCode? in
            guard let base = rawBuf.baseAddress else { return nil }
            let keyLayoutPtr = base.assumingMemoryBound(to: UCKeyboardLayout.self)

            var deadKeyState: UInt32 = 0
            let maxLen = 4
            var actualLen = 0
            var chars = [UniChar](repeating: 0, count: maxLen)

            for keyCode in 0..<128 {
                deadKeyState = 0
                let status = UCKeyTranslate(
                    keyLayoutPtr,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0, // no modifiers
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    maxLen,
                    &actualLen,
                    &chars
                )
                guard status == noErr, actualLen > 0 else { continue }
                let produced = String(utf16CodeUnits: chars, count: actualLen)
                if produced == target {
                    return CGKeyCode(keyCode)
                }
            }
            return nil
        }
    }

    /// Register once for keyboard-input-source-changed notifications so the
    /// cache stays coherent when the user switches layout.
    private static func installObserverIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !observerInstalled else { return }
        observerInstalled = true

        let name = kTISNotifySelectedKeyboardInputSourceChanged as CFString
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            KeycodeLookup.invalidateCache()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            nil,
            callback,
            name,
            nil,
            .deliverImmediately
        )
    }
}
