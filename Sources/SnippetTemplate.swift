import Foundation

struct SnippetPlaceholder: Equatable, Hashable {
    let name: String
    let defaultValue: String?
}

/// Parses and fills `{{name}}` / `{{name:default}}` placeholders in a snippet template.
/// Names accept letters, digits, underscore, hyphen, and internal spaces; surrounding
/// whitespace is trimmed. Defaults run from the first `:` to the closing `}}`.
enum SnippetTemplate {
    static let pattern: NSRegularExpression = {
        // {{ name }} or {{ name : default value }} — default may contain anything except '}'.
        try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9_\- ]+?)\s*(?::([^}]*))?\}\}"#)
    }()

    static func hasPlaceholders(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.firstMatch(in: text, range: range) != nil
    }

    /// Ordered, de-duplicated by name (first occurrence wins, including its default).
    static func placeholders(in text: String) -> [SnippetPlaceholder] {
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<String>()
        var out: [SnippetPlaceholder] = []
        for m in pattern.matches(in: text, range: range) {
            guard let nameR = Range(m.range(at: 1), in: text) else { continue }
            let name = String(text[nameR]).trimmingCharacters(in: .whitespaces)
            if name.isEmpty || seen.contains(name) { continue }
            seen.insert(name)
            var def: String? = nil
            let defRange = m.range(at: 2)
            if defRange.location != NSNotFound, let r = Range(defRange, in: text) {
                def = String(text[r])
            }
            out.append(SnippetPlaceholder(name: name, defaultValue: def))
        }
        return out
    }

    /// Replaces every occurrence with `values[name]`, falling back to the placeholder's
    /// default (when the supplied value is missing or empty), then to an empty string.
    static func fill(_ text: String, with values: [String: String]) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, range: range)
        guard !matches.isEmpty else { return text }
        let ms = NSMutableString(string: text)
        for m in matches.reversed() {
            guard let nameR = Range(m.range(at: 1), in: text) else { continue }
            let name = String(text[nameR]).trimmingCharacters(in: .whitespaces)
            var def: String? = nil
            let defRange = m.range(at: 2)
            if defRange.location != NSNotFound, let r = Range(defRange, in: text) {
                def = String(text[r])
            }
            let supplied = values[name] ?? ""
            let replacement = supplied.isEmpty ? (def ?? "") : supplied
            ms.replaceCharacters(in: m.range, with: replacement)
        }
        return ms as String
    }
}
