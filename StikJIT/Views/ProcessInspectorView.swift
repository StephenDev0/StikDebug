//
//  ProcessInspectorView.swift
//  StikJIT
//
//  Created by Stephen on 11/3/25.
//

import SwiftUI

struct ProcessInspectorView: View {
    @StateObject private var viewModel = ProcessInspectorViewModel()
    @State private var killCandidate: ProcessInfoEntry?
    @State private var killConfirmTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Process Inspector")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.refresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isRefreshing)
                    }
                }
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
        .task {
            await viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .alert(viewModel.killAlertTitle, isPresented: $viewModel.showKillAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.killAlertMessage)
        }
        .alert(viewModel.errorAlertTitle, isPresented: $viewModel.showErrorAlert) {
            Button("Try Again") { viewModel.refresh() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorAlertMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            Section("Overview") {
                LabeledContent("Total Processes") {
                    Text("\(viewModel.processes.count)")
                        .font(.title2.bold())
                }
            }
            Section("Processes") {
                if viewModel.filteredProcesses.isEmpty {
                    Text("No matching processes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.filteredProcesses) { process in
                        ProcessRow(
                            process: process,
                            isKilling: viewModel.killingPID == process.pid,
                            isConfirming: killCandidate?.pid == process.pid,
                            onKillTap: { handleKillTap(for: $0) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { viewModel.refresh() }
    }
}

private extension ProcessInspectorView {
    func handleKillTap(for process: ProcessInfoEntry) {
        if killCandidate?.pid == process.pid {
            killConfirmTask?.cancel()
            killConfirmTask = nil
            killCandidate = nil
            viewModel.kill(process: process)
        } else {
            killCandidate = process
            killConfirmTask?.cancel()
            killConfirmTask = Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if killCandidate?.pid == process.pid {
                        killCandidate = nil
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct ProcessRow: View {
    let process: ProcessInfoEntry
    let isKilling: Bool
    let isConfirming: Bool
    let onKillTap: (ProcessInfoEntry) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(process.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("PID \(process.pid)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let bundle = process.bundleID, !bundle.isEmpty {
                Text(bundle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text(process.executablePath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Spacer()
                if isKilling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                } else {
                    Button {
                        onKillTap(process)
                    } label: {
                        if isConfirming {
                            Label("Confirm", systemImage: "checkmark.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        } else {
                            Image(systemName: "xmark.circle")
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(isConfirming ? .green : .red)
                    .labelStyle(.iconOnly)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
final class ProcessInspectorViewModel: ObservableObject {
    @Published private(set) var processes: [ProcessInfoEntry] = []
    @Published var searchText: String = ""
    @Published var isRefreshing = false
    @Published var showErrorAlert = false
    @Published var errorAlertTitle = ""
    @Published var errorAlertMessage = ""
    @Published private(set) var killingPID: Int?
    @Published var showKillAlert = false
    @Published var killAlertTitle = ""
    @Published var killAlertMessage = ""
    
    private var refreshTask: Task<Void, Never>?
    private var killTimeoutTask: Task<Void, Never>?
    @Published private(set) var lastUpdated: Date?
    var filteredProcesses: [ProcessInfoEntry] {
        guard !searchText.isEmpty else { return processes }
        return processes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.executablePath.localizedCaseInsensitiveContains(searchText) ||
            "\($0.pid)".contains(searchText)
        }
    }
    
    var lastUpdatedText: String {
        guard let date = lastUpdated else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func startAutoRefresh() async {
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self else { break }
                await MainActor.run {
                    self.refresh()
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        killTimeoutTask?.cancel()
        killTimeoutTask = nil
    }
    
    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) { [weak self] in
            var err: NSError?
            let entries = FetchDeviceProcessList(&err) ?? []
            await MainActor.run {
                guard let self else { return }
                if let err {
                    self.errorAlertTitle = "Failed to Load Processes"
                    self.errorAlertMessage = err.localizedDescription
                    self.showErrorAlert = true
                } else {
                    self.processes = entries.compactMap { item -> ProcessInfoEntry? in
                        guard let dict = item as? NSDictionary else { return nil }
                        return ProcessInfoEntry(dictionary: dict)
                    }
                    self.lastUpdated = Date()
                }
                self.isRefreshing = false
            }
        }
    }
    
    func kill(process: ProcessInfoEntry) {
        guard killingPID == nil else {
            killAlertTitle = "Busy"
            killAlertMessage = "Already terminating PID \(killingPID!)."
            showKillAlert = true
            return
        }
        let targetPID = process.pid
        killingPID = targetPID
        killTimeoutTask?.cancel()
        killTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                guard let self else { return }
                if self.killingPID == targetPID {
                    self.killingPID = nil
                    self.killAlertTitle = "Kill Timed Out"
                    self.killAlertMessage = "Could not confirm termination for PID \(targetPID). Try again."
                    self.showKillAlert = true
                }
            }
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            var err: NSError?
            let success = KillDeviceProcess(Int32(targetPID), &err)
            await MainActor.run {
                guard let self else { return }
                self.killTimeoutTask?.cancel()
                self.killTimeoutTask = nil
                guard self.killingPID == targetPID else { return }
                self.killingPID = nil
                if success {
                    self.killAlertTitle = "Process Terminated"
                    self.killAlertMessage = "PID \(targetPID) was terminated."
                    self.showKillAlert = true
                    self.refresh()
                } else {
                    self.killAlertTitle = "Kill Failed"
                    self.killAlertMessage = err?.localizedDescription ?? "Unknown error"
                    self.showKillAlert = true
                }
            }
        }
    }
    
}

struct ProcessInfoEntry: Identifiable {
    let pid: Int
    private let rawPath: String
    let bundleID: String?
    let name: String?
    
    init?(dictionary: NSDictionary) {
        guard let pidNumber = dictionary["pid"] as? NSNumber else { return nil }
        pid = pidNumber.intValue
        rawPath = dictionary["path"] as? String ?? "Unknown"
        bundleID = dictionary["bundleID"] as? String
        name = dictionary["name"] as? String
    }
    
    var id: Int { pid }
    
    var executablePath: String {
        rawPath.replacingOccurrences(of: "file://", with: "")
    }
    
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let bundle = bundleID, !bundle.isEmpty {
            return bundle
        }
        let cleaned = executablePath
        if let component = cleaned.split(separator: "/").last {
            return String(component)
        }
        return "Process \(pid)"
    }
}
