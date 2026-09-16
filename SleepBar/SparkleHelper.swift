//
//  SparkleHelper.swift
//  SleepBar
//
//  Created by Nate O'Farrell on 10/31/25.
//

import Foundation
import Combine
import Sparkle

class SparkleHelper: ObservableObject {
    static let shared = SparkleHelper()
    
    private let updaterController: SPUStandardUpdaterController
    
    private init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.updateCheckInterval = 10800 // 3 hours
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

