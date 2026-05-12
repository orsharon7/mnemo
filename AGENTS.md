# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #33 review*

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never use `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` that disables `scroll-behavior: smooth` and reduces transitions/transforms.
- Declare a solid-color or legacy fallback before any modern CSS (`color-mix()`, container queries, `:has()`); for `-webkit-text-fill-color: transparent` gradient text, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles. Remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, and inline comments in sync with actual behavior in the same commit.
- Verify every acceptance criterion is implemented before closing a PR.

### Shell Scripting
- With `set -e`, handle expected non-zero exits via `if/else` or local `-e` disable; never suppress with `|| true`.
- Consolidate cleanup in one `EXIT` trap (never overwrite it); guard each `rm -rf` with `[ -n "${VAR:-}" ] && rm -rf -- "$VAR"`.
- Check array emptiness with `[ ${#ARR[@]} -gt 0 ]`; `${array+word}` is true even for empty arrays.
- Use match-only extraction (`sed -nE '...p'`, `grep -oE`) and validate extracted values before use.
- Use fixed-string comparison (`-F` / `index()`) or escape metacharacters; never interpolate unescaped variables into `awk`/`grep` patterns.
- Validate external values (git tags, CLI args) used in paths or destructive commands; reject `/`, `..`, and path metacharacters.

### CI, Release & Build
- Mark optional-tool install steps `continue-on-error: true`.
- Use `paths` filters or `if` conditions instead of `[skip ci]` when downstream workflows must still run.
- In branch-switching CI: checkout the branch first, then generate/modify files; `git reset --hard` before switching to avoid overwrite failures.
- Verify cache hits include all required artifacts; confirm version-pinned downloads match via marker file or `FORCE=1` escape hatch.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum; expose a checksum override variable alongside version overrides.
- Release order: `codesign` (Developer ID) → `xcrun notarytool submit --wait` → `xcrun stapler staple`.
- **Makefile:** Codesign last — after all bundle mutations. Add order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races. Depend only on the real file target, not both a phony and real file. For `create-dmg`, stage `.app` and `/Applications` symlink in a temp dir.

### Swift
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Regex & state:** Declare `NSRegularExpression` as `static let`; observe shared singleton state via `@ObservedObject`/`@StateObject`, never read directly.
- **Access control:** Declare types used only within one file `private` or `fileprivate`.
- **Decoded integers:** Clamp decoded numeric fields to their documented valid range immediately after decoding (e.g., `copyCount = max(1, decoded)`); apply the same clamping to values produced during migration/merge.
- **Counter overflow:** Use overflow-safe arithmetic (`addingReportingOverflow` or `saturatingAdd`) for counters incremented at runtime (e.g., `copyCount += 1`); clamp to a documented max rather than letting the value trap.
- **Content identity hashing:** Use a cryptographic hash (e.g., CryptoKit `SHA256`) for content-equality checks used in deduplication; additionally verify `content` equality before treating two entries as duplicates to eliminate collision risk.
- **Merge rule consistency:** Define one explicit merge rule per field when collapsing duplicates (e.g., "take the value from the entry with the latest `lastUsedAt`"); ensure the code, comments, and PR/commit description all agree — never let them diverge silently.
- **Lazy embedding:** Check for an existing entry (and a non-nil vector) before computing embeddings; skip the embedding call when the entry already has a vector, and perform embedding off the main thread.
- **Lossless merging:** When collapsing duplicates, prefer non-nil over nil for every optional field (vector, sourceName, type, etc.); never silently discard a richer value from a later duplicate in favour of the first-seen entry's nil.
- **Sort after mutation:** Re-sort any collection with the canonical comparator after a merge/collapse pass; never leave results in insertion order when the store has a defined sort order (e.g., pinned-first + recency).
- **Full metadata refresh on dedup:** When a duplicate is detected (e.g., `contentHash` match), update all per-event metadata fields (source app, bundle, type, etc.) along with the timestamp — never refresh only the timestamp while leaving display fields stale.
- **Persist after migration:** When a load-time migration or collapse detects changes, persist the result immediately rather than waiting for the next user-triggered save; otherwise the migration re-runs on every launch.

### Search, Text Processing & Python
- Apply identical preprocessing (case folding, whitespace normalization) to both indexed content and queries; preserve original-cased text separately for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` alongside `[ \t]` and `$` in boundary classes, and consume preceding space/tab when an operator precedes a newline boundary.
- Define one canonical list of supported operators/tokens; derive all regex alternations and switch/case logic from it — never duplicate across patterns, cases, and docstrings. Keep regex comments in sync with the pattern.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

