import SwiftUI

/// Shown at most once a day over the main window in the last days of the trial.
struct TrialReminderView: View {
    let daysRemaining: Int
    let onBuy: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 28))
                .foregroundColor(DesignTokens.accent)

            Text(TrialReminderRules.title(daysRemaining: daysRemaining))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Buy once for \(TrialReminderRules.price) and keep dictating on up to 3 Macs. No subscription.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onLater) {
                    Text("Later")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(action: onBuy) {
                    Text("Buy EmberType — \(TrialReminderRules.price)")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 380)
    }
}
