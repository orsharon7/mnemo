# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #30 review*

### Performance & Web Vitals
- Never apply `loading="lazy"` to above-the-fold images; use `fetchpriority="high"` for the primary hero asset to avoid LCP regressions.

### Accessibility & Motion Sensitivity
- Always add a `@media (prefers-reduced-motion: reduce)` override to disable `scroll-behavior: smooth` and reduce/disable CSS transitions and hover transforms.

### CSS Compatibility & Fallbacks
- When using modern CSS features (e.g. `color-mix()`, container queries, `:has()`), always declare a solid-color or safe fallback value before the modern declaration so the UI remains legible in unsupported browsers.
- When using `-webkit-text-fill-color: transparent` with a gradient background, always provide a non-`color-mix()` fallback gradient before the `color-mix()` version so text remains visible if `color-mix()` is unsupported.

### Code Quality
- Remove unused CSS custom properties (dead variables like `--unused-var`) to keep stylesheets clean and maintainable.
- Never use inline styles in HTML for layout or theming; define CSS classes instead to ensure maintainability and consistent theming across pages.
- Never include unused parameters in callback or closure signatures; simplify to only what callers and callees actually need to reduce coupling.
- Ensure UI helper text, tooltips, and labels accurately describe the actual implemented behavior — not an idealized or broader behavior — to avoid misleading users about privacy or functionality guarantees.
- Remove unused imports in all languages (Python, JS, etc.) to avoid dead code and linting failures.

### SwiftUI & Reactive State
- When reading shared observable state (e.g. a singleton) inside a SwiftUI view body, always observe it via `@ObservedObject` or `@StateObject` so the view re-renders on changes; never access singleton state directly without observation.

### HTML & Navigation
- Never use `href="#"` for navigation or brand links; link to a real destination (e.g. `/`, `index.html`, or a named anchor) to avoid dangling hash jumps.
- When a site may be deployed at a subpath (e.g. GitHub Pages project sites), use relative links (`index.html` or `./`) instead of absolute root paths (`/`) so navigation works regardless of the hosting base path.

### Product Completeness
- Before marking an issue as closed in a PR, verify every acceptance criterion from that issue is implemented (e.g. a required page, section, or link must exist, not just be planned).

### UX & Download Flows
- When a CTA is a direct download, link to the stable asset URL (e.g. `.../releases/latest/download/<asset>`) rather than an intermediate release page, so users get the file immediately.

### CI & Release Workflows
- When a CI step installs an optional tool that has a built-in fallback, mark that step `continue-on-error: true` so the fallback path can still execute on tool-install failures.
- Never use `|| true` to suppress all errors from a command; capture the exit code and only ignore known non-fatal failure codes while still surfacing real errors.

### Packaging & Build Scripts
- When creating a DMG with `create-dmg`, stage the `.app` bundle and an `/Applications` symlink in a temporary directory and pass that directory as the source, so the expected file layout is present at the root.

### Security & Input Validation
- When external values (e.g. git tags, CLI arguments) are used to construct file paths or passed to destructive commands (`rm`, `mv`), validate them first: reject strings containing `/`, `..`, or other path metacharacters, or map disallowed characters to a safe substitute (e.g. `-`) before use.

### Shell Scripting & Error Handling
- When using `set -e`, wrap any command whose non-zero exit code needs to be inspected or handled (e.g. fallback logic) in an `if/else` block or temporarily disable `-e` around it, so the script doesn't exit before the exit code can be acted upon.
- Never overwrite an existing `EXIT` trap with a new one; consolidate all cleanup into a single trap (guarding each variable with `${VAR:-}`) or accumulate cleanup commands without replacing prior traps.
- Never interpolate unescaped version strings or variable values directly into awk/grep regex patterns; escape regex metacharacters or use fixed-string comparison (`-F` / `index()`) to avoid unintended matches.
- When using `rm -rf` with variables in traps, guard each removal with a non-empty check (e.g. `[ -n "${VAR:-}" ] && rm -rf -- "$VAR"`) so cleanup is silent and safe when a variable was never set.
- Never use `${array+word}` to guard optional array arguments; an empty array (`arr=()`) is still considered "set" and will expand to an unwanted empty-string argument — check array length instead (e.g. `[ ${#ARR[@]} -gt 0 ]`) before splicing the array into a command.

### CI & Release Correctness
- When a workflow or PR claims to build, sign, and notarize a release, ensure all three steps are present (`codesign` with a Developer ID identity, `xcrun notarytool submit --wait`, and `xcrun stapler staple`); do not mark notarization requirements as closed without the actual steps in place.
- When a CI workflow uses a `paths` filter, ensure the documented trigger behavior matches the actual filter — if the intent is to deploy on every push, remove or widen the `paths` constraint.
- In Makefiles, always perform codesign as the final step after all bundle mutations (resource copies, framework embedding, icon injection) are complete; signing before bundle mutations produces an invalid signature.

### Security & Supply Chain
- When a CI script downloads a remote tarball or binary and later executes it, always verify its integrity (pinned SHA256 checksum or published signature) before extraction or use to reduce supply-chain risk.
- When a script exposes an environment variable to override a pinned dependency version, also expose a corresponding variable to override the expected checksum; never advertise version overridability while keeping the checksum hardcoded, as the override will always fail verification.

### Data Serialization & XML
- When inserting arbitrary text into XML CDATA sections, ensure the content cannot contain the CDATA terminator `]]>`; either escape/split the sequence or build the XML using a library that handles escaping automatically.

### Shell Scripting & Output Parsing
- When extracting a value with `sed` or `awk`, use a match-only mode (e.g. `sed -nE '...p'` or `grep -oE`) so unmatched input returns empty rather than the raw input line; then validate the extracted value (e.g. confirm it is numeric) before using it downstream.

### CI & Git Branch Operations
- When a CI workflow generates or modifies files and then switches branches, always perform the branch checkout first and generate/modify files afterward (or use a temp path and copy post-checkout); generating files before `git checkout` risks "untracked/modified working tree file would be overwritten" errors on subsequent runs.

<!-- END:COPILOT-RULES -->

