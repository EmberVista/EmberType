# Try spoken punctuation with your own voice

About 15 minutes. Your real EmberType is paused while you test and comes back
when you stop. Your license, history, dictionary and settings are never touched.

## Start

In cmux (it already has the Microphone and Accessibility permissions the dev
app borrows), run:

```bash
cd ~/VoiceInk-Build/EmberType-spoken-punctuation
DevHarness/try-it.sh start
```

This quits your real EmberType and opens **EmberType Dev** with your usual
hotkey, your Yeti mic and Parakeet v2. Spoken punctuation is already **on**.

Open **TextEdit** (File → New) and practise there first, then try Mail, Notes,
Messages and a Gmail draft in Chrome.

## How to talk to it

- Say punctuation as a word, in the flow of the sentence: "hello **comma** how are you **question mark**".
- Nothing is added unless you say it: no period at the end, no automatic question marks.
- The first word gets a capital only if the cursor is at the start of the text or after `.` `?` `!` or a line break.

| Say | Types |
|---|---|
| comma · period / full stop · question mark · exclamation point | `,` `.` `?` `!` |
| colon · semicolon | `:` `;` |
| open paren … close paren (or "parenthesis") | `( … )` |
| open quote … close quote | `" … "` |
| open single quote … close single quote | `' … '` |
| hyphen · em dash · ellipsis | `-` `—` `...` |
| new line · new paragraph | line break · blank line |
| greater than sign · less than sign | `>` `<` (spaced: `Edit > Start`) |
| literal period (or literal comma, etc.) | the word itself |

Plain "greater than" stays as words, so "costs greater than expected" is safe.

## Test script

Work down the list. Tick it if what's typed matches **Expect**.

**A. Inserting mid-sentence**
1. Type `Take this sentence as an example.` Click just before `sentence`. Say **"short"**.
   Expect: `Take this short sentence as an example.` (lowercase, no period, no double space)
2. Same, but click right after `this`, before the space. Say **"really"**.
   Expect: `Take this really sentence…` with one space on each side.
3. Type `Dear Sam,` and put the cursor at the end. Say **"thanks for writing"**.
   Expect: `Dear Sam, thanks for writing`
4. Put the cursor in the middle of a sentence and say a name: **"Sarah from accounting"**.
   Expect: `Sarah` keeps its capital, `from` is lowercase.

**B. Spoken punctuation in a new document**

5. Empty document. Say **"hello comma how are you question mark"**. Expect: `Hello, how are you?`
6. Say **"the meeting is at three period we will cover the budget comma the timeline comma and staffing period"**.
   Expect: `The meeting is at 3. We will cover the budget, the timeline, and staffing.`
7. Say **"is this working"** (no punctuation spoken). Expect: `is this working` or `Is this working`, with no `?`
8. Say **"the budget open paren see attached close paren is final period"**. Expect: `The budget (see attached) is final.`
9. Say **"she said open quote hello close quote and left period"**. Expect: `She said "hello" and left.`
10. Say **"first line new line second line new paragraph third"**. Expect three lines with a blank line before `Third`.
11. Say **"the trial literal period lasts seven days period"**. Expect: `The trial period lasts 7 days.`
12. Say **"I think I'm right"**. Expect `I` and `I'm` stay capitalized.
12b. Say **"press the shortcut or choose edit greater than sign start dictation period"**.
    Expect: `Press the shortcut or choose Edit > Start Dictation.` (capitals on Edit/Start depend on what Parakeet hears)

**C. Your normal speech**

13. Dictate a real email or a paragraph the way you'd normally talk, with pauses and all. Pauses
    must not create commas. Only the punctuation you say should appear.

**D. Normal mode (setting off)**

14. In EmberType Dev: **AI Models → gear icon → turn "Spoken punctuation only" off**.
    - Repeat test 1. Expect `Take this short sentence…` too. Mid-sentence inserts now fit in normal mode as well (1.0.2 gave `Take this Short. sentence`).
    - In an empty document, say "hello comma how are you". Expect the old automatic behaviour: `Hello comma how are you.`
    Turn the setting back on.

**E. Apps that hide their text**

15. Try test 1 in a Gmail draft in Chrome and in any Electron app you use (Slack, Discord).
    Some apps don't let EmberType read around the cursor. There the first word is always
    lowercase. Note which apps do this.

## See what happened

```bash
DevHarness/try-it.sh log
```

This shows, for every dictation, what Parakeet **heard** next to what was **typed**,
and where it thought the cursor was (`sentenceStart`, `midSentence` or `unknown`).
If something looks wrong, tell Claude the test number. It can read this log.

- Wrong **heard** means Parakeet misheard you (for example "Colin" for "colon"). That's the
  speech model. A Dictionary replacement can fix a word it keeps mishearing.
- Right **heard** but wrong **typed** is a bug in the new feature. That's what we're hunting.

## Stop

```bash
DevHarness/try-it.sh stop
```

This quits EmberType Dev and reopens your real EmberType. If anything gets stuck:
`DevHarness/scripts/dev-app.sh stop`, then open EmberType from Applications.
