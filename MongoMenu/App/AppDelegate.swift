//
//  AppDelegate.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var preferencesWindow: NSWindow?
    
    @Published var mongoStatus: String = "Starting..."
    
    // Subscribe to MongoDB service status changes
    private var mongoDBStatusObserver: NSObjectProtocol?
    
    // Unique identifier for this app
    private let appIdentifier = "com.maquina-app.MongoMenu"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        if !ensureSingleInstance() {
            NSApp.terminate(nil)
            return
        }
        
        print("Application did finish launching")
        // Set up menu bar status item
        setupMenuBar()
        print("Menu bar setup complete")
        
        // Start MongoDB if auto-start is enabled
        if UserDefaults.standard.bool(forKey: "AutoStartMongoDB") {
            print("Autostart enabled. Starting MongoDB...")
            startMongoDB()
        } else {
            mongoStatus = "Stopped"
            updateStatusDisplay()
        }
        
        // Setup observer for MongoDB service status changes
        mongoDBStatusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MongoDBStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isRunning = notification.object as? Bool {
                self?.mongoStatus = isRunning ? "Running" : "Stopped"
                self?.updateStatusDisplay()
            }
        }
        
        // Register for notifications when app is being activated
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAppActivationRequest),
            name: NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: nil
        )
    }
    
    private func ensureSingleInstance() -> Bool {
        // Post a notification to alert any existing instances
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: Bundle.main.bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        
        // Small delay to allow existing app to respond
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check if we received a response (handled in the notification callback)
        // If we return false from this method in the callback, the app will terminate
        return true
    }
    
    @objc private func handleAppActivationRequest(notification: NSNotification) {
        // Check if this is from another instance trying to launch
        if notification.object as? String != Bundle.main.bundleIdentifier {
            // Bring app to foreground
            NSApp.activate(ignoringOtherApps: true)
            
            // Show preferences window if it exists
            if let window = preferencesWindow {
                window.makeKeyAndOrderFront(nil)
            } else {
                openPreferences()
            }
            
            // Update notification center to indicate we're already running
            // This will cause the other instance to terminate
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("\(appIdentifier).AlreadyRunning"),
                object: Bundle.main.bundleIdentifier,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
    
    deinit {
        if let observer = mongoDBStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                // Configure the image first
                icon.size = NSSize(width: 24, height: 24)
                icon.isTemplate = true
                
                // Then assign it to the button
                button.image = icon
                print("Image set: \(String(describing: button.image))")
            } else {
                // Fallback if image can't be loaded
                print("Failed to load MenuBarIcon, using text fallback")
                button.title = "M"
            }
        }

        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "MongoDB Status: \(mongoStatus)", action: nil, keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())
        
        let startStopItem = NSMenuItem(title: "Start MongoDB", action: #selector(toggleMongoDB), keyEquivalent: "s")
        startStopItem.target = self
        menu?.addItem(startStopItem)

        menu?.addItem(NSMenuItem.separator())

        let openData = NSMenuItem(title: "Open Data Folder", action: #selector(openDataFolder), keyEquivalent: "d")
        openData.target = self
        menu?.addItem(openData)

        let openLog = NSMenuItem(title: "Open Log Folder", action: #selector(openLogFolder), keyEquivalent: "l")
        openLog.target = self
        menu?.addItem(openLog)

        menu?.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu?.addItem(preferencesItem)

        menu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }
    
    @objc func toggleMongoDB() {
        if MongoDBService.shared.isRunning {
            stopMongoDB()
        } else {
            startMongoDB()
        }
    }
    
    func startMongoDB() {
        MongoDBService.shared.startMongoDB()
        updateStatusDisplay()
    }
    
    func stopMongoDB() {
        MongoDBService.shared.stopMongoDB()
        updateStatusDisplay()
    }

    func updateStatusDisplay() {
        // Update menu item title to include port
        menu?.item(at: 0)?.title = "MongoDB Status: \(mongoStatus) (Port: \(MongoDBService.shared.port))"
        
        // Update start/stop menu item
        if let startStopItem = menu?.item(at: 2) {
            startStopItem.title = MongoDBService.shared.isRunning ? "Stop MongoDB" : "Start MongoDB"
        }
        
        // Update status bar icon if needed
        if let button = statusItem?.button {
            let icon = NSImage(named: "MenuBarIcon")
            if let icon = icon {
                icon.size = NSSize(width: 24, height: 24)
                icon.isTemplate = true
                button.image = icon
            }
        }
    }

    @objc func openDataFolder() {
        let dataDir = UserDefaults.standard.string(forKey: "MongoDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/mongo-data"
        NSWorkspace.shared.open(URL(fileURLWithPath: dataDir))
    }

    @objc func openLogFolder() {
        let logPath = UserDefaults.standard.string(forKey: "MongoLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/mongo.log"
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent()
        NSWorkspace.shared.open(logDir)
    }

    @objc func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            preferencesWindow?.center()
            preferencesWindow?.title = "MongoDB Preferences"
            preferencesWindow?.contentView = NSHostingView(rootView: PreferencesView())
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Add to your AppDelegate
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if MongoDB is running
        if MongoDBService.shared.isRunning {
            print("Application is quitting, waiting for MongoDB to stop...")
            
            // Start MongoDB shutdown
            MongoDBService.shared.stopMongoDB { [weak self] in
                // Once MongoDB is stopped, tell the app it can terminate now
                print("MongoDB has stopped, proceeding with app termination")
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
            
            // Tell the app to wait before quitting
            return .terminateLater
        } else {
            // If MongoDB is not running, we can quit immediately
            return .terminateNow
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop MongoDB when app is terminated
        MongoDBService.shared.stopMongoDB()
    }
}
