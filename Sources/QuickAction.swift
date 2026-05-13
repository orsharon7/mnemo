import Foundation
import AppKit

/// Type-aware "open" action triggered by ⌘O on the selected clip.
enum QuickAction {

    /// Footer hint string, or nil if no quick action applies.
    static func label(for entry: ClipEntry) -> String? {
        switch entry.type {
        case .url:
            // Only show the hint when ⌘O will actually open the URL (http/https or bare host).
            // For URLs with an explicit non-http(s) scheme (e.g. file:, mailto:) the action
            // is a no-op, so suppress the label to avoid a misleading hint.
            let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
                guard scheme == "http" || scheme == "https" else { return nil }
            }
            return "⌘O open URL"
        case .email: return "⌘O compose"
        case .json:  return "⌘O preview"
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
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return NSWorkspace.shared.open(url)
            }
            // Fall back to a https:// prefix only for bare hosts (no explicit scheme).
            // If the string already has an explicit non-http(s) scheme, treat as no-op.
            let hasExplicitScheme = trimmed.contains("://") || trimmed.hasPrefix("//")
            if !hasExplicitScheme, let url = URL(string: "https://" + trimmed) {
                return NSWorkspace.shared.open(url)
            }
            return false
        case .email:
            if let url = URL(string: "mailto:" + trimmed) {
                return NSWorkspace.shared.open(url)
            }
            return false
        case .json, .code, .multiline, .text:
            // JSON: caller should open Quick Look preview (rendered with monospaced body).
            // Other types have no external opener.
            return false
        }
    }
}
