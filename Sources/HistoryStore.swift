import Foundation
import AppKit
import Combine
import CryptoKit

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
    /// Number of times this content has been copied (≥ 1). Shown as a badge when > 1.
    var copyCount: Int

    init(id: UUID, content: String, contentHash: String,
         sourceBundle: String?, sourceName: String?,
         createdAt: Date, lastUsedAt: Date,
         truncated: Bool, isPinned: Bool = false,
         type: ClipEntryType = .text,
         vector: [Float]? = nil,
         copyCount: Int = 1) {
        self.id = id; self.content = content; self.contentHash = contentHash
        self.sourceBundle = sourceBundle; self.sourceName = sourceName
        self.createdAt = createdAt; self.lastUsedAt = lastUsedAt
        self.truncated = truncated; self.isPinned = isPinned; self.type = type
        self.vector = vector; self.copyCount = copyCount
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, contentHash, sourceBundle, sourceName,
             createdAt, lastUsedAt, truncated, isPinned, type, vector, copyCount
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
        copyCount = max(1, try c.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1)
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

    /// Legacy JSON file path; kept around for one-time migration into SQLite.
    private let legacyJSONURL: URL
    /// SQLite database path (`history.db`) — primary persistence as of #15.
    private let dbURL: URL
    private var sqlite: SQLiteStore?
    private let queue = DispatchQueue(label: "mnemo.store", qos: .utility)
    private var settingsObservers: [NSObjectProtocol] = []

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Mnemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        self.legacyJSONURL = dir.appendingPathComponent("history.json")
        self.dbURL = dir.appendingPathComponent("history.db")
        do {
            self.sqlite = try SQLiteStore(url: dbURL)
        } catch {
            NSLog("Mnemo SQLite open error: \(error). Falling back to in-memory only.")
            self.sqlite = nil
        }
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
            var updated: [ClipEntry] = []
            for (id, v) in batch {
                if let idx = self.entries.firstIndex(where: { $0.id == id }), self.entries[idx].vector == nil {
                    self.entries[idx].vector = v
                    updated.append(self.entries[idx])
                }
            }
            if !updated.isEmpty { self.persistUpsertMany(updated) }
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
        DispatchQueue.main.async {
            if let idx = self.entries.firstIndex(where: { $0.contentHash == hash && $0.content == text }) {
                var existing = self.entries.remove(at: idx)
                existing.lastUsedAt = Date()
                let (newCount, overflow) = existing.copyCount.addingReportingOverflow(1)
                existing.copyCount = overflow ? Int.max : newCount
                existing.sourceBundle = sourceBundle
                existing.sourceName = sourceName
                if existing.vector == nil {
                    existing.vector = Embedder.shared.embed(text)
                }
                self.insertSorted(existing)
            } else {
                let vector = Embedder.shared.embed(text)
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
            self.persistUpsert(self.entries[idx])
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
            return Self.rerankSemantic(needle,
                                       queryVector: qv,
                                       pool: pool,
                                       substringMatches: substring,
                                       now: Date())
        }

        if !substring.isEmpty || needle.count < 2 {
            return Self.stableSortPinnedFirst(substring)
        }
        let fuzzy = pool.filter { Self.isSubsequence(needle, of: $0.content.lowercased()) }
        return Self.stableSortPinnedFirst(fuzzy)
    }

    // MARK: - Semantic reranking

    /// Cosine threshold below which a candidate is dropped entirely.
    private static let semanticFloor: Float = 0.22
    /// Max semantic results returned (in addition to substring matches).
    private static let semanticTopK = 12
    /// Recency half-life in days for the recency boost.
    private static let recencyHalfLifeDays: Double = 7

    static func rerankSemantic(_: String,
                               queryVector: [Float],
                               pool: [ClipEntry],
                               substringMatches: [ClipEntry],
                               now: Date) -> [ClipEntry] {
        let substringIDs = Set(substringMatches.map { $0.id })

        var bundleCounts: [String: Int] = [:]
        for e in pool {
            if let b = e.sourceBundle { bundleCounts[b, default: 0] += 1 }
        }
        let maxBundleCount = max(1, bundleCounts.values.max() ?? 1)

        func combinedScore(_ e: ClipEntry, cosine: Float) -> Float {
            let ageDays = max(0, now.timeIntervalSince(e.lastUsedAt) / 86400)
            let recency = Float(pow(0.5, ageDays / recencyHalfLifeDays))
            let affinity: Float = {
                guard let b = e.sourceBundle, let c = bundleCounts[b] else { return 0 }
                return Float(c) / Float(maxBundleCount)
            }()
            return 0.70 * cosine + 0.20 * recency + 0.10 * affinity
        }

        let rankedSubstring = substringMatches
            .map { ($0, combinedScore($0, cosine: 1.0)) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        var semanticScored: [(entry: ClipEntry, score: Float)] = []
        semanticScored.reserveCapacity(pool.count - substringIDs.count)

        for e in pool where !substringIDs.contains(e.id) {
            guard let v = e.vector else { continue }
            let cosine = Embedder.cosine(queryVector, v)
            if cosine < semanticFloor { continue }
            semanticScored.append((e, combinedScore(e, cosine: cosine)))
        }

        semanticScored.sort { $0.score > $1.score }
        let rankedSemantic = semanticScored.prefix(semanticTopK).map { $0.entry }

        return stableSortPinnedFirst(rankedSubstring) + stableSortPinnedFirst(rankedSemantic)
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
                self.persistUpsert(e)
            }
        }
    }

    func deleteEntry(_ entry: ClipEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.id == entry.id }
            self.persistDelete(id: entry.id)
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
        guard let sqlite = sqlite else { return }
        queue.async {
            do {
                try sqlite.replaceAll(snapshot)
            } catch {
                NSLog("Mnemo SQLite persist error: \(error)")
            }
        }
    }

    private func persistUpsert(_ entry: ClipEntry) {
        guard let sqlite = sqlite else { return }
        queue.async {
            do { try sqlite.upsert(entry) }
            catch { NSLog("Mnemo SQLite upsert error: \(error)") }
        }
    }

    private func persistUpsertMany(_ entries: [ClipEntry]) {
        guard let sqlite = sqlite, !entries.isEmpty else { return }
        queue.async {
            do { try sqlite.upsertMany(entries) }
            catch { NSLog("Mnemo SQLite upsertMany error: \(error)") }
        }
    }

    private func persistDelete(id: UUID) {
        guard let sqlite = sqlite else { return }
        queue.async {
            do { try sqlite.delete(id: id) }
            catch { NSLog("Mnemo SQLite delete error: \(error)") }
        }
    }

    private func load() {
        // Preferred path: read from SQLite.
        if let sqlite = sqlite {
            do {
                var rows = try sqlite.loadAll()
                if rows.isEmpty,
                   sqlite.getMeta("migrated_from_json_at") == nil,
                   FileManager.default.fileExists(atPath: legacyJSONURL.path) {
                    // First launch after upgrade — import the legacy JSON, then keep a
                    // .bak copy of it for one version per the migration plan in #15.
                    rows = migrateLegacyJSONIntoSQLite()
                }
                let collapsed = Self.collapseDuplicates(rows)
                self.entries = collapsed
                if collapsed.count != rows.count {
                    // Dedupe trimmed something — push the cleaned set back to SQLite.
                    persistAsync()
                }
                return
            } catch {
                NSLog("Mnemo SQLite load error: \(error). Falling back to JSON.")
            }
        }
        // Fallback: legacy JSON path (used only if SQLite is unavailable, e.g. open failed).
        loadFromLegacyJSON()
    }

    /// Reads `history.json` (if present), normalizes it (legacy hash recompute + dedupe),
    /// writes everything into SQLite in a single transaction, then renames the JSON file
    /// to `history.json.bak` so the next launch goes through the SQLite-only path.
    @discardableResult
    private func migrateLegacyJSONIntoSQLite() -> [ClipEntry] {
        guard let sqlite = sqlite,
              let data = try? Data(contentsOf: legacyJSONURL),
              var decoded = try? JSONDecoder().decode([ClipEntry].self, from: data)
        else { return [] }

        let sha256Hex = CharacterSet(charactersIn: "0123456789abcdef")
        for i in decoded.indices {
            let h = decoded[i].contentHash
            if h.count != 64 || !h.unicodeScalars.allSatisfy({ sha256Hex.contains($0) }) {
                decoded[i].contentHash = sha256(decoded[i].content)
            }
        }
        let collapsed = Self.collapseDuplicates(decoded)
        do {
            try sqlite.replaceAll(collapsed)
            try sqlite.setMeta("migrated_from_json_at", String(Date().timeIntervalSince1970))
            // Rename rather than delete — keep a backup for one version, per the issue plan.
            let backup = legacyJSONURL.deletingLastPathComponent()
                .appendingPathComponent("history.json.bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: legacyJSONURL, to: backup)
            NSLog("Mnemo: migrated \(collapsed.count) entries from history.json to SQLite.")
        } catch {
            NSLog("Mnemo JSON→SQLite migration failed: \(error)")
        }
        return collapsed
    }

    /// Last-resort loader used only when SQLite couldn't be opened. Keeps the app usable
    /// (read-only persistence semantics, since persistAsync is a no-op without SQLite).
    private func loadFromLegacyJSON() {
        let bakURL = legacyJSONURL.deletingLastPathComponent()
            .appendingPathComponent("history.json.bak")
        let url = FileManager.default.fileExists(atPath: legacyJSONURL.path) ? legacyJSONURL : bakURL
        guard let data = try? Data(contentsOf: url),
              var decoded = try? JSONDecoder().decode([ClipEntry].self, from: data)
        else { return }
        let sha256Hex = CharacterSet(charactersIn: "0123456789abcdef")
        for i in decoded.indices {
            let h = decoded[i].contentHash
            if h.count != 64 || !h.unicodeScalars.allSatisfy({ sha256Hex.contains($0) }) {
                decoded[i].contentHash = sha256(decoded[i].content)
            }
        }
        self.entries = Self.collapseDuplicates(decoded)
    }

    private static func collapseDuplicates(_ entries: [ClipEntry]) -> [ClipEntry] {
        // Key on (contentHash, content) pair to avoid false merges from hash collisions.
        var seen: [String: Int] = [:]
        var result: [ClipEntry] = []
        for entry in entries {
            let dedupeKey = entry.contentHash + "\0" + entry.content
            if let existingIdx = seen[dedupeKey] {
                var merged = result[existingIdx]
                let (newCount, overflow) = merged.copyCount.addingReportingOverflow(entry.copyCount)
                merged.copyCount = overflow ? Int.max : newCount
                if entry.lastUsedAt > merged.lastUsedAt {
                    merged.lastUsedAt = entry.lastUsedAt
                    merged.sourceBundle = entry.sourceBundle
                    merged.sourceName = entry.sourceName
                    merged.isPinned = entry.isPinned
                }
                if merged.vector == nil { merged.vector = entry.vector }
                result[existingIdx] = merged
            } else {
                seen[dedupeKey] = result.count
                result.append(entry)
            }
        }
        result.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
        return result
    }

    private func sha256(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
