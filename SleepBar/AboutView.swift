//
//  AboutView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var telemetryEnabled: Bool = TelemetryManager.shared.isEnabled
    @State private var isDeactivating = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)
            
            // App Name
            Text("SleepBar")
                .font(.system(size: 28, weight: .bold))
            
            // Version
            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.horizontal, 30)
            
            // Description
            VStack(spacing: 8) {
                Text("A simple and elegant sleep timer")
                    .font(.body)
                Text("for macOS")
                    .font(.body)
            }
            .foregroundStyle(.secondary)
            
            // Website Link
            Link(destination: URL(string: "https://sleepbar.app")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption)
                    Text("sleepbar.app")
                        .font(.body)
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            // License Status
            VStack(spacing: 10) {
                if licenseManager.isLicensed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Licensed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let email = licenseManager.customerEmail {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button(action: {
                        isDeactivating = true
                        Task {
                            _ = await licenseManager.deactivateLicense()
                            isDeactivating = false
                        }
                    }) {
                        if isDeactivating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Deactivate License")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isDeactivating)
                } else if licenseManager.isTrialActive {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("Trial: \(licenseManager.daysRemainingInTrial) days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("Activate License") {
                            openWindow(id: "license")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Purchase") {
                            if let url = URL(string: "https://sleepbar.app/purchase") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Trial Expired")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("Activate License") {
                            openWindow(id: "license")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Purchase") {
                            if let url = URL(string: "https://sleepbar.app/purchase") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 30)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Share Analytics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $telemetryEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.blue)
                        .onChange(of: telemetryEnabled) { _, newValue in
                            TelemetryManager.shared.isEnabled = newValue
                        }
                }
                
                Text("Anonymous usage data sent via Apple's iCloud (CloudKit). No personal information is collected or linked to your identity.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Copyright
            Text("© 2025 Nate O'Farrell")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 340, height: 500)
        .onAppear {
            activateWindow()
        }
    }
    
    private func activateWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: { $0.title == "About SleepBar" }) {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

#Preview {
    AboutView()
}

