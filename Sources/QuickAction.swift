import Foundation
import AppKit

/// Type-aware "open" action triggered by ⌘O on the selected clip.
enum QuickAction {

    /// Footer hint string, or nil if no quick action applies.
    static func label(for entry: ClipEntry) -> String? {
        switch entry.type {
        case .url:   return "⌘O open URL"
        case .email: return "⌘O compose"
        case .json:  return "⌘O format"
        default:     return nil
        }
    }

    /// Performs the quick action. Returns `true` if it was handled by an external
    /// launch (URL/email), `false` for in-app handling (JSON preview) or no-op.
    @discardableResult
    static func perform(for entry: ClipEntry) -> Bool {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        switch entry.type {
        case .url:
            if let url = URL(string: trimmed), url.scheme != nil {
                NSWorkspace.shared.open(url)
                return true
            }
            // Fall back to a https:// prefix for bare hosts that the type detector accepted.
            if let url = URL(string: "https://" + trimmed) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        case .email:
            if let url = URL(string: "mailto:" + trimmed) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        case .json, .code, .multiline, .text:
            // JSON: caller should open Quick Look preview (rendered with monospaced body).
            // Other types have no external opener.
            return false
        }
    }
}
