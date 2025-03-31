//
//  MongoDBService.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//


import Foundation
import Cocoa

class MongoDBService: ObservableObject {
    static let shared = MongoDBService()
    
    private var mongodProcess: Process?
    private var standardOutput: Pipe?
    private var standardError: Pipe?
    
    // Add port property
    @Published var port: Int = 27017 // Default MongoDB port
    
    @Published var isRunning: Bool = false {
        didSet {
            // Post notification when status changes
            NotificationCenter.default.post(name: NSNotification.Name("MongoDBStatusChanged"), object: isRunning)
        }
    }
    
    init() {
        // Ensure default directories exist
        setupDefaultDirectories()
    }
    
    private func setupDefaultDirectories() {
        let defaults = UserDefaults.standard
        
        // Set default port if not already set
        if UserDefaults.standard.object(forKey: "MongoPort") == nil {
            UserDefaults.standard.set(27017, forKey: "MongoPort")
        }
        
        // Load port from UserDefaults
        port = UserDefaults.standard.integer(forKey: "MongoPort")
        
        // Set default directories if not set already
        if defaults.string(forKey: "MongoDataDir") == nil {
            let defaultDataDir = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/mongodb/data"
            defaults.set(defaultDataDir, forKey: "MongoDataDir")
        }
        
        if defaults.string(forKey: "MongoLogPath") == nil {
            let defaultLogPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/mongodb/logs/mongodb.log"
            defaults.set(defaultLogPath, forKey: "MongoLogPath")
        }
        
        // Create data directory if it doesn't exist
        let dataDir = defaults.string(forKey: "MongoDataDir")!
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating data directory: \(error)")
        }
        
        // Create log directory if it doesn't exist
        let logPath = defaults.string(forKey: "MongoLogPath")!
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent().path
        do {
            try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating log directory: \(error)")
        }
    }

    func startMongoDB() {
        // Check if already running
        if isRunning { return }
        
        // Find MongoDB binary path
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Unable to find resource path")
            return
        }
        
        let mongodPath = "\(resourcePath)/mongodb/bin/mongod"
        
        // Debug log
        print("Looking for MongoDB at: \(mongodPath)")
        
        // Check if file exists and is executable
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: mongodPath, isDirectory: &isDirectory)
        
        guard fileExists && !isDirectory.boolValue else {
            print("MongoDB binary not found at path: \(mongodPath)")
            // Notify user with an alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "MongoDB Binary Not Found"
                alert.informativeText = "Unable to find MongoDB binary at:\n\(mongodPath)\n\nPlease reinstall the application."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        // Check if file is executable
        let attributes = try? FileManager.default.attributesOfItem(atPath: mongodPath)
        let permissions = attributes?[.posixPermissions] as? NSNumber
        let isExecutable = (permissions?.intValue ?? 0) & 0o111 != 0
        
        guard isExecutable else {
            print("MongoDB binary is not executable")
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: mongodPath)
            print("Attempted to set executable permissions")
            return
        }
        
        print("MongoDB binary found and is executable")
        
        // Get directory paths from UserDefaults
        let defaults = UserDefaults.standard
        let dataDir = defaults.string(forKey: "MongoDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/mongodb/data"
        let logPath = defaults.string(forKey: "MongoLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/mongodb/logs/mongodb.log"
        
        // Create directories if they don't exist
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: logPath).deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating directories: \(error)")
            return
        }
        
        // Check if another instance of MongoDB is already running
        if isMongoDBAlreadyRunning() {
            displayAlert(title: "MongoDB Already Running",
                         message: "Another MongoDB instance appears to be running. Please stop it before starting a new instance.")
            return
        }
        
        // Get path to MongoDB binary
        let bundlePath = Bundle.main.resourcePath!
        let binaryPath = "\(bundlePath)/mongodb/bin/mongod"
        
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            NSLog("MongoDB binary not found at path: \(binaryPath)")
            displayAlert(title: "MongoDB Error", message: "MongoDB binary not found. Please reinstall the application.")
            return
        }
        
        // Configure and start the process
        mongodProcess = Process()
        mongodProcess?.executableURL = URL(fileURLWithPath: binaryPath)
        
        // Add --port parameter to use a specific port
        // And add --repair option in case the database was not shut down properly
        mongodProcess?.arguments = [
            "--dbpath", dataDir,
            "--logpath", logPath,
            "--logappend",
            "--port", "\(port)"
        ]
        
        // Set up pipes for capturing output
        standardOutput = Pipe()
        standardError = Pipe()
        mongodProcess?.standardOutput = standardOutput
        mongodProcess?.standardError = standardError
        
        // Handle process termination
        mongodProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if let strongSelf = self, strongSelf.isRunning {
                    strongSelf.isRunning = false
                    
                    // Check if terminated unexpectedly with error
                    if process.terminationStatus != 0 && process.terminationStatus != 15 { // 15 is SIGTERM
                        strongSelf.checkLogForErrors(logPath: logPath)
                    }
                    
                    NSLog("MongoDB process terminated with status: \(process.terminationStatus)")
                }
            }
        }
        
        // Start the MongoDB process
        do {
            try mongodProcess?.run()
            isRunning = true
            NSLog("MongoDB started with data directory: \(dataDir) and log path: \(logPath)")
            
            // Log any output
            setupOutputMonitoring()
        } catch {
            NSLog("Error starting MongoDB: \(error)")
            displayAlert(title: "MongoDB Error", message: "Failed to start MongoDB: \(error.localizedDescription)")
            isRunning = false
        }
    }

    func stopMongoDB(completion: (() -> Void)? = nil) {
        guard let process = mongodProcess, isRunning else {
            completion?()
            return
        }
        
        NSLog("Stopping MongoDB...")
        
        // First try to shut down gracefully using mongosh if available
        tryGracefulShutdown()
        
        // Set up a timer to check if the process has terminated
        let shutdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            // Check if process has terminated
            if self?.isRunning == false || process.isRunning == false {
                timer.invalidate()
                
                // Clean up
                self?.mongodProcess = nil
                self?.standardOutput = nil
                self?.standardError = nil
                self?.isRunning = false
                
                NSLog("MongoDB stopped successfully")
                
                // Call completion handler
                completion?()
            }
        }
        
        // Wait a moment for graceful shutdown to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if shutdownTimer.isValid {
                shutdownTimer.invalidate()
                
                // Force terminate if still running
                if process.isRunning {
                    NSLog("MongoDB shutdown timed out, forcing termination")
                    process.terminate()
                }
                
                // Clean up
                self.mongodProcess = nil
                self.standardOutput = nil
                self.standardError = nil
                self.isRunning = false
                
                NSLog("MongoDB forced to stop")
                
                // Call completion handler
                completion?()
            }
        }
    }
    
    private func tryGracefulShutdown() {
        guard let resourcePath = Bundle.main.resourcePath else {
            return
        }
        
        // Check for mongosh tool
        let mongoshPath = "\(resourcePath)/mongodb/bin/mongosh"
        
        guard FileManager.default.fileExists(atPath: mongoshPath) else {
            return
        }
        
        // Try to shut down gracefully
        let shutdownProcess = Process()
        shutdownProcess.executableURL = URL(fileURLWithPath: mongoshPath)
        shutdownProcess.arguments = ["--port", "\(port)", "--eval", "db.adminCommand({shutdown: 1})"]
        
        do {
            try shutdownProcess.run()
            NSLog("Sent graceful shutdown command to MongoDB on port \(port)")
        } catch {
            NSLog("Failed to send graceful shutdown: \(error)")
        }
    }
    
    private func isMongoDBAlreadyRunning() -> Bool {
        // Simple check for port 27017 (default MongoDB port)
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        checkProcess.arguments = ["-i", ":\(port)"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return !output.isEmpty
        } catch {
            NSLog("Error checking for running MongoDB: \(error)")
            return false
        }
    }
    
    private func checkLogForErrors(logPath: String) {
        do {
            let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
            let lines = logContent.components(separatedBy: .newlines).reversed()
            
            // Look through the last 50 lines for error messages
            for line in lines.prefix(50) {
                if line.contains("ERROR") || line.contains("exception") {
                    NSLog("Found error in MongoDB log: \(line)")
                    
                    // If it's a port conflict
                    if line.contains("Address already in use") || line.contains("port") {
                        displayAlert(title: "MongoDB Error",
                                   message: "MongoDB failed to start because the port is already in use. Another instance may be running.")
                    }
                    // Check for permission errors
                    else if line.contains("Permission denied") {
                        displayAlert(title: "MongoDB Error",
                                   message: "MongoDB failed to start due to permission issues accessing the data or log directories.")
                    }
                    // Otherwise show generic error
                    else {
                        displayAlert(title: "MongoDB Error",
                                   message: "MongoDB failed to start. Check the log file for details: \(logPath)")
                    }
                    
                    break
                }
            }
        } catch {
            NSLog("Error reading MongoDB log: \(error)")
        }
    }
    
    private func setupOutputMonitoring() {
        guard let outputPipe = standardOutput, let errorPipe = standardError else { return }
        
        // Monitor standard output
        DispatchQueue.global(qos: .background).async {
            let outputHandle = outputPipe.fileHandleForReading
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        NSLog("MongoDB output: \(output)")
                    }
                }
            }
        }
        
        // Monitor standard error
        DispatchQueue.global(qos: .background).async {
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let error = String(data: data, encoding: .utf8) {
                        NSLog("MongoDB error: \(error)")
                        
                        // Check for common errors and display appropriate messages
                        if error.contains("Address already in use") {
                            self.displayAlert(title: "MongoDB Error",
                                           message: "Failed to start MongoDB: Port already in use")
                        }
                    }
                }
            }
        }
    }
    
    private func displayAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
