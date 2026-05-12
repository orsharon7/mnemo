#!/usr/bin/env bash
# make-dmg.sh — Package build/Mnemo.app into a distributable DMG.
#
# Usage:
#   scripts/make-dmg.sh [version]
#
# If [version] is omitted, the DMG will be named Mnemo.dmg; otherwise
# Mnemo-<version>.dmg (e.g. Mnemo-v0.5.0.dmg).
#
# Prefers `create-dmg` (Homebrew) for a polished installer window with
# a drag-to-Applications layout. Falls back to plain `hdiutil` when
# create-dmg is unavailable (e.g. minimal CI environment).

set -euo pipefail

APP_NAME="Mnemo"
APP_BUNDLE="build/${APP_NAME}.app"
VERSION="${1:-}"

# Validate VERSION to prevent path traversal: reject '/' and '..'
if [[ -n "${VERSION}" ]]; then
  if [[ "${VERSION}" == *"/"* || "${VERSION}" == *".."* ]]; then
    echo "error: VERSION '${VERSION}' contains disallowed characters ('/' or '..'); aborting." >&2
    exit 1
  fi
fi

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "error: ${APP_BUNDLE} not found — run 'make' first." >&2
  exit 1
fi

if [[ -n "${VERSION}" ]]; then
  DMG_NAME="${APP_NAME}-${VERSION}.dmg"
else
  DMG_NAME="${APP_NAME}.dmg"
fi

OUT_DIR="build"
DMG_PATH="${OUT_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

# Single EXIT trap cleans up both possible stage dirs (guarded with :-).
CDG_STAGE=""
STAGE_DIR=""
cleanup() {
  [[ -n "${CDG_STAGE:-}" ]] && rm -rf -- "${CDG_STAGE}"
  [[ -n "${STAGE_DIR:-}"  ]] && rm -rf -- "${STAGE_DIR}"
}
trap cleanup EXIT

if command -v create-dmg >/dev/null 2>&1; then
  echo "→ Packaging ${DMG_NAME} with create-dmg…"
  # create-dmg requires the source to be a *directory* containing the .app,
  # not the .app bundle itself, so that --icon / --hide-extension can locate
  # "${APP_NAME}.app" inside the source folder.
  CDG_STAGE="$(mktemp -d)"
  cp -R "${APP_BUNDLE}" "${CDG_STAGE}/"
  ln -s /Applications "${CDG_STAGE}/Applications"

  # create-dmg exits 2 when it cannot codesign the DMG itself; that is
  # fine for an unsigned distribution build.  Any other non-zero exit is a
  # real failure — log it and fall through to the hdiutil path.
  # Temporarily disable -e so we can inspect the exit code ourselves.
  set +e
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DMG_BG="${SCRIPT_DIR}/dmg-background.png"
  CDG_BG_ARG=()
  [[ -f "${DMG_BG}" ]] && CDG_BG_ARG=(--background "${DMG_BG}")

  create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 600 360 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 180 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 180 \
    --no-internet-enable \
    "${CDG_BG_ARG[@]}" \
    "${DMG_PATH}" \
    "${CDG_STAGE}"
  CDG_EXIT=$?
  set -e
  if [[ ${CDG_EXIT} -eq 2 ]]; then
    echo "note: create-dmg exited 2 (codesign not available) — DMG is still usable." >&2
  elif [[ ${CDG_EXIT} -ne 0 ]]; then
    echo "warning: create-dmg failed (exit ${CDG_EXIT}); falling back to hdiutil." >&2
    rm -f "${DMG_PATH}"
  fi
fi

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "→ Packaging ${DMG_NAME} with hdiutil…"
  STAGE_DIR="$(mktemp -d)"
  cp -R "${APP_BUNDLE}" "${STAGE_DIR}/"
  ln -s /Applications "${STAGE_DIR}/Applications"
  hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGE_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"
fi

echo "→ Built ${DMG_PATH}"
