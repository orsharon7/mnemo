import Foundation
import AppKit

/// Type-aware "open" action triggered by ⌘O on the selected clip.
enum QuickAction {

    private static func isOpenable(_ trimmed: String) -> Bool {
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return true
        }
        // RFC-3986 scheme: letter followed by letters/digits/+/-/. then colon.
        // Catches mailto:, file:, tel:, ftp:, and // protocol-relative strings.
        // Exception: host:port patterns like localhost:3000 or example.com:8080
        // should still fall through to the https fallback.
        let isHostPort = trimmed.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9.\-]*:[0-9]+"#,
                                       options: .regularExpression) != nil
        let hasExplicitScheme = !isHostPort && (trimmed.hasPrefix("//") ||
            trimmed.range(of: #"^[a-zA-Z][a-zA-Z0-9+\-.]*:"#,
                          options: .regularExpression) != nil)
        if hasExplicitScheme { return false }
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
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return NSWorkspace.shared.open(url)
            }
            guard isOpenable(trimmed) else { return false }
            if let url = URL(string: "https://" + trimmed) {
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
