import SwiftUI
import AppKit

struct DashboardPromotionsSection: View {
    let licenseState: LicenseViewModel.LicenseState
    @State private var isAffiliatePromotionDismissed: Bool = UserDefaults.standard.affiliatePromotionDismissed

    private var shouldShowAffiliatePromotion: Bool {
        if case .licensed = licenseState {
            return !isAffiliatePromotionDismissed
        }
        return false
    }

    var body: some View {
        if shouldShowAffiliatePromotion {
            DashboardPromotionCard(
                badge: "AFFILIATE 40%",
                title: "Earn With The EmberType Affiliate Program",
                message: "Share EmberType with friends or your audience and earn 40% on every referral that upgrades.",
                accentSymbol: "link.badge.plus",
                glowColor: DesignTokens.accent,
                actionTitle: "Explore Affiliate",
                actionIcon: "arrow.up.right",
                action: openAffiliateProgram,
                onDismiss: dismissAffiliatePromotion
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            EmptyView()
        }
    }

    private func openAffiliateProgram() {
        if let url = URL(string: "https://embertype.com/affiliate") {
            NSWorkspace.shared.open(url)
        }
    }

    private func dismissAffiliatePromotion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAffiliatePromotionDismissed = true
        }
        UserDefaults.standard.affiliatePromotionDismissed = true
    }
}

private struct DashboardPromotionCard: View {
    let badge: String
    let title: String
    let message: String
    let accentSymbol: String
    let glowColor: Color
    let actionTitle: String
    let actionIcon: String
    let action: () -> Void
    var onDismiss: (() -> Void)? = nil

    // Dark gradient matching website style
    private static let defaultGradient: LinearGradient = LinearGradient(
        colors: [
            DesignTokens.bgCard,
            DesignTokens.bgSecondary
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                Text(badge.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignTokens.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundColor(DesignTokens.accent)

                Text(title)
                    .font(DesignTokens.inter(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    HStack(spacing: 6) {
                        Text(actionTitle)
                        Image(systemName: actionIcon)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(DesignTokens.accent)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(12)
                .help("Dismiss this promotion")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous)
                .fill(Self.defaultGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous)
                .stroke(DesignTokens.border, lineWidth: DesignTokens.borderWidth)
        )
        .shadow(color: glowColor.opacity(0.15), radius: 12, x: 0, y: 8)
    }
}
