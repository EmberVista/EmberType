import Foundation
import AppKit

// MARK: - Master Keys for Beta Testers
// These keys bypass Polar.sh validation entirely.
// Generate new keys by creating unique strings with the EMBER-MASTER prefix.
// Example: EMBER-MASTER-BETA001, EMBER-MASTER-FRIEND-JOHN, etc.
private let masterKeys: Set<String> = [
    "EMBER-MASTER-DEV",           // Developer key
    "EMBER-MASTER-BETA001",       // Beta tester keys
    "EMBER-MASTER-BETA002",
    "EMBER-MASTER-BETA003",
    "EMBER-MASTER-BETA004",
    "EMBER-MASTER-BETA005",
    "EMBER-MASTER-REVIEW001",     // Reviewer keys (press, YouTubers)
    "EMBER-MASTER-REVIEW002",
    "EMBER-MASTER-REVIEW003",
]

@MainActor
class LicenseViewModel: ObservableObject {
    enum LicenseState: Equatable {
        case trial(daysRemaining: Int)
        case trialExpired
        case licensed
    }

    @Published private(set) var licenseState: LicenseState = .trial(daysRemaining: 7)  // Default to trial
    @Published var licenseKey: String = ""
    @Published var isValidating = false
    @Published var validationMessage: String?
    @Published private(set) var activationsLimit: Int = 0

    private let trialPeriodDays = 7
    private let polarService = PolarService()
    private let userDefaults = UserDefaults.standard
    private let licenseManager = LicenseManager.shared

    init() {
        loadLicenseState()
        // Note: Notification observer removed - all views now share the same LicenseViewModel instance
        // via @EnvironmentObject, so state changes propagate automatically through SwiftUI.
    }

    func startTrial() {
        // Only start trial if no license key exists and no trial has started
        guard licenseManager.licenseKey == nil else {
            loadLicenseState()
            return
        }

        if licenseManager.trialStartDate == nil {
            licenseManager.trialStartDate = Date()
            userDefaults.set(true, forKey: "EmberTypeHasLaunchedBefore")
        }

        loadLicenseState()
    }

    private func loadLicenseState() {
        #if DEBUG
        // Debug: Use Xcode launch arguments to test license states
        // In Xcode: Product > Scheme > Edit Scheme > Run > Arguments
        // Add one of: -forceLicensed, -forceTrial, -forceExpired
        if CommandLine.arguments.contains("-forceLicensed") {
            licenseState = .licensed
            return
        } else if CommandLine.arguments.contains("-forceTrial") {
            licenseState = .trial(daysRemaining: 7)
            return
        } else if CommandLine.arguments.contains("-forceExpired") {
            licenseState = .trialExpired
            return
        }
        #endif

        // Check for valid license first (Keychain)
        if let storedKey = licenseManager.licenseKey, !storedKey.isEmpty {
            licenseState = .licensed
            return
        }

        // Check for master key backup (UserDefaults fallback)
        if let backupKey = userDefaults.string(forKey: "EmberTypeMasterKeyBackup"),
           masterKeys.contains(backupKey) {
            licenseState = .licensed
            return
        }

        // Check trial status
        guard let trialStart = licenseManager.trialStartDate else {
            // No trial started yet - start one
            licenseManager.trialStartDate = Date()
            userDefaults.set(true, forKey: "EmberTypeHasLaunchedBefore")
            licenseState = .trial(daysRemaining: trialPeriodDays)
            return
        }

        // Calculate days remaining in trial
        let daysSinceTrialStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
        let daysRemaining = max(0, trialPeriodDays - daysSinceTrialStart)

        if daysRemaining > 0 {
            licenseState = .trial(daysRemaining: daysRemaining)
        } else {
            licenseState = .trialExpired
        }
    }
    
    var canUseApp: Bool {
        switch licenseState {
        case .licensed, .trial:
            return true
        case .trialExpired:
            return false
        }
    }
    
    func openPurchaseLink() {
        if let url = URL(string: "https://buy.polar.sh/polar_cl_d8zIzbrwr8yG93D3zyFfwtTuXnq901xsA3Fgo0oT3xg") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func validateLicense() async {
        guard !licenseKey.isEmpty else {
            validationMessage = "Please enter a license key"
            return
        }

        isValidating = true

        // Check for master keys first (bypass Polar.sh validation)
        let normalizedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if masterKeys.contains(normalizedKey) {
            // Master key - activate without API call
            licenseManager.licenseKey = normalizedKey
            licenseManager.activationId = "master-key-activation"
            self.activationsLimit = 999  // Unlimited for master keys
            userDefaults.activationsLimit = 999
            userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
            // Backup: Also store in UserDefaults for master keys (Keychain can be unreliable)
            userDefaults.set(normalizedKey, forKey: "EmberTypeMasterKeyBackup")

            licenseState = .licensed
            validationMessage = "License activated successfully!"
            NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
            isValidating = false
            return
        }

        do {
            // First, check if the license is valid and if it requires activation
            let licenseCheck = try await polarService.checkLicenseRequiresActivation(licenseKey)
            
            if !licenseCheck.isValid {
                validationMessage = "Invalid license key"
                isValidating = false
                return
            }
            
            // Store the license key
            licenseManager.licenseKey = licenseKey

            // Handle based on whether activation is required
            if licenseCheck.requiresActivation {
                // Only reuse activation ID if it's for the SAME license key AND is a valid UUID (not "master-key-activation")
                let storedKey = licenseManager.licenseKey
                let existingActivationId = licenseManager.activationId

                if let existingActivationId = existingActivationId,
                   let storedKey = storedKey,
                   storedKey == licenseKey,
                   existingActivationId != "master-key-activation" {
                    // Revalidate existing activation for the same key
                    let isValid = try await polarService.validateLicenseKeyWithActivation(licenseKey, activationId: existingActivationId)
                    if isValid {
                        // Existing activation is valid
                        licenseState = .licensed
                        validationMessage = "License activated successfully!"
                        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
                        isValidating = false
                        return
                    }
                }

                // New key or invalid activation - clear old activation data
                licenseManager.activationId = nil

                // Need to create a new activation
                let (newActivationId, limit) = try await polarService.activateLicenseKey(licenseKey)

                // Store activation details
                licenseManager.activationId = newActivationId
                userDefaults.set(true, forKey: "EmberTypeLicenseRequiresActivation")
                self.activationsLimit = limit
                userDefaults.activationsLimit = limit

            } else {
                // This license doesn't require activation (unlimited devices)
                licenseManager.activationId = nil
                userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
                self.activationsLimit = licenseCheck.activationsLimit ?? 0
                userDefaults.activationsLimit = licenseCheck.activationsLimit ?? 0

                // Update the license state for unlimited license
                licenseState = .licensed
                validationMessage = "License validated successfully!"
                NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
                isValidating = false
                return
            }
            
            // Update the license state for activated license
            licenseState = .licensed
            validationMessage = "License activated successfully!"
            NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
            
        } catch LicenseError.activationLimitReached(let details) {
            validationMessage = "Activation limit reached: \(details)"
        } catch LicenseError.activationNotRequired {
            // This is actually a success case for unlimited licenses
            licenseManager.licenseKey = licenseKey
            licenseManager.activationId = nil
            userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
            self.activationsLimit = 0
            userDefaults.activationsLimit = 0

            licenseState = .licensed
            validationMessage = "License activated successfully!"
            NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        } catch {
            validationMessage = error.localizedDescription
        }
        
        isValidating = false
    }
    
    func removeLicense() {
        // Remove all license data from Keychain
        licenseManager.removeAll()

        // Reset UserDefaults flags
        userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
        userDefaults.set(false, forKey: "EmberTypeHasLaunchedBefore")  // Allow trial to restart
        userDefaults.activationsLimit = 0

        licenseState = .trial(daysRemaining: trialPeriodDays)  // Reset to trial state
        licenseKey = ""
        validationMessage = nil
        activationsLimit = 0
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        loadLicenseState()
    }
}


// UserDefaults extension for non-sensitive license settings
extension UserDefaults {
    var activationsLimit: Int {
        get { integer(forKey: "EmberTypeActivationsLimit") }
        set { set(newValue, forKey: "EmberTypeActivationsLimit") }
    }
}
