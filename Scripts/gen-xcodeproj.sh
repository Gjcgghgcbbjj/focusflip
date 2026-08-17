#!/bin/bash
# =============================================================================
# Generate Xcode project from project.yml using xcodegen
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! command -v xcodegen &>/dev/null; then
    echo "[gen] Installing xcodegen..."
    brew install xcodegen
fi

echo "[gen] Generating Xcode project..."
xcodegen generate

echo "[gen] ✅ FocusFlip.xcodeproj created"
