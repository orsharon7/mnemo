import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

/// User-facing settings, persisted to UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var hotkey: HotkeyConfig {
        didSet { persistHotkey() }
    }
    @Published var autoPasteOnEnter: Bool {
        didSet { defaults.set(autoPasteOnEnter, forKey: Keys.autoPaste) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LoginItem.setEnabled(launchAtLogin)
        }
    }
    @Published var maxEntries: Int {
        didSet { defaults.set(maxEntries, forKey: Keys.maxEntries) }
    }
    @Published var retentionDays: Int {
        didSet { defaults.set(retentionDays, forKey: Keys.retentionDays) }
    }
    @Published var blockLikelySecrets: Bool {
        didSet { defaults.set(blockLikelySecrets, forKey: Keys.blockSecrets) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }
    @Published var semanticSearchEnabled: Bool {
        didSet { defaults.set(semanticSearchEnabled, forKey: Keys.semanticSearch) }
    }
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }

    private init() {
        let keyCode = UInt32(defaults.object(forKey: Keys.hotkeyKeyCode) as? Int ?? kVK_ANSI_V)
        let mods = UInt32(defaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? Int(optionKey | cmdKey))
        self.hotkey = HotkeyConfig(keyCode: keyCode, modifiers: mods)

        self.autoPasteOnEnter = defaults.object(forKey: Keys.autoPaste) as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.maxEntries = defaults.object(forKey: Keys.maxEntries) as? Int ?? 2000
        self.retentionDays = defaults.object(forKey: Keys.retentionDays) as? Int ?? 30
        self.blockLikelySecrets = defaults.object(forKey: Keys.blockSecrets) as? Bool ?? true
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.onboarded) as? Bool ?? false
        self.semanticSearchEnabled = defaults.object(forKey: Keys.semanticSearch) as? Bool ?? true
        self.excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? []
    }

    private func persistHotkey() {
        defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(Int(hotkey.modifiers), forKey: Keys.hotkeyModifiers)
    }

    private enum Keys {
        static let hotkeyKeyCode  = "hotkey.keyCode"
        static let hotkeyModifiers = "hotkey.modifiers"
        static let autoPaste = "autoPasteOnEnter"
        static let launchAtLogin = "launchAtLogin"
        static let maxEntries = "maxEntries"
        static let retentionDays = "retentionDays"
        static let blockSecrets = "blockLikelySecrets"
        static let onboarded = "hasCompletedOnboarding"
        static let semanticSearch = "semanticSearchEnabled"
        static let excludedBundleIDs = "excludedBundleIDs"
    }
}

struct HotkeyConfig: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier flags: cmdKey | optionKey | shiftKey | controlKey

    /// Human-readable for the Preferences UI.
    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += HotkeyConfig.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"; case kVK_ANSI_B: return "B"; case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"; case kVK_ANSI_E: return "E"; case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"; case kVK_ANSI_H: return "H"; case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"; case kVK_ANSI_K: return "K"; case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"; case kVK_ANSI_N: return "N"; case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"; case kVK_ANSI_Q: return "Q"; case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"; case kVK_ANSI_T: return "T"; case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"; case kVK_ANSI_W: return "W"; case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"; case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"; case kVK_ANSI_1: return "1"; case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"; case kVK_ANSI_4: return "4"; case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"; case kVK_ANSI_7: return "7"; case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space:  return "Space"
        case kVK_Return: return "↩"
        default:         return "?"
        }
    }

    /// Build from a `NSEvent` keyDown during recording.
    static func from(event: NSEvent) -> HotkeyConfig? {
        var mods: UInt32 = 0
        if event.modifierFlags.contains(.command)  { mods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option)   { mods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift)    { mods |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.control)  { mods |= UInt32(controlKey) }
        // require at least one modifier to be a sane global hotkey
        guard mods != 0 else { return nil }
        return HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: mods)
    }
}
