#!/bin/bash
# =============================================================================
# FocusFlip — Build script for TrollStore-installable IPA
# =============================================================================
# Requirements:
#   - theos (https://theos.dev) installed at $THEOS
#   - iOS SDK (iPhoneOS15.6.sdk or newer) under $THEOS/sdks/
#   - ldid for fake-signing
#   - Swift toolchain (bundled with theos on Linux/macOS)
#
# Usage:
#   chmod +x Scripts/build-ipa.sh
#   ./Scripts/build-ipa.sh
#
# Output:
#   build/FocusFlip-1.0.0.ipa
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
APP_NAME="FocusFlip"
APP_VERSION="1.0.0"
BUNDLE_ID="com.focusflip.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
IPA_FILE="${BUILD_DIR}/${APP_NAME}-${APP_VERSION}.ipa"

# --- Theos setup -------------------------------------------------------------
export THEOS="${THEOS:-/opt/theos}"
if [ ! -d "$THEOS" ]; then
    # Try local theos checkout
    if [ -d "${PROJECT_DIR}/../theos" ]; then
        export THEOS="${PROJECT_DIR}/../theos"
    else
        echo "ERROR: theos not found. Set \$THEOS or install theos."
        echo "  macOS:  brew install ldid fake"
        echo "  Linux:  see https://theos.dev/install"
        exit 1
    fi
fi

echo "============================================"
echo "  Building ${APP_NAME} ${APP_VERSION}"
echo "  Project:  ${PROJECT_DIR}"
echo "  Theos:    ${THEOS}"
echo "============================================"

cd "$PROJECT_DIR"

# --- Clean previous build ----------------------------------------------------
echo "[1/5] Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Build with theos --------------------------------------------------------
echo "[2/5] Compiling Swift sources..."
make clean 2>/dev/null || true
make package FINALPACKAGE=1

# --- Locate the built .app ---------------------------------------------------
# theos outputs to .theos/obj/debug or .theos/obj/release
APP_PATH=$(find .theos -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: ${APP_NAME}.app not found after build."
    echo "  Checked: .theos/**/${APP_NAME}.app"
    exit 1
fi
echo "  Built app at: ${APP_PATH}"

# --- Fake-sign with ldid -----------------------------------------------------
echo "[3/5] Fake-signing with ldid..."
LDID_BIN=""
for candidate in "${THEOS}/toolchain/linux/iphone/swift/bin/ldid" \
                 "${THEOS}/bin/ldid" \
                 "$(which ldid 2>/dev/null)" \
                 "/usr/local/bin/ldid" \
                 "/usr/bin/ldid"; do
    if [ -x "$candidate" ]; then
        LDID_BIN="$candidate"
        break
    fi
done

if [ -z "$LDID_BIN" ]; then
    echo "ERROR: ldid not found. Install it:"
    echo "  macOS:  brew install ldid"
    echo "  Linux:  see theos docs"
    exit 1
fi

echo "  Using ldid: ${LDID_BIN}"
"$LDID_BIN" -S"${PROJECT_DIR}/FocusFlip.entitlements" "${APP_PATH}/${APP_NAME}"

# --- Package into IPA --------------------------------------------------------
echo "[4/5] Packaging IPA..."
PAYLOAD_DIR="${BUILD_DIR}/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

# Copy entitlements into IPA for TrollStore reference
cp "${PROJECT_DIR}/FocusFlip.entitlements" "${BUILD_DIR}/"

cd "$BUILD_DIR"
zip -r -q "$IPA_FILE" Payload/ FocusFlip.entitlements
rm -rf Payload/

# --- Done --------------------------------------------------------------------
echo "[5/5] Done!"
echo ""
echo "  IPA: ${IPA_FILE}"
echo "  Size: $(du -h "$IPA_FILE" | cut -f1)"
echo ""
echo "  Install via TrollStore:"
echo "    1. Transfer ${IPA_FILE} to your iOS device"
echo "    2. Open in TrollStore"
echo "    3. Tap Install"
echo "    4. App appears on home screen"
echo ""
