# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #36 review (optimized)*

### Code Quality
- Remove unused imports and unused callback/closure parameters; prefix intentionally-kept parameters with `_` (e.g. `_query`).
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, keyboard shortcut hints, comments, and PR descriptions in sync with actual behavior; never show a modifier key not required by the handler.
- Write inline comments as complete sentences; remove stray fragments.
- Verify every acceptance criterion before closing a PR.

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` disabling `scroll-behavior: smooth` and reducing transitions/transforms.
- Declare a solid-color fallback before `color-mix()`, container queries, or `:has()`; for `-webkit-text-fill-color: transparent` gradient text, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles; remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

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
- In branch-switching CI: checkout the branch first, then generate/modify files; `git reset --hard` before switching.
- Verify cache hits include all required artifacts; use a marker file or `FORCE=1` escape hatch for version-pinned downloads.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum; expose a checksum override variable alongside version overrides.
- Release order: `codesign` (Developer ID) → `xcrun notarytool submit --wait` → `xcrun stapler staple`.
- **Makefile:** Codesign last — after all bundle mutations. Use order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races; stage `.app` and `/Applications` symlink in a temp dir for `create-dmg`.

### Swift
- **Safety:** Never force-unwrap (`!`); prefer `guard let`, `if let`, or nil-coalescing.
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **URL opening:** Capture and return the `Bool` from `NSWorkspace.shared.open(_:)`; accept only `http`/`https`; reject any `<word>:` scheme prefix. Special-case bare `host:port` (digits-only after colon) as `https://`. Share one canonical "is openable" predicate between display and action. Build URLs with user-supplied content via `URLComponents`, never string concatenation.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Appearance:** Use semantic system colors (`NSColor.controlBackgroundColor`, `.separatorColor`, etc.); never hard-code `Color(white:)`, RGB, or hex values.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` — `dict[key] = nil` removes the entry, not caches a miss.
- **Numeric safety:** Clamp decoded integers immediately after decoding (e.g. `copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` / `saturatingAdd`) for counters; re-clamp after migration/merge. Clamp post-delete selection to `max(0, min(deletedIndex, newCount - 1))`.
- **Data & deduplication:** Hash with SHA256 (CryptoKit) plus `content` equality; on match, update all metadata fields, never only the timestamp. On hash algorithm change, recompute `contentHash` from `content` for all entries before deduplication. Define one merge rule per field; re-sort with the canonical comparator after any merge pass; persist immediately on load-time migration.
- **Async & state:** Capture lazily-evaluated values into `let` before `DispatchQueue.main.async`. Declare `NSRegularExpression` as `static let`. Reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler. Consolidate sibling `.onReceive` on the same publisher into one handler. Use the `onChange` signature with parameters (`{ _, _ in … }`); never the zero-parameter form.
- **Layout & display scale:** Use `Color.clear.frame(height:)` or padding for fixed-height gaps — never `Spacer().frame(height:)`. Declare `@Environment(\.displayScale) private var displayScale` in every view computing pixel-aligned sizes; derive `lineWidth` as `1 / displayScale`. Declare file-private types `private` or `fileprivate`.
- **Focus:** Gate `makeFirstResponder` in `makeNSView` on the `isFocused` binding; drive focus changes through `updateNSView`.
- **Embeddings:** Skip embedding if a non-nil vector already exists; compute embeddings off the main thread.
- **Date & metrics:** Use `Calendar` date math (`date(byAdding:)`, `startOfDay`) — never fixed second offsets or `timeIntervalSince / 86400`. Capture one `let now = Date()` per render pass; extract one `startDate(now:)` per range type and reuse it. Scope metrics to the selected time range; use `createdAt`, not `lastUsedAt`, for creation-based metrics. For inclusive day counts, apply `startOfDay` to both endpoints then add 1.
- **Accessibility:** Mark decorative chart/heatmap elements `.accessibilityHidden(true)`; expose one `accessibilityLabel`/`accessibilityValue` on the container.

### Search, Text Processing & Python
- Preprocess indexed content and queries identically (case folding, whitespace normalization); preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding; split on `\s` (including newlines) for multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` in boundary classes alongside `[ \t]` and `$`.
- Define one canonical list of supported operators/tokens; derive all regex alternations and `switch`/`case` branches from it; keep comments in sync.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->
