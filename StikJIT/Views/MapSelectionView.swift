//
//  MapSelectionView.swift
//  StikJIT
//
//  Created by Stephen on 11/3/25.
//

import SwiftUI
import MapKit
import UIKit

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct LocationSimulationView: View {
    // Serial queue: simulate_location and clear_simulated_location share C global
    // state — serialising all calls eliminates the use-after-free race.
    private static let locationQueue = DispatchQueue(label: "com.stik.location-sim",
                                                    qos: .userInitiated)

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var resendTimer: Timer?
    @State private var isBusy = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var pairingFilePath: String {
        URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path()
    }

    private var pairingExists: Bool {
        FileManager.default.fileExists(atPath: pairingFilePath)
    }

    private var deviceIP: String {
        let stored = UserDefaults.standard.string(forKey: "customTargetIP") ?? ""
        return stored.isEmpty ? "10.7.0.1" : stored
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $position) {
                    if let coordinate {
                        Marker("Pin", coordinate: coordinate)
                            .tint(.red)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { point in
                    if let loc = proxy.convert(point, from: .local) {
                        coordinate = loc
                    }
                }
                .mapControls {
                    MapCompass()
                }
            }
            .ignoresSafeArea()
            .onChange(of: coordinate) { _, new in
                if let new {
                    position = .region(MKCoordinateRegion(center: new, latitudinalMeters: 1000, longitudinalMeters: 1000))
                }
            }

            VStack(spacing: 12) {
                if let coord = coordinate {
                    Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Stop", action: clear)
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(!pairingExists || isBusy)

                        Button("Simulate Location", action: simulate)
                            .buttonStyle(.borderedProminent)
                            .disabled(!pairingExists || isBusy)
                    }
                } else {
                    Text("Tap map to drop pin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)
            .padding(.horizontal, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            stopResendLoop()
            endBackgroundTask()
        }
    }

    private func simulate() {
        guard pairingExists, let coord = coordinate, !isBusy else { return }
        isBusy = true
        let ip = deviceIP
        let path = pairingFilePath
        let lat = coord.latitude
        let lon = coord.longitude
        Self.locationQueue.async {
            let code = simulate_location(ip, lat, lon, path)
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    beginBackgroundTask()
                    startResendLoop()
                } else {
                    alertTitle = "Simulation Failed"
                    alertMessage = "Could not simulate location (error \(code)). Make sure the device is connected and the DDI is mounted."
                    showAlert = true
                }
            }
        }
    }

    private func clear() {
        guard pairingExists, !isBusy else { return }
        isBusy = true
        stopResendLoop()
        Self.locationQueue.async {
            let code = clear_simulated_location()
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    coordinate = nil
                    endBackgroundTask()
                } else {
                    alertTitle = "Clear Failed"
                    alertMessage = "Could not clear simulated location (error \(code))."
                    showAlert = true
                }
            }
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { endBackgroundTask() }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func startResendLoop() {
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            guard let coord = coordinate else { return }
            let ip = deviceIP
            let path = pairingFilePath
            let lat = coord.latitude
            let lon = coord.longitude
            Self.locationQueue.async {
                _ = simulate_location(ip, lat, lon, path)
            }
        }
    }

    private func stopResendLoop() {
        resendTimer?.invalidate()
        resendTimer = nil
    }
}
