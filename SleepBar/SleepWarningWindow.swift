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
        // Make window larger to accommodate shadow and rounded corners
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false  // We draw our own shadow in SwiftUI
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isMovableByWindowBackground = true
        self.center()
    }
    
    func show(timerManager: SleepTimerManager, onCancel: @escaping () -> Void, onSnooze: @escaping (Int) -> Void, onSleepNow: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: SleepWarningView(onCancel: onCancel, onSnooze: onSnooze, onSleepNow: onSleepNow)
                .environmentObject(timerManager)
        )
        
        // Critical: Make the hosting view fully transparent
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = CGColor.clear
        
        self.contentViewController = hostingController
        
        // Force the window to appear on top of everything
        NSApp.activate()
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
        
        // Play alert sound
        NSSound.beep()
    }
    
    func hide() {
        self.orderOut(nil)
    }
}

