import Foundation
import AppKit

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

    /// Re-evaluate license state against the trial start date.
    /// Call this before gating behavior on `.trialExpired` so the in-memory state reflects real time,
    /// not just the state captured at app launch.
    func refreshLicenseState() {
        loadLicenseState()
    }

    private func loadLicenseState() {
        #if DEBUG
        // Debug: Use Xcode launch arguments to test license states
        // In Xcode: Product > Scheme > Edit Scheme > Run > Arguments
        // Add one of: -forceLicensed, -forceTrial, -forceExpired, -forceTrialDays N
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-forceTrialDays"), i + 1 < args.count, let days = Int(args[i + 1]) {
            licenseState = days > 0 ? .trial(daysRemaining: days) : .trialExpired
            return
        } else if args.contains("-forceLicensed") {
            licenseState = .licensed
            return
        } else if args.contains("-forceTrial") {
            licenseState = .trial(daysRemaining: 7)
            return
        } else if args.contains("-forceExpired") {
            licenseState = .trialExpired
            return
        }
        #endif

        // Pre-1.1.1 builds kept a plain-text master key copy here. It no longer unlocks anything.
        userDefaults.removeObject(forKey: "EmberTypeMasterKeyBackup")

        // Check for valid license first (Keychain)
        if let storedKey = licenseManager.licenseKey, !storedKey.isEmpty {
            if LicenseRules.isRetiredMasterKey(storedKey: storedKey, activationId: licenseManager.activationId) {
                // The old master keys were published in the public source, so they are retired.
                licenseManager.licenseKey = nil
                licenseManager.activationId = nil
            } else {
                licenseState = .licensed
                return
            }
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
    
    func openPurchaseLink(source: PurchaseLink.Source) {
        NSWorkspace.shared.open(PurchaseLink.url(source: source))
    }

    /// Days left while in trial; nil when licensed or expired.
    var trialDaysRemaining: Int? {
        if case .trial(let daysRemaining) = licenseState { return daysRemaining }
        return nil
    }

    /// True at most once a day in the last days of the trial. Marks the reminder as shown.
    func takeTrialReminderIfDue() -> Bool {
        refreshLicenseState()
        let now = Date()
        guard TrialReminderRules.shouldShow(
            trialDaysRemaining: trialDaysRemaining,
            lastShown: userDefaults.object(forKey: TrialReminderRules.lastShownKey) as? Date,
            now: now
        ) else { return false }
        userDefaults.set(now, forKey: TrialReminderRules.lastShownKey)
        return true
    }
    
    func validateLicense() async {
        let key = LicenseRules.cleaned(licenseKey)
        guard !key.isEmpty else {
            validationMessage = "Please enter a license key"
            return
        }

        isValidating = true
        defer { isValidating = false }

        if LicenseRules.isMasterKey(key) {
            // Master key - activate without API call
            licenseManager.licenseKey = key.uppercased()
            licenseManager.activationId = LicenseRules.masterKeyActivationId
            self.activationsLimit = 999  // Unlimited for master keys
            userDefaults.activationsLimit = 999
            userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
            markLicensed(message: "License activated successfully!")
            return
        }

        // The key is stored only once Polar has accepted it, so a failed activation
        // (for example on a 4th Mac) never leaves a working license behind.
        do {
            let licenseCheck = try await polarService.checkLicenseRequiresActivation(key)
            guard licenseCheck.isValid else {
                validationMessage = "Invalid license key"
                return
            }

            if licenseCheck.requiresActivation {
                // Reuse this Mac's activation when re-entering the same key
                if let existingActivationId = licenseManager.activationId,
                   licenseManager.licenseKey == key,
                   existingActivationId != LicenseRules.masterKeyActivationId,
                   (try? await polarService.validateLicenseKeyWithActivation(key, activationId: existingActivationId)) == true {
                    markLicensed(message: "License activated successfully!")
                    return
                }

                let (newActivationId, limit) = try await polarService.activateLicenseKey(key)
                licenseManager.licenseKey = key
                licenseManager.activationId = newActivationId
                userDefaults.set(true, forKey: "EmberTypeLicenseRequiresActivation")
                self.activationsLimit = limit
                userDefaults.activationsLimit = limit
                markLicensed(message: "License activated successfully!")
            } else {
                // This license doesn't require activation (unlimited devices)
                storeUnlimitedLicense(key, limit: licenseCheck.activationsLimit ?? 0)
                markLicensed(message: "License validated successfully!")
            }
        } catch LicenseError.activationLimitReached(let details) {
            validationMessage = "Activation limit reached: \(details)"
        } catch LicenseError.activationNotRequired {
            // This is actually a success case for unlimited licenses
            storeUnlimitedLicense(key, limit: 0)
            markLicensed(message: "License activated successfully!")
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    /// Re-checks a stored Polar license every few days, so refunded or revoked keys stop working.
    /// Only a definite answer from Polar removes the license; being offline never does.
    func revalidateIfDue() async {
        guard let key = licenseManager.licenseKey, !key.isEmpty, !LicenseRules.isMasterKey(key) else { return }
        let lastCheckedKey = "EmberTypeLicenseLastChecked"
        guard LicenseRules.isRevalidationDue(lastChecked: userDefaults.object(forKey: lastCheckedKey) as? Date, now: Date()) else { return }

        let stillValid: Bool
        do {
            if let activationId = licenseManager.activationId {
                stillValid = try await polarService.validateLicenseKeyWithActivation(key, activationId: activationId)
            } else {
                stillValid = try await polarService.checkLicenseRequiresActivation(key).isValid
            }
        } catch LicenseError.notFound {
            stillValid = false
        } catch {
            return  // Offline or a Polar outage: keep the license and try again later
        }

        userDefaults.set(Date(), forKey: lastCheckedKey)
        guard !stillValid else { return }

        // A key entered again while this check was running is left alone.
        guard licenseManager.licenseKey == key else { return }
        licenseManager.licenseKey = nil
        licenseManager.activationId = nil
        userDefaults.activationsLimit = 0
        activationsLimit = 0
        validationMessage = "Your license is no longer active. Please re-enter your license key."
        loadLicenseState()
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
    }

    private func storeUnlimitedLicense(_ key: String, limit: Int) {
        licenseManager.licenseKey = key
        licenseManager.activationId = nil
        userDefaults.set(false, forKey: "EmberTypeLicenseRequiresActivation")
        self.activationsLimit = limit
        userDefaults.activationsLimit = limit
    }

    private func markLicensed(message: String) {
        licenseState = .licensed
        validationMessage = message
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
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
