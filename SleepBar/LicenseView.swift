//
//  LicenseView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI
import AppKit

struct LicenseView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var licenseKey = ""
    @State private var email = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isActivating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Activate SleepBar")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if licenseManager.isTrialActive {
                    Text("\(licenseManager.daysRemainingInTrial) days left in trial")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !licenseManager.isLicensed {
                    Text("Trial expired")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Form
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter your license key and email from your purchase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("email@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("License Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, design: .monospaced))
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 30)
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 30)
                }
            }
            
            // Actions
            VStack(spacing: 12) {
                Button(action: activateLicense) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Activate License")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseKey.isEmpty || email.isEmpty || isActivating)
                
                HStack(spacing: 20) {
                    Button("Purchase License") {
                        if let url = URL(string: "https://sleepbar.app/purchase") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if licenseManager.isTrialActive {
                        Button("Continue Trial") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 450)
        .onAppear {
            activateWindow()
        }
    }
    
    private func activateWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Activate SleepBar" }) {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func activateLicense() {
        showError = false
        isActivating = true
        
        Task {
            let result = await licenseManager.activateLicense(key: licenseKey, email: email)
            
            await MainActor.run {
                isActivating = false
                
                if result.success {
                    dismiss()
                } else {
                    showError = true
                    errorMessage = result.error ?? "Failed to activate license"
                }
            }
        }
    }
}

#Preview {
    LicenseView()
}

