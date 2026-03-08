import XCTest
@testable import SleepBar

@MainActor
final class LicenseManagerTests: XCTestCase {
    
    private var defaults: UserDefaults!
    private var manager: LicenseManager!
    private let suiteName = "LicenseManagerTests"
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        manager = LicenseManager(defaults: defaults)
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Trial status
    
    func testFreshInstall_trialActiveWith7Days() {
        manager.checkTrialStatus()
        
        XCTAssertTrue(manager.isTrialActive)
        XCTAssertEqual(manager.daysRemainingInTrial, manager.trialDays)
        XCTAssertFalse(manager.isLicensed)
    }
    
    func testMidTrial_correctDaysRemaining() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        defaults.set(threeDaysAgo, forKey: LicenseManager.Keys.firstLaunchDate)
        
        manager.checkTrialStatus()
        
        XCTAssertTrue(manager.isTrialActive)
        XCTAssertEqual(manager.daysRemainingInTrial, 4)
    }
    
    func testExpiredTrial_notActive() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        defaults.set(eightDaysAgo, forKey: LicenseManager.Keys.firstLaunchDate)
        
        manager.checkTrialStatus()
        
        XCTAssertFalse(manager.isTrialActive)
        XCTAssertEqual(manager.daysRemainingInTrial, 0)
        XCTAssertFalse(manager.isLicensed)
    }
    
    func testExactTrialBoundary_day7_expired() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        defaults.set(sevenDaysAgo, forKey: LicenseManager.Keys.firstLaunchDate)
        
        manager.checkTrialStatus()
        
        XCTAssertFalse(manager.isTrialActive)
    }
    
    // MARK: - getFirstLaunchDate
    
    func testGetFirstLaunchDate_createsDateOnFirstCall() {
        let before = Date()
        let firstLaunch = manager.getFirstLaunchDate()
        let after = Date()
        
        XCTAssertGreaterThanOrEqual(firstLaunch, before)
        XCTAssertLessThanOrEqual(firstLaunch, after)
        XCTAssertNotNil(defaults.object(forKey: LicenseManager.Keys.firstLaunchDate))
    }
    
    func testGetFirstLaunchDate_returnsSavedDate() {
        let specificDate = Date(timeIntervalSince1970: 1000000)
        defaults.set(specificDate, forKey: LicenseManager.Keys.firstLaunchDate)
        
        let result = manager.getFirstLaunchDate()
        XCTAssertEqual(result.timeIntervalSince1970, specificDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - validateProductIds
    
    func testValidateProductIds_correctIds_returnsTrue() {
        let meta: [String: Any] = [
            "store_id": 237783,
            "product_id": 681433
        ]
        XCTAssertTrue(manager.validateProductIds(meta: meta))
    }
    
    func testValidateProductIds_wrongStoreId_returnsFalse() {
        let meta: [String: Any] = [
            "store_id": 999999,
            "product_id": 681433
        ]
        XCTAssertFalse(manager.validateProductIds(meta: meta))
    }
    
    func testValidateProductIds_wrongProductId_returnsFalse() {
        let meta: [String: Any] = [
            "store_id": 237783,
            "product_id": 999999
        ]
        XCTAssertFalse(manager.validateProductIds(meta: meta))
    }
    
    func testValidateProductIds_missingStoreId_returnsFalse() {
        let meta: [String: Any] = [
            "product_id": 681433
        ]
        XCTAssertFalse(manager.validateProductIds(meta: meta))
    }
    
    func testValidateProductIds_missingProductId_returnsFalse() {
        let meta: [String: Any] = [
            "store_id": 237783
        ]
        XCTAssertFalse(manager.validateProductIds(meta: meta))
    }
    
    func testValidateProductIds_wrongType_returnsFalse() {
        let meta: [String: Any] = [
            "store_id": "237783",
            "product_id": 681433
        ]
        XCTAssertFalse(manager.validateProductIds(meta: meta))
    }
    
    // MARK: - formEncode
    
    func testFormEncode_plainText() {
        XCTAssertEqual(manager.formEncode("hello"), "hello")
    }
    
    func testFormEncode_spaces() {
        XCTAssertEqual(manager.formEncode("hello world"), "hello%20world")
    }
    
    func testFormEncode_specialCharacters() {
        XCTAssertEqual(manager.formEncode("key=value&foo"), "key%3Dvalue%26foo")
    }
    
    func testFormEncode_preservesSafeCharacters() {
        XCTAssertEqual(manager.formEncode("a-b.c_d~e"), "a-b.c_d~e")
    }
    
    func testFormEncode_emailAddress() {
        let encoded = manager.formEncode("user@example.com")
        XCTAssertEqual(encoded, "user%40example.com")
    }
    
    // MARK: - shouldPerformValidation
    
    func testShouldPerformValidation_neverValidated_returnsTrue() {
        XCTAssertTrue(manager.shouldPerformValidation())
    }
    
    func testShouldPerformValidation_validatedToday_returnsFalse() {
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertFalse(manager.shouldPerformValidation())
    }
    
    func testShouldPerformValidation_validated3DaysAgo_returnsTrue() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        defaults.set(threeDaysAgo, forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertTrue(manager.shouldPerformValidation())
    }
    
    func testShouldPerformValidation_validated2DaysAgo_returnsFalse() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        defaults.set(twoDaysAgo, forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertFalse(manager.shouldPerformValidation())
    }
    
    // MARK: - isWithinValidationGracePeriod
    
    func testGracePeriod_noValidation_returnsFalse() {
        XCTAssertFalse(manager.isWithinValidationGracePeriod())
    }
    
    func testGracePeriod_recentValidation_returnsTrue() {
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertTrue(manager.isWithinValidationGracePeriod())
    }
    
    func testGracePeriod_29DaysAgo_returnsTrue() {
        let date = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
        defaults.set(date, forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertTrue(manager.isWithinValidationGracePeriod())
    }
    
    func testGracePeriod_31DaysAgo_returnsFalse() {
        let date = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(date, forKey: LicenseManager.Keys.lastValidationDate)
        XCTAssertFalse(manager.isWithinValidationGracePeriod())
    }
    
    // MARK: - recordValidationFailure
    
    func testRecordValidationFailure_incrementsCounter() {
        XCTAssertEqual(defaults.integer(forKey: LicenseManager.Keys.consecutiveValidationFailures), 0)
        
        manager.recordValidationFailure()
        XCTAssertEqual(defaults.integer(forKey: LicenseManager.Keys.consecutiveValidationFailures), 1)
        
        manager.recordValidationFailure()
        XCTAssertEqual(defaults.integer(forKey: LicenseManager.Keys.consecutiveValidationFailures), 2)
    }
    
    // MARK: - canUseApp
    
    func testCanUseApp_licensed() {
        manager.isLicensed = true
        manager.isTrialActive = false
        XCTAssertTrue(manager.canUseApp)
    }
    
    func testCanUseApp_trialActive() {
        manager.isLicensed = false
        manager.isTrialActive = true
        XCTAssertTrue(manager.canUseApp)
    }
    
    func testCanUseApp_neitherLicensedNorTrial() {
        manager.isLicensed = false
        manager.isTrialActive = false
        XCTAssertFalse(manager.canUseApp)
    }
    
    // MARK: - applyGracePeriodOrInvalidate (license expiration logic)
    
    func testApplyGrace_withinGracePeriod_fewFailures_keepsLicense() {
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(2, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertTrue(manager.isLicensed)
    }
    
    func testApplyGrace_withinGracePeriod_manyFailures_keepsLicense() {
        // Grace period alone is enough to keep the license active
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(10, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertTrue(manager.isLicensed, "License should stay active when within grace period, regardless of failure count")
    }
    
    func testApplyGrace_expiredGracePeriod_fewFailures_keepsLicense() {
        // Few failures alone is enough to keep the license active
        let expired = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(expired, forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(3, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertTrue(manager.isLicensed, "License should stay active when failures < max, even if grace period expired")
    }
    
    func testApplyGrace_expiredGracePeriod_maxFailures_revokesLicense() {
        // BOTH conditions failed: grace expired AND too many failures -> license revoked
        let expired = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(expired, forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(5, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertFalse(manager.isLicensed, "License should be revoked when grace period expired AND failures >= max")
    }
    
    func testApplyGrace_noLastValidation_maxFailures_revokesLicense() {
        // No validation date means grace period check returns false
        defaults.set(5, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertFalse(manager.isLicensed, "License should be revoked with no validation history and max failures")
    }
    
    func testApplyGrace_noLastValidation_fewFailures_keepsLicense() {
        // No validation date, but failures < max -> still protected
        defaults.set(4, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertTrue(manager.isLicensed, "License should stay active when failures < max, even without validation history")
    }
    
    func testApplyGrace_exactBoundary_5failures_30days_revokes() {
        let exactBoundary = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        defaults.set(exactBoundary, forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(5, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        // 30 days: daysSinceValidation == 30, which is NOT < 30, so grace expired
        // 5 failures: which is NOT < 5, so failure check also fails
        XCTAssertFalse(manager.isLicensed, "License should be revoked at exactly 30 days and 5 failures")
    }
    
    func testApplyGrace_revocation_fallsBackToTrial() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        defaults.set(eightDaysAgo, forKey: LicenseManager.Keys.firstLaunchDate)
        
        let expired = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(expired, forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(5, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertFalse(manager.isLicensed)
        XCTAssertFalse(manager.isTrialActive, "Trial should also be expired for 8-day-old install")
        XCTAssertFalse(manager.canUseApp, "User should be completely locked out")
    }
    
    func testApplyGrace_restoresCustomerInfo() {
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(0, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        defaults.set("test@example.com", forKey: LicenseManager.Keys.customerEmail)
        defaults.set("Test User", forKey: LicenseManager.Keys.customerName)
        
        manager.applyGracePeriodOrInvalidate()
        
        XCTAssertTrue(manager.isLicensed)
        XCTAssertEqual(manager.customerEmail, "test@example.com")
        XCTAssertEqual(manager.customerName, "Test User")
    }
    
    // MARK: - Full failure cascade simulation
    
    func testFailureCascade_graduallReachesRevocation() {
        // Start with a valid license, validated 31 days ago (grace expired)
        let expired = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(expired, forKey: LicenseManager.Keys.lastValidationDate)
        manager.isLicensed = true
        
        // Simulate 4 consecutive failures -- still under the limit
        for _ in 0..<4 {
            manager.recordValidationFailure()
        }
        manager.applyGracePeriodOrInvalidate()
        XCTAssertTrue(manager.isLicensed, "4 failures should not revoke (max is 5)")
        
        // 5th failure tips it over
        manager.recordValidationFailure()
        manager.applyGracePeriodOrInvalidate()
        XCTAssertFalse(manager.isLicensed, "5th failure with expired grace should revoke license")
    }
    
    func testFailureCascade_successfulValidationResetsCounter() {
        let expired = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        defaults.set(expired, forKey: LicenseManager.Keys.lastValidationDate)
        manager.isLicensed = true
        
        // Accumulate 4 failures
        for _ in 0..<4 {
            manager.recordValidationFailure()
        }
        XCTAssertEqual(defaults.integer(forKey: LicenseManager.Keys.consecutiveValidationFailures), 4)
        
        // Simulate a successful validation resetting the counter
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(0, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        // Now even after one more failure, license stays active (grace is fresh, failures = 1)
        manager.recordValidationFailure()
        manager.applyGracePeriodOrInvalidate()
        XCTAssertTrue(manager.isLicensed, "License should survive after counter was reset by successful validation")
    }
    
    // MARK: - checkLicenseStatus
    
    func testCheckLicenseStatus_withStoredLicense_setsLicensed() {
        defaults.set("ABCD-1234-EFGH-5678", forKey: LicenseManager.Keys.licenseKey)
        defaults.set("instance-123", forKey: LicenseManager.Keys.instanceId)
        defaults.set("test@example.com", forKey: LicenseManager.Keys.customerEmail)
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        
        manager.checkLicenseStatus()
        
        XCTAssertTrue(manager.isLicensed)
        XCTAssertEqual(manager.customerEmail, "test@example.com")
    }
    
    func testCheckLicenseStatus_withoutStoredLicense_fallsBackToTrial() {
        manager.checkLicenseStatus()
        
        XCTAssertFalse(manager.isLicensed)
        XCTAssertTrue(manager.isTrialActive)
    }
    
    func testCheckLicenseStatus_withOnlyLicenseKey_noInstanceId_fallsBackToTrial() {
        defaults.set("ABCD-1234-EFGH-5678", forKey: LicenseManager.Keys.licenseKey)
        // No instanceId set
        
        manager.checkLicenseStatus()
        
        XCTAssertFalse(manager.isLicensed, "Both licenseKey and instanceId are required")
        XCTAssertTrue(manager.isTrialActive)
    }
    
    // MARK: - clearLicenseData
    
    func testClearLicenseData_removesAllLicenseKeys() {
        defaults.set("key", forKey: LicenseManager.Keys.licenseKey)
        defaults.set("instance", forKey: LicenseManager.Keys.instanceId)
        defaults.set("name", forKey: LicenseManager.Keys.instanceName)
        defaults.set(Date(), forKey: LicenseManager.Keys.lastValidationDate)
        defaults.set(3, forKey: LicenseManager.Keys.consecutiveValidationFailures)
        
        manager.clearLicenseData()
        
        XCTAssertNil(defaults.string(forKey: LicenseManager.Keys.licenseKey))
        XCTAssertNil(defaults.string(forKey: LicenseManager.Keys.instanceId))
        XCTAssertNil(defaults.string(forKey: LicenseManager.Keys.instanceName))
        XCTAssertNil(defaults.object(forKey: LicenseManager.Keys.lastValidationDate))
        XCTAssertEqual(defaults.integer(forKey: LicenseManager.Keys.consecutiveValidationFailures), 0)
    }
    
    func testClearLicenseData_preservesCustomerAndTrialInfo() {
        defaults.set("test@example.com", forKey: LicenseManager.Keys.customerEmail)
        defaults.set("Test User", forKey: LicenseManager.Keys.customerName)
        defaults.set(Date(), forKey: LicenseManager.Keys.firstLaunchDate)
        
        manager.clearLicenseData()
        
        XCTAssertNotNil(defaults.string(forKey: LicenseManager.Keys.customerEmail), "Customer email should survive clearLicenseData")
        XCTAssertNotNil(defaults.string(forKey: LicenseManager.Keys.customerName), "Customer name should survive clearLicenseData")
        XCTAssertNotNil(defaults.object(forKey: LicenseManager.Keys.firstLaunchDate), "First launch date should survive clearLicenseData")
    }
}
