# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-12 from PR #23 review*

### Performance & Web Vitals
- Never apply `loading="lazy"` to above-the-fold images; use `fetchpriority="high"` for the primary hero asset to avoid LCP regressions.

### Accessibility & Motion Sensitivity
- Always add a `@media (prefers-reduced-motion: reduce)` override to disable `scroll-behavior: smooth` and reduce/disable CSS transitions and hover transforms.

### CSS Compatibility & Fallbacks
- When using modern CSS features (e.g. `color-mix()`, container queries, `:has()`), always declare a solid-color or safe fallback value before the modern declaration so the UI remains legible in unsupported browsers.

### Code Quality
- Remove unused CSS custom properties (dead variables like `--unused-var`) to keep stylesheets clean and maintainable.

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

<!-- END:COPILOT-RULES -->

