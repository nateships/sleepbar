import XCTest
@testable import SleepBar

@MainActor
final class SleepTimerManagerTests: XCTestCase {
    
    private var defaults: UserDefaults!
    private var manager: SleepTimerManager!
    private let suiteName = "SleepTimerManagerTests"
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        manager = SleepTimerManager(defaults: defaults)
    }
    
    override func tearDown() {
        manager.cancelTimer()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
        super.tearDown()
    }
    
    // MARK: - formatTimeRemaining
    
    func testFormatTimeRemaining_secondsOnly() {
        XCTAssertEqual(manager.formatTimeRemaining(45), "0:45")
    }
    
    func testFormatTimeRemaining_minutesAndSeconds() {
        XCTAssertEqual(manager.formatTimeRemaining(90), "1:30")
    }
    
    func testFormatTimeRemaining_exactMinute() {
        XCTAssertEqual(manager.formatTimeRemaining(60), "1:00")
    }
    
    func testFormatTimeRemaining_hoursMinutesSeconds() {
        XCTAssertEqual(manager.formatTimeRemaining(3661), "1:01:01")
    }
    
    func testFormatTimeRemaining_exactHour() {
        XCTAssertEqual(manager.formatTimeRemaining(3600), "1:00:00")
    }
    
    func testFormatTimeRemaining_zero() {
        XCTAssertEqual(manager.formatTimeRemaining(0), "0:00")
    }
    
    func testFormatTimeRemaining_largeValue() {
        XCTAssertEqual(manager.formatTimeRemaining(7384), "2:03:04")
    }
    
    func testFormatTimeRemaining_singleDigitSeconds() {
        XCTAssertEqual(manager.formatTimeRemaining(5), "0:05")
    }
    
    // MARK: - Timer state transitions
    
    func testStartTimer_setsActive() {
        manager.warningEnabled = false
        manager.startTimer(minutes: 5)
        XCTAssertTrue(manager.isActive)
        XCTAssertGreaterThan(manager.timeRemaining, 0)
    }
    
    func testCancelTimer_resetsState() {
        manager.warningEnabled = false
        manager.startTimer(minutes: 5)
        manager.cancelTimer()
        
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.timeRemaining, 0)
        XCTAssertEqual(manager.timeRemainingText, "")
        XCTAssertNil(manager.endDate)
    }
    
    func testStartTimerSeconds_setsActive() {
        manager.warningEnabled = false
        manager.startTimer(seconds: 120)
        XCTAssertTrue(manager.isActive)
    }
    
    func testStartTimerUntilDate_pastDate_doesNotActivate() {
        let pastDate = Date().addingTimeInterval(-60)
        manager.startTimer(until: pastDate)
        XCTAssertFalse(manager.isActive)
    }
    
    func testStartTimerUntilDate_futureDate_activates() {
        manager.warningEnabled = false
        let futureDate = Date().addingTimeInterval(300)
        manager.startTimer(until: futureDate)
        XCTAssertTrue(manager.isActive)
    }
    
    // MARK: - Snooze
    
    func testSnoozeTimer_extendsEndDate() {
        manager.warningEnabled = false
        manager.startTimer(seconds: 300)
        let endDateBefore = manager.endDate!
        
        manager.snoozeTimer(minutes: 5)
        
        let endDateAfter = manager.endDate!
        let difference = endDateAfter.timeIntervalSince(endDateBefore)
        XCTAssertEqual(difference, 300, accuracy: 1.0)
    }
    
    func testSnoozeTimer_withNoActiveTimer_doesNothing() {
        manager.snoozeTimer(minutes: 5)
        XCTAssertNil(manager.endDate)
    }
    
    // MARK: - Alert time validation
    
    func testAlertTimeInvalid_whenThresholdExceedsDuration() {
        manager.warningEnabled = true
        manager.warningThreshold = 600 // 10 min
        manager.startTimer(seconds: 300) // 5 min timer
        
        XCTAssertTrue(manager.isAlertTimeInvalid)
        XCTAssertFalse(manager.isActive)
    }
    
    func testAlertTimeInvalid_whenThresholdEqualsDuration() {
        manager.warningEnabled = true
        manager.warningThreshold = 300
        manager.startTimer(seconds: 300)
        
        XCTAssertTrue(manager.isAlertTimeInvalid)
        XCTAssertFalse(manager.isActive)
    }
    
    func testAlertTimeValid_whenThresholdLessThanDuration() {
        manager.warningEnabled = true
        manager.warningThreshold = 60
        manager.startTimer(seconds: 300)
        
        XCTAssertFalse(manager.isAlertTimeInvalid)
        XCTAssertTrue(manager.isActive)
    }
    
    func testAlertTimeSkipped_whenWarningDisabled() {
        manager.warningEnabled = false
        manager.warningThreshold = 600
        manager.startTimer(seconds: 300)
        
        XCTAssertFalse(manager.isAlertTimeInvalid)
        XCTAssertTrue(manager.isActive)
    }
    
    // MARK: - Sleep mode persistence
    
    func testSetSleepMode_persistsToDefaults() {
        manager.setSleepMode(.display)
        XCTAssertEqual(defaults.string(forKey: "sleepMode"), "Display Only")
        XCTAssertEqual(manager.sleepMode, .display)
    }
    
    func testSleepMode_loadedFromDefaults() {
        manager.setSleepMode(.display)
        XCTAssertEqual(defaults.string(forKey: "sleepMode"), "Display Only")
        
        // Verify that a fresh manager reads the persisted value
        // (tested via setUp pattern -- set defaults, then check the manager)
        manager.cancelTimer()
        manager = nil
        
        manager = SleepTimerManager(defaults: defaults)
        XCTAssertEqual(manager.sleepMode, .display)
    }
    
    // MARK: - Warning threshold persistence
    
    func testSetWarningThreshold_persistsToDefaults() {
        manager.setWarningThreshold(seconds: 300)
        XCTAssertEqual(defaults.double(forKey: "warningThreshold"), 300)
        XCTAssertEqual(manager.warningThreshold, 300)
    }
    
    func testSetWarningEnabled_persistsToDefaults() {
        manager.setWarningEnabled(false)
        XCTAssertEqual(defaults.bool(forKey: "warningEnabled"), false)
        XCTAssertEqual(manager.warningEnabled, false)
    }
}
