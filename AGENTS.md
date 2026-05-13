# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #38 review (optimized)*

### Code Quality
- Remove unused imports and unused callback/closure parameters; prefix intentionally-kept ones with `_`.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, shortcut hints, comments, and PR descriptions in sync with actual behavior.
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
- Use match-only extraction (`sed -nE '...p'`, `grep -oE`); validate extracted values before use.
- Use fixed-string comparison (`-F` / `index()`) or escape metacharacters; never interpolate unescaped variables into `awk`/`grep` patterns.
- Validate external values (git tags, CLI args) used in paths or destructive commands; reject `/`, `..`, and path metacharacters.

### CI, Release & Build
- Mark optional-tool install steps `continue-on-error: true`.
- Use `paths` filters or `if` conditions instead of `[skip ci]` when downstream workflows must still run.
- In branch-switching CI: checkout the branch first, then generate/modify files; `git reset --hard` before switching.
- Verify cache hits include all required artifacts; use a marker file or `FORCE=1` escape hatch for version-pinned downloads.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum; expose a checksum override variable alongside version overrides.
- Release order: `codesign` → `xcrun notarytool submit --wait` → `xcrun stapler staple`. Codesign last — after all bundle mutations.
- **Makefile:** Use order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races; stage `.app` and `/Applications` symlink in a temp dir for `create-dmg`.

### Swift
- **Safety:** Never force-unwrap (`!`); prefer `guard let`, `if let`, or nil-coalescing.
- **Threading:** Annotate types/methods calling AppKit APIs with `@MainActor`; capture lazily-evaluated values into a `let` before `DispatchQueue.main.async`.
- **URL handling:** Accept only `http`/`https`; special-case bare `host:port` → prepend `https://`; construct URLs via `URLComponents`, never string concatenation; return the `Bool` from `NSWorkspace.shared.open(_:)`, never `true` unconditionally; share one canonical "is openable" predicate between display and open.
- **Appearance:** Use semantic system colors (`NSColor.controlBackgroundColor`, `.separatorColor`, etc.); never hard-code `Color(white:)`, hex, or RGB literals.
- **Numeric safety:** Clamp decoded integers immediately (`copyCount = max(1, decoded)`); re-clamp after migration/merge; use overflow-safe arithmetic for runtime counters. Clamp post-delete selection to `max(0, min(deletedIndex, newCount - 1))`; when deletion is async, derive max index from pre-delete count minus 2 (floored at 0), or update selection only after the store mutation completes.
- **Data & deduplication:** Hash with SHA256 (CryptoKit) plus `content` equality; update all metadata fields on match. On hash algorithm change, recompute `contentHash` for all entries in `load()` before dedup. Define one explicit merge rule per field; re-sort with the canonical comparator after any merge; persist immediately when a load-time migration detects changes.
- **State & subscriptions:** Declare `NSRegularExpression` as `static let`; observe shared singletons via `@ObservedObject`/`@StateObject`. Reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler on every show. Consolidate sibling `.onReceive` subscriptions on the same publisher into one handler. Use the SwiftUI `onChange` signature with parameters (`{ _, _ in … }`); never the zero-parameter form.
- **Render-pass caching:** Compute expensive derived values (filtered lists, search results, embeddings) once per render into a local `let`; never call a recomputing property multiple times in `body`.
- **Layout & display scale:** Use `Color.clear.frame(height:)` or padding for fixed-height gaps — never `Spacer().frame(height:)`. Declare `@Environment(\.displayScale) private var displayScale` in views computing pixel-aligned sizes; derive `lineWidth` as `1 / displayScale`. Declare file-private types `private` or `fileprivate`.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Date & metrics:** Use `Calendar` date math (`date(byAdding:)`, `startOfDay`) — never fixed-second offsets or `/ 86400`. Capture `let now = Date()` once per render. For inclusive day counts, apply `startOfDay` to both endpoints then add 1. Scope metrics to the selected time range; compute creation metrics from `createdAt`, not `lastUsedAt`.
- **Accessibility:** Mark decorative visuals `.accessibilityHidden(true)`; expose a single `accessibilityLabel`/`accessibilityValue` on the container.
- **Focus:** Gate `makeFirstResponder` in `makeNSView` on the `isFocused` binding; drive focus changes through `updateNSView`.
- **Embeddings:** Skip embedding if a non-nil vector already exists; compute off the main thread.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.

### Search, Text Processing & Python
- Preprocess indexed content and queries identically (case folding, whitespace normalization); preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding; split on `\s` (including newlines) for multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` in boundary classes alongside `[ \t]` and `$`.
- Define one canonical list of supported operators/tokens; derive all regex alternations and `switch`/`case` branches from it; keep comments in sync.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->
