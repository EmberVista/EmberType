import SwiftUI

struct ExperimentalFeaturesSection: View {
    @AppStorage("isExperimentalFeaturesEnabled") private var isExperimentalFeaturesEnabled = false
    @ObservedObject private var playbackController = PlaybackController.shared
    @ObservedObject private var mediaController = MediaController.shared
    @State private var expandedSections: Set<ExpandableSection> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "flask")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Experimental Features")
                        .font(.headline)
                    Text("Experimental features that might be unstable & bit buggy.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("Experimental Features", isOn: $isExperimentalFeaturesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isExperimentalFeaturesEnabled) { _, newValue in
                        if !newValue {
                            playbackController.isPauseMediaEnabled = false
                        }
                    }
            }

            if isExperimentalFeaturesEnabled {
                Divider()
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                ExpandableToggleSection(
                    section: .pauseMedia,
                    title: "Pause Media during recording",
                    helpText: "Automatically pause active media playback during recordings and resume afterward.",
                    isEnabled: $playbackController.isPauseMediaEnabled,
                    expandedSections: $expandedSections
                ) {
                    HStack(spacing: 8) {
                        Text("Resume Delay")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Picker("", selection: $mediaController.audioResumptionDelay) {
                            Text("0s").tag(0.0)
                            Text("1s").tag(1.0)
                            Text("2s").tag(2.0)
                            Text("3s").tag(3.0)
                            Text("4s").tag(4.0)
                            Text("5s").tag(5.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)

                        InfoTip(
                            title: "Audio Resume Delay",
                            message: "Delay before resuming media playback after recording stops. Useful for Bluetooth headphones that need time to switch from microphone mode back to high-quality audio mode. Recommended: 2s for AirPods/Bluetooth headphones, 0s for wired headphones."
                        )

                        Spacer()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExperimentalFeaturesEnabled)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false, useAccentGradientWhenSelected: true))
    }
}
