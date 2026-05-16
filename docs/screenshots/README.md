# Mnemo screenshots

This folder holds the visual assets embedded in the top-level `README.md`.

## Files

| Filename | Used in README | What it should show |
|---|---|---|
| `panel-hero.png` | Hero image above the keyboard table | The history panel open over a real macOS desktop, with a few representative entries (text, URL, JSON, code) and a search query that surfaces a semantic match. ~1200 px wide. |
| `demo.gif` | Animated demo below the hero | A 10-15 second loop: ⌥⌘V to open → type a query → ↑↓ navigate → ⏎ to copy → app refocuses and pastes. ≤ 3 MB, ≤ 900 px wide, 15 fps. |
| `menubar-stats.png` | Optional, "Stats" section | The Stats… window with a populated 7-day chart. |

## Why placeholders?

Mnemo is built from a Command-Line-Tools-only environment that **cannot grant
itself macOS Screen Recording permission**, so the build agent can't capture
these itself. The maintainer records them manually and drops the files in here.

Until real PNG/GIF assets land, the README links to the SVG placeholders next
to this file so the document never has broken image references.

## Recording the GIF

1. Use macOS's built-in screen recorder: `Cmd+Shift+5` → "Record Selected
   Portion" → drag a tight rectangle around the panel area → Record.
2. Trim in QuickTime if needed (`Cmd+T`) so the loop is 10-15 seconds.
3. Convert with the included script (requires `ffmpeg` from Homebrew):

   ```bash
   brew install ffmpeg            # one-time
   scripts/make-readme-gif.sh path/to/recording.mov docs/screenshots/demo.gif
   ```

   The script generates a tuned palette first (`palettegen`), then encodes the
   GIF with `paletteuse` for clean colors at small file sizes. Tweak `WIDTH`
   and `FPS` env vars if the file is over 3 MB:

   ```bash
   WIDTH=720 FPS=12 scripts/make-readme-gif.sh recording.mov docs/screenshots/demo.gif
   ```

## Recording the hero PNG

1. Open Mnemo (⌥⌘V) on a clean desktop, pre-populated with a handful of
   representative copies (text, a URL, a small JSON blob, a code snippet,
   one pinned entry).
2. Type a 3-5 letter query that produces a non-substring semantic match so
   the magic is visible.
3. `Cmd+Shift+4` → tap Space → click the panel window → save into this
   folder as `panel-hero.png`.
4. Optimize size with `pngquant` (optional):

   ```bash
   brew install pngquant
   pngquant --force --output docs/screenshots/panel-hero.png 256 docs/screenshots/panel-hero.png
   ```
