import Foundation
import FluidAudio


// Usage: ETHarness v2|v3 file1.wav [file2.wav ...]
// Runs each file through Parakeet and the dictation text pipeline in the same
// order as WhisperState (output filter → trim → spoken punctuation) and prints
// one JSON line per file.
let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: ETHarness v2|v3 files...\n".data(using: .utf8)!)
    exit(2)
}
let version: AsrModelVersion = args[1] == "v2" ? .v2 : .v3

// Same reader as ParakeetTranscriptionService.readAudioSamples (16 kHz mono Int16, 44-byte header).
func readAudioSamples(_ url: URL) throws -> [Float] {
    let data = try Data(contentsOf: url)
    return stride(from: 44, to: data.count, by: 2).map {
        data[$0..<$0 + 2].withUnsafeBytes {
            max(-1.0, min(Float(Int16(littleEndian: $0.load(as: Int16.self))) / 32767.0, 1.0))
        }
    }
}

let manager = AsrManager(config: .default)
let models = try await AsrModels.loadFromCache(configuration: nil, version: version)
try await manager.initialize(models: models)

// ETHARNESS_TOKENS=1 prints per-token timings instead (for investigating the model).
if ProcessInfo.processInfo.environment["ETHARNESS_TOKENS"] == "1" {
    for path in args.dropFirst(2) {
        let result = try await manager.transcribe(readAudioSamples(URL(fileURLWithPath: path)))
        print("## \(path)\n\(result.text)")
        for t in result.tokenTimings ?? [] {
            print(String(format: "%6.2f %6.2f %5.2f  %@", t.startTime, t.endTime, t.confidence, t.token))
        }
    }
    exit(0)
}

for path in args.dropFirst(2) {
    let url = URL(fileURLWithPath: path)
    var obj: [String: String] = ["file": url.lastPathComponent]
    do {
        // Same steps as ParakeetTranscriptionService.transcribe with the mode on.
        let samples = try readAudioSamples(url)
        let result = try await manager.transcribe(samples)
        let raw = result.text
        let tokens = (result.tokenTimings ?? []).map {
            SpokenPunctuationProcessor.TimedToken(text: $0.token, start: $0.startTime, end: $0.endTime)
        }
        let restored = SpokenPunctuationProcessor.restoreSpokenPunctuationWords(tokens: tokens, samples: samples) ?? raw
        let filtered = TranscriptionOutputFilter.filter(restored).trimmingCharacters(in: .whitespacesAndNewlines)
        obj["raw"] = raw
        obj["restored"] = restored
        obj["mid"] = SpokenPunctuationProcessor.process(filtered, capitalizeFirstWord: false)
        obj["start"] = SpokenPunctuationProcessor.process(filtered, capitalizeFirstWord: true)
    } catch {
        obj["error"] = "\(error)"
    }
    let json = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    print(String(data: json, encoding: .utf8)!)
}
