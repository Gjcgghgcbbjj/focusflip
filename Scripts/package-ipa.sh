#!/bin/bash
# =============================================================================
# Package a .xcarchive into a TrollStore-installable .ipa
# Usage: package-ipa.sh <path-to-xcarchive>
# =============================================================================
set -euo pipefail

ARCHIVE_PATH="${1:?Usage: package-ipa.sh <xcarchive-path>}"
APP_NAME="FocusFlip"
APP_VERSION="1.0.0"

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

# --- Locate ldid ---
LDID=""
for candidate in "$(which ldid 2>/dev/null)" \
                 "/opt/homebrew/bin/ldid" \
                 "/usr/local/bin/ldid"; do
    if [ -x "$candidate" ]; then
        LDIS="$candidate"
        LIDID="$candidate"
        LDID="$candidate"
        break
    fi
done
if [ -z "$LDID" ]; then
    echo "[pkg] ldid not found, installing via brew..."
    brew install ldid
    LDID="$(which ldid)"
fi
echo "[pkg] Using ldid: ${LDID}"

# --- Copy entitlements next to the app for signing ---
cp "${PROJECT_DIR}/FocusFlip.entitlements" "${BUILD_DIR}/" 2>/dev/null || true

# --- Fake-sign the binary with entitlements ---
BINARY="${APP_PATH}/${APP_NAME}"
echo "[pkg] Signing ${BINARY} with entitlements..."
"${LDID}" -S"${PROJECT_DIR}/FocusFlip.entitlements" "${BINARY}" || {
    echo "[pkg] WARNING: ldid signing failed, proceeding without entitlements"
    "${LDID}" -S "${BINARY}" || true
}

# --- Build IPA ---
echo "[pkg] Packaging IPA..."
PAYLOAD_DIR="${BUILD_DIR}/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

cd "$BUILD_DIR"
zip -r -q "$IPA_FILE" Payload/ FocusFlip.entitlements 2>/dev/null || zip -r -q "$IPA_FILE" Payload/
rm -rf Payload/

# --- Done ---
echo ""
echo "[pkg] ✅ IPA built successfully"
echo "      File: ${IPA_FILE}"
echo "      Size: $(du -h "$IPA_FILE" | cut -f1)"
echo ""
echo "      Install via TrollStore:"
echo "        1. Download the artifact from GitHub Actions"
echo "        2. Open in TrollStore on your iOS device"
echo "        3. Tap Install"
echo ""
