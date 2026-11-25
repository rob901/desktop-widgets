#!/bin/zsh
# Builds a widget app's SwiftPM executable and wraps it in a signed .app.
#
#   bundle-app.sh <package-dir> <executable-name> [install]
#
# The package dir must contain Info.plist (CFBundleExecutable = executable-name).
# Output: <package-dir>/build/<executable-name>.app
# `install` also replaces /Applications/<name>.app and launches it.
set -euo pipefail
PKG=$(cd "$1" && pwd)
NAME=$2
MODE=${3:-}
cd "$PKG"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/$NAME"

APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/$NAME"
codesign --force --sign - "$APP" >/dev/null
echo "Built $PKG/$APP"

if [[ "$MODE" == "install" ]]; then
  pkill -x "$NAME" 2>/dev/null || true
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$NAME.app"
  echo "Installed to /Applications and launched"
fi
