//
//  SleepWarningView.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI

struct SleepWarningView: View {
    @EnvironmentObject var timerManager: SleepTimerManager
    let onCancel: () -> Void
    let onSnooze: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Warning Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .padding(.top, 16)
            
            // Title
            Text("Sleep Timer Expiring Soon")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Time Remaining
            VStack(spacing: 2) {
                Text("Your Mac will sleep in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(timerManager.timeRemainingText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
            
            // Sleep Mode Info
            HStack(spacing: 4) {
                Image(systemName: timerManager.sleepMode == .system ? "power" : "display")
                    .font(.caption2)
                Text(timerManager.sleepMode.rawValue)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
            
            // Action Buttons
            VStack(spacing: 10) {
                // Snooze Options
                HStack(spacing: 8) {
                    Button("+ 5 min") {
                        onSnooze(5)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("+ 10 min") {
                        onSnooze(10)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("+ 30 min") {
                        onSnooze(30)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel Timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 340, height: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 10)
    }
}

#Preview {
    SleepWarningView(
        onCancel: {},
        onSnooze: { _ in }
    )
    .environmentObject(SleepTimerManager())
}

