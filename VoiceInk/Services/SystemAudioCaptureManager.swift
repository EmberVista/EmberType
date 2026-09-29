import Foundation
import SwiftUI
import SwiftData
import os

enum SystemAudioCaptureState: Equatable {
    case idle
    case recording
    case stopping
    case transcribing
    case enhancing
    case completed

    var message: String {
        switch self {
        case .idle:
            return ""
        case .recording:
            return "Recording system audio..."
        case .stopping:
            return "Stopping capture..."
        case .transcribing:
            return "Transcribing audio..."
        case .enhancing:
            return "Enhancing transcription with AI..."
        case .completed:
            return "Transcription completed!"
        }
    }
}

@MainActor
class SystemAudioCaptureManager: ObservableObject {
    static let shared = SystemAudioCaptureManager()

    private let logger = Logger(subsystem: "com.embervista.embertype", category: "SystemAudioCaptureManager")

    @Published var captureState: SystemAudioCaptureState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentTranscription: Transcription?
    @Published var errorMessage: String?
    @Published var availableApps: [SystemAudioApp] = []
    @Published var selectedApp: SystemAudioApp? = SystemAudioApp.allSystemAudio

    private let recorder = SystemAudioRecorder()
    private let audioProcessor = AudioProcessor()
    private var currentTask: Task<Void, Error>?
    private var recordingURL: URL?

    private init() {
        // Bind to recorder's duration updates
        Task {
            for await _ in recorder.$recordingDuration.values {
                self.recordingDuration = recorder.recordingDuration
            }
        }
    }

    // MARK: - Permission Handling

    var hasPermission: Bool {
        recorder.hasPermission()
    }

    func requestPermission() {
        recorder.requestPermission()
    }

    func openSystemPreferences() {
        recorder.openSystemPreferences()
    }

    // MARK: - App Management

    func refreshAvailableApps() async {
        do {
            availableApps = try await recorder.getRunningApplications()
            logger.notice("Refreshed available apps: \(self.availableApps.count)")
        } catch {
            logger.error("Failed to get running applications: \(error.localizedDescription)")
            availableApps = [SystemAudioApp.allSystemAudio]
        }
    }

    // MARK: - Capture Control

    func startCapture() async {
        guard captureState == .idle else { return }

        errorMessage = nil
        captureState = .recording

        do {
            let url = try await recorder.startCapture(app: selectedApp)
            recordingURL = url
            logger.notice("Started capture to: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            captureState = .idle
        }
    }

    func stopCapture(modelContext: ModelContext, whisperState: WhisperState) {
        guard captureState == .recording else { return }

        captureState = .stopping
        currentTask?.cancel()

        currentTask = Task {
            do {
                let audioURL = try await recorder.stopCapture()

                captureState = .transcribing

                guard let currentModel = whisperState.currentTranscriptionModel else {
                    throw TranscriptionError.noModelSelected
                }

                let serviceRegistry = TranscriptionServiceRegistry(whisperState: whisperState, modelsDirectory: whisperState.modelsDirectory)
                defer {
                    serviceRegistry.cleanup()
                }

                // Process audio to Whisper format
                let samples = try await audioProcessor.processAudioToSamples(audioURL)

                // Save processed samples
                let processedURL = audioURL.deletingLastPathComponent()
                    .appendingPathComponent("processed_\(UUID().uuidString).wav")
                try audioProcessor.saveSamplesAsWav(samples: samples, to: processedURL)

                // Transcribe
                let transcriptionStart = Date()
                var text = try await serviceRegistry.transcribe(audioURL: processedURL, model: currentModel)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                // Filter and format
                text = TranscriptionOutputFilter.filter(text)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)

                if UserDefaults.standard.object(forKey: "IsTextFormattingEnabled") as? Bool ?? true {
                    text = WhisperTextFormatter.format(text)
                }

                text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)

                let powerModeManager = PowerModeManager.shared
                let activePowerModeConfig = powerModeManager.currentActiveConfiguration
                let powerModeName = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.name : nil
                let powerModeEmoji = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.emoji : nil

                // Handle enhancement if enabled
                if let enhancementService = whisperState.enhancementService,
                   enhancementService.isEnhancementEnabled,
                   enhancementService.isConfigured {
                    captureState = .enhancing
                    do {
                        let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(text)
                        let transcription = Transcription(
                            text: text,
                            duration: recordingDuration,
                            enhancedText: enhancedText,
                            audioFileURL: processedURL.absoluteString,
                            transcriptionModelName: currentModel.displayName,
                            aiEnhancementModelName: enhancementService.getAIService()?.currentModel,
                            promptName: promptName,
                            transcriptionDuration: transcriptionDuration,
                            enhancementDuration: enhancementDuration,
                            aiRequestSystemMessage: enhancementService.lastSystemMessageSent,
                            aiRequestUserMessage: enhancementService.lastUserMessageSent,
                            powerModeName: powerModeName,
                            powerModeEmoji: powerModeEmoji
                        )
                        modelContext.insert(transcription)
                        try modelContext.save()
                        NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
                        currentTranscription = transcription
                    } catch {
                        logger.error("Enhancement failed: \(error.localizedDescription)")
                        let transcription = Transcription(
                            text: text,
                            duration: recordingDuration,
                            audioFileURL: processedURL.absoluteString,
                            transcriptionModelName: currentModel.displayName,
                            promptName: nil,
                            transcriptionDuration: transcriptionDuration,
                            powerModeName: powerModeName,
                            powerModeEmoji: powerModeEmoji
                        )
                        modelContext.insert(transcription)
                        try modelContext.save()
                        NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
                        currentTranscription = transcription
                    }
                } else {
                    let transcription = Transcription(
                        text: text,
                        duration: recordingDuration,
                        audioFileURL: processedURL.absoluteString,
                        transcriptionModelName: currentModel.displayName,
                        promptName: nil,
                        transcriptionDuration: transcriptionDuration,
                        powerModeName: powerModeName,
                        powerModeEmoji: powerModeEmoji
                    )
                    modelContext.insert(transcription)
                    try modelContext.save()
                    NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
                    currentTranscription = transcription
                }

                // Clean up original file
                try? FileManager.default.removeItem(at: audioURL)

                captureState = .completed
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                captureState = .idle

            } catch {
                if Task.isCancelled {
                    logger.notice("Capture task was cancelled")
                } else {
                    logger.error("Capture failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
                captureState = .idle
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        recorder.cancel()
        captureState = .idle
        recordingDuration = 0
    }
}
