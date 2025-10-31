//
//  AboutView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    
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
            Text("Version 1.0.0")
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
            VStack(spacing: 8) {
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
                } else if licenseManager.isTrialActive {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("Trial: \(licenseManager.daysRemainingInTrial) days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Trial Expired")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Copyright
            Text("© 2025 Nate O'Farrell")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 340, height: 380)
    }
}

#Preview {
    AboutView()
}

