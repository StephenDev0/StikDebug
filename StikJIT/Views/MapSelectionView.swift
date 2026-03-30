//
//  MapSelectionView.swift
//  StikJIT
//
//  Created by Stephen on 11/3/25.
//

import SwiftUI
import MapKit
import UIKit

private struct CoordinateSnapshot: Equatable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    // Serial queue: the location simulation helpers share process-wide state, so
    // serialising all calls avoids handle lifetime races.
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

    @State private var searchText = ""
    @StateObject private var searchCompleter = LocationSearchCompleter()

    // Bookmarks
    @State private var bookmarks: [LocationBookmark] = []
    @State private var showBookmarks = false
    @State private var showSaveBookmark = false
    @State private var newBookmarkName = ""

    private var pairingFilePath: String {
        PairingFileStore.prepareURL().path()
    }

    private var pairingExists: Bool {
        FileManager.default.fileExists(atPath: pairingFilePath)
    }

    private var deviceIP: String {
        let stored = UserDefaults.standard.string(forKey: "customTargetIP") ?? ""
        return stored.isEmpty ? "10.7.0.1" : stored
    }

    private var searchResultsListBase: some View {
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

    @ViewBuilder
    private var searchResultsList: some View {
        if #available(iOS 26, *) {
            searchResultsListBase
                .glassEffect(in: .rect(cornerRadius: 12))
        } else {
            searchResultsListBase
        }
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
                .onChange(of: coordinate.map(CoordinateSnapshot.init)) { _, new in
                    if let new {
                        position = .region(
                            MKCoordinateRegion(
                                center: new.coordinate,
                                latitudinalMeters: 1000,
                                longitudinalMeters: 1000
                            )
                        )
                    }
                }

            VStack(spacing: 0) {
                if !searchCompleter.results.isEmpty {
                    searchResultsList
                }

                Spacer()

                // Bottom controls
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

                            Button {
                                showSaveBookmark = true
                            } label: {
                                Image(systemName: "bookmark")
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
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
        let ip = deviceIP
        let path = pairingFilePath
        let lat = coord.latitude
        let lon = coord.longitude
        runLocationCommand(
            errorTitle: "Simulation Failed",
            errorMessage: { code in
                "Could not simulate location (error \(code)). Make sure the device is connected and the DDI is mounted."
            },
            operation: { simulate_location(ip, lat, lon, path) }
        ) {
            beginBackgroundTask()
            startResendLoop()
            BackgroundLocationManager.shared.requestStart()
        }
    }

    private func runLocationCommand(
        errorTitle: String,
        errorMessage: @escaping (Int32) -> String,
        operation: @escaping () -> Int32,
        onSuccess: @escaping () -> Void
    ) {
        isBusy = true
        Self.locationQueue.async {
            let code = operation()
            DispatchQueue.main.async {
                isBusy = false
                if code == 0 {
                    onSuccess()
                } else {
                    alertTitle = errorTitle
                    alertMessage = errorMessage(code)
                    showAlert = true
                }
            }
        }
    }

    private func clear() {
        guard pairingExists, !isBusy else { return }
        stopResendLoop()
        runLocationCommand(
            errorTitle: "Clear Failed",
            errorMessage: { code in "Could not clear simulated location (error \(code))." },
            operation: clear_simulated_location
        ) {
            coordinate = nil
            endBackgroundTask()
            BackgroundLocationManager.shared.requestStop()
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
