# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-11 from PR #20 review*

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

<!-- END:COPILOT-RULES -->

