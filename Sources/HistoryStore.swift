import Foundation
import AppKit
import Combine

struct ClipEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var contentHash: String
    var sourceBundle: String?
    var sourceName: String?
    var createdAt: Date
    var lastUsedAt: Date
    var truncated: Bool
    var isPinned: Bool
    var type: ClipEntryType
    var vector: [Float]?

    init(id: UUID, content: String, contentHash: String,
         sourceBundle: String?, sourceName: String?,
         createdAt: Date, lastUsedAt: Date,
         truncated: Bool, isPinned: Bool = false,
         type: ClipEntryType = .text,
         vector: [Float]? = nil) {
        self.id = id; self.content = content; self.contentHash = contentHash
        self.sourceBundle = sourceBundle; self.sourceName = sourceName
        self.createdAt = createdAt; self.lastUsedAt = lastUsedAt
        self.truncated = truncated; self.isPinned = isPinned; self.type = type
        self.vector = vector
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, contentHash, sourceBundle, sourceName,
             createdAt, lastUsedAt, truncated, isPinned, type, vector
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        contentHash = try c.decode(String.self, forKey: .contentHash)
        sourceBundle = try c.decodeIfPresent(String.self, forKey: .sourceBundle)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try c.decode(Date.self, forKey: .lastUsedAt)
        truncated = try c.decode(Bool.self, forKey: .truncated)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        type = try c.decodeIfPresent(ClipEntryType.self, forKey: .type) ?? .text
        vector = try c.decodeIfPresent([Float].self, forKey: .vector)
    }
}

final class HistoryStore: ObservableObject {

    static let maxBytes = 1 * 1024 * 1024
    static let defaultMaxEntries = 2000
    static let defaultRetentionDays = 30

    @Published private(set) var entries: [ClipEntry] = []
    @Published var captureEnabled: Bool = true

    private var maxEntries: Int = defaultMaxEntries
    private var retentionDays: Int = defaultRetentionDays

    private let dbURL: URL
    private let queue = DispatchQueue(label: "mnemo.store", qos: .utility)
    private var settingsObservers: [NSObjectProtocol] = []

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Mnemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        self.dbURL = dir.appendingPathComponent("history.json")
        load()
        backfillVectorsIfNeeded()
    }

    /// Embed entries missing vectors after schema upgrade or model becoming available.
    private func backfillVectorsIfNeeded() {
        guard Embedder.shared.isAvailable else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // Snapshot ids+contents to avoid mutating the array under us.
            let snapshot: [(UUID, String)] = DispatchQueue.main.sync {
                self.entries.filter { $0.vector == nil }.map { ($0.id, $0.content) }
            }
            guard !snapshot.isEmpty else { return }
            var batch: [(UUID, [Float])] = []
            for (id, text) in snapshot {
                if let v = Embedder.shared.embed(text) {
                    batch.append((id, v))
                }
                if batch.count >= 50 {
                    self.applyBackfill(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }
            if !batch.isEmpty { self.applyBackfill(batch) }
        }
    }

    private func applyBackfill(_ batch: [(UUID, [Float])]) {
        DispatchQueue.main.async {
            var dirty = false
            for (id, v) in batch {
                if let idx = self.entries.firstIndex(where: { $0.id == id }), self.entries[idx].vector == nil {
                    self.entries[idx].vector = v
                    dirty = true
                }
            }
            if dirty { self.persistAsync() }
        }
    }

    func add(text rawText: String, sourceBundle: String?, sourceName: String?) {
        var text = rawText
        var truncated = false
        if text.utf8.count > Self.maxBytes {
            let data = Data(text.utf8).prefix(Self.maxBytes)
            text = String(data: data, encoding: .utf8) ?? String(text.prefix(Self.maxBytes / 4))
            truncated = true
        }

        let hash = sha256(text)
        let detectedType = TypeDetector.detect(text)
        let vector = Embedder.shared.embed(text)
        DispatchQueue.main.async {
            if let idx = self.entries.firstIndex(where: { $0.contentHash == hash }) {
                // Preserve pin state on dedupe; refresh recency.
                var existing = self.entries.remove(at: idx)
                existing.lastUsedAt = Date()
                if existing.vector == nil { existing.vector = vector }
                self.insertSorted(existing)
            } else {
                let entry = ClipEntry(id: UUID(),
                                      content: text,
                                      contentHash: hash,
                                      sourceBundle: sourceBundle,
                                      sourceName: sourceName,
                                      createdAt: Date(),
                                      lastUsedAt: Date(),
                                      truncated: truncated,
                                      isPinned: false,
                                      type: detectedType,
                                      vector: vector)
                self.insertSorted(entry)
            }
            self.applyRetention()
            self.persistAsync()
        }
    }

    /// Insert keeping pinned-first ordering, recency within each group.
    private func insertSorted(_ entry: ClipEntry) {
        entries.insert(entry, at: 0)
        entries.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
    }

    func togglePin(_ entry: ClipEntry) {
        DispatchQueue.main.async {
            guard let idx = self.entries.firstIndex(where: { $0.id == entry.id }) else { return }
            self.entries[idx].isPinned.toggle()
            // Re-sort to surface/demote.
            self.entries.sort { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.lastUsedAt > rhs.lastUsedAt
            }
            self.persistAsync()
        }
    }

    /// Single source-of-truth operator table.
    /// Each entry maps the operator token (lowercased, with leading "/") to either
    /// a `ClipEntryType` filter or `nil` for special-purpose operators (/pin).
    private static let operatorTable: [(token: String, type: ClipEntryType?)] = [
        ("/url",       .url),
        ("/json",      .json),
        ("/code",      .code),
        ("/email",     .email),
        ("/text",      .text),
        ("/multiline", .multiline),
        ("/pin",       nil),
    ]

    /// Regex derived from `operatorTable`; compiled once at class load time.
    /// Matches an operator token preceded by start-of-string or whitespace (group 1),
    /// followed by a non-newline space/tab, a newline boundary lookahead, or end-of-string.
    private static let operatorRegex: NSRegularExpression = {
        let alternation = operatorTable.map { NSRegularExpression.escapedPattern(for: $0.token) }.joined(separator: "|")
        let pattern = "(?i)(^|\\s)(\(alternation))(?:[ \\t]|(?=[\\r\\n])|$)"
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// Trailing-whitespace-before-newline cleanup regex; removes spaces/tabs that
    /// operator stripping can leave immediately before a newline.
    private static let trailingSpaceBeforeNewlineRegex = try! NSRegularExpression(
        pattern: "[ \\t]+(?=\\r?\\n)"
    )

    /// Parse search operators from the query string.
    /// Returns `(types: Set<ClipEntryType>, pinOnly: Bool, text: String)` where
    /// `types` is the set of type filters, `pinOnly` indicates the /pin operator was present,
    /// and `text` is the remaining free-text query with operators stripped.
    /// Internal whitespace (including newlines) is preserved so multi-line snippet searches
    /// match correctly; leading/trailing whitespace is trimmed by the caller before matching.
    private static func parseOperators(_ q: String) -> (types: Set<ClipEntryType>, pinOnly: Bool, text: String) {
        var types: Set<ClipEntryType> = []
        var pinOnly = false
        // Tokenize only to identify operators; do NOT re-join tokens (that would collapse \n → space).
        let tokens = q.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        for token in tokens {
            if let entry = operatorTable.first(where: { $0.token == token.lowercased() }) {
                if let t = entry.type { types.insert(t) } else { pinOnly = true }
            }
        }
        // Remove operator tokens from the original string, preserving all internal whitespace,
        // so multi-line free-text queries (e.g. "a\nb") are not collapsed to "a b".
        // Replacing with $1 can leave a trailing space/tab before a newline when the operator
        // was "word /op\nnextword" — clean that up so multi-line substring matches still work.
        let range = NSRange(q.startIndex..., in: q)
        var freeText = Self.operatorRegex.stringByReplacingMatches(in: q, range: range, withTemplate: "$1")
        let freeRange = NSRange(freeText.startIndex..., in: freeText)
        freeText = Self.trailingSpaceBeforeNewlineRegex.stringByReplacingMatches(
            in: freeText, range: freeRange, withTemplate: ""
        )
        return (types, pinOnly, freeText)
    }

    func search(_ q: String) -> [ClipEntry] {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return entries }

        let (typeFilters, pinOnly, freeText) = Self.parseOperators(trimmed)
        let freeTextTrimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)

        var pool = entries
        if !typeFilters.isEmpty { pool = pool.filter { typeFilters.contains($0.type) } }
        if pinOnly            { pool = pool.filter { $0.isPinned } }

        if freeTextTrimmed.isEmpty { return pool }

        let needle = freeTextTrimmed.lowercased()

        let substring = pool.filter { $0.content.lowercased().contains(needle) }

        let useSemantic = Settings.shared.semanticSearchEnabled
            && Embedder.shared.isAvailable
            && freeTextTrimmed.count >= 3

        if useSemantic, let qv = Embedder.shared.embed(freeTextTrimmed) {
            let threshold: Float = 0.30
            var scored: [(ClipEntry, Float)] = []
            scored.reserveCapacity(pool.count)
            let substringIDs = Set(substring.map { $0.id })
            for e in pool {
                guard let v = e.vector, !substringIDs.contains(e.id) else { continue }
                let s = Embedder.cosine(qv, v)
                if s >= threshold { scored.append((e, s)) }
            }
            scored.sort { $0.1 > $1.1 }
            let semantic = scored.prefix(10).map { $0.0 }
            let merged = substring + semantic
            return Self.stableSortPinnedFirst(merged)
        }

        if !substring.isEmpty || needle.count < 2 {
            return Self.stableSortPinnedFirst(substring)
        }
        let fuzzy = pool.filter { Self.isSubsequence(needle, of: $0.content.lowercased()) }
        return Self.stableSortPinnedFirst(fuzzy)
    }

    private static func stableSortPinnedFirst(_ list: [ClipEntry]) -> [ClipEntry] {
        let pinned = list.filter { $0.isPinned }
        let rest = list.filter { !$0.isPinned }
        return pinned + rest
    }

    private static func isSubsequence(_ needle: String, of hay: String) -> Bool {
        var ni = needle.startIndex
        for ch in hay {
            if ni == needle.endIndex { return true }
            if ch == needle[ni] { ni = needle.index(after: ni) }
        }
        return ni == needle.endIndex
    }

    func useEntry(_ entry: ClipEntry) {
        DispatchQueue.main.async {
            if let idx = self.entries.firstIndex(where: { $0.id == entry.id }) {
                var e = self.entries.remove(at: idx)
                e.lastUsedAt = Date()
                self.insertSorted(e)
                self.persistAsync()
            }
        }
    }

    func deleteEntry(_ entry: ClipEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.id == entry.id }
            self.persistAsync()
        }
    }

    func clearAll() {
        DispatchQueue.main.async {
            // Preserve pinned entries through Clear All (Alfred behavior).
            self.entries.removeAll { !$0.isPinned }
            self.persistAsync()
        }
    }

    /// Pull the current limits from Settings and apply retention immediately.
    func applySettings() {
        let s = Settings.shared
        self.maxEntries = max(100, s.maxEntries)
        self.retentionDays = max(1, s.retentionDays)
        DispatchQueue.main.async {
            self.applyRetention()
            self.persistAsync()
        }
    }

    private func applyRetention() {
        // Pinned entries are immune to both cap and age-out.
        let pinned = entries.filter { $0.isPinned }
        var unpinned = entries.filter { !$0.isPinned }
        let cutoff = Date().addingTimeInterval(-TimeInterval(retentionDays * 24 * 3600))
        if unpinned.count > maxEntries / 2 {
            unpinned.removeAll { $0.lastUsedAt < cutoff }
        }
        let unpinnedCap = max(0, maxEntries - pinned.count)
        if unpinned.count > unpinnedCap {
            unpinned = Array(unpinned.prefix(unpinnedCap))
        }
        entries = pinned + unpinned
        entries.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
    }

    private func persistAsync() {
        let snapshot = entries
        let url = dbURL
        queue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: [.atomic])
                try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                       ofItemAtPath: url.path)
            } catch {
                NSLog("Mnemo persist error: \(error)")
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: dbURL) else { return }
        if let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) {
            self.entries = decoded
        }
    }

    private func sha256(_ s: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
