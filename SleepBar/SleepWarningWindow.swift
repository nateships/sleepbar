//
//  SleepWarningWindow.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import SwiftUI
import AppKit

class SleepWarningWindow: NSWindow {
    static let shared = SleepWarningWindow()
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 340),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.center()
    }
    
    func show(timerManager: SleepTimerManager, onCancel: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        let hostingController = NSHostingController(
            rootView: SleepWarningView(onCancel: onCancel, onSnooze: onSnooze)
                .environmentObject(timerManager)
        )
        
        self.contentViewController = hostingController
        
        // Force the window to appear on top of everything
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
        
        // Play alert sound
        NSSound.beep()
    }
    
    func hide() {
        self.orderOut(nil)
    }
}

