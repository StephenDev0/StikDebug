//
//  CoordinateConverter.swift
//  StikDebug
//

import CoreLocation

/// WGS‑84 ↔ GCJ‑02 (Mars coordinate) bi‑directional conversion.
///
/// MapKit in mainland China renders on GCJ‑02 tiles provided by Amap
/// (高德).  Points picked on the map are therefore in GCJ‑02, but
/// `simulate_location()` always treats its input as WGS‑84.  This utility
/// converts GCJ‑02 back to WGS‑84 before simulation so the simulated
/// location lands on the correct spot on all map providers.
enum CoordinateConverter {

    // MARK: - Constants (from the public domain GCJ‑02 algorithm)

    private static let a = 6378245.0  // semi‑major axis
    private static let ee = 0.00669342162296594323 // eccentricity squared

    // MARK: - Public API

    /// WGS‑84 → GCJ‑02 (forward).
    static func wgs84ToGCJ02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let (lat, lon) = transform(coordinate.latitude, coordinate.longitude, delta: 1)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// GCJ‑02 → WGS‑84 (inverse, via fixed‑point iteration).
    static func gcj02ToWGS84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // 1st pass
        let d1 = delta(lat, lon)
        var wgsLat = lat - d1.lat
        var wgsLon = lon - d1.lon

        // 2nd pass (refined)
        let d2 = delta(wgsLat, wgsLon)
        wgsLat = lat - d2.lat
        wgsLon = lon - d2.lon

        return CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLon)
    }

    // MARK: - Private helpers

    private static func transform(_ lat: Double, _ lon: Double, delta: Int) -> (Double, Double) {
        let d = self.delta(lat, lon)
        return (lat + Double(delta) * d.lat, lon + Double(delta) * d.lon)
    }

    private static func delta(_ lat: Double, _ lon: Double) -> (lat: Double, lon: Double) {
        var dLat = 0.0, dLon = 0.0

        if isOutOfChina(lat, lon) {
            return (dLat, dLon)
        }

        dLat = transformLat(lon - 105.0, lat - 35.0)
        dLon = transformLon(lon - 105.0, lat - 35.0)
        let radLat = lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (dLat, dLon)
    }

    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y
            + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x
            + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }

    /// Rough bounding‑box check — avoids unnecessary iteration for
    /// coordinates clearly outside mainland China.
    private static func isOutOfChina(_ lat: Double, _ lon: Double) -> Bool {
        // Hong Kong, Macau, and Taiwan are excluded because their
        // MapKit tiles are *not* GCJ‑02.
        if lat < 0.8293 || lat > 55.8271 || lon < 72.004 || lon > 137.8347 {
            return true
        }
        // Exclude Hong Kong
        if lat >= 22.15 && lat <= 22.58 && lon >= 113.82 && lon <= 114.42 {
            return true
        }
        // Exclude Macau
        if lat >= 22.06 && lat <= 22.22 && lon >= 113.52 && lon <= 113.62 {
            return true
        }
        // Exclude Taiwan
        if lat >= 21.9 && lat <= 25.4 && lon >= 120.0 && lon <= 122.1 {
            return true
        }
        return false
    }
}
