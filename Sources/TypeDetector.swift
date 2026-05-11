import Foundation

enum ClipEntryType: String, Codable {
    case text
    case url
    case email
    case json
    case code
    case multiline

    var badge: String? {
        switch self {
        case .url: return "URL"
        case .email: return "EMAIL"
        case .json: return "JSON"
        case .code: return "CODE"
        case .multiline: return "TEXT"
        case .text: return nil
        }
    }
}

enum TypeDetector {

    static func detect(_ raw: String) -> ClipEntryType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        // Single line URL/email checks first.
        if !trimmed.contains("\n") {
            if isEmail(trimmed) { return .email }
            if isURL(trimmed) { return .url }
        }

        if isJSON(trimmed) { return .json }
        if looksLikeCode(trimmed) { return .code }
        if trimmed.contains("\n") { return .multiline }
        return .text
    }

    private static func isURL(_ s: String) -> Bool {
        guard s.count <= 2048 else { return false }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(s.startIndex..., in: s)
        guard let match = detector?.firstMatch(in: s, options: [], range: range) else { return false }
        return match.range == range
    }

    private static func isEmail(_ s: String) -> Bool {
        guard s.count <= 320, s.contains("@") else { return false }
        // Re-use NSDataDetector via mailto detection on bare email is unreliable, do a simple shape check.
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isJSON(_ s: String) -> Bool {
        guard let first = s.first, (first == "{" || first == "[") else { return false }
        guard s.count >= 2, s.count <= 256 * 1024 else { return false }
        guard let data = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }

    private static func looksLikeCode(_ s: String) -> Bool {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return false }
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count
        if indented >= 2 { return true }
        // Common code-y punctuation density on a multiline blob.
        let codeChars = CharacterSet(charactersIn: "{};()=<>")
        var hits = 0
        for u in s.unicodeScalars { if codeChars.contains(u) { hits += 1 } }
        let density = Double(hits) / Double(max(1, s.count))
        return density > 0.04
    }
}
