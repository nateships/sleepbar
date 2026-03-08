//
//  TelemetryManager.swift
//  SleepBar
//

import CloudKit
import Foundation

final class TelemetryManager {
    static let shared = TelemetryManager()

    private let container = CKContainer(identifier: "iCloud.app.sleepbar.SleepBar")
    private let defaults = UserDefaults.standard

    private let enabledKey = "telemetryEnabled"
    private let anonymousIdKey = "telemetryAnonymousId"

    var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    private var anonymousId: String {
        if let existing = defaults.string(forKey: anonymousIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: anonymousIdKey)
        return newId
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var licenseStatus: String {
        let lm = LicenseManager.shared
        if lm.isLicensed { return "licensed" }
        if lm.isTrialActive { return "trial" }
        return "expired"
    }

    private init() {}

    func track(_ eventType: String, metadata: [String: Any]? = nil) {
        guard isEnabled else { return }

        let record = CKRecord(recordType: "TelemetryEvent")
        record["eventType"] = eventType as CKRecordValue
        record["anonymousId"] = anonymousId as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue
        record["osVersion"] = osVersion as CKRecordValue
        record["licenseStatus"] = licenseStatus as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        if let metadata = metadata,
           let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["metadata"] = jsonString as CKRecordValue
        }

        container.publicCloudDatabase.save(record) { _, error in
            #if DEBUG
            if let error = error {
                print("[Telemetry] Failed to save \(eventType): \(error.localizedDescription)")
            } else {
                print("[Telemetry] Saved \(eventType)")
            }
            #endif
        }
    }
}
