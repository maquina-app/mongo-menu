//
//  MongoMenuApp.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//


import SwiftUI

struct MongoMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Check if another instance is running using file lock approach
        if !SingleInstanceManager.shared.acquireLock() {
            // Another instance is running, terminate this one
            print("Another instance of MongoMenu is already running. Terminating.")
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}
