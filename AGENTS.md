# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #38 review*

### Frontend & CSS
- Set `fetchpriority="high"` on the primary hero image; never `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` disabling `scroll-behavior: smooth` and reducing transitions/transforms.
- Declare a solid-color fallback before `color-mix()`, container queries, or `:has()`; for `-webkit-text-fill-color: transparent` gradient text, add a non-`color-mix()` fallback gradient first.
- Use CSS classes for layout/theming; never inline styles; remove unused custom properties.
- Never use `href="#"`; use relative links (`index.html`, `./`) for subpath-deployed sites.
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters; when a parameter is intentionally kept for future use, prefix it with `_` (e.g. `_ query`) to suppress the warning without removing the call site.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, comments, and PR descriptions in sync with actual behavior in the same commit.
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
- **Makefile:** Codesign last — after all bundle mutations. Use order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races; depend only on the real file target. Stage `.app` and `/Applications` symlink in a temp dir for `create-dmg`.

### Swift
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **URL opening:** Capture and return the `Bool` result of `NSWorkspace.shared.open(_:)`; never ignore it or return `true` unconditionally.
- **URL scheme restriction:** When opening URLs intended for a browser, restrict allowed schemes to `http`/`https`; reject `file:`, `tel:`, and other custom schemes to avoid launching unexpected handlers.
- **URL scheme fallback:** Only apply an `https://` prefix fallback when the input string has no explicit scheme; if an explicit non-http(s) scheme is present (e.g. `mailto:`, `tel:`, `file:`), return `false`/nil rather than prepending `https://` and producing a malformed URL.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Appearance:** Use semantic system colors (`NSColor.controlBackgroundColor`, `.windowBackgroundColor`, `.separatorColor`, etc.); never hard-code `Color(white:)`, `Color(red:green:blue:)`, or literal hex values.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Numeric safety:** Clamp decoded integer fields immediately after decoding (`copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` / `saturatingAdd`) for runtime counters; re-clamp after migration/merge.
- **Deduplication:** Use SHA256 (CryptoKit) plus `content` equality; on match, update all metadata fields — never only the timestamp. Prefer non-nil over nil when collapsing duplicates.
- **Data consistency:** Define one explicit merge rule per field; re-sort with the canonical comparator after any merge pass; persist immediately when a load-time migration detects changes. On hash algorithm change, recompute `contentHash` from `content` for all decoded entries in `load()` before deduplication.
- **Async & state:** Capture lazily-evaluated values into a `let` before `DispatchQueue.main.async`. Declare `NSRegularExpression` as `static let`; observe shared singletons via `@ObservedObject`/`@StateObject`. Reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler on every show. Consolidate dependent `.onReceive` subscriptions on sibling views into one handler.
- **Layout & access:** Use `Color.clear.frame(height:)` or padding for fixed-height gaps — never `Spacer().frame(height:)`. Declare types used only within one file `private` or `fileprivate`.
- **Lazy embedding:** Skip embedding if a non-nil vector already exists; compute embeddings off the main thread.
- **Display scale & hairlines:** Use `@Environment(\.displayScale)` for per-pixel sizing; derive `lineWidth` as `1 / displayScale` for exact 1px Retina strokes. Never use `NSScreen.main?.backingScaleFactor` or hard-code `lineWidth: 1`. Declare `@Environment(\.displayScale) private var displayScale` in every SwiftUI view that computes pixel-aligned sizes before referencing it.
- **Force-unwrap:** Never force-unwrap (`!`); prefer `guard let`, `if let`, or nil-coalescing.
- **Focus management:** Gate `makeFirstResponder` in `makeNSView` on the `isFocused` binding; drive focus changes through `updateNSView`.
- **Stats & date ranges:** Use `Calendar` date math (`date(byAdding:)`, `startOfDay`, start-of-month) for time range boundaries — never fixed second offsets; avoids DST drift and makes labels like "This Month" mean the calendar month, not a rolling window.
- **Metric scoping:** When ranking or aggregating items within a selected time range, use a metric scoped to that range (not a lifetime counter); ensure UI labels match the actual metric being computed.
- **Capture rate:** Compute "capture rate" (or any creation-based metric) from `createdAt` within the range, not `lastUsedAt`; keep the numerator semantics consistent with the metric's name and tooltip.
- **Sort pass ordering:** When multiple sort passes run in sequence (e.g. pinned-first after relevance ranking), verify their combined effect matches documented priority guarantees; if one pass can override another's ordering, document the precedence rule explicitly and keep PR descriptions accurate.
- **Time snapshot:** Capture a single `let now = Date()` at the start of each render pass or refresh; never use a computed `var now` that calls `Date()` repeatedly, as multiple accesses within one pass can return different times and produce inconsistent range boundaries or counts.
- **Range-start helpers:** Extract a single `startDate(now:)` (or equivalent) method on range/enum types and reuse it everywhere; never duplicate range-start logic across computed properties — divergence causes silent inconsistencies. Eliminate unreachable `switch` arms (e.g., a `.allTime` case inside a branch already guarded by `range != .allTime`).
- **Unused properties with fixed approximations:** Remove or replace properties whose fixed/hardcoded values diverge from their semantic definition (e.g., `spanDays = 30` for a calendar month that can be 28–31 days) until a correct, calendar-aware implementation is needed; a dormant property with a wrong value is a future bug.

### Search, Text Processing & Python
- Preprocess indexed content and queries identically (case folding, whitespace normalization); preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` in boundary classes alongside `[ \t]` and `$`.
- Define one canonical list of supported operators/tokens; derive all regex alternations and switch/case branches from it; keep comments in sync.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

