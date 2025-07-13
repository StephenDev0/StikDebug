//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Pipify

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct HomeView: View {

    @AppStorage("username") private var username = "User"
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentColor) private var environmentAccentColor
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("bundleID") private var bundleID: String = ""
    @State private var isProcessing = false
    @State private var isShowingInstalledApps = false
    @State private var isShowingPairingFilePicker = false
    @State private var pairingFileExists: Bool = false
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var showingConsoleLogsView = false
    @State private var importProgress: Float = 0.0
    
    @State private var pidTextAlertShow = false
    @State private var pidStr = ""
    
    @State private var viewDidAppeared = false
    @State private var pendingBundleIdToEnableJIT : String? = nil
    @State private var pendingPIDToEnableJIT : Int? = nil
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false

    @AppStorage("useDefaultScript") private var useDefaultScript = false
    @AppStorage("enablePiP") private var enablePiP = true
    @State var scriptViewShow = false
    @AppStorage("DefaultScriptName") var selectedScript = "attachDetach.js"
    @State var jsModel: RunJSViewModel?
    
    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }

    var body: some View {
        ZStack {
            // Use system background
            Color(colorScheme == .dark ? .black : .white)
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Spacer()
                VStack(spacing: 5) {
                    Text("Welcome to StikDebug \(username)!")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text(pairingFileExists ? "Click connect to get started" : "Pick pairing file to get started")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Button(action: {
                    
                    
                    if pairingFileExists {
                        // Got a pairing file, show apps
                        if !isMounted() {
                            showAlert(title: "Device Not Mounted".localized, message: "The Developer Disk Image has not been mounted yet. Check in settings for more information.".localized, showOk: true) { cool in
                                // No Need
                            }
                            return
                        }
                        
                        isShowingInstalledApps = true
                        
                    } else {
                        // No pairing file yet, let's get one
                        isShowingPairingFilePicker = true
                    }
                }) {
                    HStack {
                        Image(systemName: pairingFileExists ? "cable.connector.horizontal" : "doc.badge.plus")
                            .font(.system(size: 20))
                        Text(pairingFileExists ? "Connect by App" : "Select Pairing File")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(accentColor.contrastText())
                    .cornerRadius(16)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                
                if pairingFileExists && enableAdvancedOptions {
                    Button(action: {
                        pidTextAlertShow = true
                    }) {
                        HStack {
                            Image(systemName: "cable.connector.horizontal")
                                .font(.system(size: 20))
                            Text("Connect by PID")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor)
                        .foregroundColor(accentColor.contrastText())
                        .cornerRadius(16)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                }
                
                Button(action: {
                    showingConsoleLogsView = true
                }) {
                    HStack {
                        Image(systemName: "apple.terminal")
                            .font(.system(size: 20))
                        Text("Open Console")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(accentColor.contrastText())
                    .cornerRadius(16)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingConsoleLogsView) {
                    ConsoleLogsView()
                }
                
                // Status message area - keeps layout consistent
                ZStack {
                    // Progress bar for importing file
                    if isImportingFile {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Processing pairing file...")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                Text("\(Int(importProgress * 100))%")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondaryText)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * CGFloat(importProgress), height: 8)
                                        .animation(.linear(duration: 0.3), value: importProgress)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Success message
                    if showPairingFileMessage && pairingFileIsValid {
                        Text("✓ Pairing file successfully imported")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                    
                    // Invisible text to reserve space - no layout jumps
                    Text(" ").opacity(0)
                }
                .frame(height: isImportingFile ? 60 : 30)  // Adjust height based on what's showing
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            checkPairingFileExists()
            // Don't initialize specific color value when empty - empty means "use system theme"
            // This was causing the toggle to turn off when returning to settings
            
            // Initialize background color
            refreshBackground()
            
            // Add notification observer for showing pairing file picker
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowPairingFilePicker"),
                object: nil,
                queue: .main
            ) { _ in
                isShowingPairingFilePicker = true
            }
        }
        .onReceive(timer) { _ in
            refreshBackground()
            checkPairingFileExists()

        }
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList]) {result in
            switch result {
            
            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        if fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path) {
                            try fileManager.removeItem(at: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        }
                        
                        try fileManager.copyItem(at: url, to: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        print("File copied successfully!")
                        
                        // Show progress bar and initialize progress
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0.0
                            pairingFileExists = true
                        }
                        
                        // Start heartbeat in background
                        startHeartbeatInBackground()
                        
                        // Create timer to update progress instead of sleeping
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.25
                                } else {
                                    timer.invalidate()
                                    isImportingFile = false
                                    pairingFileIsValid = true
                                    
                                    // Show success message
                                    withAnimation {
                                        showPairingFileMessage = true
                                    }
                                    
                                    // Hide message after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            showPairingFileMessage = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Ensure timer keeps running
                        RunLoop.current.add(progressTimer, forMode: .common)
                        
                    } catch {
                        print("Error copying file: \(error)")
                    }
                } else {
                    print("Source file does not exist.")
                }
                
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackHelper.trigger()
                startJITInBackground(with: selectedBundle)
            }
        }
        .pipify(isPresented: Binding(
            get: { enablePiP && isProcessing },
            set: { newValue in isProcessing = newValue }
        )) {
            RunJSViewPiP(model: $jsModel)
        }
        .sheet(isPresented: $scriptViewShow) {
            NavigationView {
                if let jsModel {
                    RunJSView(model: jsModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    scriptViewShow = false
                                    isProcessing = false
                                }
                            }
                        }
                        .navigationTitle(selectedScript)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onChange(of: scriptViewShow) { oldValue, newValue in
            if !newValue, let jsModel {
                jsModel.executionInterrupted = true
                jsModel.semaphore?.signal()
            }
        }
        .textFieldAlert(
            isPresented: $pidTextAlertShow,
            title: "Please enter the PID of the process you want to connect to".localized,
            text: $pidStr,
            placeholder: "",
            action: { newText in

                guard let pidStr = newText, pidStr != "" else {
                    return
                }
                
                guard let pid = Int(pidStr) else {
                    showAlert(title: "", message: "Invalid PID".localized, showOk: true, completion: { _ in })
                    return
                }
                startJITInBackground(with: pid)
                
            },
            actionCancel: {_ in
                pidStr = ""
            }
        )
        .onOpenURL { url in
            print(url.path)
            if url.host != "enable-jit" {
                return
            }
            
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
                if viewDidAppeared {
                    startJITInBackground(with: bundleId)
                } else {
                    pendingBundleIdToEnableJIT = bundleId
                }
            } else if let pidStr = components?.queryItems?.first(where: { $0.name == "pid" })?.value, let pid = Int(pidStr) {
                if viewDidAppeared {
                    startJITInBackground(with: pid)
                } else {
                    pendingPIDToEnableJIT = pid
                }
            }
            
        }
        .onAppear() {
            viewDidAppeared = true
            if let pendingBundleIdToEnableJIT {
                startJITInBackground(with: pendingBundleIdToEnableJIT)
                self.pendingBundleIdToEnableJIT = nil
            }
            if let pendingPIDToEnableJIT {
                startJITInBackground(with: pendingPIDToEnableJIT)
                self.pendingPIDToEnableJIT = nil
            }
        }
    }
    

    
    private func checkPairingFileExists() {
        let fileExists = FileManager.default.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
        
        // If the file exists, check if it's valid
        if fileExists {
            // Check if the pairing file is valid
            let isValid = isPairing()
            pairingFileExists = isValid
        } else {
            pairingFileExists = false
        }
    }
    
    private func refreshBackground() {
        // This function is no longer needed for background color
        // but we'll keep it empty to avoid breaking anything
    }
    
    private func getJsCallback(for scriptName: String? = nil) -> DebugAppCallback? {
        let name = scriptName ?? selectedScript
        let selectedScriptURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts").appendingPathComponent(name)
        
        if !FileManager.default.fileExists(atPath: selectedScriptURL.path) {
            return nil
        }
        
        return { pid, debugProxyHandle, semaphore in
            jsModel = RunJSViewModel(pid: Int(pid), debugProxy: debugProxyHandle, semaphore: semaphore)
            scriptViewShow = true
            DispatchQueue.global(qos: .background).async {
                do {
                    try jsModel?.runScript(path: selectedScriptURL)
                    isProcessing = false
                } catch {
                    showAlert(title: "Error Occurred While Executing the Default Script.".localized, message: error.localizedDescription, showOk: true)
                }
            }
        }
    }
    
    private func startJITInBackground(with bundleID: String) {
        isProcessing = true
        
        // Add log message
        LogManager.shared.addInfoLog("Starting Debug for \(bundleID)")
        
        DispatchQueue.global(qos: .background).async {
            var callback: DebugAppCallback? = nil
            if enableAdvancedOptions {
                let mapping = UserDefaults.standard.dictionary(forKey: "BundleScriptMap") as? [String: String]
                if let script = mapping?[bundleID] {
                    callback = getJsCallback(for: script)
                } else if useDefaultScript {
                    callback = getJsCallback()
                }
            }
            let success = JITEnableContext.shared.debugApp(withBundleID: bundleID, logger: { message in

                if let message = message {
                    // Log messages from the JIT process
                    LogManager.shared.addInfoLog(message)
                }
            }, jsCallback: callback)
            
            DispatchQueue.main.async {
                LogManager.shared.addInfoLog("Debug process completed for \(bundleID)")
                isProcessing = false
            }
        }
    }
    
    private func startJITInBackground(with pid: Int) {
        isProcessing = true
        
        // Add log message
        LogManager.shared.addInfoLog("Starting JIT for pid \(pid)")
        
        DispatchQueue.global(qos: .background).async {

            let jsCallback: DebugAppCallback? = (enableAdvancedOptions && useDefaultScript) ? getJsCallback() : nil
            let success = JITEnableContext.shared.debugApp(withPID: Int32(pid), logger: { message in

                if let message = message {
                    // Log messages from the JIT process
                    LogManager.shared.addInfoLog(message)
                }
            }, jsCallback: jsCallback)
            
            DispatchQueue.main.async {
                LogManager.shared.addInfoLog("JIT process completed for \(pid)")
                showAlert(title: "Success".localized, message: String(format: "JIT has been enabled for pid %d.".localized, pid), showOk: true, messageType: .success)
                isProcessing = false
            }
        }
    }
}

class InstalledAppsViewModel: ObservableObject {
    @Published var apps: [String: String] = [:]
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        do {
            self.apps = try JITEnableContext.shared.getAppList()
        } catch {
            print(error)
            self.apps = [:]
        }
    }
}



#Preview {
    HomeView()
}
