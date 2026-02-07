import SwiftUI

struct LicenseManagementView: View {
    @EnvironmentObject private var licenseViewModel: LicenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                
                // Main Content
                VStack(spacing: 32) {
                    if case .licensed = licenseViewModel.licenseState {
                        activatedContent
                    } else {
                        purchaseContent
                    }
                }
                .padding(32)
            }
        }
        .background(
            ZStack {
                Color(NSColor.controlBackgroundColor)
                GridBackgroundView(opacity: 0.06)
            }
        )
    }
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            // App Icon
            AppIconView()
            
            // Title Section
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignTokens.accent)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 8) { 
                        Text(licenseViewModel.licenseState == .licensed ? "EmberType Pro" : "Upgrade to Pro")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("v\(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                }
                
                Text(licenseViewModel.licenseState == .licensed ?
                     "Thank you for supporting EmberType" :
                     "Transcribe what you say to text instantly with AI")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if case .licensed = licenseViewModel.licenseState {
                    HStack(spacing: 40) {
                        Button {
                            if let url = URL(string: "https://github.com/EmberVista/EmberType/releases") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            featureItem(icon: "list.bullet.clipboard.fill", title: "Changelog", color: DesignTokens.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            EmailSupport.openSupportEmail()
                        } label: {
                            featureItem(icon: "envelope.fill", title: "Email Support", color: DesignTokens.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let url = URL(string: "https://embertype.com/docs") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            featureItem(icon: "book.fill", title: "Docs", color: DesignTokens.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let url = URL(string: "https://embertype.com/tip") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            featureItem(icon: "heart.fill", title: "Tip Jar", color: DesignTokens.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical, 60)
    }
    
    private var purchaseContent: some View {
        VStack(spacing: 40) {
            // Purchase Card
            VStack(spacing: 24) {
                // Lifetime Access Badge
                HStack {
                    Image(systemName: "infinity.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.accent)
                    Text("Buy Once, Own Forever")
                        .font(.headline)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(DesignTokens.accent.opacity(0.1))
                .cornerRadius(DesignTokens.cornerRadiusCard)
                
                // Purchase Button 
                Button(action: {
                    if let url = URL(string: "https://buy.polar.sh/polar_cl_d8zIzbrwr8yG93D3zyFfwtTuXnq901xsA3Fgo0oT3xg") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Upgrade to EmberType Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                
                // Features Grid
                HStack(spacing: 40) {
                    featureItem(icon: "bubble.left.and.bubble.right.fill", title: "Priority Support", color: DesignTokens.accent)
                    featureItem(icon: "infinity.circle.fill", title: "Lifetime Access", color: DesignTokens.accent)
                    featureItem(icon: "arrow.up.circle.fill", title: "Free Updates", color: DesignTokens.accent)
                    featureItem(icon: "macbook.and.iphone", title: "Up to 3 Macs", color: DesignTokens.accent)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(32)
            .background(CardBackground(isSelected: false))
            .shadow(color: .black.opacity(0.05), radius: 10)

            // License Activation
            VStack(spacing: 20) {
                Text("Already have a license?")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    TextField("Enter your license key", text: $licenseViewModel.licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                    
                    Button(action: {
                        Task { await licenseViewModel.validateLicense() }
                    }) {
                        if licenseViewModel.isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Activate")
                                .frame(width: 80)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseViewModel.isValidating)
                }
                
                if let message = licenseViewModel.validationMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.callout)
                }
            }
            .padding(32)
            .background(CardBackground(isSelected: false))
            .shadow(color: .black.opacity(0.05), radius: 10)
            
            // Already Purchased Section
            VStack(spacing: 16) {
                Text("Already purchased?")
                    .font(.headline)

                Text("Your license key was emailed to you after purchase. You can also view your key and manage device activations through our payment provider, Polar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://polar.sh/purchases") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Manage License")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        if let url = URL(string: "https://embertype.com/docs#license-help") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("License Help")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(32)
            .background(CardBackground(isSelected: false))
            .shadow(color: .black.opacity(0.05), radius: 10)
        }
    }
    
    private var activatedContent: some View {
        VStack(spacing: 32) {
            // Status Card
            VStack(spacing: 24) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignTokens.accent)
                    Text("License Active")
                        .font(.headline)
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignTokens.accent))
                        .foregroundStyle(.white)
                }
                
                Divider()
                
                Text("Your license is valid for up to 3 personal Macs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(CardBackground(isSelected: false))
            .shadow(color: .black.opacity(0.05), radius: 10)
            
            // Deactivation Card
            VStack(alignment: .leading, spacing: 16) {
                Text("License Management")
                    .font(.headline)

                Button(role: .destructive, action: {
                    licenseViewModel.removeLicense()
                }) {
                    Label("Deactivate License", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .background(CardBackground(isSelected: false))
            .shadow(color: .black.opacity(0.05), radius: 10)
        }
    }
    
    private func featureItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
    
}


