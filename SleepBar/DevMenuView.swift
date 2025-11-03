//
//  DevMenuView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

#if DEBUG
import SwiftUI
import AppKit

struct DevMenuView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var testEmail = "test@example.com"
    @State private var showMessage = false
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("🛠️ Developer Tools")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Current Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status:")
                    .font(.headline)
                
                HStack {
                    Text("Licensed:")
                    Spacer()
                    Text(licenseManager.isLicensed ? "✅ Yes" : "❌ No")
                        .foregroundStyle(licenseManager.isLicensed ? .green : .red)
                }
                
                HStack {
                    Text("Trial Active:")
                    Spacer()
                    Text(licenseManager.isTrialActive ? "✅ Yes" : "❌ No")
                        .foregroundStyle(licenseManager.isTrialActive ? .green : .red)
                }
                
                HStack {
                    Text("Days Remaining:")
                    Spacer()
                    Text("\(licenseManager.daysRemainingInTrial)")
                }
                
                if let email = licenseManager.customerEmail {
                    HStack {
                        Text("Customer:")
                        Spacer()
                        Text(email)
                            .font(.caption)
                    }
                }
                
                if let key = licenseManager.licenseKey {
                    HStack {
                        Text("License Key:")
                        Spacer()
                        Text(String(key.prefix(20)) + "...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            
            // Test Actions
            VStack(spacing: 12) {
                Text("Test Actions:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Reset Trial
                Button(action: {
                    licenseManager.resetTrial()
                    showMessageAlert("Trial reset! 7 days remaining.")
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset Trial (7 days)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Generate Test Key
                VStack(spacing: 8) {
                    TextField("Test email", text: $testEmail)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        let key = licenseManager.generateTestLicenseKey(for: testEmail)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key, forType: .string)
                        showMessageAlert("Test key copied to clipboard:\n\(key)")
                    }) {
                        HStack {
                            Image(systemName: "key")
                            Text("Generate & Copy Test Key")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Expire Trial
                Button(action: {
                    licenseManager.expireTrialForTesting()
                    showMessageAlert("Trial expired! App is now locked.")
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Expire Trial (Test Lock Screen)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                // Deactivate License
                if licenseManager.isLicensed {
                    Button(action: {
                        Task {
                            let success = await licenseManager.deactivateLicense()
                            showMessageAlert(success ? "License deactivated!" : "Deactivation failed")
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Deactivate License")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.horizontal, 20)
            
            if showMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Close Button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 600)
        .onAppear {
            activateWindow()
        }
    }
    
    private func activateWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Developer Tools" }) {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func showMessageAlert(_ msg: String) {
        message = msg
        showMessage = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showMessage = false
        }
    }
}

#Preview {
    DevMenuView()
}
#endif

