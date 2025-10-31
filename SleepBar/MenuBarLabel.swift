//
//  MenuBarLabel.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var timerManager: SleepTimerManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: timerManager.isActive ? "moon.zzz.fill" : "moon.zzz")
                .symbolRenderingMode(.hierarchical)
            
            if timerManager.isActive {
                Text(timerManager.timeRemainingText)
                    .monospacedDigit()
                    .font(.system(size: 12))
            }
        }
    }
}

#Preview {
    MenuBarLabel()
        .environmentObject(SleepTimerManager())
}

