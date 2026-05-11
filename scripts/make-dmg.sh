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

if command -v create-dmg >/dev/null 2>&1; then
  echo "→ Packaging ${DMG_NAME} with create-dmg…"
  # create-dmg exits 2 when it cannot codesign the DMG itself; that is
  # fine for an unsigned distribution build.
  create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 600 360 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 180 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 180 \
    --no-internet-enable \
    "${DMG_PATH}" \
    "${APP_BUNDLE}" \
  || true
  if [[ ! -f "${DMG_PATH}" ]]; then
    echo "warning: create-dmg did not produce ${DMG_PATH}; falling back to hdiutil." >&2
  fi
fi

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "→ Packaging ${DMG_NAME} with hdiutil…"
  STAGE_DIR="$(mktemp -d)"
  trap 'rm -rf "${STAGE_DIR}"' EXIT
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
