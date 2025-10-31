//
//  LicenseView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI

struct LicenseView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var licenseKey = ""
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
                Text("Enter your license key from your purchase email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Enter license key", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, design: .monospaced))
                        .disableAutocorrection(true)
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
                .disabled(licenseKey.isEmpty || isActivating)
                
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
        .frame(width: 400, height: 400)
    }
    
    private func activateLicense() {
        showError = false
        isActivating = true
        
        Task {
            let result = await licenseManager.activateLicense(key: licenseKey)
            
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

