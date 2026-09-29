#!/usr/bin/env python3
"""Layer 2: real Parakeet (v2 + v3) on synthetic speech → dictation pipeline.

Renders corpus/cases.json with several macOS voices, runs ETHarness, and checks
each result against the expected text for its cursor position. Writes
corpus/results/latest.json.

Synthetic voices produce their own mishearings ("colon" → "Colin"), so a
result is judged against corpus/results/baseline.json: the run fails only if a
case that passed in the baseline now fails (a regression). Use
--update-baseline after an intended improvement."""
import json, os, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
voices = ["Samantha", "Daniel", "Karen", "Moira", "Fred"]
subprocess.run([sys.executable, os.path.join(here, "make-audio.py"), *voices], check=True, stdout=subprocess.DEVNULL)
subprocess.run(["swift", "build", "-c", "release"], cwd=root, check=True, stdout=subprocess.DEVNULL)
cases = {c["id"]: c for c in json.load(open(os.path.join(root, "corpus", "cases.json")))}
audio = os.path.join(root, "corpus", "audio")
results = []
for model in ["v3", "v2"]:
    files = sorted(os.path.join(audio, f) for f in os.listdir(audio) if f.endswith(".wav"))
    out = subprocess.run([os.path.join(root, ".build", "release", "ETHarness"), model, *files],
                         capture_output=True, text=True, check=True).stdout
    for line in (l for l in out.splitlines() if l.startswith("{\"file")):  # FluidAudio logs to stdout too
        r = json.loads(line)
        cid, voice = r["file"][:-4].split("__")
        c = cases.get(cid)
        if not c:
            continue
        got = r.get(c["pos"], r.get("error"))
        expected = c["expect"] if isinstance(c["expect"], list) else [c["expect"]]
        ok = got in expected
        results.append({"model": model, "voice": voice, "case": cid, "ok": ok, "got": got,
                        "expect": c["expect"], "raw": r.get("raw"), "restored": r.get("restored")})
os.makedirs(os.path.join(root, "corpus", "results"), exist_ok=True)
json.dump(results, open(os.path.join(root, "corpus", "results", "latest.json"), "w"), indent=1)
for model in ["v3", "v2"]:
    for voice in voices:
        rs = [r for r in results if r["model"] == model and r["voice"] == voice]
        print(f"{model} {voice:10} {sum(r['ok'] for r in rs)}/{len(rs)}")
print("\nFailures:")
for r in results:
    if not r["ok"]:
        print(f"  [{r['model']} {r['voice']}] {r['case']}: raw={r['raw']!r}\n   restored={r['restored']!r}\n      got={r['got']!r}\n   expect={r['expect']!r}")
baseline_path = os.path.join(root, "corpus", "results", "baseline.json")
key = lambda r: (r["model"], r["voice"], r["case"])
if "--update-baseline" in sys.argv or not os.path.exists(baseline_path):
    json.dump(results, open(baseline_path, "w"), indent=1)
    print("\nbaseline updated")
    sys.exit(0)
baseline = {key(r): r["ok"] for r in json.load(open(baseline_path))}
regressions = [r for r in results if baseline.get(key(r)) and not r["ok"]]
fixed = [r for r in results if baseline.get(key(r)) is False and r["ok"]]
print(f"\nvs baseline: {len(regressions)} regressions, {len(fixed)} newly passing")
for r in regressions:
    print(f"  REGRESSION [{r['model']} {r['voice']}] {r['case']}: {r['got']!r}")
sys.exit(1 if regressions else 0)
