#!/usr/bin/env bash
# fetch-sparkle.sh — download and unpack the Sparkle framework + tools.
#
# Sparkle is not vendored in the repo. This script fetches the release tarball
# once and extracts:
#   - Frameworks/Sparkle.framework   (linked at build + embedded in app bundle)
#   - Frameworks/bin/sign_update     (used by release.yml to sign DMGs)
#   - Frameworks/bin/generate_appcast (used by release.yml)
#
# Idempotent: re-running with the framework already present is a no-op.
#
# Override version with SPARKLE_VERSION env var.

set -euo pipefail

VERSION="${SPARKLE_VERSION:-2.9.1}"
FRAMEWORKS_DIR="Frameworks"
SPARKLE_FRAMEWORK="${FRAMEWORKS_DIR}/Sparkle.framework"
VERSION_MARKER="${FRAMEWORKS_DIR}/.sparkle-version"

# Pinned SHA256 for Sparkle 2.9.1 tarball — update when bumping VERSION.
# Override with SPARKLE_SHA256 when also overriding SPARKLE_VERSION.
EXPECTED_SHA256="${SPARKLE_SHA256:-c0dde519fd2a43ddfc6a1eb76aec284d7d888fe281414f9177de3164d98ba4c7}"

if [[ -d "${SPARKLE_FRAMEWORK}" ]] && \
   [[ -x "${FRAMEWORKS_DIR}/bin/sign_update" ]] && \
   [[ -x "${FRAMEWORKS_DIR}/bin/generate_appcast" ]] && \
   [[ -x "${FRAMEWORKS_DIR}/bin/generate_keys" ]] && \
   [[ -f "${VERSION_MARKER}" ]] && \
   [[ "$(cat "${VERSION_MARKER}")" == "${VERSION}" ]]; then
  echo "→ Sparkle.framework ${VERSION} already present at ${FRAMEWORKS_DIR}"
  exit 0
fi

mkdir -p "${FRAMEWORKS_DIR}"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

URL="https://github.com/sparkle-project/Sparkle/releases/download/${VERSION}/Sparkle-${VERSION}.tar.xz"
echo "→ Downloading Sparkle ${VERSION}…"
curl -L --fail -o "${TMP}/sparkle.tar.xz" "${URL}"

echo "→ Verifying integrity…"
ACTUAL_SHA256=$(shasum -a 256 "${TMP}/sparkle.tar.xz" | awk '{print $1}')
if [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]]; then
  echo "ERROR: SHA256 mismatch! expected=${EXPECTED_SHA256} actual=${ACTUAL_SHA256}" >&2
  exit 1
fi

echo "→ Extracting…"
tar -xf "${TMP}/sparkle.tar.xz" -C "${TMP}"

cp -R "${TMP}/Sparkle.framework" "${FRAMEWORKS_DIR}/"
mkdir -p "${FRAMEWORKS_DIR}/bin"
cp "${TMP}/bin/sign_update" "${FRAMEWORKS_DIR}/bin/sign_update"
cp "${TMP}/bin/generate_appcast" "${FRAMEWORKS_DIR}/bin/generate_appcast"
cp "${TMP}/bin/generate_keys" "${FRAMEWORKS_DIR}/bin/generate_keys"
chmod +x "${FRAMEWORKS_DIR}/bin/"*

echo "${VERSION}" > "${VERSION_MARKER}"
echo "→ Sparkle ${VERSION} ready at ${SPARKLE_FRAMEWORK}"
