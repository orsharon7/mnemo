# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #38 review*

### Code Quality
- Remove unused imports and unused callback/closure parameters; prefix intentionally-kept parameters with `_`.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, comments, and PR descriptions in sync with actual behavior in the same commit.
- Write inline comments as complete sentences; remove stray fragments.
- Verify every acceptance criterion before closing a PR.

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` that disables `scroll-behavior: smooth` and reduces transitions/transforms.
- Declare a solid-color fallback before `color-mix()`, container queries, or `:has()`; for `-webkit-text-fill-color: transparent` gradient text, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles; remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters; prefix intentionally kept parameters with `_` (e.g. `_query`).
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, comments, and PR descriptions in sync with actual behavior in the same commit.
- Keep keyboard shortcut hints (e.g. `⌘⌫`, `⌃↩`) exactly in sync with the actual key-handling code; never display a modifier that isn't required by the handler.
- Write inline comments as complete sentences; remove stray fragments.
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
- In branch-switching CI: checkout the branch first, then generate/modify files; `git reset --hard` before switching.
- Verify cache hits include all required artifacts; use a marker file or `FORCE=1` escape hatch for version-pinned downloads.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum; expose a checksum override variable alongside version overrides.
- Release order: `codesign` (Developer ID) → `xcrun notarytool submit --wait` → `xcrun stapler staple`.
- **Makefile:** Codesign last — after all bundle mutations. Use order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races; stage `.app` and `/Applications` symlink in a temp dir for `create-dmg`.

### Swift
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **URL opening:** Capture and return the `Bool` from `NSWorkspace.shared.open(_:)`; never ignore it or return `true` unconditionally. Restrict browser URLs to `http`/`https`; reject `file:`, `tel:`, and other schemes. Apply `https://` prefix only when the input has no explicit scheme; return `false`/nil for explicit non-http(s) schemes. Detect non-http(s) schemes by matching any `<word>:` prefix (not just `://` or `//`), so that `mailto:`, `tel:`, and `file:` are rejected even when they lack `//`. Share one canonical "is openable as URL" predicate between label/hint display and the open action — never let them use diverging logic.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Appearance:** Use semantic system colors (`NSColor.controlBackgroundColor`, `.windowBackgroundColor`, `.separatorColor`, etc.); never hard-code `Color(white:)`, `Color(red:green:blue:)`, or hex values.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Numeric safety:** Clamp decoded integer fields immediately after decoding (e.g. `copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` / `saturatingAdd`) for runtime counters; re-clamp after migration/merge.
- **Deduplication:** Use SHA256 (CryptoKit) plus `content` equality; on match, update all metadata fields — never only the timestamp. Prefer non-nil over nil when collapsing duplicates. On hash algorithm change, recompute `contentHash` from `content` for all entries in `load()` before deduplication.
- **Data consistency:** Define one explicit merge rule per field; re-sort with the canonical comparator after any merge pass; persist immediately when a load-time migration detects changes.
- **Async & state:** Capture lazily-evaluated values into a `let` before `DispatchQueue.main.async`. Declare `NSRegularExpression` as `static let`; observe shared singletons via `@ObservedObject`/`@StateObject`. Reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler on every show. Consolidate sibling `.onReceive` subscriptions on the same publisher into one handler. Always use the current SwiftUI `onChange` closure signature that accepts parameters (`{ _, _ in … }` or `{ _ in … }`); never use the zero-parameter form, which fails to compile with modern toolchains.
- **Layout:** Use `Color.clear.frame(height:)` or padding for fixed-height gaps — never `Spacer().frame(height:)`. Declare types used only within one file `private` or `fileprivate`.
- **Display scale & hairlines:** Declare `@Environment(\.displayScale) private var displayScale` in every SwiftUI view that computes pixel-aligned sizes; derive `lineWidth` as `1 / displayScale`. Never use `NSScreen.main?.backingScaleFactor` or hard-code `lineWidth: 1`.
- **Force-unwrap:** Never force-unwrap (`!`); prefer `guard let`, `if let`, or nil-coalescing.
- **Focus management:** Gate `makeFirstResponder` in `makeNSView` on the `isFocused` binding; drive focus changes through `updateNSView`.
- **Lazy embedding:** Skip embedding if a non-nil vector already exists; compute embeddings off the main thread.
- **Date ranges & metrics:** Use `Calendar` date math (`date(byAdding:)`, `startOfDay`, start-of-month) for time boundaries — never fixed second offsets. Capture a single `let now = Date()` at the start of each render/refresh pass. Extract one `startDate(now:)` method per range type and reuse it everywhere; eliminate duplicated range-start logic and unreachable `switch` arms. Scope metrics to the selected time range (not lifetime counters); compute creation-based metrics (e.g. "capture rate") from `createdAt`, not `lastUsedAt`. Remove properties with hardcoded approximations (e.g. `spanDays = 30`) that diverge from their semantic definition. Ensure UI labels match the metric actually computed; document sort-pass precedence when multiple passes run in sequence.

### Search, Text Processing & Python
- Preprocess indexed content and queries identically (case folding, whitespace normalization); preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding. Split on `\s` (including newlines) so pasted multi-line input tokenizes correctly.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` in boundary classes alongside `[ \t]` and `$`.
- Define one canonical list of supported operators/tokens; derive all regex alternations and `switch`/`case` branches from it; keep comments in sync.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

