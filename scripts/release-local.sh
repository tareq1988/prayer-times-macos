#!/usr/bin/env bash
#
# Cut a local release: build a universal ad-hoc app, EdDSA-sign it for Sparkle,
# update the appcast, and publish a GitHub Release.
#
# This is the un-notarized path (no Apple Developer ID needed). The build is
# ad-hoc signed, so users right-click → Open on first launch. For notarized
# releases, use the GitHub Actions workflow instead (see RELEASING.md).
#
# Prereqs: Xcode, xcodegen, gh (authenticated), and Sparkle keys in the keychain
# (run .tools/sparkle/bin/generate_keys once). The Sparkle tools are auto-fetched.
#
# Usage:  ./scripts/release-local.sh 0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-local.sh <version>  (e.g. 0.2.0)}"
TAG="v$VERSION"
APP_NAME="Prayer Times"
REPO="tareq1988/prayer-times-macos"
SPARKLE_VERSION="2.6.4"

echo "→ Releasing $TAG"

# 0. Ensure version in project.yml matches.
if ! grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml; then
  echo "✗ project.yml MARKETING_VERSION != $VERSION. Bump it first, commit, then re-run."
  exit 1
fi

# 1. Sparkle tools.
if [[ ! -x .tools/sparkle/bin/generate_appcast ]]; then
  echo "→ Fetching Sparkle tools…"
  mkdir -p .tools && curl -fsSL -o .tools/sparkle.tar.xz \
    "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
  mkdir -p .tools/sparkle && tar -xf .tools/sparkle.tar.xz -C .tools/sparkle
fi

# 2. Build universal, ad-hoc signed, Release.
echo "→ Building universal Release…"
xcodegen generate >/dev/null
rm -rf build && mkdir -p build/dist
xcodebuild -project PrayerTimes.xcodeproj -scheme PrayerTimes -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/dd \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES \
  ENABLE_HARDENED_RUNTIME=NO \
  build >/dev/null
echo "✓ Built ($(lipo -archs "build/dd/Build/Products/Release/$APP_NAME.app/Contents/MacOS/$APP_NAME"))"

# 3. Zip.
ZIP="build/dist/PrayerTimes-$VERSION.zip"
ditto -c -k --keepParent "build/dd/Build/Products/Release/$APP_NAME.app" "$ZIP"

# 4. Sign + appcast (private key from keychain), pointing at the release asset URL.
.tools/sparkle/bin/generate_appcast \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  build/dist >/dev/null
cp build/dist/appcast.xml docs/appcast.xml
echo "✓ Appcast updated"

# 5. Commit + push the appcast.
git add docs/appcast.xml
git commit -m "chore(release): appcast for $TAG" || echo "  (no appcast change)"
git push origin main

# 6. Publish the GitHub Release (creates the tag at current main). Use the
# matching CHANGELOG.md section as the release notes when present; otherwise let
# GitHub auto-generate from commits.
NOTES_FILE="$(mktemp)"
if [[ -f CHANGELOG.md ]] && awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" {grab=1; next}
    grab && /^## \[/ {exit}
    grab && (NF || body) {body=1; print}
  ' CHANGELOG.md > "$NOTES_FILE" && [[ -s "$NOTES_FILE" ]]; then
  gh release create "$TAG" "$ZIP" --title "Prayer Times $TAG" --notes-file "$NOTES_FILE" --target main
else
  gh release create "$TAG" "$ZIP" --title "Prayer Times $TAG" --generate-notes --target main
fi
rm -f "$NOTES_FILE"

echo "✓ Released: https://github.com/$REPO/releases/tag/$TAG"

# 7. Bump the Homebrew cask in the tap (version + sha256). The tap is the single
# source of truth — there is no in-repo copy to keep in sync.
TAP_REPO="tareq1988/homebrew-tap"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
TAP_DIR="$(mktemp -d)/homebrew-tap"
if git clone -q "git@github.com:$TAP_REPO.git" "$TAP_DIR" 2>/dev/null; then
  CASK="$TAP_DIR/Casks/prayer-times.rb"
  sed -i '' -E "s/version \"[^\"]+\"/version \"$VERSION\"/; s/sha256 \"[^\"]+\"/sha256 \"$SHA\"/" "$CASK"
  ( cd "$TAP_DIR" && git add Casks/prayer-times.rb \
      && git commit -q -m "chore: bump prayer-times to $VERSION" \
      && git push -q origin main )
  echo "✓ Homebrew cask bumped to $VERSION in $TAP_REPO"
else
  echo "⚠ Could not clone $TAP_REPO; bump its Casks/prayer-times.rb manually (version: $VERSION, sha256: $SHA)"
fi
