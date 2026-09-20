//
//  NowPlayingMonitor.swift
//  SleepBar
//

import Combine
import Foundation
import MediaRemoteAdapter

/// Reads the system Now Playing item through the MediaRemote adapter.
/// The adapter runs the Apple-signed perl binary, because macOS 15.4
/// and later block direct MediaRemote access from third-party apps.
/// `item` is nil when nothing plays, the item has no finite duration,
/// or the adapter fails. The UI then shows no media option.
final class NowPlayingMonitor: ObservableObject {
    struct Item {
        let title: String
        let appName: String?
        let endDate: Date
    }

    @Published private(set) var item: Item?

    private let controller = MediaController()

    /// Query once. The callback runs on a background thread.
    func refresh() {
        controller.getTrackInfo { [weak self] info in
            let item = NowPlayingMonitor.item(from: info)
            DispatchQueue.main.async {
                self?.item = item
            }
        }
    }

    static func item(from info: TrackInfo?) -> Item? {
        guard let payload = info?.payload,
              payload.isPlaying == true,
              let title = payload.title, !title.isEmpty,
              let durationMicros = payload.durationMicros,
              durationMicros.isFinite, durationMicros > 0,
              let elapsed = payload.currentElapsedTime else {
            return nil
        }
        let remaining = durationMicros / 1_000_000 - elapsed
        // Items that end within a minute are not useful as a sleep target.
        guard remaining > 60 else { return nil }
        return Item(
            title: title,
            appName: payload.applicationName,
            endDate: Date().addingTimeInterval(remaining)
        )
    }
}
