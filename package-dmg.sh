#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

zsh build-app.sh

DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$(mktemp -d /tmp/AppStoreSwitcher-dmg.XXXXXX)"
DMG_PATH="$DIST_DIR/App Store 账号管理-0.1.0.dmg"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
cp -R "$PROJECT_DIR/App Store 账号管理.app" "$STAGING_DIR/App Store 账号管理.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "App Store 账号管理" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "已生成: $DMG_PATH"
