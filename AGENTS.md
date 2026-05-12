# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #32 review (optimized)*

### Frontend & CSS
- Never apply `loading="lazy"` to above-the-fold images; use `fetchpriority="high"` on the primary hero asset.
- Always add `@media (prefers-reduced-motion: reduce)` to disable `scroll-behavior: smooth` and reduce/disable transitions and hover transforms.
- Declare a solid-color or safe fallback before any modern CSS feature (`color-mix()`, container queries, `:has()`).
- For `-webkit-text-fill-color: transparent` gradient text, declare a non-`color-mix()` fallback gradient before the `color-mix()` version.
- Never use inline styles for layout or theming; use CSS classes.
- Remove unused CSS custom properties and unused imports (all languages).
- Only insert separator characters (`•`, `|`, `/`) between two items that are both present — never unconditionally.

### HTML & Navigation
- Never use `href="#"`; link to a real destination (`/`, `index.html`, or a named anchor).
- Use relative links (`index.html`, `./`) instead of root-absolute paths (`/`) for sites deployed at a subpath (e.g. GitHub Pages).
- For direct-download CTAs, link to the stable asset URL (`.../releases/latest/download/<asset>`), not an intermediate release page.

### Code Quality
- Remove unused parameters from callbacks and closures.
- Keep UI labels, tooltips, and help text synchronized with actual behavior; list every supported operator/command in hint text.
- Keep inline comments synchronized with the code path; update them in the same commit as the implementation change.

### Shell Scripting
- Under `set -e`, wrap commands whose exit code must be inspected in `if/else` or temporarily disable `-e`; never use `|| true` to blanket-suppress errors.
- Consolidate all cleanup into a single `EXIT` trap; never overwrite an existing trap.
- Guard `rm -rf` variables in traps: `[ -n "${VAR:-}" ] && rm -rf -- "$VAR"`.
- Check array length (`[ ${#ARR[@]} -gt 0 ]`) before splicing into a command; `${array+word}` treats an empty array as set.
- Use match-only extraction (`sed -nE '...p'`, `grep -oE`) so unmatched input returns empty, then validate the result before use.
- Use fixed-string comparison (`-F` / `index()`) or escape metacharacters before interpolating variables into awk/grep patterns.
- Validate external values (git tags, CLI args) used in file paths or destructive commands; reject or sanitize strings containing `/` or `..`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections, or use a library that handles it automatically.
- Always specify `encoding="utf-8"` (and `newline="\n"` for stable diffs) in Python file I/O (`open()`, `Path.read_text/write_text`).

### CI & Release
- Mark optional-tool install steps `continue-on-error: true` when a built-in fallback exists.
- Never use `[skip ci]` when downstream workflows (Pages deploy, appcast) must still run; use `paths` filters or `if` conditions instead.
- Verify all required cache artifacts (binaries, config files) are present and version-matched before skipping a download — not just the top-level directory; expose a `FORCE=1` escape hatch for version overrides.
- Checkout the target branch before generating or modifying files; reset the working tree (`git reset --hard`) before any branch switch.
- Ensure CI `paths` filters match documented trigger behavior; widen the filter if the intent is to deploy on every push.
- **Release signing:** `codesign` (Developer ID) → `xcrun notarytool submit --wait` → `xcrun stapler staple`, in that order; never close notarization requirements without all three steps present.
- In Makefiles, run `codesign` as the final step after all bundle mutations; use order-only prerequisites (`$(TARGET): | dirs`) to prevent parallel-build races on shared directories; depend only on real file targets, not phony wrappers.
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum before execution; expose a companion checksum override variable alongside any version override variable.
- Before marking an issue closed in a PR, verify every acceptance criterion is implemented.

### Swift
- Observe shared singleton state via `@ObservedObject` or `@StateObject` in SwiftUI views; never read it directly without observation.
- Annotate Swift types/methods that call AppKit APIs (`NSWorkspace`, `NSImage`) with `@MainActor`.
- Swift classes used as `NSMenuItem` targets or referenced via `#selector` must inherit from `NSObject`.
- Cache with `NSCache` (set `countLimit`), not an unbounded `Dictionary`; memoize negative lookups in a bounded miss cache (not via `nil` subscript assignment, which removes the key).
- Declare types used only within a single file as `private` or `fileprivate`.

### Search & Text Processing
- Split user-supplied strings on `.whitespacesAndNewlines` / `\s` so newlines in pasted input are recognized as delimiters.
- Apply identical preprocessing (lowercasing, normalization) to both indexed content and queries; preserve the original-cased text separately for embeddings and display.

<!-- END:COPILOT-RULES -->

