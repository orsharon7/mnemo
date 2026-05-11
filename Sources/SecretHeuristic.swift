import Foundation

/// Heuristic detector for "this copy probably contains a secret".
/// Conservative — we'd rather miss a few than capture an API key.
enum SecretHeuristic {

    /// Common API key / token prefixes — substring match (case-sensitive where the real key is).
    private static let prefixes: [String] = [
        "sk-",            // OpenAI
        "sk_live_", "sk_test_", // Stripe
        "pk_live_", "pk_test_",
        "rk_live_", "rk_test_",
        "ghp_", "gho_", "ghs_", "ghu_", "ghr_", // GitHub
        "github_pat_",
        "xoxb-", "xoxp-", "xoxa-", "xoxr-", "xoxs-", // Slack
        "AKIA", "ASIA",   // AWS access keys
        "AIza",           // Google API
        "ya29.",          // Google OAuth
        "eyJ",            // JWT header b64 ({"alg)
        "-----BEGIN ",    // PEM block
        "glpat-",         // GitLab PAT
        "npm_",           // npm token
        "dop_v1_",        // DigitalOcean
        "shpat_", "shpss_", "shpca_", "shppa_"  // Shopify
    ]

    static func looksLikeSecret(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // PEM blocks / known prefixes win immediately.
        for p in prefixes {
            if trimmed.hasPrefix(p) || trimmed.contains("\n" + p) {
                return true
            }
        }

        // Multiline / very short strings: probably not a secret token blob.
        if trimmed.contains("\n") { return false }
        if trimmed.count < 24 { return false }
        if trimmed.count > 4096 { return false }
        if trimmed.contains(" ") { return false }

        // High-entropy heuristic: alnum/symbol token-ish + shannon entropy > 4.2
        // Token-ish = mostly base64/hex/url-safe chars.
        let tokenSet: Set<Character> = Set(
            "abcdefghijklmnopqrstuvwxyz" +
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
            "0123456789" +
            "-_.+/=:"
        )
        let tokenLike = trimmed.allSatisfy { tokenSet.contains($0) }
        guard tokenLike else { return false }

        let hasUpper = trimmed.contains { $0.isUppercase }
        let hasLower = trimmed.contains { $0.isLowercase }
        let hasDigit = trimmed.contains { $0.isNumber }
        // Real secrets almost always mix at least 2 of these classes.
        let mixedClasses = [hasUpper, hasLower, hasDigit].filter { $0 }.count >= 2
        guard mixedClasses else { return false }

        let entropy = shannonEntropy(trimmed)
        return entropy >= 4.2
    }

    private static func shannonEntropy(_ s: String) -> Double {
        var counts: [Character: Int] = [:]
        for c in s { counts[c, default: 0] += 1 }
        let n = Double(s.count)
        var h = 0.0
        for (_, c) in counts {
            let p = Double(c) / n
            h -= p * log2(p)
        }
        return h
    }
}
