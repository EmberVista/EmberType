#!/bin/bash
# Full EmberType dictation test run. No mic, no clicks, no real app data touched.
#   1. unit tests        swift test (processor, cursor rules, token timings)
#   2. speech model      real Parakeet v2+v3 on synthetic speech, 5 voices, vs baseline
#   3. real app          dev build dictating into TextEdit (skip with --no-app)
set -euo pipefail
cd "$(dirname "$0")"
echo "== 1. unit tests";   swift test 2>&1 | grep -E "error:|failed|Executed [0-9]+ tests, with" | tail -1
echo "== 2. speech model"; python3 scripts/run-asr.py | tail -14
if [ "${1:-}" != "--no-app" ]; then
    echo "== 3. real app";  scripts/dev-app.sh build | tail -1; python3 scripts/e2e-app.py
fi
