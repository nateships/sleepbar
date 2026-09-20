//
//  NowPlayingMonitorTests.swift
//  SleepBarTests
//

import XCTest
import MediaRemoteAdapter
@testable import SleepBar

final class NowPlayingMonitorTests: XCTestCase {

    private func info(isPlaying: Bool? = true,
                      durationSeconds: Double? = 600,
                      elapsedSeconds: Double = 100,
                      title: String? = "Film") -> TrackInfo {
        let payload = TrackInfo.Payload(
            title: title,
            isPlaying: isPlaying,
            durationMicros: durationSeconds.map { $0 * 1_000_000 },
            elapsedTimeMicros: elapsedSeconds * 1_000_000,
            applicationName: "Player",
            timestampEpochMicros: Date().timeIntervalSince1970 * 1_000_000,
            playbackRate: 1
        )
        return TrackInfo(payload: payload)
    }

    func testPlayingItem_endsAtDurationMinusElapsed() {
        let item = NowPlayingMonitor.item(from: info())
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.title, "Film")
        XCTAssertEqual(item?.appName, "Player")
        XCTAssertEqual(item!.endDate.timeIntervalSinceNow, 500, accuracy: 2)
    }

    func testNilInfo_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: nil))
    }

    func testPausedItem_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: info(isPlaying: false)))
    }

    func testMissingDuration_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: info(durationSeconds: nil)))
    }

    func testInfiniteDuration_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: info(durationSeconds: .infinity)))
    }

    func testEndsWithinAMinute_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: info(durationSeconds: 600, elapsedSeconds: 570)))
    }

    func testEmptyTitle_returnsNil() {
        XCTAssertNil(NowPlayingMonitor.item(from: info(title: "")))
    }
}
