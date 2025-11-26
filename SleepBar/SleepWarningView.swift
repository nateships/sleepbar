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
    let onSleepNow: () -> Void
    
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
                Text("at \(timerManager.targetTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            VStack(spacing: 12) {
                // Snooze Options
                HStack(spacing: 8) {
                    SnoozeButton(title: "+ 5 min") { onSnooze(5) }
                    SnoozeButton(title: "+ 10 min") { onSnooze(10) }
                    SnoozeButton(title: "+ 30 min") { onSnooze(30) }
                }
                
                // Sleep Now Button
                Button(action: onSleepNow) {
                    Label("Sleep Now", systemImage: "moon.zzz.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .foregroundColor(.white)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Cancel Button
                Button(action: onCancel) {
                    Label("Cancel Timer", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .foregroundColor(.white)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 340, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Custom snooze button with blue styling
struct SnoozeButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .foregroundColor(.white)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    SleepWarningView(
        onCancel: {},
        onSnooze: { _ in },
        onSleepNow: {}
    )
    .environmentObject(SleepTimerManager())
}

