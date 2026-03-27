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

// MARK: - Bookmark Model

struct LocationBookmark: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Search Completer

@MainActor
final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.results = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
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
    @State private var routeProgressTimer: Timer?
    @State private var isBusy = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var searchText = ""
    @StateObject private var searchCompleter = LocationSearchCompleter()

    // Bookmarks
    @State private var bookmarks: [LocationBookmark] = []
    @State private var showBookmarks = false
    @State private var showSaveBookmark = false
    @State private var newBookmarkName = ""
    @State private var isDrawingPath = false
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeDurationMinutes: Double = 5

    private let routeUpdateInterval: TimeInterval = 2

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

                    if routeCoordinates.count > 1 {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(.blue, lineWidth: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { point in
                    if let loc = proxy.convert(point, from: .local) {
                        if isDrawingPath {
                            routeCoordinates.append(loc)
                            coordinate = loc
                        } else {
                            coordinate = loc
                        }
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

            VStack(spacing: 0) {
                if !searchCompleter.results.isEmpty {
                    if #available(iOS 26, *) {
                        List(searchCompleter.results.prefix(5), id: \.self) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 350)
                        .scrollDisabled(true)
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    } else {
                        List(searchCompleter.results.prefix(5), id: \.self) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 350)
                        .scrollDisabled(true)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 12) {
                    if let coord = coordinate {
                        Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)

                        if routeCoordinates.count > 1 {
                            HStack(spacing: 8) {
                                Text("Route duration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Stepper(value: $routeDurationMinutes, in: 1...180, step: 1) {
                                    Text("\(Int(routeDurationMinutes)) min")
                                        .font(.caption.monospaced())
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button("Stop", action: clear)
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(!pairingExists || isBusy)

                            Button("Simulate Location", action: simulate)
                                .buttonStyle(.borderedProminent)
                                .disabled(!pairingExists || isBusy)

                            Button {
                                isDrawingPath.toggle()
                                if !isDrawingPath {
                                    if let coord = coordinate, routeCoordinates.isEmpty {
                                        routeCoordinates = [coord]
                                    }
                                } else {
                                    stopRouteLoop()
                                }
                            } label: {
                                Image(systemName: isDrawingPath ? "pencil.circle.fill" : "pencil.circle")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)

                            if routeCoordinates.count > 1 {
                                Button("Run Path", action: simulateRoute)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .disabled(!pairingExists || isBusy)
                            }

                            Button {
                                showSaveBookmark = true
                            } label: {
                                Image(systemName: "bookmark")
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)

                            if !routeCoordinates.isEmpty {
                                Button {
                                    stopRouteLoop()
                                    routeCoordinates.removeAll()
                                    if isDrawingPath {
                                        isDrawingPath = false
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: "bookmark.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                TextField("Search location...", text: $searchText)
                    .padding(.leading, 6)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newValue in
                        searchCompleter.update(query: newValue)
                    }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Save Bookmark", isPresented: $showSaveBookmark) {
            TextField("Name", text: $newBookmarkName)
            Button("Save") { addBookmark() }
            Button("Cancel", role: .cancel) { newBookmarkName = "" }
        } message: {
            Text("Enter a name for this location.")
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(bookmarks: $bookmarks) { bookmark in
                coordinate = bookmark.coordinate
                showBookmarks = false
            } onDelete: { offsets in
                bookmarks.remove(atOffsets: offsets)
                saveBookmarks()
            }
        }
        .onAppear {
            loadBookmarks()
        }
        .onDisappear {
            stopResendLoop()
            stopRouteLoop()
            if backgroundTaskID != .invalid {
                BackgroundLocationManager.shared.requestStop()
            }
            endBackgroundTask()
        }
    }

    // MARK: - Bookmarks

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: "locationBookmarks"),
              let decoded = try? JSONDecoder().decode([LocationBookmark].self, from: data) else { return }
        bookmarks = decoded
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: "locationBookmarks")
        }
    }

    private func addBookmark() {
        guard let coord = coordinate else { return }
        let name = newBookmarkName.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookmark = LocationBookmark(
            name: name.isEmpty ? String(format: "%.4f, %.4f", coord.latitude, coord.longitude) : name,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        bookmarks.append(bookmark)
        saveBookmarks()
        newBookmarkName = ""
    }

    // MARK: - Location

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        searchText = ""
        searchCompleter.results = []

        let request = MKLocalSearch.Request(completion: result)
        MKLocalSearch(request: request).start { response, _ in
            if let item = response?.mapItems.first {
                coordinate = item.placemark.coordinate
            }
        }
    }

    private func simulate() {
        guard pairingExists, let coord = coordinate, !isBusy else { return }
        stopRouteLoop()
        routeCoordinates.removeAll()
        isDrawingPath = false
        isBusy = true
        let ip = deviceIP
        let path = pairingFilePath
        let lat = coord.latitude
        let lon = coord.longitude
        Self.locationQueue.async {
            let code = Self.sendSimulatedLocation(ip: ip, latitude: lat, longitude: lon, pairingPath: path)
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    beginBackgroundTask()
                    startResendLoop()
                    BackgroundLocationManager.shared.requestStart()
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
        stopRouteLoop()
        Self.locationQueue.async {
            let code = clear_simulated_location()
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    coordinate = nil
                    endBackgroundTask()
                    BackgroundLocationManager.shared.requestStop()
                } else {
                    alertTitle = "Clear Failed"
                    alertMessage = "Could not clear simulated location (error \(code))."
                    showAlert = true
                }
            }
        }
    }

    private func simulateRoute() {
        guard pairingExists, !isBusy, routeCoordinates.count > 1 else { return }
        stopResendLoop()
        stopRouteLoop()
        isDrawingPath = false
        isBusy = true

        let totalDuration = routeDurationMinutes * 60
        let pathCoordinates = routeCoordinates
        let ip = deviceIP
        let path = pairingFilePath
        let start = pathCoordinates[0]

        Self.locationQueue.async {
            let code = Self.sendSimulatedLocation(ip: ip, latitude: start.latitude, longitude: start.longitude, pairingPath: path)
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    coordinate = start
                    beginBackgroundTask()
                    BackgroundLocationManager.shared.requestStart()
                    startRouteLoop(pathCoordinates: pathCoordinates, totalDuration: totalDuration)
                } else {
                    alertTitle = "Simulation Failed"
                    alertMessage = "Could not start path simulation (error \(code)). Make sure the device is connected and the DDI is mounted."
                    showAlert = true
                }
            }
        }
    }

    private func startRouteLoop(pathCoordinates: [CLLocationCoordinate2D], totalDuration: TimeInterval) {
        let duration = max(totalDuration, routeUpdateInterval)
        let startDate = Date()
        routeProgressTimer?.invalidate()
        routeProgressTimer = Timer.scheduledTimer(withTimeInterval: routeUpdateInterval, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startDate)
            let progress = min(elapsed / duration, 1)
            let next = interpolatePathCoordinate(pathCoordinates, progress: progress)
            coordinate = next

            let ip = deviceIP
            let path = pairingFilePath
            Self.locationQueue.async {
                _ = Self.sendSimulatedLocation(ip: ip,
                                               latitude: next.latitude,
                                               longitude: next.longitude,
                                               pairingPath: path)
            }

            if progress >= 1 {
                timer.invalidate()
                routeProgressTimer = nil
                startResendLoop()
            }
        }
    }

    private func stopRouteLoop() {
        routeProgressTimer?.invalidate()
        routeProgressTimer = nil
    }

    private func interpolatePathCoordinate(_ points: [CLLocationCoordinate2D], progress: Double) -> CLLocationCoordinate2D {
        guard points.count > 1 else { return points.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0) }

        let totalDistance = zip(points, points.dropFirst())
            .map { CLLocation(latitude: $0.0.latitude, longitude: $0.0.longitude)
                .distance(from: CLLocation(latitude: $0.1.latitude, longitude: $0.1.longitude)) }
            .reduce(0, +)

        if totalDistance <= 0 {
            return points.last!
        }

        let targetDistance = totalDistance * progress
        var traveled: CLLocationDistance = 0

        for (start, end) in zip(points, points.dropFirst()) {
            let segmentDistance = CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
            if traveled + segmentDistance >= targetDistance {
                let segmentProgress = segmentDistance > 0 ? (targetDistance - traveled) / segmentDistance : 0
                let lat = start.latitude + (end.latitude - start.latitude) * segmentProgress
                let lon = start.longitude + (end.longitude - start.longitude) * segmentProgress
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            traveled += segmentDistance
        }

        return points.last!
    }

    private static func sendSimulatedLocation(ip: String, latitude: Double, longitude: Double, pairingPath: String) -> Int32 {
        simulate_location(ip, latitude, longitude, pairingPath)
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
                _ = Self.sendSimulatedLocation(ip: ip, latitude: lat, longitude: lon, pairingPath: path)
            }
        }
    }

    private func stopResendLoop() {
        resendTimer?.invalidate()
        resendTimer = nil
    }
}

// MARK: - Bookmarks Sheet

struct BookmarksView: View {
    @Binding var bookmarks: [LocationBookmark]
    let onSelect: (LocationBookmark) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark.slash",
                        description: Text("Drop a pin on the map and tap the bookmark icon to save a location.")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                onSelect(bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.name)
                                        .foregroundStyle(.primary)
                                    Text(String(format: "%.6f, %.6f", bookmark.latitude, bookmark.longitude))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: onDelete)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !bookmarks.isEmpty {
                    EditButton()
                }
            }
        }
    }
}
