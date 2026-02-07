import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreMedia
import os

enum SystemAudioRecorderError: LocalizedError {
    case screenCaptureNotAvailable
    case noAudioAvailable
    case failedToCreateStream
    case failedToCreateFile
    case failedToStartCapture
    case notRecording

    var errorDescription: String? {
        switch self {
        case .screenCaptureNotAvailable:
            return "Screen capture is not available on this system"
        case .noAudioAvailable:
            return "No audio source available for capture"
        case .failedToCreateStream:
            return "Failed to create audio capture stream"
        case .failedToCreateFile:
            return "Failed to create audio output file"
        case .failedToStartCapture:
            return "Failed to start audio capture"
        case .notRecording:
            return "Not currently recording"
        }
    }
}

struct SystemAudioApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let runningApplication: SCRunningApplication?

    static let allSystemAudio = SystemAudioApp(
        id: "all-system-audio",
        name: "All System Audio",
        bundleIdentifier: "",
        runningApplication: nil
    )

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SystemAudioApp, rhs: SystemAudioApp) -> Bool {
        lhs.id == rhs.id
    }
}

/// Thread-safe audio sample buffer
private final class AudioSampleBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let queue = DispatchQueue(label: "com.embervista.embertype.samplebuffer")

    func append(_ newSamples: [Float]) {
        queue.sync {
            samples.append(contentsOf: newSamples)
        }
    }

    func removeAll() {
        queue.sync {
            samples.removeAll()
        }
    }

    func getSamples() -> [Float] {
        queue.sync {
            return samples
        }
    }
}

@MainActor
class SystemAudioRecorder: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.embervista.embertype", category: "SystemAudioRecorder")

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var stream: SCStream?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    // Audio format settings
    private let outputSampleRate: Double = 16000
    private let outputChannels: Int = 1

    // Thread-safe audio sample buffer
    private let sampleBuffer = AudioSampleBuffer()

    override init() {
        super.init()
    }

    // MARK: - Permission Handling

    func hasPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Running Applications

    func getRunningApplications() async throws -> [SystemAudioApp] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        var apps: [SystemAudioApp] = [SystemAudioApp.allSystemAudio]
        var seenBundleIds = Set<String>()

        for app in content.applications {
            guard !seenBundleIds.contains(app.bundleIdentifier) else { continue }
            seenBundleIds.insert(app.bundleIdentifier)

            // Skip EmberType itself
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }

            let systemApp = SystemAudioApp(
                id: app.bundleIdentifier,
                name: app.applicationName,
                bundleIdentifier: app.bundleIdentifier,
                runningApplication: app
            )
            apps.append(systemApp)
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Recording Control

    func startCapture(app: SystemAudioApp?) async throws -> URL {
        guard hasPermission() else {
            throw SystemAudioRecorderError.screenCaptureNotAvailable
        }

        // Stop any existing recording
        if isRecording {
            _ = try await stopCapture()
        }

        // Reset state
        sampleBuffer.removeAll()

        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw SystemAudioRecorderError.noAudioAvailable
        }

        // Configure stream for audio capture
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        // Minimize video capture (required by API but not used)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        // Create content filter
        let filter: SCContentFilter
        if let selectedApp = app, let runningApp = selectedApp.runningApplication {
            // Capture specific app audio
            filter = SCContentFilter(desktopIndependentWindow: content.windows.first { $0.owningApplication?.bundleIdentifier == runningApp.bundleIdentifier } ?? content.windows.first!)
        } else {
            // Capture all system audio using display
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        }

        // Create stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        // Add audio output handler
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.embervista.embertype.systemaudio"))

        // Start capture
        try await stream.startCapture()

        // Create output file path
        let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.embervista.EmberType")
            .appendingPathComponent("Recordings")

        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        let fileName = "system_audio_\(UUID().uuidString).wav"
        let outputURL = recordingsDirectory.appendingPathComponent(fileName)
        self.recordingURL = outputURL

        // Start recording state
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        logger.notice("Started system audio capture")
        return outputURL
    }

    func stopCapture() async throws -> URL {
        guard isRecording, let stream = stream, let outputURL = recordingURL else {
            throw SystemAudioRecorderError.notRecording
        }

        // Stop the stream
        try await stream.stopCapture()
        self.stream = nil

        // Stop timer
        durationTimer?.invalidate()
        durationTimer = nil

        // Get the collected samples
        let samples = sampleBuffer.getSamples()

        // Save samples to WAV file
        try saveAsWav(samples: samples, to: outputURL)

        isRecording = false
        logger.notice("Stopped system audio capture. Duration: \(self.recordingDuration)s, Samples: \(samples.count)")

        return outputURL
    }

    func cancel() {
        Task {
            if let stream = stream {
                try? await stream.stopCapture()
            }
            self.stream = nil
            durationTimer?.invalidate()
            durationTimer = nil
            isRecording = false
            recordingDuration = 0

            sampleBuffer.removeAll()

            // Clean up file if exists
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            recordingURL = nil
        }
    }

    // MARK: - Audio Processing

    nonisolated private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }

        let inputSampleRate = asbd.pointee.mSampleRate
        let inputChannels = Int(asbd.pointee.mChannelsPerFrame)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == kCMBlockBufferNoErr, let data = dataPointer else {
            return
        }

        // Convert to Float32 samples
        let floatData = data.withMemoryRebound(to: Float32.self, capacity: length / MemoryLayout<Float32>.size) { ptr in
            Array(UnsafeBufferPointer(start: ptr, count: length / MemoryLayout<Float32>.size))
        }

        // Resample and convert to mono
        let processedSamples = resample(
            samples: floatData,
            fromRate: inputSampleRate,
            toRate: outputSampleRate,
            inputChannels: inputChannels
        )

        // Append to buffer (thread-safe)
        self.sampleBuffer.append(processedSamples)
    }

    nonisolated private func resample(samples: [Float], fromRate: Double, toRate: Double, inputChannels: Int) -> [Float] {
        guard !samples.isEmpty else { return [] }

        // First convert to mono by averaging channels
        var monoSamples: [Float] = []
        let frameCount = samples.count / inputChannels

        for i in 0..<frameCount {
            var sum: Float = 0
            for ch in 0..<inputChannels {
                let index = i * inputChannels + ch
                if index < samples.count {
                    sum += samples[index]
                }
            }
            monoSamples.append(sum / Float(inputChannels))
        }

        // Resample if needed
        if fromRate == toRate {
            return monoSamples
        }

        let ratio = toRate / fromRate
        let outputLength = Int(Double(monoSamples.count) * ratio)
        var outputSamples = [Float](repeating: 0, count: outputLength)

        for i in 0..<outputLength {
            let inputIndex = Double(i) / ratio
            let inputIndexInt = Int(inputIndex)
            let frac = Float(inputIndex - Double(inputIndexInt))

            let idx1 = min(inputIndexInt, monoSamples.count - 1)
            let idx2 = min(inputIndexInt + 1, monoSamples.count - 1)

            // Linear interpolation
            outputSamples[i] = monoSamples[idx1] + frac * (monoSamples[idx2] - monoSamples[idx1])
        }

        return outputSamples
    }

    private func saveAsWav(samples: [Float], to url: URL) throws {
        guard !samples.isEmpty else {
            throw SystemAudioRecorderError.failedToCreateFile
        }

        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputSampleRate,
            channels: AVAudioChannelCount(outputChannels),
            interleaved: true
        )

        guard let outputFormat = outputFormat else {
            throw SystemAudioRecorderError.failedToCreateFile
        }

        let buffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        )

        guard let buffer = buffer else {
            throw SystemAudioRecorderError.failedToCreateFile
        }

        // Normalize samples
        let maxSample = samples.map(abs).max() ?? 1.0
        let normalizedSamples = maxSample > 0 ? samples.map { $0 / maxSample } : samples

        // Convert float samples to int16
        let int16Samples = normalizedSamples.map { max(-1.0, min(1.0, $0)) * Float(Int16.max) }.map { Int16($0) }

        // Copy samples to buffer
        int16Samples.withUnsafeBufferPointer { int16Buffer in
            buffer.int16ChannelData![0].update(from: int16Buffer.baseAddress!, count: int16Samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        // Create audio file
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )

        try audioFile.write(from: buffer)

        logger.notice("Saved WAV file: \(url.lastPathComponent), samples: \(samples.count)")
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            logger.error("Stream stopped with error: \(error.localizedDescription)")
            self.cancel()
        }
    }
}

// MARK: - SCStreamOutput

extension SystemAudioRecorder: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        processAudioBuffer(sampleBuffer)
    }
}
