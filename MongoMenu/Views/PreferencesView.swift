//
//  PreferencesView.swift
//  MongoMenu
//
//  Created by Mario Alberto Chávez on 30/03/25.
//


import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct PreferencesView: View {
    @AppStorage("MongoDataDir") private var dataDir: String = "\(FileManager.default.homeDirectoryForCurrentUser.path)/mongo-data"
    @AppStorage("MongoLogPath") private var logPath: String = "\(FileManager.default.homeDirectoryForCurrentUser.path)/mongo.log"
    @AppStorage("AutoStartMongoDB") private var autoStartMongoDB: Bool = true
    @AppStorage("LaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("MongoPort") private var mongoPort: Int = 27017
    
    @State private var showDataDirPicker = false
    @State private var showLogPathPicker = false
    @State private var restartRequired = false
    @State private var selectedTab = 0
    
    @ObservedObject private var mongoDBService = MongoDBService.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Settings Tab
            settingsView
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(0)
            
            // About Tab
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(1)
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            // Update the service with the current port
            mongoDBService.port = mongoPort
            
            // Ensure UI reflects the actual UserDefaults value
            let storedValue = UserDefaults.standard.bool(forKey: "AutoStartMongoDB")
            if autoStartMongoDB != storedValue {
                autoStartMongoDB = storedValue
            }
            print("Current auto-start setting: \(autoStartMongoDB)")
        }
    }
    
    // Settings Tab Content
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Start MongoDB when app launches", isOn: $autoStartMongoDB)
                .onChange(of: autoStartMongoDB) { oldValue, newValue in
                    // Force UserDefaults synchronization
                    UserDefaults.standard.set(newValue, forKey: "AutoStartMongoDB")
                    UserDefaults.standard.synchronize()
                    print("Auto-start MongoDB setting changed to: \(newValue)")
                }
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { oldValue, newValue in
                    setLaunchAtLogin(newValue)
                }
            
            Divider()
            
            // Add port configuration
            HStack {
                Text("MongoDB Port:")
                Spacer()
                TextField("", value: $mongoPort, formatter: NumberFormatter())
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            .onChange(of: mongoPort) { oldValue, newValue in
                restartRequired = mongoDBService.isRunning
            }
            
            HStack {
                Text("Data Directory:")
                Spacer()
                TextField("", text: $dataDir)
                    .frame(minWidth: 200)
                Button("Browse...") {
                    showDataDirPicker = true
                }
                .sheet(isPresented: $showDataDirPicker) {
                    DirectoryPickerView(selectedPath: $dataDir, title: "Select MongoDB Data Directory")
                }
            }
            .onChange(of: dataDir) { oldValue, newValue in
                restartRequired = mongoDBService.isRunning
            }
            
            HStack {
                Text("Log File Path:")
                Spacer()
                TextField("", text: $logPath)
                    .frame(minWidth: 200)
                Button("Browse...") {
                    showLogPathPicker = true
                }
                .sheet(isPresented: $showLogPathPicker) {
                    FilePickerView(selectedPath: $logPath, title: "Select MongoDB Log File")
                }
            }
            .onChange(of: logPath) { oldValue, newValue in
                restartRequired = mongoDBService.isRunning
            }
            
            if restartRequired {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    Text("Changes require MongoDB restart")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Restart MongoDB") {
                        restartMongoDB()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            
            HStack {
                Text("MongoDB Status: \(mongoDBService.isRunning ? "Running" : "Stopped")")
                    .foregroundColor(mongoDBService.isRunning ? .green : .red)
                Spacer()
                Button(mongoDBService.isRunning ? "Stop MongoDB" : "Start MongoDB") {
                    if mongoDBService.isRunning {
                        mongoDBService.stopMongoDB()
                    } else {
                        mongoDBService.startMongoDB()
                    }
                }
            }
            .padding(.top)
        }
        .padding()
    }
    
    // About Tab Content
    private var aboutView: some View {
        VStack(spacing: 20) {
            // Company Logo
            Image("CompanyLogo") // Add your company logo to Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 20)
            
            // App Name
            Text("MongoMenu")
                .font(.system(size: 24, weight: .bold))
            
            // Version
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Company Name
            Text("Maquina App")
                .font(.headline)
                .padding(.top, 10)
            
            // URL (clickable)
            Link("https://maquina.app", destination: URL(string: "https://maquina.app")!)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            // Copyright
            Text("© \(Calendar.current.component(.year, from: Date())) Maquina App. All rights reserved.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
            
            // MongoDB Trademark Disclaimer
            VStack(spacing: 0) {
                Text("MongoDB and the MongoDB logo are registered")
                Text("trademarks of MongoDB, Inc.")
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            .padding(.top, 5)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        #if os(macOS)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Error setting launch at login: \(error)")
        }
        #endif
    }
    
    private func restartMongoDB() {
        if mongoDBService.isRunning {
            mongoDBService.stopMongoDB()
            // Small delay to ensure proper shutdown
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                mongoDBService.startMongoDB()
                restartRequired = false
            }
        }
    }
}

// Directory Picker View
struct DirectoryPickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("Select Directory") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}

// File Picker View
struct FilePickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("Select File") {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType.log]
                panel.nameFieldStringValue = "mongo.log"
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}
