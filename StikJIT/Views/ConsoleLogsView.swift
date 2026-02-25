//
//  ConsoleLogsView.swift
//  StikJIT
//
//  Created by neoarz on 3/29/25.
//

import SwiftUI
import UIKit

struct ConsoleLogsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var logManager = LogManager.shared
    @StateObject private var systemLogStream = SystemLogStream()
    @State private var selectedConsoleTab: ConsoleTab = .idevice
    @State private var jitScrollView: ScrollViewProxy? = nil
    @State private var showingCustomAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isError = false
    
    @State private var logCheckTimer: Timer? = nil
    
    @State private var isViewActive = false
    @State private var lastProcessedLineCount = 0
    @State private var isLoadingLogs = false
    @State private var jitIsAtBottom = true
    @State private var syslogIsAtBottom = true
    @State private var syslogSearchText = ""
    @State private var showingSyslogSpeedSelector = false
    private let appLogRefreshInterval: TimeInterval = 3.0
    private let syslogIntervalOptions: [Double] = [0.0, 0.2, 0.5, 1.0, 1.5, 2.0]


    private var filteredSyslogEntries: [SystemLogStream.Entry] {
        if syslogSearchText.isEmpty {
            return systemLogStream.entries
        }
        let query = syslogSearchText.lowercased()
        return systemLogStream.entries.filter { $0.raw.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectedConsoleTab == .idevice {
                    jitLogsPane
                } else {
                    syslogLogsPane
                }
            }
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedConsoleTab) {
                        Text("App").tag(ConsoleTab.idevice)
                        Text("System").tag(ConsoleTab.syslog)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if selectedConsoleTab == .idevice {
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                Task { await loadIdeviceLogsAsync() }
                            }
                            Button("Clear", systemImage: "trash", role: .destructive) {
                                logManager.clearLogs()
                            }
                            Button("Copy Logs", systemImage: "doc.on.doc") {
                                copyJITLogs()
                            }
                            exportMenuOption
                        } else {
                            Button(syslogControlLabel, systemImage: syslogControlIcon) {
                                toggleSyslogPlayback()
                            }
                            Button("Clear", systemImage: "trash", role: .destructive) {
                                systemLogStream.clear()
                            }
                            Button("Copy Logs", systemImage: "doc.on.doc") {
                                copySyslogToClipboard()
                            }
                            Button("Adjust Speed", systemImage: "slider.horizontal.3") {
                                showingSyslogSpeedSelector = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingCustomAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("Syslog Speed", isPresented: $showingSyslogSpeedSelector) {
                ForEach(syslogIntervalOptions, id: \.self) { option in
                    Button(intervalLabel(for: option)) {
                        systemLogStream.updateInterval = option
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose how quickly new relay entries appear.")
            }
        }
                .onDisappear {
            systemLogStream.stop()
        }
        .onChange(of: systemLogStream.lastError) { newError in
            if let error = newError {
                alertTitle = "Syslog Error"
                alertMessage = error
                isError = true
                showingCustomAlert = true
                systemLogStream.lastError = nil
            }
        }
    }
    
    private var jitLogsPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("=== DEVICE INFORMATION ===")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.vertical, 4)

                        Text("iOS Version: \(UIDevice.current.systemVersion)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Device: \(UIDevice.current.name)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Model: \(UIDevice.current.model)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("=== LOG ENTRIES ===")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    ForEach(logManager.logs) { logEntry in
                        Text(AttributedString(createLogAttributedString(logEntry)))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 4)
                            .id(logEntry.id)
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("jitScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "jitScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                jitIsAtBottom = offset > -20
            }
            .onChange(of: logManager.logs.count) { _ in
                guard jitIsAtBottom, let lastLog = logManager.logs.last else { return }
                withAnimation {
                    proxy.scrollTo(lastLog.id, anchor: .bottom)
                }
            }
            .onAppear {
                jitScrollView = proxy
                isViewActive = true
                Task { await loadIdeviceLogsAsync() }
                startLogCheckTimer()
            }
            .onDisappear {
                isViewActive = false
                stopLogCheckTimer()
            }
        }
    }
    
    private var syslogLogsPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter logs", text: $syslogSearchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !syslogSearchText.isEmpty {
                    Button {
                        syslogSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredSyslogEntries) { entry in
                            Text(AttributedString(createSyslogAttributedString(entry)))
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 1)
                                .padding(.horizontal, 4)
                                .id(entry.id)
                        }
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("syslogScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "syslogScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    syslogIsAtBottom = offset > -20
                }
                .onChange(of: systemLogStream.entries.count) { _ in
                    guard syslogIsAtBottom, syslogSearchText.isEmpty,
                          let lastLog = systemLogStream.entries.last else { return }
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    if selectedConsoleTab == .syslog && !systemLogStream.isStreaming {
                        systemLogStream.start()
                    }
                }
                .onDisappear {
                    systemLogStream.stop()
                }
            }
        }
    }

    private func copyJITLogs() {
        var logsContent = "=== DEVICE INFORMATION ===\n"
        logsContent += "Version: \(UIDevice.current.systemVersion)\n"
        logsContent += "Name: \(UIDevice.current.name)\n"
        logsContent += "Model: \(UIDevice.current.model)\n"
        logsContent += "StikJIT Version: App Version: 1.0\n\n"
        logsContent += "=== LOG ENTRIES ===\n"
        logsContent += logManager.logs.map {
            "[\(formatTime(date: $0.timestamp))] [\($0.type.rawValue)] \($0.message)"
        }.joined(separator: "\n")
        UIPasteboard.general.string = logsContent
        alertTitle = "Logs Copied"
        alertMessage = "Logs have been copied to clipboard."
        isError = false
        showingCustomAlert = true
    }

    @ViewBuilder
    private var exportMenuOption: some View {
        let logURL: URL = URL.documentsDirectory.appendingPathComponent("idevice_log.txt")
        if FileManager.default.fileExists(atPath: logURL.path) {
            ShareLink(
                item: logURL,
                preview: SharePreview("idevice_log.txt", image: Image(systemName: "doc.text"))
            ) {
                Label("Export Logs", systemImage: "square.and.arrow.up")
            }
        } else {
            Button("Export Logs", systemImage: "square.and.arrow.up") {
                alertTitle = "Export Failed"
                alertMessage = "No idevice logs found"
                isError = true
                showingCustomAlert = true
            }
        }
    }
    
    private func createLogAttributedString(_ logEntry: LogManager.LogEntry) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        
        let timestampString = "[\(formatTime(date: logEntry.timestamp))]"
        let timestampAttr = NSAttributedString(
            string: timestampString,
            attributes: [.foregroundColor: colorScheme == .dark ? UIColor.gray : UIColor.darkGray]
        )
        fullString.append(timestampAttr)
        fullString.append(NSAttributedString(string: " "))
        
        let typeString = "[\(logEntry.type.rawValue)]"
        let typeColor = UIColor(colorForLogType(logEntry.type))
        let typeAttr = NSAttributedString(
            string: typeString,
            attributes: [.foregroundColor: typeColor]
        )
        fullString.append(typeAttr)
        fullString.append(NSAttributedString(string: " "))
        
        let messageAttr = NSAttributedString(
            string: logEntry.message,
            attributes: [.foregroundColor: colorScheme == .dark ? UIColor.white : UIColor.black]
        )
        fullString.append(messageAttr)
        
        return fullString
    }

    private func createSyslogAttributedString(_ entry: SystemLogStream.Entry) -> NSAttributedString {
        let type = logType(for: entry.raw)
        let fullString = NSMutableAttributedString()

        let timestampString = "[\(DateFormatter.consoleLogsFormatter.string(from: entry.timestamp))]"
        fullString.append(NSAttributedString(
            string: timestampString,
            attributes: [.foregroundColor: colorScheme == .dark ? UIColor.gray : UIColor.darkGray]
        ))
        fullString.append(NSAttributedString(string: " "))

        let typeAttr = NSAttributedString(
            string: "[\(type.rawValue)]",
            attributes: [.foregroundColor: UIColor(colorForLogType(type))]
        )
        fullString.append(typeAttr)
        fullString.append(NSAttributedString(string: " "))

        let messageAttr = NSAttributedString(
            string: entry.raw,
            attributes: [.foregroundColor: colorScheme == .dark ? UIColor.white : UIColor.black]
        )
        fullString.append(messageAttr)

        return fullString
    }
    private func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func colorForLogType(_ type: LogManager.LogEntry.LogType) -> Color {
        switch type {
        case .info:
            return .green
        case .error:
            return .red
        case .debug:
            return .blue
        case .warning:
            return .orange
        }
    }

    private func logType(for line: String) -> LogManager.LogEntry.LogType {
        let lowercase = line.lowercased()
        if lowercase.contains("error") {
            return .error
        } else if lowercase.contains("warning") {
            return .warning
        } else if lowercase.contains("debug") {
            return .debug
        } else {
            return .info
        }
    }

    private var syslogErrorCount: Int {
        systemLogStream.entries.reduce(0) { count, entry in
            count + (logType(for: entry.raw) == .error ? 1 : 0)
        }
    }

    private func intervalLabel(for value: Double) -> String {
        if value <= 0 {
            return "Live"
        }
        return "\(String(format: "%.1f", value))s"
    }
    
    private func loadIdeviceLogsAsync() async {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true

        let logPath = URL.documentsDirectory.appendingPathComponent("idevice_log.txt").path

        guard FileManager.default.fileExists(atPath: logPath) else {
            await MainActor.run {
                logManager.addInfoLog("No idevice logs found (Restart the app to continue reading)")
                isLoadingLogs = false
            }
            return
        }

        // Do all file I/O and parsing on a background thread
        let result: ([LogManager.LogEntry], Int)? = await Task.detached(priority: .userInitiated) {
            do {
                let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
                let lines = logContent.components(separatedBy: .newlines)

                let maxLines = 500
                let startIndex = max(0, lines.count - maxLines)
                let recentLines = lines[startIndex..<lines.count]

                let skipPrefixes = ["=== DEVICE INFORMATION ===", "Version:", "Name:", "Model:", "=== LOG ENTRIES ==="]

                var parsed: [LogManager.LogEntry] = []
                parsed.reserveCapacity(recentLines.count)

                for line in recentLines {
                    if line.isEmpty { continue }
                    if skipPrefixes.contains(where: { line.contains($0) }) { continue }

                    let type: LogManager.LogEntry.LogType
                    if line.contains("ERROR") || line.contains("Error") {
                        type = .error
                    } else if line.contains("WARNING") || line.contains("Warning") {
                        type = .warning
                    } else if line.contains("DEBUG") {
                        type = .debug
                    } else {
                        type = .info
                    }
                    parsed.append(LogManager.LogEntry(timestamp: Date(), type: type, message: line))
                }

                return (parsed, lines.count)
            } catch {
                return nil
            }
        }.value

        await MainActor.run {
            if let (entries, lineCount) = result {
                lastProcessedLineCount = lineCount
                logManager.setLogs(entries)
                if jitIsAtBottom, let last = logManager.logs.last {
                    jitScrollView?.scrollTo(last.id, anchor: .bottom)
                }
            } else {
                logManager.addErrorLog("Failed to read idevice logs")
            }
            isLoadingLogs = false
        }
    }
    
    private func startLogCheckTimer() {
        guard logCheckTimer == nil else { return }
        logCheckTimer = Timer.scheduledTimer(withTimeInterval: appLogRefreshInterval, repeats: true) { _ in
            if isViewActive {
                Task { await checkForNewLogs() }
            }
        }
        if let logCheckTimer {
            RunLoop.main.add(logCheckTimer, forMode: .common)
        }
    }
    
    private func checkForNewLogs() async {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true

        let logPath = URL.documentsDirectory.appendingPathComponent("idevice_log.txt").path
        let previousCount = lastProcessedLineCount

        guard FileManager.default.fileExists(atPath: logPath) else {
            isLoadingLogs = false
            return
        }

        // Parse new lines on a background thread
        let result: ([LogManager.LogEntry], Int)? = await Task.detached(priority: .userInitiated) {
            do {
                let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
                let lines = logContent.components(separatedBy: .newlines)

                guard lines.count > previousCount else { return ([], lines.count) }

                let newLines = lines[previousCount..<lines.count]
                var parsed: [LogManager.LogEntry] = []
                parsed.reserveCapacity(newLines.count)

                for line in newLines {
                    if line.isEmpty { continue }

                    let type: LogManager.LogEntry.LogType
                    if line.contains("ERROR") || line.contains("Error") {
                        type = .error
                    } else if line.contains("WARNING") || line.contains("Warning") {
                        type = .warning
                    } else if line.contains("DEBUG") {
                        type = .debug
                    } else {
                        type = .info
                    }
                    parsed.append(LogManager.LogEntry(timestamp: Date(), type: type, message: line))
                }

                return (parsed, lines.count)
            } catch {
                return nil
            }
        }.value

        await MainActor.run {
            if let (entries, lineCount) = result {
                lastProcessedLineCount = lineCount
                if !entries.isEmpty {
                    logManager.appendLogs(entries, maxTotal: 500)
                    if jitIsAtBottom, let last = logManager.logs.last {
                        jitScrollView?.scrollTo(last.id, anchor: .bottom)
                    }
                }
            } else {
                logManager.addErrorLog("Failed to read new logs")
            }
            isLoadingLogs = false
        }
    }
    
    private func stopLogCheckTimer() {
        logCheckTimer?.invalidate()
        logCheckTimer = nil
    }

    private func toggleSyslogPlayback() {
        if !systemLogStream.isStreaming {
            systemLogStream.start()
        } else {
            systemLogStream.togglePause()
        }
    }

    private func copySyslogToClipboard() {
        let entries = filteredSyslogEntries
        guard !entries.isEmpty else {
            alertTitle = "Export Failed"
            alertMessage = syslogSearchText.isEmpty ? "No syslog entries to copy." : "No matching syslog entries to copy."
            isError = true
            showingCustomAlert = true
            return
        }

        let content = entries.map { entry in
            "[\(DateFormatter.consoleLogsFormatter.string(from: entry.timestamp))] \(entry.raw)"
        }.joined(separator: "\n")

        UIPasteboard.general.string = content
        alertTitle = "Logs Copied"
        alertMessage = syslogSearchText.isEmpty
            ? "Latest syslog entries copied to clipboard."
            : "\(entries.count) filtered syslog entries copied to clipboard."
        isError = false
        showingCustomAlert = true
    }

    private var syslogControlIcon: String {
        if !systemLogStream.isStreaming || systemLogStream.isPaused {
            return "play.fill"
        }
        return "pause.fill"
    }

    private var syslogControlLabel: String {
        if !systemLogStream.isStreaming {
            return "Start syslog relay"
        }
        return systemLogStream.isPaused ? "Resume syslog stream" : "Pause syslog stream"
    }

}


struct ConsoleLogsView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleLogsView()
    }
}

private enum ConsoleTab: Hashable {
    case idevice
    case syslog
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension DateFormatter {
    static let consoleLogsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
