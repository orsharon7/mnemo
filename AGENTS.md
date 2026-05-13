# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-13 from PR #36 review*

### Code Quality
- Remove unused imports and unused callback/closure parameters; prefix intentionally-kept parameters with `_` (e.g. `_query`).
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present.
- Keep UI labels, tooltips, keyboard shortcut hints, comments, and PR descriptions in sync with actual behavior; never display a modifier key not required by the handler.
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
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **URL opening:** Capture and return the `Bool` from `NSWorkspace.shared.open(_:)`; never ignore it or return `true` unconditionally. Accept only `http`/`https`; reject any `<word>:` prefix (covers `mailto:`, `file:`, `tel:` even without `//`). Special-case bare `host:port` (colon followed only by digits, e.g. `localhost:3000`) — treat as no explicit scheme and apply `https://`. Share one canonical "is openable as URL" predicate between display and the open action. Construct URLs containing user-supplied content (addresses, query parameters) via `URLComponents` — never string concatenation — so percent-encoding is handled correctly and `URL(string:)` cannot fail on valid input.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Appearance:** Use semantic system colors (`NSColor.controlBackgroundColor`, `.windowBackgroundColor`, `.separatorColor`, etc.); never hard-code `Color(white:)`, `Color(red:green:blue:)`, or hex values.
- **Caching:** Use `NSCache` with a `countLimit`; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Numeric safety:** Clamp decoded integer fields immediately after decoding (e.g. `copyCount = max(1, decoded)`); use overflow-safe arithmetic (`addingReportingOverflow` / `saturatingAdd`) for runtime counters; re-clamp after migration/merge. Clamp post-delete selection to `max(0, min(deletedIndex, newCount - 1))`; never use `count - 2`.
- **Data & deduplication:** Use SHA256 (CryptoKit) plus `content` equality; on match, update all metadata fields — never only the timestamp. Prefer non-nil over nil when collapsing duplicates. On hash algorithm change, recompute `contentHash` from `content` for all entries in `load()` before deduplication. Define one explicit merge rule per field; re-sort with the canonical comparator after any merge pass; persist immediately when a load-time migration detects changes.
- **Async & state:** Capture lazily-evaluated values into a `let` before `DispatchQueue.main.async`. Declare `NSRegularExpression` as `static let`; observe shared singletons via `@ObservedObject`/`@StateObject`. Reset all ephemeral `@State` (focus, selection, query, scroll) in the panel-opened handler on every show. Consolidate sibling `.onReceive` subscriptions on the same publisher into one handler. Always use the SwiftUI `onChange` signature accepting parameters (`{ _, _ in … }`); never use the zero-parameter form.
- **Layout:** Use `Color.clear.frame(height:)` or padding for fixed-height gaps — never `Spacer().frame(height:)`. Declare types used only within one file `private` or `fileprivate`.
- **Display scale:** Declare `@Environment(\.displayScale) private var displayScale` in every SwiftUI view computing pixel-aligned sizes; derive `lineWidth` as `1 / displayScale`. Never use `NSScreen.main?.backingScaleFactor` or hard-code `lineWidth: 1`.
- **Safety:** Never force-unwrap (`!`); prefer `guard let`, `if let`, or nil-coalescing.
- **Focus:** Gate `makeFirstResponder` in `makeNSView` on the `isFocused` binding; drive focus changes through `updateNSView`.
- **Embeddings:** Skip embedding if a non-nil vector already exists; compute embeddings off the main thread.
- **Date ranges & metrics:** Use `Calendar` date math (`date(byAdding:)`, `startOfDay`, start-of-month) — never fixed second offsets or `timeIntervalSince(...) / 86400`. Capture a single `let now = Date()` per render/refresh pass. Extract one `startDate(now:)` per range type and reuse it everywhere. Scope metrics to the selected time range; compute creation-based metrics from `createdAt`, not `lastUsedAt`. Keep UI labels in sync with the metric actually computed; document sort-pass precedence. For inclusive day counts, apply `startOfDay` to both endpoints then add 1 — `Calendar.dateComponents([.day], from: oldest, to: now).day` counts day boundaries crossed (off by 1), inflating per-day rates.
- **Accessibility:** Mark decorative per-element chart/heatmap visuals `.accessibilityHidden(true)`; expose a single `accessibilityLabel`/`accessibilityValue` on the container.

### Search, Text Processing & Python
- Preprocess indexed content and queries identically (case folding, whitespace normalization); preserve original-cased text for embeddings/display.
- Trim whitespace from user input; reject blank/whitespace-only strings before searching or embedding; split on `\s` (including newlines) for multi-line input.
- In regex token-stripping, consume adjacent whitespace in the same substitution; include `\n`/`\r\n` in boundary classes alongside `[ \t]` and `$`.
- Define one canonical list of supported operators/tokens; derive all regex alternations and `switch`/`case` branches from it; keep comments in sync.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->
