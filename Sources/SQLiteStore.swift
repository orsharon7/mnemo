import Foundation
import SQLite3

/// Thin wrapper around the system `sqlite3` dylib. No SwiftPM dependency.
///
/// Schema (v1):
///
///   CREATE TABLE entries (
///     id            TEXT PRIMARY KEY,           -- UUID string
///     content       TEXT NOT NULL,
///     content_hash  TEXT NOT NULL,
///     source_bundle TEXT,
///     source_name   TEXT,
///     created_at    REAL NOT NULL,              -- Unix epoch seconds
///     last_used_at  REAL NOT NULL,
///     truncated     INTEGER NOT NULL,           -- 0/1
///     is_pinned     INTEGER NOT NULL,           -- 0/1
///     type          TEXT NOT NULL,
///     vector        BLOB,                       -- Float32 LE, length = 4*dim
///     copy_count    INTEGER NOT NULL DEFAULT 1
///   );
///
///   CREATE VIRTUAL TABLE entries_fts USING fts5(
///     content, content='entries', content_rowid='rowid'
///   );
///
///   CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
///
/// All multi-row writes are wrapped in `BEGIN IMMEDIATE` / `COMMIT`.
final class SQLiteStore {

    enum SQLiteError: Error, CustomStringConvertible {
        case open(String)
        case prepare(String)
        case step(String)
        case exec(String)
        var description: String {
            switch self {
            case .open(let m), .prepare(let m), .step(let m), .exec(let m): return m
            }
        }
    }

    static let schemaVersion = 1

    let url: URL
    private var db: OpaquePointer?

    init(url: URL) throws {
        self.url = url
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle = handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 rc=\(rc)"
            if let h = handle { sqlite3_close(h) }
            throw SQLiteError.open(msg)
        }
        self.db = handle
        // 0600 perms on the file (and -wal/-shm best-effort once they exist).
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")
        try migrate()
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - Schema

    private func migrate() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
            """)
        try exec("""
            CREATE TABLE IF NOT EXISTS entries (
                id            TEXT PRIMARY KEY,
                content       TEXT NOT NULL,
                content_hash  TEXT NOT NULL,
                source_bundle TEXT,
                source_name   TEXT,
                created_at    REAL NOT NULL,
                last_used_at  REAL NOT NULL,
                truncated     INTEGER NOT NULL,
                is_pinned     INTEGER NOT NULL,
                type          TEXT NOT NULL,
                vector        BLOB,
                copy_count    INTEGER NOT NULL DEFAULT 1
            );
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_entries_last_used ON entries(last_used_at DESC);")
        try exec("CREATE INDEX IF NOT EXISTS idx_entries_pinned ON entries(is_pinned, last_used_at DESC);")
        try exec("CREATE INDEX IF NOT EXISTS idx_entries_hash ON entries(content_hash);")

        // FTS5 on content. We use external content table=entries so we don't double-store the text.
        try exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
                content, content='entries', content_rowid='rowid', tokenize='unicode61'
            );
            """)
        // Triggers keep entries_fts in sync with entries.
        try exec("""
            CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
                INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
            END;
            """)
        try exec("""
            CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
                INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
            END;
            """)
        try exec("""
            CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
                INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
                INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
            END;
            """)

        try setMeta("schema_version", String(Self.schemaVersion))
    }

    // MARK: - Public CRUD

    /// Load every entry, ordered for the UI (pinned first, then most-recent).
    func loadAll() throws -> [ClipEntry] {
        let sql = """
            SELECT id, content, content_hash, source_bundle, source_name,
                   created_at, last_used_at, truncated, is_pinned, type, vector, copy_count
            FROM entries
            ORDER BY is_pinned DESC, last_used_at DESC;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            throw SQLiteError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        var result: [ClipEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = Self.readEntry(stmt) { result.append(entry) }
        }
        return result
    }

    /// Insert or replace a single entry. Wrapped in an implicit transaction.
    func upsert(_ entry: ClipEntry) throws {
        try inTransaction { try self.upsertNoTx(entry) }
    }

    /// Insert or replace many entries in a single transaction (much faster).
    func upsertMany(_ entries: [ClipEntry]) throws {
        try inTransaction {
            for entry in entries { try self.upsertNoTx(entry) }
        }
    }

    /// Replace the full entry set atomically (delete-then-insert in one txn).
    /// Used by HistoryStore after retention/clear-all/dedup operations to keep
    /// the on-disk state in lock-step with the in-memory `entries` array.
    func replaceAll(_ entries: [ClipEntry]) throws {
        try inTransaction {
            try self.execNoTx("DELETE FROM entries;")
            for entry in entries { try self.upsertNoTx(entry) }
        }
    }

    func delete(id: UUID) throws {
        try inTransaction {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM entries WHERE id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
                throw SQLiteError.prepare(self.lastErrorMessage())
            }
            defer { sqlite3_finalize(stmt) }
            _ = id.uuidString.withCString { sqlite3_bind_text(stmt, 1, $0, -1, Self.SQLITE_TRANSIENT) }
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw SQLiteError.step(self.lastErrorMessage())
            }
        }
    }

    /// Returns rowids matching an FTS5 query. Caller is responsible for mapping back to ids.
    /// Used as a future hook; current HistoryStore search still goes through the in-memory pool
    /// because the semantic+recency+affinity ranker needs the full ClipEntry.
    func ftsRowidMatches(_ query: String, limit: Int = 200) throws -> [Int64] {
        let sql = "SELECT rowid FROM entries_fts WHERE entries_fts MATCH ? ORDER BY rank LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            throw SQLiteError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        _ = query.withCString { sqlite3_bind_text(stmt, 1, $0, -1, Self.SQLITE_TRANSIENT) }
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var ids: [Int64] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(sqlite3_column_int64(stmt, 0))
        }
        return ids
    }

    // MARK: - Meta

    func getMeta(_ key: String) -> String? {
        let sql = "SELECT value FROM meta WHERE key = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        _ = key.withCString { sqlite3_bind_text(stmt, 1, $0, -1, Self.SQLITE_TRANSIENT) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cstr)
    }

    func setMeta(_ key: String, _ value: String) throws {
        let sql = "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            throw SQLiteError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        _ = key.withCString   { sqlite3_bind_text(stmt, 1, $0, -1, Self.SQLITE_TRANSIENT) }
        _ = value.withCString { sqlite3_bind_text(stmt, 2, $0, -1, Self.SQLITE_TRANSIENT) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SQLiteError.step(lastErrorMessage()) }
    }

    // MARK: - Internals

    /// SQLite "transient" sentinel — make a copy of bound bytes. SQLITE_TRANSIENT is a macro
    /// in C that evaluates to (sqlite3_destructor_type)-1, which doesn't import into Swift, so
    /// we reconstruct it here.
    static let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

    private func inTransaction(_ body: () throws -> Void) throws {
        try execNoTx("BEGIN IMMEDIATE;")
        do {
            try body()
            try execNoTx("COMMIT;")
        } catch {
            try? execNoTx("ROLLBACK;")
            throw error
        }
    }

    private func upsertNoTx(_ entry: ClipEntry) throws {
        let sql = """
            INSERT INTO entries
              (id, content, content_hash, source_bundle, source_name,
               created_at, last_used_at, truncated, is_pinned, type, vector, copy_count)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
              content       = excluded.content,
              content_hash  = excluded.content_hash,
              source_bundle = excluded.source_bundle,
              source_name   = excluded.source_name,
              created_at    = excluded.created_at,
              last_used_at  = excluded.last_used_at,
              truncated     = excluded.truncated,
              is_pinned     = excluded.is_pinned,
              type          = excluded.type,
              vector        = excluded.vector,
              copy_count    = excluded.copy_count;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            throw SQLiteError.prepare(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        _ = entry.id.uuidString.withCString { sqlite3_bind_text(stmt, 1, $0, -1, Self.SQLITE_TRANSIENT) }
        _ = entry.content.withCString       { sqlite3_bind_text(stmt, 2, $0, -1, Self.SQLITE_TRANSIENT) }
        _ = entry.contentHash.withCString   { sqlite3_bind_text(stmt, 3, $0, -1, Self.SQLITE_TRANSIENT) }
        if let b = entry.sourceBundle {
            _ = b.withCString { sqlite3_bind_text(stmt, 4, $0, -1, Self.SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        if let n = entry.sourceName {
            _ = n.withCString { sqlite3_bind_text(stmt, 5, $0, -1, Self.SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_double(stmt, 6, entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, entry.lastUsedAt.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 8, entry.truncated ? 1 : 0)
        sqlite3_bind_int(stmt, 9, entry.isPinned ? 1 : 0)
        _ = entry.type.rawValue.withCString { sqlite3_bind_text(stmt, 10, $0, -1, Self.SQLITE_TRANSIENT) }
        if let v = entry.vector, !v.isEmpty {
            let data = Self.encodeVector(v)
            _ = data.withUnsafeBytes { raw in
                sqlite3_bind_blob(stmt, 11, raw.baseAddress, Int32(data.count), Self.SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        sqlite3_bind_int64(stmt, 12, Int64(entry.copyCount))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.step(lastErrorMessage())
        }
    }

    private static func readEntry(_ stmt: OpaquePointer) -> ClipEntry? {
        guard let idCstr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idCstr)),
              let contentCstr = sqlite3_column_text(stmt, 1),
              let hashCstr = sqlite3_column_text(stmt, 2)
        else { return nil }

        let content      = String(cString: contentCstr)
        let contentHash  = String(cString: hashCstr)
        let sourceBundle = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let sourceName   = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let createdAt    = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        let lastUsedAt   = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
        let truncated    = sqlite3_column_int(stmt, 7) != 0
        let isPinned     = sqlite3_column_int(stmt, 8) != 0
        let typeRaw      = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? ClipEntryType.text.rawValue
        let type         = ClipEntryType(rawValue: typeRaw) ?? .text
        var vector: [Float]? = nil
        if let blob = sqlite3_column_blob(stmt, 10) {
            let bytes = Int(sqlite3_column_bytes(stmt, 10))
            if bytes > 0 {
                let data = Data(bytes: blob, count: bytes)
                vector = decodeVector(data)
            }
        }
        let copyCount = max(1, Int(sqlite3_column_int64(stmt, 11)))

        return ClipEntry(id: id, content: content, contentHash: contentHash,
                         sourceBundle: sourceBundle, sourceName: sourceName,
                         createdAt: createdAt, lastUsedAt: lastUsedAt,
                         truncated: truncated, isPinned: isPinned, type: type,
                         vector: vector, copyCount: copyCount)
    }

    static func encodeVector(_ v: [Float]) -> Data {
        var copy = v
        return copy.withUnsafeMutableBufferPointer { buf in
            Data(bytes: buf.baseAddress!, count: buf.count * MemoryLayout<Float>.size)
        }
    }

    static func decodeVector(_ data: Data) -> [Float]? {
        let stride = MemoryLayout<Float>.size
        guard data.count > 0, data.count % stride == 0 else { return nil }
        let count = data.count / stride
        var out = [Float](repeating: 0, count: count)
        _ = out.withUnsafeMutableBytes { dst in
            data.copyBytes(to: dst.bindMemory(to: UInt8.self), count: data.count)
        }
        return out
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "sqlite3_exec rc=\(rc)"
            sqlite3_free(err)
            throw SQLiteError.exec(msg)
        }
    }

    private func execNoTx(_ sql: String) throws { try exec(sql) }

    private func lastErrorMessage() -> String {
        guard let db = db, let cstr = sqlite3_errmsg(db) else { return "unknown sqlite error" }
        return String(cString: cstr)
    }
}
