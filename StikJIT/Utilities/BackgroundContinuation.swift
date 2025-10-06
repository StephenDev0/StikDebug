import Foundation
import OSLog

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Represents an active continued-processing request so the caller can close it explicitly.
struct BackgroundContinuationToken: Hashable {
    fileprivate let id = UUID()
}

enum BackgroundContinuation {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.stik.StikJIT", category: "Background")

    static func setup() {
        #if canImport(BackgroundTasks)
        if #available(iOS 26.0, *) {
            BGContinuationController.shared.setup()
        }
        #endif
    }

    @discardableResult
    static func begin(title: String, subtitle: String) -> BackgroundContinuationToken? {
        #if canImport(BackgroundTasks)
        if #available(iOS 26.0, *) {
            return BGContinuationController.shared.begin(title: title, subtitle: subtitle)
        }
        #endif
        logger.debug("BGContinuedProcessingTask unavailable on this OS")
        return nil
    }

    static func end(success: Bool, token: BackgroundContinuationToken?) {
        guard let token else { return }
        #if canImport(BackgroundTasks)
        if #available(iOS 26.0, *) {
            BGContinuationController.shared.end(success: success, token: token)
            return
        }
        #endif
        logger.debug("No continued-processing task to finish")
    }

    static var isAvailable: Bool {
        #if canImport(BackgroundTasks)
        if #available(iOS 26.0, *) {
            return BGContinuationController.shared.isConfigured
        }
        #endif
        return false
    }
}

#if canImport(BackgroundTasks)
@available(iOS 26.0, *)
private final class BGContinuationController {
    static let shared = BGContinuationController()

    private let scheduler = BGTaskScheduler.shared
    private let taskIdentifier: String
    private var registered = false
    private var pendingToken: BackgroundContinuationToken?
    private var activeToken: BackgroundContinuationToken?
    private var activeTask: BGContinuedProcessingTask?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.stik.StikJIT", category: "Background")

    private init() {
        let baseIdentifier = Bundle.main.bundleIdentifier ?? "com.stik.StikJIT"
        taskIdentifier = baseIdentifier + ".continuedProcessing"
    }

    var isConfigured: Bool { registered }

    func setup() {
        guard !registered else { return }
        registered = scheduler.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            self?.handle(task: task)
        }
        if !registered {
            logger.error("Failed to register continued-processing handler")
            LogManager.shared.addErrorLog("Unable to register continued processing background handler.")
        } else {
            logger.debug("Registered continued-processing handler")
        }
    }

    func begin(title: String, subtitle: String) -> BackgroundContinuationToken? {
        setup()
        guard registered else { return nil }

        let request = BGContinuedProcessingTaskRequest(identifier: taskIdentifier, title: title, subtitle: subtitle)
        request.strategy = .queue

        let token = BackgroundContinuationToken()
        do {
            try scheduler.submit(request)
            pendingToken = token
            logger.info("Submitted continued-processing task request: \(title, privacy: .public)")
            LogManager.shared.addInfoLog("Requested continued processing for \(title)")
            return token
        } catch {
            logger.error("Failed to submit continued-processing task: \(error.localizedDescription, privacy: .public)")
            LogManager.shared.addErrorLog("Unable to request continued processing: \(error.localizedDescription)")
            return nil
        }
    }

    func end(success: Bool, token: BackgroundContinuationToken) {
        if pendingToken == token {
            scheduler.cancel(taskRequestWithIdentifier: taskIdentifier)
            pendingToken = nil
        }

        if activeToken == token {
            activeTask?.setTaskCompleted(success: success)
            activeTask = nil
            activeToken = nil
            logger.info("Marked continued-processing task as completed: success=\(success)")
            LogManager.shared.addInfoLog(success ? "Background continued processing finished." : "Background continued processing ended early.")
        }
    }

    private func handle(task: BGTask) {
        guard let continuedTask = task as? BGContinuedProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }

        activeTask = continuedTask
        activeToken = pendingToken
        pendingToken = nil

        continuedTask.expirationHandler = { [weak self] in
            guard let self else { return }
            self.logger.warning("Continued-processing task expired")
            self.activeTask?.setTaskCompleted(success: false)
            self.activeTask = nil
            if let activeToken {
                LogManager.shared.addWarningLog("Background continued processing expired before completion.")
            }
            self.activeToken = nil
        }
    }
}
#endif
