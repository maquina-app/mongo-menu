//
//  AppActivationHandler.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//


import Cocoa

class AppActivationHandler {
    static let shared = AppActivationHandler()
    
    private let appIdentifier: String
    
    private init() {
        self.appIdentifier = Bundle.main.bundleIdentifier ?? "com.example.MongoMenu"
    }
    
    /// Check if another instance is running and activate it
    /// - Returns: true if this is the first instance, false if another instance is running
    func checkAndActivateExistingInstance() -> Bool {
        // Register for activation response from existing instance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExistingInstanceResponse),
            name: NSNotification.Name("\(appIdentifier).AlreadyRunning"),
            object: nil
        )
        
        // Post notification to see if an existing instance responds
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: appIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        
        // Wait briefly to see if existing instance responds
        let date = Date()
        let runLoop = RunLoop.current
        while Date().timeIntervalSince(date) < 1.0 {
            if existingInstanceDetected {
                return false
            }
            runLoop.run(until: Date().addingTimeInterval(0.1))
        }
        
        return !existingInstanceDetected
    }
    
    private var existingInstanceDetected = false
    
    @objc private func handleExistingInstanceResponse(_ notification: Notification) {
        existingInstanceDetected = true
    }
}
