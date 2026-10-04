import XCTest
@testable import ETHarness

final class TrialReminderTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func shows(_ days: Int?, lastShown: Date? = nil, now: Date? = nil) -> Bool {
        TrialReminderRules.shouldShow(trialDaysRemaining: days, lastShown: lastShown, now: now ?? date(2, 10), calendar: calendar)
    }

    func testShowsOnlyInTheLastTwoDays() {
        XCTAssertFalse(shows(7))
        XCTAssertFalse(shows(3))
        XCTAssertTrue(shows(2))
        XCTAssertTrue(shows(1))
    }

    func testNeverWhenLicensedOrExpired() {
        XCTAssertFalse(shows(nil))  // licensed or expired
        XCTAssertFalse(shows(0))
        XCTAssertFalse(shows(-1))
    }

    func testAtMostOncePerDay() {
        XCTAssertFalse(shows(2, lastShown: date(2, 9), now: date(2, 23, 59)))
        XCTAssertFalse(shows(1, lastShown: date(2, 0, 1), now: date(2, 18)))
        XCTAssertTrue(shows(1, lastShown: date(2, 23, 59), now: date(3, 0, 1)))  // next calendar day
        XCTAssertTrue(shows(2, lastShown: date(1, 10), now: date(2, 10)))
    }

    func testAlreadyShownTodayNeverOverridesLicensedOrExpired() {
        XCTAssertFalse(shows(nil, lastShown: date(1, 10)))
        XCTAssertFalse(shows(0, lastShown: date(1, 10)))
    }

    func testClockMovedBackStillAtMostOncePerDay() {
        XCTAssertTrue(shows(2, lastShown: date(5, 10), now: date(2, 10)))
        XCTAssertFalse(shows(2, lastShown: date(2, 11), now: date(2, 10)))
    }

    func testTitles() {
        XCTAssertEqual(TrialReminderRules.title(daysRemaining: 2), "Your EmberType trial ends in 2 days")
        XCTAssertEqual(TrialReminderRules.title(daysRemaining: 1), "Your EmberType trial ends within a day")
    }
}

final class PurchaseLinkTests: XCTestCase {
    func testEveryLinkKeepsTheCheckoutAndNamesItsSource() throws {
        for source in PurchaseLink.Source.allCases {
            let url = PurchaseLink.url(source: source)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, "embertype.com")
            XCTAssertEqual(components.path, "/buy/")
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(query["utm_source"], source.rawValue)
            XCTAssertEqual(query["utm_medium"], "app")
            XCTAssertEqual(query.count, 2)  // no plan, so the individual license
            // embertype.com/buy/ only passes utm values made of [A-Za-z0-9._-], up to 64 characters
            XCTAssertNotNil(source.rawValue.range(of: "^[A-Za-z0-9._-]{1,64}$", options: .regularExpression))
        }
    }

    func testSourcesAreDistinct() {
        let names = PurchaseLink.Source.allCases.map(\.rawValue)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(PurchaseLink.url(source: .trialReminder).absoluteString,
                       "https://embertype.com/buy/?utm_source=app-trial-reminder&utm_medium=app")
    }
}
