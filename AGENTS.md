# AGENTS

Project instructions for AI coding agents.

<!-- BEGIN:COPILOT-RULES -->
## Coding Guidelines (AI-maintained)
*Auto-updated by pr-review-reflect — do not edit this section manually.*
*Last updated: 2026-05-11 from PR #23 review*

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

<!-- END:COPILOT-RULES -->

