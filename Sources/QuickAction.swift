import Foundation
import AppKit

/// Type-aware "open" action triggered by ⌘O on the selected clip.
enum QuickAction {

    private static let browserSchemes: Set<String> = ["http", "https"]

    /// Returns true when `trimmed` is openable as an http/https URL (directly or
    /// via https:// prefix). Protocol-relative strings (`//...`) and bare host:port
    /// strings (e.g. `localhost:3000`) are treated as https-prefixable.
    private static func isOpenable(_ trimmed: String) -> Bool {
        // Detect host:port patterns (e.g. localhost:3000, example.com:8080) FIRST,
        // before URL(string:) can misidentify the host as a scheme.
        // The pre-colon token must look like a hostname: either "localhost", an IPv4
        // literal (digits and dots only), or a name containing at least one dot.
        // This prevents scheme-like strings (tel:123, mailto:25) from matching.
        let isHostPort = trimmed.range(
            of: #"^(localhost|[0-9]+(?:\.[0-9]+){3}|[a-zA-Z0-9][a-zA-Z0-9\-]*(?:\.[a-zA-Z0-9][a-zA-Z0-9\-]*)++):[0-9]+"#,
            options: .regularExpression) != nil
        if isHostPort {
            return URL(string: "https://" + trimmed) != nil
        }
        // Protocol-relative (//example.com) — will be prefixed with https:.
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed) != nil
        }
        // Explicit scheme: only allow http/https.
        if let url = URL(string: trimmed), let scheme = url.scheme {
            return browserSchemes.contains(scheme)
        }
        // Bare host (no scheme, no port) — try https:// prefix.
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
            if let url = URL(string: trimmed), let scheme = url.scheme, browserSchemes.contains(scheme) {
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
