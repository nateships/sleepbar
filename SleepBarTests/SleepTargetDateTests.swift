import XCTest
@testable import SleepBar

final class SleepTargetDateTests: XCTestCase {

    private var calendar: Calendar!
    /// 2026-03-10 09:30 local time.
    private var now: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 30))!
    }

    private func components(_ date: Date?) -> (day: Int, hour: Int, minute: Int) {
        let c = calendar.dateComponents([.day, .hour, .minute], from: date!)
        return (c.day!, c.hour!, c.minute!)
    }

    // MARK: - 12-hour to 24-hour conversion

    func testTwelveAM_isMidnight() {
        let c = components(sleepTargetDate(hour12: 12, minute: 0, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.hour, 0)
        XCTAssertEqual(c.day, 11, "midnight already passed today, so it rolls to tomorrow")
    }

    func testTwelvePM_isNoon() {
        let c = components(sleepTargetDate(hour12: 12, minute: 0, isPM: true, from: now, calendar: calendar))
        XCTAssertEqual(c.hour, 12)
        XCTAssertEqual(c.day, 10)
    }

    func testOnePM_isThirteen() {
        let c = components(sleepTargetDate(hour12: 1, minute: 0, isPM: true, from: now, calendar: calendar))
        XCTAssertEqual(c.hour, 13)
    }

    func testElevenAM_stays11() {
        let c = components(sleepTargetDate(hour12: 11, minute: 15, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.hour, 11)
        XCTAssertEqual(c.minute, 15)
    }

    func testElevenPM_is23() {
        let c = components(sleepTargetDate(hour12: 11, minute: 59, isPM: true, from: now, calendar: calendar))
        XCTAssertEqual(c.hour, 23)
        XCTAssertEqual(c.minute, 59)
    }

    // MARK: - Today vs tomorrow

    func testFutureTimeToday_staysToday() {
        let c = components(sleepTargetDate(hour12: 10, minute: 0, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.day, 10)
    }

    func testPastTimeToday_rollsToTomorrow() {
        let c = components(sleepTargetDate(hour12: 8, minute: 0, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.day, 11)
    }

    func testExactCurrentMinute_rollsToTomorrow() {
        // 9:30 AM equals `now`, which is not in the future.
        let c = components(sleepTargetDate(hour12: 9, minute: 30, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.day, 11)
    }

    func testOneMinuteAhead_staysToday() {
        let c = components(sleepTargetDate(hour12: 9, minute: 31, isPM: false, from: now, calendar: calendar))
        XCTAssertEqual(c.day, 10)
    }

    func testResultIsAlwaysInTheFuture() {
        for hour in 1...12 {
            for isPM in [false, true] {
                let target = sleepTargetDate(hour12: hour, minute: 0, isPM: isPM, from: now, calendar: calendar)!
                XCTAssertGreaterThan(target, now, "hour \(hour) \(isPM ? "PM" : "AM")")
                XCTAssertLessThanOrEqual(target.timeIntervalSince(now), 24 * 3600)
            }
        }
    }

    // MARK: - Month and DST boundaries

    func testPastTimeOnLastDayOfMonth_rollsIntoNextMonth() {
        let endOfMonth = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 22, minute: 0))!
        let target = sleepTargetDate(hour12: 6, minute: 0, isPM: false, from: endOfMonth, calendar: calendar)!
        let c = calendar.dateComponents([.month, .day, .hour], from: target)
        XCTAssertEqual(c.month, 4)
        XCTAssertEqual(c.day, 1)
        XCTAssertEqual(c.hour, 6)
    }

    func testAcrossSpringForwardDST_keepsWallClockHour() {
        // DST starts 2026-03-08 at 2:00 AM in New York.
        let beforeDST = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 0))!
        let target = sleepTargetDate(hour12: 7, minute: 0, isPM: false, from: beforeDST, calendar: calendar)!
        let c = calendar.dateComponents([.day, .hour], from: target)
        XCTAssertEqual(c.day, 8)
        XCTAssertEqual(c.hour, 7)
    }
}
