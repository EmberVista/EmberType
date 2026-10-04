#!/bin/bash
# Build and run an isolated dev copy of EmberType for automated testing.
#
#   scripts/dev-app.sh build   Debug build, bundle id com.embervista.EmberType.dev, ad hoc signed
#   scripts/dev-app.sh start [ARGS]   launch it in a sandbox home (see below), with the debug dictation hook;
#                              ARGS replace -forceLicensed (e.g. -forceTrialDays 2)
#   scripts/dev-app.sh stop
#   scripts/dev-app.sh set KEY TYPE VALUE   write a setting in the dev profile (defaults syntax, e.g. -bool true)
#   scripts/dev-app.sh reset   wipe the dev profile
#
# Isolation: the bundle id gives the dev app its own preferences domain
# (~/Library/Preferences/com.embervista.EmberType.dev.plist), and
# CFFIXED_USER_HOME=DevHarness/.devhome moves its history database and
# recordings (which the app keeps at a fixed Application Support path) out of
# the real ~/Library. Only the Parakeet model files are shared (symlinked).
# It is launched by executable path, so macOS attributes Accessibility to the
# terminal that runs this script; no permission prompts for the dev build.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
DEVHOME="$HERE/.devhome"
DERIVED="$HERE/.build/xcode"
APP="$DERIVED/Build/Products/Debug/EmberType.app"
BUNDLE_ID="com.embervista.EmberType.dev"
# Reuse Xcode's package checkouts when present (no network needed).
PKGS="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/VoiceInk-*/SourcePackages 2>/dev/null | head -1 || true)"

prefs() { defaults "$@"; }

case "${1:-}" in
build)
    args=(-project "$REPO/VoiceInk.xcodeproj" -scheme EmberType -configuration Debug
          -derivedDataPath "$DERIVED" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGNING_ALLOWED=NO)
    [ -n "$PKGS" ] && args+=(-clonedSourcePackagesDirPath "$PKGS")
    xcodebuild "${args[@]}" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName EmberType Dev" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string EmberType Dev" "$APP/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName EmberType Dev" "$APP/Contents/Info.plist"
    # Ad hoc sign inside-out. The dev entitlements drop keychain-access-groups,
    # which needs a provisioning profile; no hardened runtime, so ad hoc
    # frameworks load.
    find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -exec codesign --force --sign - {} \;
    codesign --force --sign - --entitlements "$HERE/dev.entitlements" "$APP"
    codesign --verify --deep --strict "$APP" && echo "signed: $APP"
    ;;
start)
    shift
    license_args=("$@"); [ $# -eq 0 ] && license_args=(-forceLicensed)
    "$0" stop >/dev/null 2>&1 || true
    mkdir -p "$DEVHOME/Library/Application Support"
    ln -sfn "$HOME/Library/Application Support/FluidAudio" "$DEVHOME/Library/Application Support/FluidAudio"
    prefs write "$BUNDLE_ID" hasCompletedOnboarding -bool true
    prefs write "$BUNDLE_ID" EmberTypeHasLaunchedBefore -bool true
    prefs write "$BUNDLE_ID" EmberTypeAffiliatePromotionDismissed -bool true
    prefs write "$BUNDLE_ID" enableAnnouncements -bool false
    prefs write "$BUNDLE_ID" autoUpdateCheck -bool false
    prefs write "$BUNDLE_ID" SUEnableAutomaticChecks -bool false
    prefs write "$BUNDLE_ID" SUHasLaunchedBefore -bool true
    prefs write "$BUNDLE_ID" isSystemMuteEnabled -bool false
    prefs write "$BUNDLE_ID" isSoundFeedbackEnabled -bool false
    prefs write "$BUNDLE_ID" isAIEnhancementEnabled -bool false
    prefs write "$BUNDLE_ID" "ParakeetModelDownloaded_parakeet-tdt-0.6b-v2" -bool true
    prefs write "$BUNDLE_ID" "ParakeetModelDownloaded_parakeet-tdt-0.6b-v3" -bool true
    prefs read "$BUNDLE_ID" CurrentTranscriptionModel >/dev/null 2>&1 || \
        prefs write "$BUNDLE_ID" CurrentTranscriptionModel "parakeet-tdt-0.6b-v3"
    CFFIXED_USER_HOME="$DEVHOME" nohup "$APP/Contents/MacOS/EmberType" "${license_args[@]}" -debugDictationHook \
        >"$HERE/.build/dev-app.log" 2>&1 &
    echo "started pid $! (log: $HERE/.build/dev-app.log)"
    ;;
stop)
    pkill -f "$APP/Contents/MacOS/EmberType" && echo stopped || echo "not running"
    ;;
set)
    shift; prefs write "$BUNDLE_ID" "$@"
    ;;
reset)
    "$0" stop >/dev/null 2>&1 || true
    rm -rf "$DEVHOME"
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "dev profile removed"
    ;;
*)
    sed -n '2,16p' "$0"; exit 2 ;;
esac
