//
//  SleepBarApp.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI

@main
struct SleepBarApp: App {
    @StateObject private var timerManager = SleepTimerManager()
    
    init() {
        TelemetryManager.shared.track("app_launch")
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(timerManager)
        } label: {
            MenuBarLabel()
                .environmentObject(timerManager)
        }
        .menuBarExtraStyle(.window)
        
        Window("About SleepBar", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Window("Activate SleepBar", id: "license") {
            LicenseView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        #if DEBUG
        Window("Developer Tools", id: "devtools") {
            DevMenuView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .keyboardShortcut("d", modifiers: [.command, .shift])
        #endif
    }
}
