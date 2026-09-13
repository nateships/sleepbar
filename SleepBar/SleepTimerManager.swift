//
//  SleepTimerManager.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import Foundation
import SwiftUI
import Combine
import AppKit

enum SleepMode: String, CaseIterable {
    case system = "System"
    case display = "Display Only"
}

class SleepTimerManager: ObservableObject {
    @Published var isActive = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var timeRemainingText = ""
    @Published var sleepMode: SleepMode = .system
    @Published var warningThreshold: TimeInterval = 60 // 1 minute default
    @Published var warningEnabled: Bool = true // Alert enabled by default
    @Published var isAlertTimeInvalid: Bool = false // Tracks if alert time exceeds timer duration
    
    private var timer: Timer?
    var endDate: Date?
    private var hasShownWarning = false

    /// Tests set this to observe timer expiry without putting the Mac to sleep.
    var sleepAction: ((SleepMode) -> Void)?
    
    let defaults: UserDefaults
    private let warningThresholdKey = "warningThreshold"
    private let warningEnabledKey = "warningEnabled"
    private let sleepModeKey = "sleepMode"
    
    convenience init() {
        self.init(defaults: .standard)
    }
    
    nonisolated deinit {
        timer?.invalidate()
    }
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
        
        if defaults.object(forKey: warningThresholdKey) != nil {
            warningThreshold = defaults.double(forKey: warningThresholdKey)
        }
        
        if defaults.object(forKey: warningEnabledKey) != nil {
            warningEnabled = defaults.bool(forKey: warningEnabledKey)
        }
        
        if let savedModeString = defaults.string(forKey: sleepModeKey),
           let savedMode = SleepMode(rawValue: savedModeString) {
            sleepMode = savedMode
        }
    }
    
    func setSleepMode(_ mode: SleepMode) {
        sleepMode = mode
        defaults.set(mode.rawValue, forKey: sleepModeKey)
    }
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var targetTimeText: String {
        guard let endDate = endDate else { return "" }
        return Self.timeFormatter.string(from: endDate)
    }
    
    func setWarningThreshold(seconds: TimeInterval) {
        warningThreshold = seconds
        defaults.set(seconds, forKey: warningThresholdKey)
    }
    
    func setWarningEnabled(_ enabled: Bool) {
        warningEnabled = enabled
        defaults.set(enabled, forKey: warningEnabledKey)
    }
    
    func startTimer(minutes: Int) {
        startTimer(seconds: TimeInterval(minutes * 60))
    }
    
    func startTimer(seconds: TimeInterval) {
        beginTimer(endDate: Date().addingTimeInterval(seconds), duration: seconds)
    }
    
    func startTimer(until targetDate: Date) {
        let duration = targetDate.timeIntervalSinceNow
        guard duration > 0 else { return }
        beginTimer(endDate: targetDate, duration: duration)
    }
    
    private func beginTimer(endDate newEndDate: Date, duration: TimeInterval) {
        if warningEnabled && warningThreshold >= duration {
            isAlertTimeInvalid = true
            return
        }
        
        isAlertTimeInvalid = false
        endDate = newEndDate
        timeRemaining = duration
        isActive = true
        hasShownWarning = false
        
        TelemetryManager.shared.track("timer_start", metadata: [
            "duration": duration,
            "sleepMode": sleepMode.rawValue
        ])
        
        updateTimeRemaining()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
        timer?.tolerance = 0.1
    }
    
    func cancelTimer(userInitiated: Bool = true) {
        if userInitiated && isActive {
            TelemetryManager.shared.track("timer_cancel", metadata: [
                "timeRemaining": timeRemaining
            ])
        }
        timer?.invalidate()
        timer = nil
        isActive = false
        timeRemaining = 0
        timeRemainingText = ""
        endDate = nil
        hasShownWarning = false
    }
    
    func snoozeTimer(minutes: Int) {
        guard let currentEndDate = endDate else { return }
        let newEndDate = currentEndDate.addingTimeInterval(TimeInterval(minutes * 60))
        endDate = newEndDate
        hasShownWarning = false
        TelemetryManager.shared.track("snooze", metadata: ["minutes": minutes])
    }
    
    private func updateTimeRemaining() {
        guard let endDate = endDate else {
            cancelTimer(userInitiated: false)
            return
        }
        
        let remaining = endDate.timeIntervalSinceNow
        
        if remaining <= 0 {
            cancelTimer(userInitiated: false)
            executeSleep()
        } else {
            timeRemaining = remaining
            timeRemainingText = formatTimeRemaining(remaining)
            
            // Show warning if enabled and threshold reached
            if warningEnabled && !hasShownWarning && remaining <= warningThreshold {
                hasShownWarning = true
                showWarningWindow()
            }
        }
    }
    
    private func showWarningWindow() {
        TelemetryManager.shared.track("warning_shown", metadata: [
            "warningThreshold": warningThreshold
        ])
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            SleepWarningWindow.shared.show(
                timerManager: self,
                onCancel: { [weak self] in
                    self?.cancelTimer()
                    SleepWarningWindow.shared.hide()
                },
                onSnooze: { [weak self] minutes in
                    self?.snoozeTimer(minutes: minutes)
                    SleepWarningWindow.shared.hide()
                },
                onSleepNow: { [weak self] in
                    self?.cancelTimer(userInitiated: false)
                    SleepWarningWindow.shared.hide()
                    self?.executeSleep()
                }
            )
        }
    }
    
    func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    func executeSleep() {
        TelemetryManager.shared.track("timer_complete", metadata: [
            "sleepMode": sleepMode.rawValue
        ])
        
        SleepWarningWindow.shared.hide()

        if let sleepAction {
            sleepAction(sleepMode)
            return
        }

        switch sleepMode {
        case .system:
            putSystemToSleep()
        case .display:
            putDisplayToSleep()
        }
    }
    
    private func putSystemToSleep() {
        Task {
            await ejectExternalDrives()
            runPmset(arguments: ["sleepnow"])
        }
    }
    
    private func ejectExternalDrives() async {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        
        guard let volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey
        ], options: [.skipHiddenVolumes]) else {
            return
        }
        
        for volume in volumes {
            do {
                let resourceValues = try volume.resourceValues(forKeys: [
                    .volumeIsRemovableKey,
                    .volumeIsEjectableKey,
                    .volumeIsInternalKey
                ])
                
                let isInternal = resourceValues.volumeIsInternal ?? true
                let isEjectable = resourceValues.volumeIsEjectable ?? false
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                
                if (!isInternal || isEjectable || isRemovable) && volume.path != "/" {
                    try workspace.unmountAndEjectDevice(at: volume)
                    print("Ejected volume: \(volume.path)")
                }
            } catch {
                print("Error ejecting volume \(volume.path): \(error)")
            }
        }
    }
    
    private func putDisplayToSleep() {
        runPmset(arguments: ["displaysleepnow"])
    }
    
    private func runPmset(arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = arguments
            task.standardError = Pipe()
            task.standardOutput = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("pmset \(arguments.joined(separator: " ")) failed: \(error)")
            }
        }
    }
}