import XCTest
@testable import SleepBar

final class InputValidationTests: XCTestCase {
    
    // MARK: - filterNumeric
    
    func testFilterNumeric_digitsOnly() {
        XCTAssertEqual(filterNumeric("42", max: 100), "42")
    }
    
    func testFilterNumeric_stripsNonDigits() {
        XCTAssertEqual(filterNumeric("1a2b3", max: 999), "123")
    }
    
    func testFilterNumeric_clampsToMax() {
        XCTAssertEqual(filterNumeric("75", max: 60), "60")
    }
    
    func testFilterNumeric_atMax_returnsValue() {
        XCTAssertEqual(filterNumeric("59", max: 59), "59")
    }
    
    func testFilterNumeric_emptyString() {
        XCTAssertEqual(filterNumeric("", max: 100), "")
    }
    
    func testFilterNumeric_allNonDigits() {
        XCTAssertEqual(filterNumeric("abc", max: 100), "")
    }
    
    func testFilterNumeric_zero() {
        XCTAssertEqual(filterNumeric("0", max: 60), "0")
    }
    
    // MARK: - filterHour
    
    func testFilterHour_validHour() {
        XCTAssertEqual(filterHour("10"), "10")
    }
    
    func testFilterHour_clampsAbove12() {
        XCTAssertEqual(filterHour("15"), "12")
    }
    
    func testFilterHour_zero_returnsEmpty() {
        XCTAssertEqual(filterHour("0"), "")
    }
    
    func testFilterHour_twelve() {
        XCTAssertEqual(filterHour("12"), "12")
    }
    
    func testFilterHour_one() {
        XCTAssertEqual(filterHour("1"), "1")
    }
    
    func testFilterHour_emptyString() {
        XCTAssertEqual(filterHour(""), "")
    }
    
    func testFilterHour_stripsNonDigits() {
        XCTAssertEqual(filterHour("1a0"), "10")
    }
    
    func testFilterHour_allNonDigits() {
        XCTAssertEqual(filterHour("abc"), "")
    }
    
    // MARK: - filterMinute
    
    func testFilterMinute_validMinute() {
        XCTAssertEqual(filterMinute("30"), "30")
    }
    
    func testFilterMinute_clampsAbove59() {
        XCTAssertEqual(filterMinute("75"), "59")
    }
    
    func testFilterMinute_zero() {
        XCTAssertEqual(filterMinute("0"), "0")
    }
    
    func testFilterMinute_fifty_nine() {
        XCTAssertEqual(filterMinute("59"), "59")
    }
    
    func testFilterMinute_emptyString() {
        XCTAssertEqual(filterMinute(""), "")
    }
    
    func testFilterMinute_stripsNonDigits() {
        XCTAssertEqual(filterMinute("4x5"), "45")
    }
    
    func testFilterMinute_singleDigit() {
        XCTAssertEqual(filterMinute("5"), "5")
    }
}
