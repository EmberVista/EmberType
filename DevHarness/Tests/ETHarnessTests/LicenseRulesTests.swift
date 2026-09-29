import XCTest
@testable import ETHarness

final class LicenseRulesTests: XCTestCase {
    func testSha256MatchesKnownVector() {
        XCTAssertEqual(LicenseRules.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // Keys in the pre-1.1.1 format, which was published in the public source.
    func testOldFormatMasterKeysNoLongerUnlock() {
        for key in ["EMBER-MASTER-TEST", "EMBER-MASTER-BETA999", "ember-master-sample", " EMBER-MASTER-X\n"] {
            XCTAssertFalse(LicenseRules.isMasterKey(key), key)
            XCTAssertTrue(LicenseRules.isRetiredMasterKey(storedKey: key, activationId: "master-key-activation"), key)
            XCTAssertTrue(LicenseRules.isRetiredMasterKey(storedKey: key, activationId: nil), key)
        }
    }

    func testPolarKeysAreNeverTreatedAsMasterKeys() {
        let polarKey = "ET-3F2A1B4C-5D6E-4F70-8A9B-0C1D2E3F4A5B"
        XCTAssertFalse(LicenseRules.isMasterKey(polarKey))
        XCTAssertFalse(LicenseRules.isRetiredMasterKey(storedKey: polarKey, activationId: "6f1c2d3e-4b5a-4c6d-8e7f-9a0b1c2d3e4f"))
        XCTAssertFalse(LicenseRules.isRetiredMasterKey(storedKey: polarKey, activationId: nil))
    }

    // The keys live only in a private file outside the repo; skip where it doesn't exist.
    func testCurrentMasterKeysUnlockAndStayValid() throws {
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("EmberType-Releases/1.1.1/master-keys-PRIVATE.txt")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { throw XCTSkip("private key file not present") }
        let keys = text.split(separator: "\n").filter { !$0.hasPrefix("#") }.compactMap { $0.split(separator: " ").last.map(String.init) }
        XCTAssertEqual(keys.count, LicenseRules.masterKeyHashes.count)
        for key in keys {
            XCTAssertTrue(LicenseRules.isMasterKey(key), "hash missing for a key in the private file")
            XCTAssertTrue(LicenseRules.isMasterKey(" \(key.lowercased())\n"), "pasted variants should work")
            XCTAssertFalse(LicenseRules.isRetiredMasterKey(storedKey: key, activationId: "master-key-activation"))
        }
    }

    func testPastedWhitespaceIsTrimmedButCaseAndDashesKept() {
        XCTAssertEqual(LicenseRules.cleaned("  ET-abC-123 \n"), "ET-abC-123")
    }

    func testRevalidationSchedule() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(LicenseRules.isRevalidationDue(lastChecked: nil, now: now))
        XCTAssertFalse(LicenseRules.isRevalidationDue(lastChecked: now.addingTimeInterval(-2 * 86_400), now: now))
        XCTAssertTrue(LicenseRules.isRevalidationDue(lastChecked: now.addingTimeInterval(-3 * 86_400), now: now))
        // A check dated in the future (clock moved back) doesn't postpone the next one.
        XCTAssertTrue(LicenseRules.isRevalidationDue(lastChecked: now.addingTimeInterval(86_400), now: now))
    }
}
