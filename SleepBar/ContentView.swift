//
//  ContentView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI
import AppKit

func filterNumeric(_ value: String, max: Int) -> String {
    let filtered = value.filter { $0.isNumber }
    if let number = Int(filtered), number > max {
        return String(max)
    }
    return filtered
}

func filterHour(_ value: String) -> String {
    let filtered = value.filter { $0.isNumber }
    guard !filtered.isEmpty else { return "" }
    if let number = Int(filtered) {
        if number > 12 { return "12" }
        else if number == 0 { return "" }
        return String(number)
    }
    return filtered
}

func filterMinute(_ value: String) -> String {
    let filtered = value.filter { $0.isNumber }
    guard !filtered.isEmpty else { return "" }
    if let number = Int(filtered), number > 59 {
        return "59"
    }
    return filtered
}

struct ContentView: View {
    @EnvironmentObject var timerManager: SleepTimerManager
    @ObservedObject private var licenseManager = LicenseManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSleepMode: SleepMode = .system
    // Custom timer inputs. AppStorage keeps edits when the menu closes
    // or the app relaunches, not only when a timer starts.
    // The section opens on appear when a custom timer was the last timer started.
    @AppStorage("showCustomInput") private var customTimerWasLastUsed = false
    @State private var showCustomInput = false
    @AppStorage("lastCustomMode") private var customMode: CustomTimerMode = .duration

    // Custom duration inputs
    @AppStorage("lastHours") private var hoursText: String = "0"
    @AppStorage("lastMinutes") private var minutesText: String = "15"

    // Specific time inputs
    @AppStorage("lastHour") private var hourText: String = "10"
    @AppStorage("lastMinute") private var minuteText: String = "00"
    @AppStorage("lastIsPM") private var isPM: Bool = true
    
    // Alert time input
    @State private var alertMinutesText: String = "1"
    @State private var alertMinutes: Int = 1

    // Mirrors SMAppService status. onAppear reads it because the user can
    // change it in System Settings. The read is an XPC call, so it is not
    // in the initializer, which runs on every view update.
    @State private var launchAtLogin = false
    
    // Force refresh of target times when menu opens
    @State private var refreshID = UUID()
    
    enum CustomTimerMode: String, CaseIterable {
        case duration = "Duration"
        case specificTime = "Specific Time"
    }
    
    let quickTimers = [
        (minutes: 15, label: "15m"),
        (minutes: 30, label: "30m"),
        (minutes: 60, label: "1h"),
        (minutes: 120, label: "2h")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if timerManager.isActive {
                activeTimerView
            } else {
                timerSelectionView
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
        .padding(8)
        .onAppear {
            selectedSleepMode = timerManager.sleepMode
            alertMinutes = Int(timerManager.warningThreshold / 60)
            alertMinutesText = String(alertMinutes)
            launchAtLogin = LaunchAtLogin.isEnabled
            showCustomInput = customTimerWasLastUsed
            restoreEmptyCustomInputs()
            refreshID = UUID() // Refresh target times whenever menu opens
        }
    }
    
    private var activeTimerView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("SleepBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Timer Display
            VStack(spacing: 8) {
                Text(timerManager.timeRemainingText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Text("Sleep at \(timerManager.targetTimeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Label(timerManager.sleepMode.rawValue, systemImage: timerManager.sleepMode == .system ? "power" : "display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Quick Extension Buttons
            VStack(spacing: 8) {
                Text("Extend Timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Button("+5m") {
                        timerManager.snoozeTimer(minutes: 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button("+10m") {
                        timerManager.snoozeTimer(minutes: 10)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button("+30m") {
                        timerManager.snoozeTimer(minutes: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button("+1h") {
                        timerManager.snoozeTimer(minutes: 60)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Cancel Button
            Button(action: {
                timerManager.cancelTimer()
            }) {
                Label("Cancel Timer", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Quit Button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit SleepBar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var timerSelectionView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "moon.zzz")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("SleepBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Quick Timer Buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(quickTimers, id: \.minutes) { option in
                    Button(action: {
                        if licenseManager.canUseApp {
                            customTimerWasLastUsed = false
                            timerManager.startTimer(minutes: option.minutes)
                        } else {
                            openWindow(id: "license")
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: licenseManager.canUseApp ? "clock.fill" : "lock.fill")
                                .font(.title3)
                            Text(option.label)
                                .font(.callout)
                                .fontWeight(.semibold)
                            if licenseManager.canUseApp {
                                Text(targetTimeForMinutes(option.minutes))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(licenseManager.canUseApp ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundStyle(licenseManager.canUseApp ? .blue : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .id(refreshID) // Force refresh when refreshID changes
            
            // Custom Timer Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showCustomInput.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showCustomInput ? "chevron.down" : "chevron.right")
                        .font(.caption)
                    Text(showCustomInput ? "Hide Custom" : "Custom Timer")
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Custom Timer Input (expandable)
            if showCustomInput {
                customTimerSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            // Sleep Mode Picker
            VStack(spacing: 6) {
                Text("Sleep Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                
                Picker("", selection: $selectedSleepMode) {
                    ForEach(SleepMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .onChange(of: selectedSleepMode) { oldValue, newValue in
                    timerManager.setSleepMode(newValue)
                }
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            // Pre-Sleep Alert Settings
            VStack(spacing: 10) {
                // Toggle with label
                SettingsToggleRow(
                    title: "Pre-Sleep Alert",
                    caption: "Show warning before sleep",
                    isOn: Binding(
                        get: { timerManager.warningEnabled },
                        set: { timerManager.setWarningEnabled($0) }
                    )
                )
                
                // Alert time input (only visible when enabled)
                if timerManager.warningEnabled {
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            Text("Alert")
                                .font(.caption)
                                .foregroundStyle(timerManager.isAlertTimeInvalid ? .red : .secondary)
                            
                            HStack(spacing: 0) {
                                // Text field
                                TextField("1", text: $alertMinutesText)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 45, height: 26)
                                    .background(timerManager.isAlertTimeInvalid ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                    .onChange(of: alertMinutesText) { _, newValue in
                                        let filtered = filterNumeric(newValue, max: 60)
                                        alertMinutesText = filtered
                                        if let minutes = Int(filtered), minutes > 0 {
                                            alertMinutes = minutes
                                            timerManager.setWarningThreshold(seconds: TimeInterval(minutes * 60))
                                            // Clear error when user changes the value
                                            timerManager.isAlertTimeInvalid = false
                                        }
                                    }
                                
                                // Stepper buttons
                                VStack(spacing: 0) {
                                    Button(action: {
                                        if alertMinutes < 60 {
                                            alertMinutes += 1
                                            alertMinutesText = String(alertMinutes)
                                            timerManager.setWarningThreshold(seconds: TimeInterval(alertMinutes * 60))
                                            // Clear error when user changes the value
                                            timerManager.isAlertTimeInvalid = false
                                        }
                                    }) {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 8, weight: .bold))
                                            .frame(width: 20, height: 13)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(timerManager.isAlertTimeInvalid ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                                    
                                    Button(action: {
                                        if alertMinutes > 1 {
                                            alertMinutes -= 1
                                            alertMinutesText = String(alertMinutes)
                                            timerManager.setWarningThreshold(seconds: TimeInterval(alertMinutes * 60))
                                            // Clear error when user changes the value
                                            timerManager.isAlertTimeInvalid = false
                                        }
                                    }) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 8, weight: .bold))
                                            .frame(width: 20, height: 13)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(timerManager.isAlertTimeInvalid ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(timerManager.isAlertTimeInvalid ? Color.red.opacity(0.4) : Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            
                            Text(alertMinutes == 1 ? "minute before sleeping" : "minutes before sleeping")
                                .font(.caption)
                                .foregroundStyle(timerManager.isAlertTimeInvalid ? .red : .secondary)
                            
                            Spacer()
                        }
                        
                        // Error message
                        if timerManager.isAlertTimeInvalid {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("Alert time must be less than timer duration")
                                    .font(.caption2)
                                Spacer()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 4)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Open at Login
            SettingsToggleRow(
                title: "Open at Login",
                caption: "Start SleepBar when you log in",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                        } catch {
                            NSLog("Launch at login change failed: \(error.localizedDescription)")
                        }
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                )
            )
            .padding(.vertical, 4)

            Divider()
                .padding(.horizontal, 16)

            // License Status Banner
            if licenseManager.isTrialActive {
                HStack {
                    Text("Trial: \(licenseManager.daysRemainingInTrial) days left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Activate") {
                        openWindow(id: "license")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
            } else if !licenseManager.isLicensed {
                HStack {
                    Text("Trial expired - Activate to continue")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Activate") {
                        openWindow(id: "license")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }
            
            // App Menu Section
            VStack(spacing: 4) {
                Button(action: {
                    SparkleHelper.shared.checkForUpdates()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Check for Updates")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                
                if !licenseManager.isLicensed {
                    Button(action: {
                        dismiss()
                        openWindow(id: "license")
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Activate License")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                
                Button(action: {
                    dismiss()
                    openWindow(id: "about")
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("About SleepBar")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            #if DEBUG
            // Dev Tools Button
            Button(action: {
                openWindow(id: "devtools")
            }) {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("Developer Tools")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            #endif
            
            // Quit Button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit SleepBar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var customTimerSection: some View {
        VStack(spacing: 12) {
            // Mode Selector
            Picker("", selection: $customMode) {
                ForEach(CustomTimerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            // Input Fields based on mode
            if customMode == .duration {
                durationInputFields
            } else {
                specificTimeInputFields
            }
            
            // Single Start Button
            Button(action: startCustomTimer) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Start Timer")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!isCustomTimerValid)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .id(refreshID) // Force refresh when refreshID changes
    }
    
    private var durationInputFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    TextField("0", text: $hoursText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .frame(width: 70, height: 50)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: hoursText) { _, newValue in
                            hoursText = filterNumeric(newValue, max: 23)
                        }
                    Text("hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(":")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    TextField("15", text: $minutesText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .frame(width: 70, height: 50)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: minutesText) { _, newValue in
                            minutesText = filterNumeric(newValue, max: 59)
                        }
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Target time display
            if isCustomTimerValid {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Sleep at \(targetTimeForCustomDuration())")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var specificTimeInputFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("10", text: $hourText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(width: 70, height: 60)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: hourText) { _, newValue in
                        hourText = filterHour(newValue)
                    }
                
                Text(":")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.secondary)
                
                TextField("00", text: $minuteText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(width: 70, height: 60)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: minuteText) { _, newValue in
                        minuteText = filterMinute(newValue)
                    }
                
                Picker("", selection: $isPM) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
    
    private var isCustomTimerValid: Bool {
        if customMode == .duration {
            let h = Int(hoursText) ?? 0
            let m = Int(minutesText) ?? 0
            return h > 0 || m > 0
        } else {
            guard let hour = Int(hourText), let minute = Int(minuteText) else { return false }
            return hour >= 1 && hour <= 12 && minute >= 0 && minute <= 59
        }
    }
    
    private func startCustomTimer() {
        guard licenseManager.canUseApp else {
            openWindow(id: "license")
            return
        }

        customTimerWasLastUsed = true

        if customMode == .duration {
            let hours = Int(hoursText) ?? 0
            let minutes = Int(minutesText) ?? 0
            let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
            if totalSeconds > 0 {
                timerManager.startTimer(seconds: totalSeconds)
            }
        } else {
            startTimeBasedTimer()
        }
    }
    
    private func filterNumeric(_ value: String, max: Int) -> String {
        SleepBar.filterNumeric(value, max: max)
    }
    
    private func filterHour(_ value: String) -> String {
        SleepBar.filterHour(value)
    }
    
    private func filterMinute(_ value: String) -> String {
        SleepBar.filterMinute(value)
    }
    
    private func startTimeBasedTimer() {
        guard let hour = Int(hourText), let minute = Int(minuteText),
              let targetDate = sleepTargetDate(hour12: hour, minute: minute, isPM: isPM) else { return }
        timerManager.startTimer(until: targetDate)
    }
    
    private func targetTimeForMinutes(_ minutes: Int) -> String {
        let targetDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return SleepTimerManager.timeFormatter.string(from: targetDate)
    }
    
    private func targetTimeForCustomDuration() -> String {
        let hours = Int(hoursText) ?? 0
        let minutes = Int(minutesText) ?? 0
        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
        let targetDate = Date().addingTimeInterval(totalSeconds)
        return SleepTimerManager.timeFormatter.string(from: targetDate)
    }
    
    // An empty field shows only its placeholder, but the Start button
    // stays disabled. Restore the defaults so the two do not disagree.
    private func restoreEmptyCustomInputs() {
        if hoursText.isEmpty && minutesText.isEmpty {
            hoursText = "0"
            minutesText = "15"
        }
        if hourText.isEmpty { hourText = "10" }
        if minuteText.isEmpty { minuteText = "00" }
    }
}

// A label with a caption on the left and a switch on the right.
private struct SettingsToggleRow: View {
    let title: String
    let caption: String
    let isOn: Binding<Bool>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
        .environmentObject(SleepTimerManager())
}
