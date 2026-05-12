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
        DispatchQueue.main.async {
            if let idx = self.entries.firstIndex(where: { $0.contentHash == hash }) {
                var existing = self.entries.remove(at: idx)
                existing.lastUsedAt = Date()
                existing.copyCount += 1
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
            self.persistAsync()
        }
    }

    func search(_ q: String) -> [ClipEntry] {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return entries }
        let needle = trimmed.lowercased()

        let substring = entries.filter { $0.content.lowercased().contains(needle) }

        let useSemantic = Settings.shared.semanticSearchEnabled
            && Embedder.shared.isAvailable
            && trimmed.count >= 3

        if useSemantic, let qv = Embedder.shared.embed(trimmed) {
            // NLEmbedding sentence vectors run low; 0.30 is a reasonable signal floor
            // empirically. We cap top-K to keep noise out.
            let threshold: Float = 0.30
            var scored: [(ClipEntry, Float)] = []
            scored.reserveCapacity(entries.count)
            let substringIDs = Set(substring.map { $0.id })
            for e in entries {
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
        // Last resort: fuzzy subsequence.
        let fuzzy = entries.filter { Self.isSubsequence(needle, of: $0.content.lowercased()) }
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
        if var decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) {
            decoded = Self.collapseDuplicates(decoded)
            self.entries = decoded
        }
    }

    private static func collapseDuplicates(_ entries: [ClipEntry]) -> [ClipEntry] {
        var seen: [String: Int] = [:]
        var result: [ClipEntry] = []
        for entry in entries {
            if let existingIdx = seen[entry.contentHash] {
                var merged = result[existingIdx]
                merged.copyCount += entry.copyCount
                if entry.lastUsedAt > merged.lastUsedAt { merged.lastUsedAt = entry.lastUsedAt }
                if !merged.isPinned && entry.isPinned { merged.isPinned = true }
                if merged.vector == nil { merged.vector = entry.vector }
                result[existingIdx] = merged
            } else {
                seen[entry.contentHash] = result.count
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
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
