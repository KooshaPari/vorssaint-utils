#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Notarizes and staples a built artifact (the .app or the .dmg) with Apple's
# notary service, so Gatekeeper opens it without the "unverified developer"
# warning. Run in CI: once on the app (before packaging) and once on the DMG.
#
# Two credential routes, in this order:
#
#   1. A stored keychain profile:  NOTARY_PROFILE
#      Created once, interactively, in a logged-in GUI session:
#        xcrun notarytool store-credentials vorssaint-notary \
#            --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>
#      Then NOTARY_PROFILE=vorssaint-notary is all a build needs. This is the
#      route that survives a new shell, a reboot and a CI secret rotation, and
#      it is the one a human at the keyboard can set up in one command.
#
#   2. The App Store Connect API key, from the environment (CI secrets):
#        NOTARY_API_KEY_P8   base64 of the .p8 (never a path, never printed)
#        NOTARY_KEY_ID       the key's ID
#        NOTARY_ISSUER_ID    the issuer UUID
#
# Usage:
#   Tools/notarize.sh <app-or-dmg>     notarize and staple
#   Tools/notarize.sh --preflight      report which route is usable, change nothing
#
# When no route is usable it skips quietly (exit 0), so a plain build without
# notarization still succeeds. --preflight exits 2 in that case, which is what
# makes "why is F1 blocked" answerable in one command instead of a search.
# REQUIRE_NOTARIZATION=1 turns the skip into a failure, for a release build.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-}"
have_key_route=0
if [[ -n "${NOTARY_API_KEY_P8:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
    have_key_route=1
fi

preflight() {
    print "Notarization credential check"
    print "  route 1: keychain profile (NOTARY_PROFILE)"
    if [[ -n "$PROFILE" ]]; then
        print "    NOTARY_PROFILE=$PROFILE is set"
        if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
            print "    ✓ the profile authenticates with the notary service"
            return 0
        fi
        print "    ✗ the profile is set but the notary service rejected it or the keychain is locked"
        print "      a locked login keychain in a non-GUI session produces this; retry from Terminal.app"
    else
        print "    ✗ NOTARY_PROFILE is not set"
    fi
    print "  route 2: App Store Connect API key (NOTARY_API_KEY_P8 + NOTARY_KEY_ID + NOTARY_ISSUER_ID)"
    if [[ $have_key_route -eq 1 ]]; then
        print "    ✓ all three values are present"
        return 0
    fi
    for name in NOTARY_API_KEY_P8 NOTARY_KEY_ID NOTARY_ISSUER_ID; do
        if [[ -z "${(P)name:-}" ]]; then
            print "    ✗ $name is not set"
        fi
    done
    print ""
    print "No usable route. The .p8 must be base64 of the key's bytes, not a path."
    print "Nothing to do beyond providing one of the two routes above."
    return 2
}

if [[ "${1:-}" == "--preflight" ]]; then
    preflight
    exit $?
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo "usage: notarize.sh <app-or-dmg>" >&2
    echo "       notarize.sh --preflight" >&2
    exit 1
fi

AUTH=()
P8=""
if [[ -n "$PROFILE" ]]; then
    AUTH=(--keychain-profile "$PROFILE")
elif [[ $have_key_route -eq 1 ]]; then
    WORK_KEY="$(mktemp -d)"
    trap 'rm -rf "$WORK_KEY"' EXIT
    P8="$WORK_KEY/AuthKey.p8"
    printf '%s' "$NOTARY_API_KEY_P8" | base64 --decode > "$P8"
    AUTH=(--key "$P8" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
else
    if [[ "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
        echo "Release notarization credentials are incomplete — run Tools/notarize.sh --preflight" >&2
        exit 1
    fi
    echo "No notarization credentials in the environment — skipping ($TARGET)."
    echo "Run Tools/notarize.sh --preflight to see which route is missing."
    exit 0
fi
if [[ ! -e "$TARGET" ]]; then
    echo "✗ $TARGET not found" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; [[ -n "$P8" ]] && rm -f "$P8"' EXIT

# notarytool needs a zip/dmg/pkg. A .app is zipped first; a .dmg is submitted
# as-is. Stapling always targets the original artifact.
case "$TARGET" in
    *.app)
        xattr -cr "$TARGET"
        codesign --verify --deep --strict "$TARGET"
        SUBMIT="$WORK/$(basename "$TARGET").zip"
        /usr/bin/ditto -c -k --keepParent "$TARGET" "$SUBMIT"
        ;;
    *)
        SUBMIT="$TARGET"
        ;;
esac

echo "▸ Submitting $(basename "$TARGET") to the notary service (can take a few minutes)…"
xcrun notarytool submit "$SUBMIT" "${AUTH[@]}" --wait

# Staple the ticket so it is recognized even offline. Fails (and fails the build)
# if notarization did not actually succeed, so a bad result never ships.
echo "▸ Stapling $(basename "$TARGET")…"
xcrun stapler staple "$TARGET"
echo "✓ Notarized and stapled: $(basename "$TARGET")"
