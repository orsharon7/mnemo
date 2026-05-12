# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #33 review*

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never use `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` disabling `scroll-behavior: smooth` and reducing transitions/transforms.
- Declare a solid-color or legacy fallback before any modern CSS (`color-mix()`, container queries, `:has()`); for gradient text using `-webkit-text-fill-color: transparent`, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles. Remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, and inline comments in sync with actual behavior in the same commit.
- Verify every acceptance criterion before closing a PR.

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
- **Numeric safety:** Clamp decoded integer fields to their valid range immediately after decoding (e.g., `copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` or `saturatingAdd`) for runtime-incremented counters; apply the same clamping after migration/merge.
- **Deduplication:** Use `SHA256` (CryptoKit) for content-equality checks; also verify `content` equality to eliminate hash collisions. On match, update all metadata fields (source app, bundle, type, timestamp) — never only the timestamp. Prefer non-nil over nil for every optional field (vector, sourceName, type, etc.) when collapsing duplicates.
- **Merge rules:** Define one explicit merge rule per field (e.g., "take the value from the entry with the latest `lastUsedAt`"); keep code, comments, and PR description in agreement.
- **Lazy embedding:** Check for a non-nil vector before computing embeddings; skip if already present and perform embedding off the main thread.
- **Post-mutation consistency:** Re-sort with the canonical comparator after any merge/collapse pass. Persist immediately when a load-time migration detects changes; don't wait for the next user-triggered save.
- **Hash algorithm migration:** When changing a persisted hash algorithm (e.g., upgrading to SHA-256), recompute `contentHash` from `content` for all decoded entries on `load()` — before deduplication or collapse — so legacy and new hashes don't coexist and break dedup/`copyCount` increment across versions.

### Search, Text Processing & Python
- Apply identical preprocessing (case folding, whitespace normalization) to both indexed content and queries; preserve original-cased text separately for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` alongside `[ \t]` and `$` in boundary classes.
- Define one canonical list of supported operators/tokens; derive all regex alternations and switch/case logic from it — never duplicate across patterns, cases, and docstrings. Keep regex comments in sync with the pattern.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

