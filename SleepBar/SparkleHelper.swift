//
//  SparkleHelper.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import Foundation
import Sparkle

class SparkleHelper: ObservableObject {
    static let shared = SparkleHelper()
    
    private let updaterController: SPUStandardUpdaterController
    
    private init() {
        // Initialize Sparkle updater controller
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    var canCheckForUpdates: Bool {
        return updaterController.updater.canCheckForUpdates
    }
    
    var automaticallyChecksForUpdates: Bool {
        get {
            return updaterController.updater.automaticallyChecksForUpdates
        }
        set {
            updaterController.updater.automaticallyChecksForUpdates = newValue
        }
    }
    
    var updateCheckInterval: TimeInterval {
        get {
            return updaterController.updater.updateCheckInterval
        }
        set {
            updaterController.updater.updateCheckInterval = newValue
        }
    }
}

