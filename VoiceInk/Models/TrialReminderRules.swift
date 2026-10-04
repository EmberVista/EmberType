import Foundation

/// When to show the "trial ends soon" reminder. No UI or storage here, so it can be unit tested.
enum TrialReminderRules {
    /// The reminder appears once the trial has this many days or fewer left.
    static let maxDaysRemaining = 2
    static let lastShownKey = "EmberTypeTrialReminderLastShown"
    static let price = "$39"

    /// `trialDaysRemaining` is nil when the app is licensed or the trial has expired.
    /// At most once per calendar day.
    static func shouldShow(trialDaysRemaining: Int?, lastShown: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let days = trialDaysRemaining, days > 0, days <= maxDaysRemaining else { return false }
        guard let lastShown else { return true }
        return !calendar.isDate(lastShown, inSameDayAs: now)
    }

    static func title(daysRemaining: Int) -> String {
        daysRemaining <= 1
            ? "Your EmberType trial ends within a day"
            : "Your EmberType trial ends in \(daysRemaining) days"
    }
}
