# Changelog

All notable changes to EmberType will be documented in this file.

## [1.1.2] - 2026-10-02

### Changed
- Bug fixes and improvements.

## [1.1.1] - 2026-09-29

### Changed
- Reliability and security improvements, including more dependable license activation and clearer messages when activation goes wrong.

## [1.1] - 2026-09-28

### Added
- **Spoken punctuation.** EmberType can now type only the punctuation you say, and add none of its own.
  - **Turn it on:** open EmberType → **AI Models** (sidebar) → **gear icon** (right end of the model filter row) → switch on **Spoken punctuation only**. It's off by default.
  - **Say:** comma, period (or full stop), question mark, exclamation point, colon, semicolon, open paren / close paren, open quote / close quote, open single quote / close single quote, hyphen, em dash, ellipsis, greater than sign, less than sign, new line, new paragraph.
  - Example: "dear Sam comma thanks for the notes period can we talk friday question mark" → `Dear Sam, thanks for the notes. Can we talk Friday?`
  - Say "literal" first to type the word itself: "literal period" → `period`.
  - Nothing is added unless you say it: no automatic period at the end, no guessed question marks.
  - Full guide: https://embertype.com/docs/spoken-punctuation/

### Changed
- **Adding words mid-sentence now fits in.** When you click into the middle of a sentence and dictate, EmberType reads the text around the cursor and types `Take this short sentence`, not `Take this Short. sentence`: no capital, no period, correct spacing. This works with spoken punctuation on or off, in apps that let EmberType read their text (most Mac apps; some web apps don't).
- **Ollama setup is clearer.** When Ollama is running but has no language model, EmberType now says "No models installed" with the Terminal command to fix it, instead of "Disconnected".

### Fixed
- The "Add space after paste" setting had no effect; a space was always added.

## [1.0.2] - 2026-09-24

### Fixed
- "Manage License" button opened a 404 page (polar.sh/purchases). It now opens the Polar customer portal (polar.sh/embervista/portal), where customers can view their license key and device activations.

## [1.0.1] - 2026-04-18

### Changed
- An expired trial now opens the purchase page instead of transcribing (previously it pasted a "trial expired" notice ahead of the text)

## [0.9.5] - 2026-02-07

### Changed
- Default transcription model changed to Parakeet TDT V3 (faster, more accurate)
- Recommended models list updated to prioritize Parakeet models

### Added
- Custom keyboard shortcut support during onboarding (including Hyperkey)

### Fixed
- Accessibility permission dialog appearing twice during onboarding setup
- Permission status not updating when toggled in System Settings

## [0.9.1] - 2026-01-23

### Added
- First notarized beta build
- Bug fixes and improvements
