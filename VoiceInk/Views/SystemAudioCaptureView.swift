import SwiftUI
import SwiftData

struct SystemAudioCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var whisperState: WhisperState
    @StateObject private var captureManager = SystemAudioCaptureManager.shared

    @State private var isEnhancementEnabled = false
    @State private var selectedPromptId: UUID?
    @State private var showingPermissionAlert = false

    var body: some View {
        ZStack {
            Color(NSColor.controlBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    CompactHeroSection(
                        icon: "speaker.wave.2.fill",
                        title: "Capture System Audio",
                        description: "Record and transcribe audio from any app on your Mac"
                    )

                    if !captureManager.hasPermission {
                        permissionRequestView
                    } else {
                        captureControlsView
                    }

                    Divider()
                        .padding(.vertical)

                    // Show current transcription result
                    if let transcription = captureManager.currentTranscription {
                        TranscriptionResultView(transcription: transcription)
                    }
                }
                .padding(24)
            }
        }
        .alert("Error", isPresented: .constant(captureManager.errorMessage != nil)) {
            Button("OK", role: .cancel) {
                captureManager.errorMessage = nil
            }
        } message: {
            if let errorMessage = captureManager.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            if captureManager.hasPermission {
                await captureManager.refreshAvailableApps()
            }
        }
        .onAppear {
            if let enhancementService = whisperState.getEnhancementService() {
                isEnhancementEnabled = enhancementService.isEnhancementEnabled
                selectedPromptId = enhancementService.selectedPromptId
            }
        }
    }

    // MARK: - Permission Request View

    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("Screen Recording Permission Required")
                    .font(.headline)

                Text("EmberType needs Screen Recording permission to capture system audio. This permission allows capturing audio from other applications.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Button(action: {
                captureManager.requestPermission()
                captureManager.openSystemPreferences()
            }) {
                HStack {
                    Text("Open System Settings")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: 300)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignTokens.cornerRadiusCard)
            }
            .buttonStyle(.plain)

            Text("After granting permission, you may need to restart EmberType.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .background(CardBackground(isSelected: false))
        .cornerRadius(DesignTokens.cornerRadiusCard)
    }

    // MARK: - Capture Controls View

    private var captureControlsView: some View {
        VStack(spacing: 20) {
            // Audio Source Picker
            audioSourcePicker

            // AI Enhancement Settings
            if let enhancementService = whisperState.getEnhancementService() {
                aiEnhancementSettings(enhancementService: enhancementService)
            }

            // Recording Controls
            recordingControls
        }
    }

    private var audioSourcePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Audio Source")
                    .font(.headline)

                Spacer()

                Button(action: {
                    Task {
                        await captureManager.refreshAvailableApps()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(captureManager.captureState != .idle)
            }

            Menu {
                ForEach(captureManager.availableApps) { app in
                    Button(action: {
                        captureManager.selectedApp = app
                    }) {
                        HStack {
                            if app.id == "all-system-audio" {
                                Image(systemName: "speaker.wave.3.fill")
                            } else {
                                Image(systemName: "app.fill")
                            }
                            Text(app.name)
                            if captureManager.selectedApp?.id == app.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if captureManager.selectedApp?.id == "all-system-audio" {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "app.fill")
                            .foregroundColor(.accentColor)
                    }
                    Text(captureManager.selectedApp?.name ?? "Select Source")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(CardBackground(isSelected: false))
                .cornerRadius(DesignTokens.cornerRadiusCard)
            }
            .disabled(captureManager.captureState != .idle)
        }
        .padding()
        .background(CardBackground(isSelected: false))
        .cornerRadius(DesignTokens.cornerRadiusCard)
    }

    private func aiEnhancementSettings(enhancementService: AIEnhancementService) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Toggle("AI Enhancement", isOn: $isEnhancementEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: isEnhancementEnabled) { oldValue, newValue in
                        enhancementService.isEnhancementEnabled = newValue
                    }

                if isEnhancementEnabled {
                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 8) {
                        Text("Prompt:")
                            .font(.subheadline)

                        if enhancementService.allPrompts.isEmpty {
                            Text("No prompts available")
                                .foregroundColor(.secondary)
                                .italic()
                                .font(.caption)
                        } else {
                            let promptBinding = Binding<UUID>(
                                get: {
                                    selectedPromptId ?? enhancementService.allPrompts.first?.id ?? UUID()
                                },
                                set: { newValue in
                                    selectedPromptId = newValue
                                    enhancementService.selectedPromptId = newValue
                                }
                            )

                            Picker("", selection: promptBinding) {
                                ForEach(enhancementService.allPrompts) { prompt in
                                    Text(prompt.title).tag(prompt.id)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CardBackground(isSelected: false))
        .disabled(captureManager.captureState != .idle)
    }

    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Recording state indicator
            if captureManager.captureState == .recording {
                VStack(spacing: 12) {
                    // Animated recording indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(1.5)
                                    .opacity(0.5)
                            )

                        Text("Recording")
                            .font(.headline)
                            .foregroundColor(.red)
                    }

                    // Duration display
                    Text(formatDuration(captureManager.recordingDuration))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 20)
            } else if captureManager.captureState != .idle {
                // Processing state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(captureManager.captureState.message)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }

            // Control buttons
            HStack(spacing: 16) {
                if captureManager.captureState == .idle {
                    Button(action: {
                        Task {
                            await captureManager.startCapture()
                        }
                    }) {
                        HStack {
                            Image(systemName: "record.circle")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Start Recording")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(DesignTokens.cornerRadiusCard)
                    }
                    .buttonStyle(.plain)
                } else if captureManager.captureState == .recording {
                    Button(action: {
                        captureManager.stopCapture(modelContext: modelContext, whisperState: whisperState)
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Stop & Transcribe")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(DesignTokens.cornerRadiusCard)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        captureManager.cancel()
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if captureManager.captureState == .idle {
                Text("Record audio from YouTube, Zoom, podcasts, or any other application")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(CardBackground(isSelected: false))
        .cornerRadius(DesignTokens.cornerRadiusCard)
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    SystemAudioCaptureView()
}
