#!/usr/bin/env bash
# scripts/make-readme-gif.sh
#
# Convert a screen recording (.mov / .mp4) into an optimized GIF suitable for
# embedding in README.md. Tuned for ~3 MB or smaller at 900px / 15 fps.
#
# Usage:
#   scripts/make-readme-gif.sh INPUT [OUTPUT]
#
# Env overrides:
#   WIDTH=720         override max width  (default 900)
#   FPS=12            override frame rate (default 15)
#   START=00:00:00    trim start  (passed as -ss before -i)
#   DURATION=14       trim length (passed as -t)
#
# Requires: ffmpeg (brew install ffmpeg).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") INPUT [OUTPUT]" >&2
  exit 64
fi

INPUT="$1"
OUTPUT="${2:-docs/screenshots/demo.gif}"
WIDTH="${WIDTH:-900}"
FPS="${FPS:-15}"
START="${START:-}"
DURATION="${DURATION:-}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "error: ffmpeg not found. Install with: brew install ffmpeg" >&2
  exit 127
fi

if [[ ! -f "$INPUT" ]]; then
  echo "error: input file not found: $INPUT" >&2
  exit 66
fi

mkdir -p "$(dirname "$OUTPUT")"

PALETTE="$(mktemp -t mnemo-palette).png"
trap 'rm -f "$PALETTE"' EXIT

TRIM_ARGS=()
[[ -n "$START"    ]] && TRIM_ARGS+=(-ss "$START")
[[ -n "$DURATION" ]] && TRIM_ARGS+=(-t  "$DURATION")

FILTER="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"

echo "→ Generating palette ($WIDTH px @ ${FPS} fps)…"
ffmpeg -y -hide_banner -loglevel warning \
  "${TRIM_ARGS[@]}" -i "$INPUT" \
  -vf "${FILTER},palettegen=stats_mode=diff" \
  "$PALETTE"

echo "→ Encoding GIF → $OUTPUT"
ffmpeg -y -hide_banner -loglevel warning \
  "${TRIM_ARGS[@]}" -i "$INPUT" -i "$PALETTE" \
  -lavfi "${FILTER} [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  "$OUTPUT"

SIZE_KB=$(( $(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT") / 1024 ))
echo "→ Done: ${OUTPUT} (${SIZE_KB} KB)"
if (( SIZE_KB > 3072 )); then
  echo "warning: ${SIZE_KB} KB exceeds the 3 MB README budget." >&2
  echo "         Try: WIDTH=720 FPS=12 $(basename "$0") $INPUT $OUTPUT" >&2
fi
