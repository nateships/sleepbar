//
//  LaunchAtLogin.swift
//  SleepBar
//

import ServiceManagement

/// Registers SleepBar as a login item through SMAppService.
/// The user can also change this in System Settings > General > Login Items.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            // macOS can hold the item until the user approves it in
            // System Settings. Take the user there, or the switch only
            // snaps back with no explanation.
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
