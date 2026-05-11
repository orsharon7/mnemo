# Mnemo

A tiny native macOS clipboard history manager. Lives in the menu bar, captures every copy in the background, and lets you summon a search-and-paste panel with a global hotkey — the Alfred clipboard experience as a standalone, local-only app.

> Full product definition (Problem Framing, JTBD, User Stories, PRD, Architecture, Decisions Log)
> lives in the Obsidian vault at `~/Documents/Obsidian Vault/Mnemo/`.

## Status — v0.4 (On-device semantic search)

P0 stories implemented & verified:

- ✅ US-1 Capture every text copy automatically
- ✅ US-2 Menu-bar-only (no Dock icon)
- ✅ US-3 Global hotkey (default ⌥⌘V, **configurable** in Preferences)
- ✅ US-4 Substring + **on-device semantic** search + subsequence fuzzy fallback (hybrid)
- ✅ US-5 Enter to copy + dismiss + refocus previous app
- ✅ US-6 ↑↓ navigate, ⌘1–9 quick pick, Esc to dismiss
- ✅ US-7 Persistent history (`~/Library/Application Support/Mnemo/history.json`, mode 0600)
- ✅ US-8 Pause Capture (menu bar)
- ✅ US-9 Clear History (menu bar) — pinned entries survive

P1 stories shipped:

- ✅ US-10 Honor `org.nspasteboard.ConcealedType` **+ heuristic secret blocker** (prefixes + Shannon entropy)
- ✅ **Per-app exclusion list** — skip clipboard capture when the frontmost app's bundle ID is on the exclusion list (Preferences → Excluded Apps)
- ✅ US-11 Launch at login (`SMAppService.mainApp`)
- ✅ US-12 Preferences window — configurable hotkey, retention, auto-paste, launch-at-login, secret-blocker toggle, **semantic-search toggle**
- ✅ Auto-paste via synthetic ⌘V (opt-in, gated on Accessibility)

P1.5 product polish (v0.3):

- ✅ **Pin / favorite** entries with ⌘P — pinned sort to top, immune to Clear All & retention cap
- ✅ **Type detection** at capture (URL / EMAIL / JSON / CODE / TEXT) with row badges
- ✅ **Quick Look** preview on Space — full content, monospaced, scrollable
- ✅ **First-launch onboarding** (non-modal floating panel)

P2 (v0.4):

- ✅ **Semantic search** via Apple `NLEmbedding` (English sentence model, 512-dim). 100% on-device, no API key, no network. Hybrid order: substring → semantic top-K → fuzzy fallback. Toggle in Preferences → Search.

## Permissions

Mnemo runs with **zero permissions** by default. The only optional permission is **Accessibility**, and only if you turn on _Auto-paste on Enter_ in Preferences. Without it you simply press ⌘V yourself after Enter.

## Build & run

Requires macOS 14+ and Command Line Tools (`xcode-select --install`). Full Xcode is **not** required.

```bash
cd ~/Repos/Mnemo
make run             # build and launch
make install         # build and copy to /Applications
make clean
```

First launch puts an icon in the menu bar. Press **⌥⌘V** anywhere to open the panel.

## Keyboard

| Key | Action |
|---|---|
| ⌥⌘V | Open / close the panel (global, rebindable) |
| Type | Filter history (substring, case-insensitive; fuzzy subsequence fallback) |
| ↑ ↓ | Move selection |
| ⏎ | Copy selection, dismiss, refocus previous app — then ⌘V to paste (or enable auto-paste) |
| Space | Quick Look full content of selected entry (works when search is empty) |
| ⌘P | Pin / unpin selected entry |
| ⌘⌫ | Delete selected entry from history (works when search is empty) |
| ⌘1 … ⌘9 | Quick-pick the Nth result |
| Esc | Dismiss panel (or Quick Look if open) |

## Privacy

- 100% local. Zero network calls.
- History at `~/Library/Application Support/Mnemo/history.json`, mode `0600`.
- **Pause Capture** stops writes until you resume.
- **Clear History…** wipes everything *except pinned entries* (pinned snippets are explicit choices).
- Copies marked as concealed by password managers (1Password, Bitwarden, …) are skipped automatically.
- **Heuristic secret blocker (default ON)** — blocks API keys / tokens at capture time: known prefixes (`sk-`, `ghp_`, `AKIA`, `eyJ`, `ya29.`, `xoxb-`, `glpat-`, PEM blocks, …) and single-line high-entropy tokens (Shannon ≥ 4.2, mixed character classes). Opt-out in Preferences → Privacy.

## Storage limits

- Up to 2,000 entries.
- Up to 1 MB per entry — longer is truncated and flagged.
- 30-day retention (soft — applied once cap exceeded).

## Roadmap

See the Obsidian vault `07 - Backlog & Roadmap.md`. Next up:

- Image / file / rich-text capture with type-aware previews
- Per-app exclusion list (skip capture from designated bundle IDs)
- Type-filtered search operators (`/url`, `/json`, `/pin`)
- Snippet templates with `{{placeholders}}`
- Migrate persistence to SQLite + FTS5 once entries grow
- Notarized DMG + Homebrew cask
- iCloud sync (opt-in, end-to-end encrypted)
