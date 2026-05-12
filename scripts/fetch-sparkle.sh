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

if [[ -d "${SPARKLE_FRAMEWORK}" ]]; then
  echo "→ Sparkle.framework already present at ${SPARKLE_FRAMEWORK}"
  exit 0
fi

mkdir -p "${FRAMEWORKS_DIR}"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

URL="https://github.com/sparkle-project/Sparkle/releases/download/${VERSION}/Sparkle-${VERSION}.tar.xz"
echo "→ Downloading Sparkle ${VERSION}…"
curl -L --fail -o "${TMP}/sparkle.tar.xz" "${URL}"

echo "→ Extracting…"
tar -xf "${TMP}/sparkle.tar.xz" -C "${TMP}"

cp -R "${TMP}/Sparkle.framework" "${FRAMEWORKS_DIR}/"
mkdir -p "${FRAMEWORKS_DIR}/bin"
cp "${TMP}/bin/sign_update" "${FRAMEWORKS_DIR}/bin/sign_update"
cp "${TMP}/bin/generate_appcast" "${FRAMEWORKS_DIR}/bin/generate_appcast"
cp "${TMP}/bin/generate_keys" "${FRAMEWORKS_DIR}/bin/generate_keys"
chmod +x "${FRAMEWORKS_DIR}/bin/"*

echo "→ Sparkle ${VERSION} ready at ${SPARKLE_FRAMEWORK}"
