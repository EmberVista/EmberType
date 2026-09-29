#!/usr/bin/env python3
"""Layer 3: the real dev app, end to end, into TextEdit.

For each scenario: open a TextEdit document with some text, put the caret
somewhere, have the dev app "dictate" a corpus WAV through its real pipeline
(transcribe → spoken punctuation → paste with Cmd+V), then read the document
back. Needs scripts/dev-app.sh build first. Takes over the keyboard focus for
~2 s per scenario; don't type while it runs."""
import json, os, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
audio = os.path.join(root, "corpus", "audio")
driver = os.path.join(root, ".build", "release", "ETDriver")
devapp = os.path.join(here, "dev-app.sh")

def osa(script):
    return subprocess.run(["osascript", "-e", script], capture_output=True, text=True, check=True).stdout.strip()

# Only documents this script creates are touched; anything already open in
# TextEdit is left alone.
def textedit_doc(text):
    osa('tell application "TextEdit" to activate')
    name = osa(f'tell application "TextEdit" to get name of (make new document with properties {{text:{json.dumps(text)}}})')
    time.sleep(0.6)
    return name

def close_doc(name):
    osa(f'tell application "TextEdit" to close document {json.dumps(name)} saving no')

def run(scenario):
    name, before, cursor, wav, expect = scenario
    doc = textedit_doc(before)
    subprocess.run([driver, "set-cursor", str(cursor)], check=True)
    subprocess.run([driver, "dictate", os.path.join(audio, wav)], check=True)
    time.sleep(0.8)  # paste is dispatched after the pipeline finishes
    got = subprocess.run([driver, "get-text"], capture_output=True, text=True).stdout
    close_doc(doc)
    ok = got == expect
    print(f"{'PASS' if ok else 'FAIL'}  {name}\n      got    {got!r}" + ("" if ok else f"\n      expect {expect!r}"))
    return ok

ON = [
    # Customer report: insert a word mid-sentence.
    ("insert after space", "Take this sentence as an example.", 10, "insert-short__Samantha.wav",
     "Take this short sentence as an example."),
    ("insert before space", "Take this sentence as an example.", 9, "insert-short__Samantha.wav",
     "Take this short sentence as an example."),
    ("insert after comma", "Dear Sam,", 9, "insert-phrase__Samantha.wav", "Dear Sam, all of my "),
    ("new doc, spoken punctuation", "", 0, "comma-question__Samantha.wav", "Hello, how are you? "),
    ("after a sentence, none spoken", "Done. ", 6, "no-spoken-punct-question__Samantha.wav", "Done. Is this working "),
    ("line breaks", "", 0, "newlines__Samantha.wav", "First line\nSecond line\n\nThird paragraph "),
    ("spoken comma the model converted", "", 0, "two-sentences__Karen.wav",
     "The meeting is at 3. We will discuss the budget, the timeline, and staffing. "),
]

def main():
    subprocess.run([sys.executable, os.path.join(here, "make-audio.py"), "Samantha", "Karen"], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["swift", "build", "-c", "release", "--product", "ETDriver"], cwd=root, check=True, stdout=subprocess.DEVNULL)
    results = []
    # Fixed model so results are comparable (try-it.sh copies the user's own model in).
    subprocess.run([devapp, "set", "CurrentTranscriptionModel", "parakeet-tdt-0.6b-v3"], check=True)
    subprocess.run([devapp, "set", "IsSpokenPunctuationEnabled", "-bool", "true"], check=True)
    subprocess.run([devapp, "start"], check=True, stdout=subprocess.DEVNULL)
    time.sleep(6)
    print("== Spoken punctuation ON")
    results += [run(s) for s in ON]

    # Regression: with the setting off, behaviour must match 1.0.2
    # (model punctuation kept, automatic formatting, trailing space).
    subprocess.run([devapp, "set", "IsSpokenPunctuationEnabled", "-bool", "false"], check=True)
    subprocess.run([devapp, "start"], check=True, stdout=subprocess.DEVNULL)
    time.sleep(6)
    print("== Spoken punctuation OFF (normal mode)")
    results.append(run(("off: new text unchanged from 1.0.2", "", 0, "comma-question__Samantha.wav", "Hello comma how are you question mark. ")))
    results.append(run(("off: after a sentence unchanged", "Done. ", 6, "insert-short__Samantha.wav", "Done. Short. ")))
    # 1.0.2 gave "Take this Short. sentence." (customer report).
    results.append(run(("off: mid-sentence insert fits in", "Take this sentence.", 10, "insert-short__Samantha.wav",
                        "Take this short sentence.")))
    subprocess.run([devapp, "stop"], stdout=subprocess.DEVNULL)
    print(f"\n{sum(results)}/{len(results)} passed")
    sys.exit(0 if all(results) else 1)

main()
