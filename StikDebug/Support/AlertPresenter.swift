//
//  AlertPresenter.swift
//  StikDebug
//

import UIKit

enum AlertPresenter {
    static func show(
        title: String,
        message: String,
        showOk: Bool,
        showTryAgain: Bool = false,
        primaryButtonText: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            guard let rootViewController = UIApplication.shared.activeRootViewController else {
                return
            }

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            if showTryAgain {
                alert.addAction(UIAlertAction(title: primaryButtonText ?? "Try Again", style: .default) { _ in
                    completion?(true)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completion?(false)
                })
            } else if showOk {
                alert.addAction(UIAlertAction(title: primaryButtonText ?? "OK", style: .default) { _ in
                    completion?(true)
                })
            } else {
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completion?(true)
                })
            }

            UIApplication.shared.topViewController(from: rootViewController)?.present(alert, animated: true)
        }
    }

    static func dismissPresentedAlert() {
        DispatchQueue.main.async {
            guard let rootViewController = UIApplication.shared.activeRootViewController,
                  let topController = UIApplication.shared.topViewController(from: rootViewController),
                  topController is UIAlertController else {
                return
            }
            topController.dismiss(animated: true)
        }
    }
}

public func showAlert(
    title: String,
    message: String,
    showOk: Bool,
    showTryAgain: Bool = false,
    primaryButtonText: String? = nil,
    completion: ((Bool) -> Void)? = nil
) {
    AlertPresenter.show(
        title: title,
        message: message,
        showOk: showOk,
        showTryAgain: showTryAgain,
        primaryButtonText: primaryButtonText,
        completion: completion
    )
}

private extension UIApplication {
    var activeRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    func topViewController(from rootViewController: UIViewController) -> UIViewController? {
        var topController: UIViewController? = rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
