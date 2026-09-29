#!/bin/bash
# Try the dev build with your own voice and mic. See TRY-IT.md.
#
#   DevHarness/try-it.sh start   quit the real EmberType, start "EmberType Dev" with your hotkey + mic
#   DevHarness/try-it.sh log     what Parakeet heard vs. what was typed, for this session
#   DevHarness/try-it.sh stop    quit EmberType Dev and reopen the real EmberType
#
# Run it from cmux (it lends its Microphone + Accessibility permission to the dev app).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/.build/xcode/Build/Products/Debug/EmberType.app"
REAL="com.embervista.EmberType"
DEV="com.embervista.EmberType.dev"
STATE="$HERE/.build/try-it"
mkdir -p "$STATE"

real_running() { pgrep -f "/Applications/EmberType.app/Contents/MacOS/EmberType" >/dev/null; }

case "${1:-}" in
start)
    [ -d "$APP" ] || "$HERE/scripts/dev-app.sh" build
    # TRYIT_KEEP_REAL=1 skips the swap (used by automated checks of this script).
    if [ -z "${TRYIT_KEEP_REAL:-}" ] && real_running; then
        echo "Quitting your real EmberType (it comes back with: try-it.sh stop)..."
        touch "$STATE/real-was-running"
        osascript -e "tell application id \"$REAL\" to quit" || true
        for _ in $(seq 1 20); do real_running || break; sleep 0.5; done
    fi
    # Same hotkey, mic and model as your real setup.
    for key in selectedHotkey1 selectedHotkey2 isMiddleClickToggleEnabled middleClickActivationDelay \
               audioInputMode selectedAudioDeviceUID prioritizedDevices RecorderType AppendTrailingSpace \
               CurrentTranscriptionModel SelectedLanguage; do
        if defaults export "$REAL" - | plutil -extract "$key" xml1 -o "$STATE/v.plist" - 2>/dev/null; then
            python3 - "$key" "$STATE/v.plist" "$DEV" <<'PY'
import plistlib, subprocess, sys
key, path, domain = sys.argv[1:]
v = plistlib.load(open(path, "rb"))
t = {bool: "-bool", int: "-int", float: "-float", str: "-string"}.get(type(v))
if t: subprocess.run(["defaults", "write", domain, key, t, str(v).lower() if t == "-bool" else str(v)], check=True)
elif isinstance(v, bytes): subprocess.run(["defaults", "write", domain, key, "-data", v.hex()], check=True)
PY
        fi
    done
    defaults write "$DEV" IsSpokenPunctuationEnabled -bool true
    defaults write "$DEV" isAIEnhancementEnabled -bool false
    "$HERE/scripts/dev-app.sh" start >/dev/null
    # Record what the model heard and what was typed (app log, public fields only).
    date "+=== session started %Y-%m-%d %H:%M ===" >> "$STATE/session.log"
    nohup log stream --style compact --level info \
        --predicate 'subsystem == "com.embervista.embertype" AND (eventMessage CONTAINS "Raw transcript" OR eventMessage CONTAINS "Spoken punctuation" OR eventMessage CONTAINS "Formatted transcript")' \
        >> "$STATE/session.log" 2>/dev/null &
    echo $! > "$STATE/log.pid"
    echo "EmberType Dev is running. Spoken punctuation is ON. Use your usual hotkey."
    echo "Instructions: DevHarness/TRY-IT.md    Results: DevHarness/try-it.sh log"
    ;;
log)
    [ -f "$STATE/session.log" ] || { echo "no session yet"; exit 0; }
    python3 - "$STATE/session.log" <<'PY'
import re, sys
for line in open(sys.argv[1]):
    if line.startswith("==="):
        print(line.strip()); continue
    m = re.search(r"(\d\d:\d\d:\d\d).*?📝 (Raw transcript|Spoken punctuation \((\w+)\)|Formatted transcript): (.*)", line)
    if not m: continue
    t, kind, pos, text = m.groups()
    if kind == "Raw transcript": print(f"\n{t}  heard  {text!r}")
    elif pos:                    print(f"          typed  {text!r}   (cursor: {pos})")
    else:                        print(f"          typed  {text!r}   (spoken punctuation OFF)")
PY
    ;;
stop)
    "$HERE/scripts/dev-app.sh" stop >/dev/null || true
    [ -f "$STATE/log.pid" ] && kill "$(cat "$STATE/log.pid")" 2>/dev/null || true
    rm -f "$STATE/log.pid"
    if [ -f "$STATE/real-was-running" ]; then
        open -b "$REAL" && rm -f "$STATE/real-was-running" && echo "Your real EmberType is back."
    fi
    echo "EmberType Dev stopped. Session log kept: DevHarness/try-it.sh log"
    ;;
*) sed -n '2,9p' "$0"; exit 2 ;;
esac
