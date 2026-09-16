import XCTest
@testable import SleepBar

/// Covers settings restore, timer expiry, and the Sleep Now path. The sleep
/// command is replaced by `sleepAction` so that no test puts the Mac to sleep.
@MainActor
final class SleepTimerManagerExpiryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var manager: SleepTimerManager!
    private let suiteName = "SleepTimerManagerExpiryTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        manager = SleepTimerManager(defaults: defaults)
        manager.sleepAction = { _ in
            XCTFail("sleepAction called without a test expectation")
        }
    }

    override func tearDown() {
        manager.cancelTimer()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - Settings restored from defaults

    func testWarningThreshold_loadedFromDefaults() {
        defaults.set(300.0, forKey: "warningThreshold")
        let restored = SleepTimerManager(defaults: defaults)
        XCTAssertEqual(restored.warningThreshold, 300)
    }

    func testWarningEnabled_loadedFromDefaults() {
        defaults.set(false, forKey: "warningEnabled")
        let restored = SleepTimerManager(defaults: defaults)
        XCTAssertFalse(restored.warningEnabled)
    }

    func testDefaults_whenNothingStored() {
        XCTAssertEqual(manager.warningThreshold, 60)
        XCTAssertTrue(manager.warningEnabled)
        XCTAssertEqual(manager.sleepMode, .system)
    }

    // MARK: - Start state

    func testStartTimer_setsEndDateAndText() {
        manager.startTimer(minutes: 15)
        let expectedEnd = Date().addingTimeInterval(15 * 60)
        XCTAssertEqual(manager.endDate!.timeIntervalSince(expectedEnd), 0, accuracy: 1)
        XCTAssertTrue(["15:00", "14:59"].contains(manager.timeRemainingText), manager.timeRemainingText)
        XCTAssertFalse(manager.targetTimeText.isEmpty)
    }

    func testTargetTimeText_emptyWhenInactive() {
        XCTAssertEqual(manager.targetTimeText, "")
        manager.startTimer(minutes: 15)
        manager.cancelTimer()
        XCTAssertEqual(manager.targetTimeText, "")
    }

    func testStartTimer_afterInvalidAlert_clearsInvalidFlag() {
        manager.setWarningThreshold(seconds: 120)
        manager.startTimer(minutes: 1)
        XCTAssertTrue(manager.isAlertTimeInvalid)
        XCTAssertFalse(manager.isActive)

        manager.startTimer(minutes: 15)
        XCTAssertFalse(manager.isAlertTimeInvalid)
        XCTAssertTrue(manager.isActive)
    }

    func testStartTimer_replacesRunningTimer() {
        manager.startTimer(minutes: 15)
        let firstEnd = manager.endDate!
        manager.startTimer(minutes: 60)
        XCTAssertGreaterThan(manager.endDate!, firstEnd.addingTimeInterval(40 * 60))
        XCTAssertTrue(manager.isActive)
    }

    // MARK: - Expiry

    func testTimerExpiry_callsSleepActionWithModeAndResetsState() {
        manager.setWarningEnabled(false)
        manager.setSleepMode(.display)

        let slept = expectation(description: "sleepAction called")
        var receivedMode: SleepMode?
        manager.sleepAction = { mode in
            receivedMode = mode
            slept.fulfill()
        }

        manager.startTimer(seconds: 1)
        XCTAssertTrue(manager.isActive)

        wait(for: [slept], timeout: 5)
        XCTAssertEqual(receivedMode, .display)
        XCTAssertFalse(manager.isActive)
        XCTAssertNil(manager.endDate)
        XCTAssertEqual(manager.timeRemaining, 0)
    }

    func testCancelledTimer_neverCallsSleepAction() {
        manager.setWarningEnabled(false)
        manager.startTimer(seconds: 1)
        manager.cancelTimer()

        // sleepAction from setUp fails the test if it fires.
        let idle = expectation(description: "wait past the original end date")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { idle.fulfill() }
        wait(for: [idle], timeout: 5)
        XCTAssertFalse(manager.isActive)
    }

    func testSnoozedTimer_doesNotExpireAtOriginalEndDate() {
        manager.setWarningEnabled(false)
        manager.startTimer(seconds: 1)
        manager.snoozeTimer(minutes: 60)

        let idle = expectation(description: "wait past the original end date")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { idle.fulfill() }
        wait(for: [idle], timeout: 5)
        XCTAssertTrue(manager.isActive)
    }

    // MARK: - Sleep Now

    func testExecuteSleep_usesCurrentModeAndHidesNothingElse() {
        manager.setSleepMode(.system)
        var receivedMode: SleepMode?
        manager.sleepAction = { receivedMode = $0 }

        manager.executeSleep()
        XCTAssertEqual(receivedMode, .system)
    }
}
