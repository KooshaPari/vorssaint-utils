#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Emits the Homebrew cask for a built DMG, so the tap is a copy-paste rather
# than three hand-computed fields. The checksum is computed from the file in
# front of it; nothing about the artifact is assumed.
#
# Usage:
#   Tools/make-cask.sh dist/Vorssaint-<version>.dmg            print the cask
#   Tools/make-cask.sh dist/Vorssaint-<version>.dmg > Casks/x.rb
#
# The URL is the GitHub release asset path, which is the only place a notarized
# DMG may live: a cask pointing at anything unsigned is worse than no cask,
# because `brew install` would then hand Gatekeeper a refusal and call it a
# Vorssaint bug. That is why this does not run until F1 does.
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:-}"
if [[ -z "$DMG" || ! -f "$DMG" ]]; then
    echo "usage: make-cask.sh <built-dmg>" >&2
    exit 1
fi

APP=""
for candidate in build/stage/*.app(N); do
    APP="$candidate"
    break
done
if [[ -z "$APP" ]]; then
    echo "✗ no staged .app; run ./build.sh first so the bundle id and version are read from it" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")"
APP_NAME="$(basename "$APP" .app)"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
ASSET="$(basename "$DMG")"
REPO="$(git config --get remote.origin.url | sed -e 's#^.*github.com[:/]##' -e 's#\.git$##')"

if [[ -z "$REPO" ]]; then
    echo "✗ no GitHub origin; a cask needs an absolute release URL" >&2
    exit 1
fi

cat <<CASK
cask "$(print -r -- "$APP_NAME" | tr '[:upper:]' '[:lower:]')" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/$ASSET",
      verified: "github.com/$REPO/"
  name "$APP_NAME"
  desc "Menu bar utilities for macOS"
  homepage "https://github.com/$REPO"

  depends_on macos: ">= :sonoma"

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Application Support/$BUNDLE_ID",
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/HTTPStorages/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
CASK
