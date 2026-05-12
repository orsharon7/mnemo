# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #35 review*

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` that disables `scroll-behavior: smooth` and reduces transitions/transforms.
- Declare a solid-color or legacy fallback before any modern CSS (`color-mix()`, container queries, `:has()`); for gradient text using `-webkit-text-fill-color: transparent`, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles. Remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, inline comments, and PR descriptions in sync with actual behavior in the same commit.
- Write inline comments as complete sentences; remove stray words or fragments before committing.
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
- **Numeric safety:** Clamp decoded integer fields immediately after decoding (e.g., `copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` or `saturatingAdd`) for runtime-incremented counters; apply the same clamping after migration/merge.
- **Deduplication:** Use SHA256 (CryptoKit) plus `content` equality for dedup checks; on match, update all metadata fields — never only the timestamp. Prefer non-nil over nil for every optional field when collapsing duplicates.
- **Data consistency:** Define one explicit merge rule per field. Re-sort with the canonical comparator after any merge/collapse pass. Persist immediately when a load-time migration detects changes.
- **Hash migration:** When changing a persisted hash algorithm, recompute `contentHash` from `content` for all decoded entries on `load()` before deduplication — so legacy and new hashes don't coexist.
- **Lazy embedding:** Skip embedding if a non-nil vector already exists; compute embeddings off the main thread.
- **Async capture:** Capture lazily-evaluated values (e.g., `filtered.first?.id`) into a `let` constant before `DispatchQueue.main.async`; never re-evaluate stateful expressions inside the async block.
- **Panel state:** On show/hide without re-creation, reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler — not only on first load.
- **Event handlers:** Consolidate multiple `.onReceive` subscriptions on sibling views into one handler when one handler's output depends on state mutated by the other.
- **Appearance:** Never use hard-coded `Color(white:)`, `Color(red:green:blue:)`, or literal hex colors in SwiftUI/AppKit views; use semantic system colors (`NSColor.controlBackgroundColor`, `.windowBackgroundColor`, `.separatorColor`, etc.) so the UI adapts to Light/Dark Mode and custom appearances.

### Search, Text Processing & Python
- Apply identical preprocessing (case folding, whitespace normalization) to both indexed content and queries; preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` alongside `[ \t]` and `$` in boundary classes.
- Define one canonical list of supported operators/tokens; derive all regex alternations and switch/case logic from it. Keep regex comments in sync with the pattern.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

