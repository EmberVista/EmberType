import Foundation
import os

/// Lets EmberType require an update remotely. https://embertype.com/app-config.json holds
/// `{"minimumBuild": N}`; builds below N stop transcribing and ask the user to update.
/// Only raise N to a build that is already live in the appcast, or nobody can comply.
enum MinimumVersion {
    static let configURL = URL(string: "https://embertype.com/app-config.json")!
    static let minimumBuildKey = "EmberTypeMinimumBuild"
    static let lastFetchKey = "EmberTypeMinimumBuildFetchedAt"
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    private static let logger = Logger(subsystem: "com.embervista.embertype", category: "MinimumVersion")

    static func parseMinimumBuild(_ data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["minimumBuild"] as? NSNumber)?.intValue
    }

    static func isUpdateRequired(currentBuild: Int, minimumBuild: Int) -> Bool {
        currentBuild < minimumBuild
    }

    static func isRefreshDue(lastFetch: Date?, now: Date) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= refreshInterval || lastFetch > now
    }

    /// An unreadable build number never blocks.
    static var currentBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? .max
    }

    /// Uses the last value fetched, so the requirement also holds offline.
    static var isUpdateRequired: Bool {
        isUpdateRequired(currentBuild: currentBuild, minimumBuild: UserDefaults.standard.integer(forKey: minimumBuildKey))
    }

    static func refreshIfDue() async {
        let defaults = UserDefaults.standard
        guard isRefreshDue(lastFetch: defaults.object(forKey: lastFetchKey) as? Date, now: Date()) else { return }

        var request = URLRequest(url: configURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let minimumBuild = parseMinimumBuild(data) else {
            return  // Offline or a bad file: keep the last known value
        }
        defaults.set(minimumBuild, forKey: minimumBuildKey)
        defaults.set(Date(), forKey: lastFetchKey)
        logger.notice("Minimum build \(minimumBuild), this build \(currentBuild)")
    }
}
