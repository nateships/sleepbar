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
    private var endDate: Date?
    private var hasShownWarning = false
    
    private let warningThresholdKey = "warningThreshold"
    private let warningEnabledKey = "warningEnabled"
    
    init() {
        // Load saved warning threshold, default to 60 seconds (1 minute)
        if UserDefaults.standard.object(forKey: warningThresholdKey) != nil {
            warningThreshold = UserDefaults.standard.double(forKey: warningThresholdKey)
        }
        
        // Load saved warning enabled state, default to true
        if UserDefaults.standard.object(forKey: warningEnabledKey) != nil {
            warningEnabled = UserDefaults.standard.bool(forKey: warningEnabledKey)
        }
    }
    
    var targetTimeText: String {
        guard let endDate = endDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endDate)
    }
    
    func setWarningThreshold(seconds: TimeInterval) {
        warningThreshold = seconds
        UserDefaults.standard.set(seconds, forKey: warningThresholdKey)
    }
    
    func setWarningEnabled(_ enabled: Bool) {
        warningEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: warningEnabledKey)
    }
    
    func startTimer(minutes: Int) {
        startTimer(seconds: TimeInterval(minutes * 60))
    }
    
    func startTimer(seconds: TimeInterval) {
        // Validate that alert time is less than timer duration
        if warningEnabled && warningThreshold >= seconds {
            isAlertTimeInvalid = true
            return
        }
        
        // Clear any previous error state
        isAlertTimeInvalid = false
        
        endDate = Date().addingTimeInterval(seconds)
        timeRemaining = seconds
        isActive = true
        hasShownWarning = false
        
        // Update immediately
        updateTimeRemaining()
        
        // Create timer that updates every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }
    
    func startTimer(until targetDate: Date) {
        let duration = targetDate.timeIntervalSinceNow
        guard duration > 0 else { return }
        
        // Validate that alert time is less than timer duration
        if warningEnabled && warningThreshold >= duration {
            isAlertTimeInvalid = true
            return
        }
        
        // Clear any previous error state
        isAlertTimeInvalid = false
        
        endDate = targetDate
        timeRemaining = duration
        isActive = true
        hasShownWarning = false
        
        // Update immediately
        updateTimeRemaining()
        
        // Create timer that updates every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }
    
    func cancelTimer() {
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
    }
    
    private func updateTimeRemaining() {
        guard let endDate = endDate else {
            cancelTimer()
            return
        }
        
        let remaining = endDate.timeIntervalSinceNow
        
        if remaining <= 0 {
            cancelTimer()
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
                }
            )
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func executeSleep() {
        // Hide the warning window before sleeping
        SleepWarningWindow.shared.hide()
        
        switch sleepMode {
        case .system:
            putSystemToSleep()
        case .display:
            putDisplayToSleep()
        }
    }
    
    private func putSystemToSleep() {
        // Eject external drives before sleeping
        ejectExternalDrives()
        
        // Small delay to ensure drives are ejected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Put the entire system to sleep using pmset
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["sleepnow"]
            
            // Suppress stderr to avoid console warnings
            task.standardError = Pipe()
            task.standardOutput = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("Failed to put system to sleep: \(error)")
            }
        }
    }
    
    private func ejectExternalDrives() {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        
        // Get all mounted volumes
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
                
                // Only eject external, removable, or ejectable volumes
                let isInternal = resourceValues.volumeIsInternal ?? true
                let isEjectable = resourceValues.volumeIsEjectable ?? false
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                
                if !isInternal || isEjectable || isRemovable {
                    // Skip the boot volume
                    if volume.path != "/" {
                        workspace.unmountAndEjectDevice(atPath: volume.path)
                        print("Ejecting volume: \(volume.path)")
                    }
                }
            } catch {
                print("Error checking volume \(volume.path): \(error)")
            }
        }
    }
    
    private func putDisplayToSleep() {
        // Put only the display to sleep using pmset
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        
        // Suppress stderr to avoid console warnings
        task.standardError = Pipe()
        task.standardOutput = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to put display to sleep: \(error)")
        }
    }
}