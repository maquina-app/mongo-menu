//
//  LoggingService.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//


import Foundation

class LoggingService {
    static let shared = LoggingService()
    
    private let logFile: URL
    private let dateFormatter: DateFormatter
    
    init() {
        // Setup date formatter for log timestamps
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Create app support directory for logs
        let fileManager = FileManager.default
        var appSupportDir = try! fileManager.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        
        appSupportDir = appSupportDir.appendingPathComponent("MongoMenu", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try! fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Set log file path
        logFile = appSupportDir.appendingPathComponent("mongomenu.log")
        
        // Initialize log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFile.path) {
            fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
        }
        
        // Log app start
        log("MongoMenu started")
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // Print to console
        print(logMessage, terminator: "")
        
        // Write to file
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

// Convenience functions
func logDebug(_ message: String) {
    LoggingService.shared.log(message, level: .debug)
}

func logInfo(_ message: String) {
    LoggingService.shared.log(message, level: .info)
}

func logWarning(_ message: String) {
    LoggingService.shared.log(message, level: .warning)
}

func logError(_ message: String) {
    LoggingService.shared.log(message, level: .error)
}
