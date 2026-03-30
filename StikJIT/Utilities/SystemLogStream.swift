//
//  SystemLogStream.swift
//  StikJIT
//
//  Created by Stephen on 09/21/2025.
//

import Foundation

@MainActor
final class SystemLogStream: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let raw: String
    }

    @Published private(set) var entries: [Entry] = []
    @Published var lastError: String? = nil
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published var updateInterval: TimeInterval = 0 {
        didSet {
            if updateInterval < 0 { updateInterval = 0 }
            flushTimer?.invalidate()
            flushTimer = nil
            if !isPaused && !pendingEntries.isEmpty {
                if updateInterval == 0 {
                    flushAllPending()
                } else {
                    scheduleFlushIfNeeded()
                }
            }
        }
    }

    private let maxEntries = 1500
    private var pendingEntries: [Entry] = []
    private var flushTimer: Timer?
    private var retryTimer: Timer?
    private var batchTimer: Timer?
    private static let batchInterval: TimeInterval = 0.1

    func start() {
        retryTimer?.invalidate()
        retryTimer = nil
        guard !isStreaming else {
            if isPaused { resume() }
            return
        }
        isStreaming = true
        isPaused = false
        lastError = nil
        startBatchTimer()

        JITEnableContext.shared.startSyslogRelay(handler: { [weak self] line in
            Task { @MainActor [weak self] in
                self?.handleLine(line)
            }
        }, onError: { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleError(error)
            }
        })
    }

    func stop() {
        guard isStreaming else { return }
        isStreaming = false
        isPaused = false
        JITEnableContext.shared.stopSyslogRelay()
        flushTimer?.invalidate()
        flushTimer = nil
        batchTimer?.invalidate()
        batchTimer = nil
        pendingEntries.removeAll()
        retryTimer?.invalidate()
        retryTimer = nil
    }

    func clear() {
        entries.removeAll()
        pendingEntries.removeAll()
        flushTimer?.invalidate()
        flushTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        flushTimer?.invalidate()
        flushTimer = nil
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        if updateInterval == 0 {
            flushAllPending()
        } else {
            scheduleFlushIfNeeded()
        }
    }

    private func handleLine(_ line: String) {
        guard isStreaming else { return }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = Entry(timestamp: Date(), message: prettify(line: trimmed), raw: trimmed)
        pendingEntries.append(entry)
        if pendingEntries.count > maxEntries {
            pendingEntries.removeFirst(pendingEntries.count - maxEntries)
        }
        // Batching is handled by batchTimer / scheduleFlushIfNeeded
        if updateInterval > 0 {
            scheduleFlushIfNeeded()
        }
    }

    private func handleError(_ error: NSError?) {
        isStreaming = false
        isPaused = false
        flushTimer?.invalidate()
        flushTimer = nil
        batchTimer?.invalidate()
        batchTimer = nil
        lastError = error?.localizedDescription ?? "System log stream stopped"
        scheduleAutoRetry()
    }

    private func startBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: Self.batchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isPaused, self.updateInterval == 0, !self.pendingEntries.isEmpty else { return }
                self.flushAllPending()
            }
        }
        if let batchTimer {
            RunLoop.main.add(batchTimer, forMode: .common)
        }
    }

    private func flushAllPending() {
        guard !pendingEntries.isEmpty else { return }
        entries.append(contentsOf: pendingEntries)
        pendingEntries.removeAll()
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    private func prettify(line: String) -> String {
        if let range = line.range(of: ": ") {
            let messagePart = line[range.upperBound...]
            return String(messagePart)
        }
        return line
    }

    func concatenatedLog(limit: Int = 500) -> String {
        let slice = entries.suffix(limit)
        return slice.map { "[\(DateFormatter.consoleFormatter.string(from: $0.timestamp))] \($0.raw)" }
            .joined(separator: "\n")
    }

    private func scheduleFlushIfNeeded() {
        guard !isPaused else { return }
        guard !pendingEntries.isEmpty else { return }
        guard flushTimer == nil else { return }
        guard updateInterval > 0 else {
            // Live mode uses batchTimer instead
            return
        }

        flushTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.flushTimer = nil
                guard !self.isPaused else { return }
                self.flushAllPending()
                if !self.pendingEntries.isEmpty {
                    self.scheduleFlushIfNeeded()
                }
            }
        }

        if let flushTimer {
            RunLoop.main.add(flushTimer, forMode: .common)
        }
    }

    private func scheduleAutoRetry() {
        guard !isStreaming else { return }
        guard retryTimer == nil else { return }
        let timer = Timer(timeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.retryTimer = nil
                if !self.isStreaming && !self.isPaused {
                    self.start()
                }
            }
        }
        retryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

private extension DateFormatter {
    static let consoleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
