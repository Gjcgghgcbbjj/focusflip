#!/bin/bash
# =============================================================================
# Package a .xcarchive into a TrollStore-installable .ipa
#
# IMPORTANT: This script does NOT pre-sign the binary.
# TrollStore signs apps itself at install time and injects its own
# platform-application entitlements. Pre-signing with speculative
# entitlements caused crash-on-launch — so we deliberately skip it.
#
# Usage: package-ipa.sh <path-to-xcarchive>
# =============================================================================
set -euo pipefail

ARCHIVE_PATH="${1:?Usage: package-ipa.sh <xcarchive-path>}"
APP_NAME="FocusFlip"
APP_VERSION="${APP_VERSION:-1.0.0}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
IPA_FILE="${BUILD_DIR}/${APP_NAME}-${APP_VERSION}.ipa"

# --- Locate the .app inside the archive ---
APP_PATH=$(find "${ARCHIVE_PATH}" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: ${APP_NAME}.app not found in archive at ${ARCHIVE_PATH}"
    find "${ARCHIVE_PATH}" -name "*.app" -type d
    exit 1
fi
echo "[pkg] Found app: ${APP_PATH}"

# --- Sanity check: binary exists ---
if [ ! -f "${APP_PATH}/${APP_NAME}" ]; then
    echo "ERROR: binary ${APP_PATH}/${APP_NAME} not found"
    exit 1
fi
echo "[pkg] Binary exists: $(( $(stat -f%z "${APP_PATH}/${APP_NAME}" 2>/dev/null || stat -c%s "${APP_PATH}/${APP_NAME}" 2>/dev/null) / 1024 )) KB"

# --- Remove any code signature from the binary ---
# (xcodebuild with CODE_SIGNING_ALLOWED=NO leaves it unsigned, but be safe)
# Strip ad-hoc signature if present
if command -v codesign &>/dev/null; then
    codesign --remove-signature "${APP_PATH}/${APP_NAME}" 2>/dev/null || true
fi

# --- Build IPA (unsigned — TrollStore signs on install) ---
echo "[pkg] Packaging unsigned IPA..."
PAYLOAD_DIR="${BUILD_DIR}/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

cd "$BUILD_DIR"
rm -f "$IPA_FILE"
zip -r -q "$IPA_FILE" Payload/
rm -rf Payload/

# --- Done ---
echo ""
echo "[pkg] ✅ IPA built successfully (unsigned, TrollStore will sign)"
echo "      File: ${IPA_FILE}"
echo "      Size: $(du -h "$IPA_FILE" | cut -f1)"
echo ""
echo "      Install via TrollStore:"
echo "        1. Download the artifact from GitHub Actions"
echo "        2. Open in TrollStore on your iOS device"
echo "        3. Tap Install"
echo ""
