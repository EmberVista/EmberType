import XCTest
@testable import ETHarness

final class MinimumVersionTests: XCTestCase {
    private func parse(_ json: String) -> Int? { MinimumVersion.parseMinimumBuild(Data(json.utf8)) }

    func testParsesTheConfigFile() {
        XCTAssertEqual(parse(#"{"minimumBuild": 208}"#), 208)
        XCTAssertEqual(parse(#"{"minimumBuild": 0, "note": "anything"}"#), 0)
    }

    // A broken or unexpected file must never block anyone.
    func testBadFilesAreIgnored() {
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("<html>404</html>"))
        XCTAssertNil(parse(#"{"minimumBuild": "208"}"#))
        XCTAssertNil(parse(#"{"other": 1}"#))
        XCTAssertNil(parse("[208]"))
    }

    func testOnlyOlderBuildsAreBlocked() {
        XCTAssertTrue(MinimumVersion.isUpdateRequired(currentBuild: 207, minimumBuild: 208))
        XCTAssertFalse(MinimumVersion.isUpdateRequired(currentBuild: 208, minimumBuild: 208))
        XCTAssertFalse(MinimumVersion.isUpdateRequired(currentBuild: 209, minimumBuild: 208))
        XCTAssertFalse(MinimumVersion.isUpdateRequired(currentBuild: 208, minimumBuild: 0))
        XCTAssertFalse(MinimumVersion.isUpdateRequired(currentBuild: .max, minimumBuild: 999))
    }

    func testRefreshSchedule() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(MinimumVersion.isRefreshDue(lastFetch: nil, now: now))
        XCTAssertFalse(MinimumVersion.isRefreshDue(lastFetch: now.addingTimeInterval(-5 * 3600), now: now))
        XCTAssertTrue(MinimumVersion.isRefreshDue(lastFetch: now.addingTimeInterval(-6 * 3600), now: now))
        XCTAssertTrue(MinimumVersion.isRefreshDue(lastFetch: now.addingTimeInterval(3600), now: now))
    }
}
