//
//  BackgroundAudioManager.swift
//  StikJIT
//

import AVFoundation

final class BackgroundAudioManager {
    static let shared = BackgroundAudioManager()

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var isRunning = false
    private var persistentEnabled = false
    private var activityCount = 0
    private var healthCheckTimer: Timer?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    func start() {
        persistentEnabled = true
        refreshRunningState()
    }

    func stop() {
        persistentEnabled = false
        refreshRunningState()
    }

    func requestStart() {
        activityCount += 1
        refreshRunningState()
    }

    func requestStop() {
        activityCount = max(activityCount - 1, 0)
        refreshRunningState()
    }

    private func refreshRunningState() {
        let shouldRun = persistentEnabled || (activityCount > 0 && UserDefaults.standard.bool(forKey: "keepAliveAudio"))
        guard shouldRun != isRunning else {
            if shouldRun {
                recoverIfNeeded()
            }
            return
        }

        isRunning = shouldRun
        if shouldRun {
            startEngine()
            startHealthCheck()
        } else {
            healthCheckTimer?.invalidate()
            healthCheckTimer = nil
            player.stop()
            engine.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func startEngine() {
        do {
            engine.stop()
            player.stop()
            engine = AVAudioEngine()
            player = AVAudioPlayerNode()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)

            engine.attach(player)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            scheduleSilence()
            try engine.start()
            player.play()
        } catch {
            LogManager.shared.addErrorLog("BackgroundAudioManager: \(error.localizedDescription)")
        }
    }

    private func scheduleSilence() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        // PCM buffer is zero-initialized — pure silence
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    // Runs every 2 seconds to reclaim the session if continuous game audio
    // holds it and the interruption-ended notification never fires.
    private func startHealthCheck() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.recoverIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
    }

    private func recoverIfNeeded() {
        guard isRunning, !engine.isRunning || !player.isPlaying else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try engine.start()
            }
            player.play()
        } catch {
            // Session still held by the game — will retry next tick
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .ended,
              isRunning else { return }

        // Best-effort immediate resume; health check will cover failures.
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    @objc private func handleMediaServicesReset() {
        guard isRunning else { return }
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        startEngine()
    }
}
