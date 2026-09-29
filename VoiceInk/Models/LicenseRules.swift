import Foundation
import CryptoKit

/// License decisions that need no network, Keychain or UI, so they can be unit tested.
enum LicenseRules {
    /// SHA-256 of each master key. The keys themselves are kept out of the source,
    /// which is public. Generate a key, then add its hash here.
    static let masterKeyHashes: Set<String> = [
        "a577453a7afd41adc2736dbca5a30ce47ac60240a49890880def384ab31dcd28", // DEV
        "7f32c691c9ba5862be4f4c821c957c4c49ba3388b179f59d72708635574d6213", // BETA001
        "863fa89dc6a1ca88c2a174aaf127ad7f04e0b878d11b69b48441ac7fff8e12fa", // BETA002
        "868e13958f68f65a90eb9c62bc30283510fc5bad66f5b80da833015d5f7de980", // BETA003
        "fceec78cdacc1e3e25e9feba301504d099f67485c2d9f4f527a8c46f01405050", // BETA004
        "ae16178ab51af83306753df67192eb6e30b772fa9805336ec9fc627c0bb4c623", // BETA005
        "7972a125d9b46b567bc9297f204bd28325d45f2f743c70481e1bc2d934bc9b96", // REVIEW001
        "68e5faab4e254a8d3ff29a5d5678ae87fd95fd0f88fc95ab9580bd41c11cc328", // REVIEW002
        "d9e9cde1f5154c147538ef396c5c778d6dcb3033caded09cc8e721e8c43f3a4d", // REVIEW003
    ]

    /// Activation ID stored alongside a master key, which Polar never sees.
    static let masterKeyActivationId = "master-key-activation"

    /// How often a stored Polar license is re-checked.
    static let revalidationInterval: TimeInterval = 3 * 24 * 60 * 60

    /// Trims pasted whitespace and newlines. Polar keys keep their case and dashes.
    static func cleaned(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isMasterKey(_ key: String) -> Bool {
        masterKeyHashes.contains(sha256(cleaned(key).uppercased()))
    }

    /// A stored key that bypassed Polar but is no longer a valid master key,
    /// such as the master keys used before 1.1.1.
    static func isRetiredMasterKey(storedKey: String, activationId: String?) -> Bool {
        let looksLikeMaster = activationId == masterKeyActivationId || cleaned(storedKey).uppercased().hasPrefix("EMBER-")
        return looksLikeMaster && !isMasterKey(storedKey)
    }

    static func isRevalidationDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= revalidationInterval || lastChecked > now
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
