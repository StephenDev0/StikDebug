//
//  BackgroundLocationManager.swift
//  StikDebug
//

import CoreLocation

final class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationManager()

    private let locationManager = CLLocationManager()
    private var isRunning = false
    private var activityCount = 0
    private var forcedActivityCount = 0

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = CLLocationDistanceMax
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        isRunning = true
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func stop() {
        isRunning = false
        locationManager.stopUpdatingLocation()
    }

    func requestStart(force: Bool = false) {
        if force {
            forcedActivityCount += 1
        } else {
            activityCount += 1
        }
        refreshRunningState()
    }

    func requestStop(force: Bool = false) {
        if force {
            forcedActivityCount = max(forcedActivityCount - 1, 0)
        } else {
            activityCount = max(activityCount - 1, 0)
        }
        refreshRunningState()
    }

    private func refreshRunningState() {
        let shouldRun = forcedActivityCount > 0
            || (activityCount > 0 && UserDefaults.standard.bool(forKey: "keepAliveLocation"))

        if shouldRun, !isRunning {
            start()
        } else if !shouldRun, isRunning {
            stop()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRunning else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location fixes may fail (e.g. no GPS indoors) — that's fine.
        // The manager just needs to be running, not actually fix a location.
    }
}
