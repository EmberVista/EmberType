import Foundation
import SwiftUI
import os

@MainActor
class TranscriptionServiceRegistry {
    private let whisperState: WhisperState
    private let modelsDirectory: URL
    private let logger = Logger(subsystem: "com.embervista.embertype", category: "TranscriptionServiceRegistry")

    private(set) lazy var localTranscriptionService = LocalTranscriptionService(
        modelsDirectory: modelsDirectory,
        whisperState: whisperState
    )
    private(set) lazy var cloudTranscriptionService = CloudTranscriptionService(modelContext: whisperState.modelContext)
    private(set) lazy var nativeAppleTranscriptionService = NativeAppleTranscriptionService()
    private(set) lazy var parakeetTranscriptionService = ParakeetTranscriptionService()

    init(whisperState: WhisperState, modelsDirectory: URL) {
        self.whisperState = whisperState
        self.modelsDirectory = modelsDirectory
    }

    func service(for provider: ModelProvider) -> TranscriptionService {
        switch provider {
        case .local:
            return localTranscriptionService
        case .parakeet:
            return parakeetTranscriptionService
        case .nativeApple:
            return nativeAppleTranscriptionService
        default:
            return cloudTranscriptionService
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        try requireActiveLicense()
        let service = service(for: model.provider)
        logger.debug("Transcribing with \(model.displayName) using \(String(describing: type(of: service)))")
        return try await service.transcribe(audioURL: audioURL, model: model)
    }

    /// Dictation audio. With spoken punctuation on, Parakeet returns spoken
    /// punctuation marks as words so SpokenPunctuationProcessor keeps them.
    func transcribeDictation(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        try requireActiveLicense()
        if SpokenPunctuationProcessor.isEnabled, model.provider == .parakeet {
            return try await parakeetTranscriptionService.transcribe(audioURL: audioURL, model: model, restoringSpokenPunctuation: true)
        }
        return try await transcribe(audioURL: audioURL, model: model)
    }

    /// Every transcription path (dictation, Transcribe Audio, re-transcribe, system audio)
    /// comes through here, so the trial ends for all of them at once.
    private func requireActiveLicense() throws {
        if MinimumVersion.isUpdateRequired {
            NotificationCenter.default.post(name: .updateRequired, object: nil)
            throw TranscriptionError.updateRequired
        }
        whisperState.licenseViewModel.refreshLicenseState()
        if case .trialExpired = whisperState.licenseViewModel.licenseState {
            throw TranscriptionError.trialExpired
        }
    }

    func cleanup() {
        parakeetTranscriptionService.cleanup()
    }
}
