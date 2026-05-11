import Foundation
import NaturalLanguage

/// On-device sentence embedder backed by Apple's `NLEmbedding`.
/// Output vectors are L2-normalized, so cosine similarity == dot product.
final class Embedder {

    static let shared = Embedder()

    private let embedding: NLEmbedding?
    private let queue = DispatchQueue(label: "clipmate.embedder", qos: .utility)

    /// Cap input length to keep embedding latency tight and avoid wasting tokens on huge clips.
    private let maxChars = 2000

    private init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var isAvailable: Bool { embedding != nil }
    var dimension: Int { embedding?.dimension ?? 0 }

    /// Synchronous embed. Returns nil if NLEmbedding isn't available or returns no vector.
    func embed(_ text: String) -> [Float]? {
        guard let model = embedding else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let input = trimmed.count > maxChars
            ? String(trimmed.prefix(maxChars))
            : trimmed
        guard let dv = model.vector(for: input) else { return nil }
        return Self.normalize(dv.map { Float($0) })
    }

    /// Batch embed for backfill, off the main queue.
    func embedAsync(_ text: String, completion: @escaping ([Float]?) -> Void) {
        queue.async { [weak self] in
            let v = self?.embed(text)
            DispatchQueue.main.async { completion(v) }
        }
    }

    /// L2-normalize so cosine(a,b) == dot(a,b).
    static func normalize(_ v: [Float]) -> [Float] {
        var sum: Float = 0
        for x in v { sum += x * x }
        let n = sum.squareRoot()
        guard n > 1e-12 else { return v }
        return v.map { $0 / n }
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var s: Float = 0
        for i in 0..<a.count { s += a[i] * b[i] }
        return s
    }
}
