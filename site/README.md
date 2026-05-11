# Mnemo — Landing Page

This directory contains the marketing site for [Mnemo](https://github.com/orsharon7/mnemo), a tiny native macOS clipboard manager.

It is a single-page static site: plain HTML5, one stylesheet, one SVG asset, no JavaScript, no tracking, no build step.

## Files

- `index.html` — the page
- `style.css` — styles (light + dark via `prefers-color-scheme`)
- `assets/screenshot-placeholder.svg` — hero illustration placeholder

## Preview locally

From the repo root:

```bash
cd site
python3 -m http.server 8000
```

Then open <http://localhost:8000>.

Any other static file server works equally well (`npx serve`, `caddy file-server`, etc.).

## Deploy

The site is designed to be deployed directly as static files. The simplest option is **GitHub Pages from `/site`**:

1. Push this branch to `main` (or merge it).
2. In the repo settings → **Pages**, set:
   - **Source**: `Deploy from a branch`
   - **Branch**: `main` · **Folder**: `/site`
3. GitHub will serve it at `https://orsharon7.github.io/mnemo/`.

Alternative one-click hosts: Netlify, Vercel, Cloudflare Pages — point them at the `site/` directory and they will serve it as-is.

## Customizing

- Update the download link in `index.html` (the `Download latest release` CTAs) if the release URL changes.
- Replace `assets/screenshot-placeholder.svg` with a real product screenshot when one is available; the `<img>` tag in the hero is sized to fit a ~960×600 image.
