import Foundation
import AppKit

/// Type-aware "open" action triggered by ⌘O on the selected clip.
enum QuickAction {

    /// Returns true when `trimmed` is directly openable as-is, or can be opened
    /// with an https:// prefix. Protocol-relative strings (`//...`) are treated
    /// as https-prefixable and therefore openable.
    private static func isOpenable(_ trimmed: String) -> Bool {
        // Already has an explicit scheme (http, https, ftp, file, mailto, …) — openable directly.
        if let url = URL(string: trimmed), url.scheme != nil {
            return true
        }
        // Protocol-relative (//example.com) — will be prefixed with https:.
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed) != nil
        }
        // Exception: host:port patterns like localhost:3000 or example.com:8080
        // should still fall through to the https fallback (not treated as explicit scheme).
        let isHostPort = trimmed.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9.\-]*:[0-9]+"#,
                                       options: .regularExpression) != nil
        let hasExplicitScheme = !isHostPort &&
            trimmed.range(of: #"^[a-zA-Z][a-zA-Z0-9+\-.]*:"#,
                          options: .regularExpression) != nil
        if hasExplicitScheme { return true }
        return URL(string: "https://" + trimmed) != nil
    }

    /// Footer hint string, or nil if no quick action applies.
    static func label(for entry: ClipEntry) -> String? {
        switch entry.type {
        case .url:
            let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isOpenable(trimmed) else { return nil }
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
            guard isOpenable(trimmed) else { return false }
            if let url = URL(string: trimmed), url.scheme != nil {
                return NSWorkspace.shared.open(url)
            }
            let prefixed = trimmed.hasPrefix("//") ? "https:" + trimmed : "https://" + trimmed
            if let url = URL(string: prefixed) {
                return NSWorkspace.shared.open(url)
            }
            return false
        case .email:
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = trimmed
            if let url = components.url {
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
