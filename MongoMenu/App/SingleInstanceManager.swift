//
//  SingleInstanceManager.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//

import Foundation
import Darwin

class SingleInstanceManager {
    static let shared = SingleInstanceManager()
    
    private let lockFilePath: String
    private var lockFileDescriptor: Int32 = -1
    
    private init() {
        // Create lock file in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appBundleID = Bundle.main.bundleIdentifier ?? "com.example.MongoMenu"
        let appDirectory = appSupport.appendingPathComponent(appBundleID)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        // Set lock file path
        lockFilePath = appDirectory.appendingPathComponent("app.lock").path
    }
    
    /// Attempts to acquire lock to ensure only one instance is running
    /// - Returns: True if this is the only instance, false otherwise
    func acquireLock() -> Bool {
        // Open the file with O_CREAT | O_WRONLY | O_EXLOCK | O_NONBLOCK
        // O_EXLOCK is used to obtain an exclusive lock
        // O_NONBLOCK makes it non-blocking (returns immediately if can't get lock)
        lockFileDescriptor = open(lockFilePath, O_CREAT | O_WRONLY | O_EXLOCK | O_NONBLOCK, 0o644)
        
        if lockFileDescriptor == -1 {
            print("Could not acquire lock. Another instance is likely running.")
            return false
        }
        
        // Write PID to the file
        let pid = ProcessInfo.processInfo.processIdentifier
        let pidString = "\(pid)\n"
        
        if let data = pidString.data(using: .utf8) {
            _ = data.withUnsafeBytes { buffer in
                write(lockFileDescriptor, buffer.baseAddress, buffer.count)
            }
        }
        
        return true
    }
    
    /// Release the lock when the app terminates
    func releaseLock() {
        if lockFileDescriptor != -1 {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }
}
