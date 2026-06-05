#!/usr/bin/env bash
#
# Build, install into /Applications, and relaunch the Prayer Times menu bar app.
#
# Usage:
#   ./scripts/run.sh      # regenerate (if needed) + build + install + relaunch
#   ./scripts/run.sh -g   # force `xcodegen generate` first
#   ./scripts/run.sh -r   # build Release instead of Debug
#   ./scripts/run.sh -q   # just quit the running app (no build)
#
set -euo pipefail

# Operate from the repo root (this script lives in scripts/).
cd "$(dirname "$0")/.."

INSTALL_DIR="/Applications"
PROJECT="PrayerTimes.xcodeproj"
SCHEME="PrayerTimes"
CONFIG="Debug"
APP_PROCESS="Prayer Times.app/Contents/MacOS"
FORCE_GENERATE=0
QUIT_ONLY=0

while getopts "grqh" opt; do
  case "$opt" in
    g) FORCE_GENERATE=1 ;;
    r) CONFIG="Release" ;;
    q) QUIT_ONLY=1 ;;
    h) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option. Use -h for help."; exit 1 ;;
  esac
done

kill_app() {
  if pgrep -f "$APP_PROCESS" >/dev/null; then
    echo "→ Quitting running instance…"
    pkill -f "$APP_PROCESS" || true
    sleep 1
  fi
}

if [[ "$QUIT_ONLY" -eq 1 ]]; then
  kill_app
  echo "✓ Quit."
  exit 0
fi

# Regenerate the Xcode project when missing, forced, or when any source/resource
# is newer than the project (so newly added files/assets are always picked up —
# XcodeGen captures the file list at generate time).
NEWER=""
if [[ -f "$PROJECT/project.pbxproj" ]]; then
  NEWER="$(find PrayerTimes project.yml -newer "$PROJECT/project.pbxproj" 2>/dev/null | head -1)"
fi
if [[ "$FORCE_GENERATE" -eq 1 || ! -d "$PROJECT" || -n "$NEWER" ]]; then
  echo "→ Generating Xcode project…"
  xcodegen generate
fi

echo "→ Building ($CONFIG)…"
# Surface only warnings/errors and the final status; full log on failure.
BUILD_LOG="$(mktemp)"
# Proper ad-hoc signing (no cert/team needed) so the bundle identifier is bound
# and resources are sealed — required for UserNotifications to grant authorization.
# A bare CODE_SIGNING_ALLOWED=NO produces a linker ad-hoc signature that macOS
# treats as identity-less, and the notification prompt never appears.
if ! xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration "$CONFIG" \
      -destination 'platform=macOS' \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=YES \
      CODE_SIGNING_ALLOWED=YES \
      ENABLE_HARDENED_RUNTIME=NO \
      build >"$BUILD_LOG" 2>&1; then
  echo "✗ Build failed:"
  grep -E "error:" "$BUILD_LOG" || tail -30 "$BUILD_LOG"
  rm -f "$BUILD_LOG"
  exit 1
fi
grep -E "warning:.*\.swift" "$BUILD_LOG" | grep -v appintents || true
rm -f "$BUILD_LOG"
echo "✓ Build succeeded."

APP="$(find ~/Library/Developer/Xcode/DerivedData/PrayerTimes-*/Build/Products/"$CONFIG" \
        -maxdepth 1 -name "*.app" 2>/dev/null | head -1)"
if [[ -z "${APP:-}" ]]; then
  echo "✗ Could not locate the built .app."
  exit 1
fi

kill_app

# Install into /Applications by replacing any existing copy, so the app under
# test is the same bundle a user would run (correct identity, Launch Services
# registration, and self-update path).
APP_NAME="$(basename "$APP")"
INSTALLED="$INSTALL_DIR/$APP_NAME"
echo "→ Installing into $INSTALL_DIR (replacing existing)…"
rm -rf "$INSTALLED"
cp -R "$APP" "$INSTALLED"

echo "→ Launching: $INSTALLED"
open "$INSTALLED"
sleep 1
if pgrep -f "$APP_PROCESS" >/dev/null; then
  echo "✓ Running. Look for the item in your menu bar."
else
  echo "✗ App did not stay running."
  exit 1
fi
