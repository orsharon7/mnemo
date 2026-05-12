# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #31 review (optimized)*

### Frontend & CSS
- Never apply `loading="lazy"` to above-the-fold images; use `fetchpriority="high"` on the primary hero asset.
- Always add `@media (prefers-reduced-motion: reduce)` to disable `scroll-behavior: smooth` and reduce/disable transitions and hover transforms.
- Before any modern CSS declaration (`color-mix()`, container queries, `:has()`), declare a safe solid-color or legacy fallback so the UI remains legible in unsupported browsers.
- For `-webkit-text-fill-color: transparent` gradient text, provide a non-`color-mix()` fallback gradient before the `color-mix()` version.
- Never use inline styles for layout or theming; define CSS classes instead.
- Remove unused CSS custom properties.

### HTML & Navigation
- Never use `href="#"`; link to a real destination (`/`, `index.html`, or a named anchor).
- Use relative links (`index.html` or `./`) instead of absolute root paths (`/`) for sites deployed at a subpath (e.g. GitHub Pages).
- For direct-download CTAs, link to the stable asset URL (`.../releases/latest/download/<asset>`), not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters in all languages.
- Never render separators (`•`, `|`, `/`) unconditionally between optional UI items; only insert between two items that are both present.
- Keep UI labels, tooltips, and help text synchronized with actual behavior; list every supported operator/command in hint text or remove undocumented ones.
- Keep inline comments synchronized with the code path; update comments in the same commit as the implementation change.
- Before closing an issue in a PR, verify every acceptance criterion is implemented.

### Shell Scripting
- With `set -e`, wrap commands whose non-zero exit needs handling in `if/else` or temporarily disable `-e`; never use `|| true` to blanket-suppress errors.
- Never overwrite an `EXIT` trap; consolidate cleanup into one trap, guarding each variable with `${VAR:-}`.
- In trap `rm -rf`, guard with a non-empty check: `[ -n "${VAR:-}" ] && rm -rf -- "$VAR"`.
- Never check `${array+word}` to guard optional array args; an empty array is still "set" — check `[ ${#ARR[@]} -gt 0 ]` instead.
- Use match-only mode when extracting with `sed`/`awk` (e.g. `sed -nE '...p'`, `grep -oE`); validate the extracted value before downstream use.
- Never interpolate unescaped variables into `awk`/`grep` regex patterns; use fixed-string comparison (`-F` / `index()`) or escape metacharacters.
- Validate external values (git tags, CLI args) used in file paths or destructive commands (`rm`, `mv`): reject `/`, `..`, or path metacharacters.

### CI & Release
- Mark optional-tool install steps `continue-on-error: true` so built-in fallback paths can still execute.
- Never use `[skip ci]` when downstream workflows (Pages deploy, appcast) must still run; use `paths` filters or `if` conditions to narrow suppression.
- Verify cache hits include all required artifacts (binaries, configs), not just the top-level directory; for version-pinned downloads, confirm the cached version matches (version marker file or `FORCE=1` escape hatch).
- In CI branch-switching workflows, checkout the branch first, then generate/modify files; reset the working tree (`git reset --hard`) before switching to avoid "would be overwritten" failures.
- Ensure release workflows include all three steps: `codesign` (Developer ID), `xcrun notarytool submit --wait`, and `xcrun stapler staple`; do not close notarization issues without all three present.
- Match CI `paths` filter behavior to documented intent; widen or remove the filter if the intent is to deploy on every push.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum before execution; expose a matching checksum override variable alongside any version override variable.

### Makefile & Build Scripts
- In Makefiles, codesign last — after all bundle mutations (resource copies, framework embedding, icon injection).
- Add order-only prerequisites (`$(TARGET): | dirs`) to targets writing into phony-created directories to prevent `make -j` races.
- Depend only on the real file target, not both a phony wrapper and the real file, to avoid redundant fetches.
- For `create-dmg`, stage the `.app` bundle and `/Applications` symlink in a temp directory and pass that as the source.

### Swift
- **Threading:** Annotate Swift types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Caching:** Use `NSCache` with a `countLimit` instead of an unbounded `Dictionary` for images/resources; apply the same bound to negative-lookup (miss) caches.
- **Cache misses:** Memoize negative lookups in a separate bounded structure (e.g. `Set<Key>` with max size); `dict[key] = nil` removes the key and won't store a miss.
- **Reactive state:** Observe shared singleton state in SwiftUI via `@ObservedObject` or `@StateObject`; never read it directly without observation.
- **Access control:** Declare Swift types used only within one file `private` or `fileprivate`.

### Search & Text Processing
- Apply identical preprocessing (case folding, whitespace normalization) to both indexed content and queries; mismatched normalization degrades match quality.
- When lowercasing for matching, preserve the original-cased text separately for embeddings or display.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections, or use a library that handles it automatically.

### Python
- Always pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()` on UTF-8 or XML/JSON files.

<!-- END:COPILOT-RULES -->

