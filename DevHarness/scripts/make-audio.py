#!/usr/bin/env python3
"""Render corpus/cases.json phrases to 16 kHz mono 16-bit WAVs (44-byte header,
the format EmberType's recorder writes) using macOS `say`, one file per voice."""
import json, os, subprocess, sys, tempfile, wave

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
cases = json.load(open(os.path.join(root, "corpus", "cases.json")))
voices = sys.argv[1:] or ["Samantha"]
out = os.path.join(root, "corpus", "audio")
os.makedirs(out, exist_ok=True)
for voice in voices:
    for c in cases:
        dst = os.path.join(out, f"{c['id']}__{voice}.wav")
        if os.path.exists(dst):
            continue
        with tempfile.TemporaryDirectory() as t:
            aiff, raw = os.path.join(t, "a.aiff"), os.path.join(t, "a.raw")
            # Pad with silence: a real press-to-talk recording has lead-in/out, and
            # clips under ~1 s are rejected by FluidAudio.
            subprocess.run(["say", "-v", voice, "-o", aiff, "[[slnc 600]] " + c["say"] + " [[slnc 600]]"], check=True)
            subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@16000", "-c", "1", aiff, raw + ".caf"], check=True)
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", raw + ".caf", raw + ".wav"], check=True)
            with wave.open(raw + ".wav") as r:
                frames = r.readframes(r.getnframes())
            with wave.open(dst, "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(frames)
        print(dst)
