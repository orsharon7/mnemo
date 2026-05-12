# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #32 review*

### Frontend, HTML & Navigation
- Set `fetchpriority="high"` on the primary hero image; never `loading="lazy"` on above-the-fold images.
- Add `@media (prefers-reduced-motion: reduce)` disabling `scroll-behavior: smooth` and reducing transitions/transforms.
- Before any modern CSS (`color-mix()`, container queries, `:has()`), declare a solid-color or legacy fallback; for `-webkit-text-fill-color: transparent` gradient text, add a non-`color-mix()` fallback gradient first.
- Define CSS classes for layout/theming; never inline styles. Remove unused CSS custom properties.
- Never use `href="#"`; link to a real destination (`/`, `index.html`, or a named anchor).
- Use relative links (`index.html`, `./`) not absolute root paths for subpath-deployed sites (e.g. GitHub Pages).
- Link download CTAs to `.../releases/latest/download/<asset>`, not an intermediate release page.

### Code Quality
- Remove unused imports and unused callback/closure parameters.
- Insert separators (`•`, `|`, `/`) only when both adjacent items are present; never unconditionally.
- Keep UI labels, tooltips, hint text, and inline comments synchronized with actual behavior in the same commit.
- Verify every acceptance criterion is implemented before closing a PR issue.

### Shell Scripting
- With `set -e`, handle expected non-zero exits via `if/else` or local `-e` disable; never blanket-suppress with `|| true`.
- Consolidate all cleanup into one `EXIT` trap (never overwrite it); guard each `rm -rf` with `[ -n "${VAR:-}" ] && rm -rf -- "$VAR"`.
- Check array emptiness with `[ ${#ARR[@]} -gt 0 ]`; `${array+word}` is true even for empty arrays.
- Use match-only extraction (`sed -nE '...p'`, `grep -oE`) and validate extracted values before use.
- Use fixed-string comparison (`-F` / `index()`) or escape metacharacters; never interpolate unescaped variables into `awk`/`grep` patterns.
- Validate external values (git tags, CLI args) used in paths or destructive commands; reject `/`, `..`, and path metacharacters.

### CI & Release
- Mark optional-tool install steps `continue-on-error: true`.
- Replace `[skip ci]` with `paths` filters or `if` conditions when downstream workflows (Pages deploy, appcast) must still run.
- In branch-switching CI workflows, checkout the branch first, then generate/modify files; `git reset --hard` before switching to avoid overwrite failures.
- Verify cache hits include all required artifacts; for version-pinned downloads confirm the cached version matches (marker file or `FORCE=1` escape hatch).
- Verify downloaded tarballs/binaries with a pinned SHA256 checksum; expose a checksum override variable alongside any version override.
- Release workflows must run all three steps in order: `codesign` (Developer ID) → `xcrun notarytool submit --wait` → `xcrun stapler staple`.

### Makefile & Build Scripts
- Codesign last — after all bundle mutations (resource copies, framework embedding, icon injection).
- Add order-only prerequisites (`$(TARGET): | dirs`) to prevent `make -j` races on phony-created directories.
- Depend only on the real file target, not both a phony wrapper and the real file.
- For `create-dmg`, stage the `.app` bundle and `/Applications` symlink in a temp directory and pass it as the source.

### Swift
- **Threading:** Annotate types/methods calling AppKit APIs (`NSWorkspace`, `NSImage`, etc.) with `@MainActor`.
- **ObjC interop:** Classes used as `NSMenuItem` targets or via `#selector` must inherit from `NSObject`.
- **Caching:** Use `NSCache` with a `countLimit` for images/resources; memoize negative lookups in a separate bounded `Set<Key>` (`dict[key] = nil` removes the entry, not caches a miss).
- **Regex & state:** Declare `NSRegularExpression` as `static let` (compiled once); observe shared singleton state via `@ObservedObject`/`@StateObject`, never read directly.
- **Access control:** Declare types used only within one file `private` or `fileprivate`.

### Search, Text Processing & Python
- Apply identical preprocessing (case folding, whitespace normalization) to both indexed content and queries; preserve original-cased text separately for embeddings/display.
- Trim whitespace from user input and reject blank strings (not just `.isEmpty`) before searching or embedding — whitespace-only needles produce unintended matches.
- Split user input on `\s` (including newlines) so tokens are recognized in pasted multi-line input.
- When stripping tokens via regex, consume adjacent whitespace in the same substitution to prevent doubled spaces.
- When matching operator/token boundaries in regex, include `\n`/`\r\n` alongside `[ \t]` and `$`; operators followed by a newline won't be stripped if newlines are not in the boundary character class, leaving operator text in the remaining needle.
- Pass `encoding="utf-8"` (and `newline="\n"` for stable diffs) to `open()`, `Path.read_text()`, and `Path.write_text()`.
- Escape/split `]]>` before inserting arbitrary text into XML CDATA sections.

<!-- END:COPILOT-RULES -->

