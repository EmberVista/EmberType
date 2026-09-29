# DevHarness

Automated testing for EmberType's dictation pipeline. No microphone, no clicks,
and the real installed EmberType (its settings, history and license) is never
touched.

```bash
DevHarness/test-all.sh          # everything (~3 min; layer 3 briefly takes keyboard focus)
DevHarness/test-all.sh --no-app # layers 1–2 only, safe to run while using the Mac
```

## Layers

| Layer | What runs | Command |
|---|---|---|
| 1. Unit | `SpokenPunctuationProcessor`, `CursorContextService`, token-timing restore, on fixed model-shaped strings | `swift test` |
| 2. Speech model | macOS `say` renders `corpus/cases.json` in 5 voices → real Parakeet v2 + v3 → the app's text pipeline. Compared to `corpus/results/baseline.json`; fails only on regressions | `python3 scripts/run-asr.py [--update-baseline]` |
| 3. Real app | Debug build of the app dictates corpus WAVs into TextEdit through its real transcribe → process → paste path, with the setting on and off | `scripts/dev-app.sh build && python3 scripts/e2e-app.py` |

Layers 1–2 compile the app's own source files (`Sources/ETHarness/*.swift` are
symlinks into `VoiceInk/Services/`), so they test shipped code, not copies.

## The dev app (`scripts/dev-app.sh`)

- Bundle id `com.embervista.EmberType.dev` → its own preferences domain.
- Runs with `CFFIXED_USER_HOME=DevHarness/.devhome`, so its history database and
  recordings stay out of `~/Library/Application Support/com.embervista.EmberType`.
  Parakeet models are symlinked from the real `FluidAudio` folder (no download).
- Ad hoc signed with `dev.entitlements` (the release entitlements minus
  `keychain-access-groups`, which needs a provisioning profile). `-forceLicensed`.
- Launched by executable path, so Accessibility is attributed to the terminal
  running the script (which must have Accessibility). No prompts for the dev build.
- `-debugDictationHook`: a `#if DEBUG` observer in `WhisperState` that takes an
  audio path via distributed notification and runs it as a dictation. Compiled
  out of Release builds (check: `strings <release binary> | grep debugDictation` → nothing).

`scripts/dev-app.sh set KEY -bool true` changes a dev setting; `reset` wipes the dev profile.

## Adding a case

Add `{"id", "say", "pos": "mid"|"start", "expect"}` to `corpus/cases.json`
(`expect` may be a list of acceptable outputs), run `run-asr.py`, check the
new rows, then `--update-baseline`.

## Known limits

- Synthetic voices, not people. The Fred voice is poorly recognised by
  Parakeet and fails most cases by design; it's there to catch crashes.
- Parakeet mishears some command words from synthetic voices ("Colin",
  "Kama", "parenis"); those show as baseline failures, not pipeline bugs.
- Layer 3 needs TextEdit and the keyboard focus for ~2 s per scenario.
  It only opens and closes documents it creates.
