//
//  PairingLocalNetworkAuthorization.swift
//  StikDebug
//

import Foundation
import Network

@MainActor
final class PairingLocalNetworkAuthorization {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?

    private let probeType = "_stikdebugpair._tcp"

    func request(timeout: TimeInterval = 60) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            guard let listener = try? NWListener(using: params) else {
                finish(false)
                return
            }

            listener.service = NWListener.Service(name: "StikDebugPairProbe", type: probeType)
            listener.newConnectionHandler = { $0.cancel() }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated {
                        self?.finish(false)
                    }
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated {
                        self?.finish(false)
                    }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard !results.isEmpty else { return }
                MainActor.assumeIsolated {
                    self?.finish(true)
                }
            }
            self.browser = browser

            listener.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated {
                    self?.finish(false)
                }
            }
        }
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
    }
}
