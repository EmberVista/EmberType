import Foundation

/// The buy link, tagged with the in-app spot the click came from.
/// embertype.com/buy/ adds the affiliate referral from the browser's cookie (so
/// affiliates keep credit for in-app purchases) and forwards to the Polar checkout
/// with the `utm_*` parameters, which Polar copies into the checkout's metadata
/// (https://polar.sh/docs/features/checkout/links.md, "Query parameters").
/// No `plan` parameter, so it opens the individual license.
enum PurchaseLink {
    static let checkoutURL = "https://embertype.com/buy/"

    enum Source: String, CaseIterable {
        case trialReminder = "app-trial-reminder"      // reminder shown in the last days of the trial
        case trialExpired = "app-trial-expired"        // opened automatically when an expired trial tries to dictate
        case dashboardTrial = "app-dashboard-trial"    // Dashboard banner during the trial
        case dashboardExpired = "app-dashboard-expired" // Dashboard banner after the trial ends
        case licenseView = "app-license-view"          // EmberType Pro page
    }

    static func url(source: Source) -> URL {
        var components = URLComponents(string: checkoutURL)!
        components.queryItems = [
            URLQueryItem(name: "utm_source", value: source.rawValue),
            URLQueryItem(name: "utm_medium", value: "app"),
        ]
        return components.url!
    }
}
