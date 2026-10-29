import Foundation

/// WMM 2025-2030 geomagnetic field model, evaluated fully offline.
/// Coefficients and recurrence follow the AOSP GeomagneticField implementation
/// and the NOAA/NCEI WMM2025 coefficient set (epoch 2025.0, valid 2025-2030).
public struct GeomagneticField: Sendable {
    public let north: Double       // nT
    public let east: Double        // nT
    public let down: Double        // nT
    public let declination: Double // degrees; east positive, west negative
    public let inclination: Double // degrees
    public let horizontalStrength: Double // nT
    public let fieldStrength: Double       // nT
}

public final class WorldMagneticModel {
    public static let shared = WorldMagneticModel()

    private static let g: [[Double]] = [[0.0], [-29351.8, -1410.8], [-2556.6, 2951.1, 1649.3], [1361.0, -2404.1, 1243.8, 453.6], [895.0, 799.5, 55.7, -281.1, 12.1], [-233.2, 368.9, 187.2, -138.7, -142.0, 20.9], [64.4, 63.8, 76.9, -115.7, -40.9, 14.9, -60.7], [79.5, -77.0, -8.8, 59.3, 15.8, 2.5, -11.1, 14.2], [23.2, 10.8, -17.5, 2.0, -21.7, 16.9, 15.0, -16.8, 0.9], [4.6, 7.8, 3.0, -0.2, -2.5, -13.1, 2.4, 8.6, -8.7, -12.9], [-1.3, -6.4, 0.2, 2.0, -1.0, -0.6, -0.9, 1.5, 0.9, -2.7, -3.9], [2.9, -1.5, -2.5, 2.4, -0.6, -0.1, -0.6, -0.1, 1.1, -1.0, -0.2, 2.6], [-2.0, -0.2, 0.3, 1.2, -1.3, 0.6, 0.6, 0.5, -0.1, -0.4, -0.2, -1.3, -0.7]]
    private static let h: [[Double]] = [[0.0], [0.0, 4545.4], [0.0, -3133.6, -815.1], [0.0, -56.6, 237.5, -549.5], [0.0, 278.6, -133.9, 212.0, -375.6], [0.0, 45.4, 220.2, -122.9, 43.0, 106.1], [0.0, -18.4, 16.8, 48.8, -59.8, 10.9, 72.7], [0.0, -48.9, -14.4, -1.0, 23.4, -7.4, -25.1, -2.3], [0.0, 7.1, -12.6, 11.4, -9.7, 12.7, 0.7, -5.2, 3.9], [0.0, -24.8, 12.2, 8.3, -3.3, -5.2, 7.2, -0.6, 0.8, 10.0], [0.0, 3.3, 0.0, 2.4, 5.3, -9.1, 0.4, -4.2, -3.8, 0.9, -9.1], [0.0, 0.0, 2.9, -0.6, 0.2, 0.5, -0.3, -1.2, -1.7, -2.9, -1.8, -2.3], [0.0, -1.3, 0.7, 1.0, -1.4, -0.0, 0.6, -0.1, 0.8, 0.1, -1.0, 0.1, 0.2]]
    private static let deltaG: [[Double]] = [[0.0], [12.0, 9.7], [-11.6, -5.2, -8.0], [-1.3, -4.2, 0.4, -15.6], [-1.6, -2.4, -6.0, 5.6, -7.0], [0.6, 1.4, 0.0, 0.6, 2.2, 0.9], [-0.2, -0.4, 0.9, 1.2, -0.9, 0.3, 0.9], [-0.0, -0.1, -0.1, 0.5, -0.1, -0.8, -0.8, 0.8], [-0.1, 0.2, 0.0, 0.5, -0.1, 0.3, 0.2, -0.0, 0.2], [-0.0, -0.1, 0.1, 0.3, -0.3, 0.0, 0.3, -0.1, 0.1, -0.1], [0.1, 0.0, 0.1, 0.1, -0.0, -0.3, 0.0, -0.1, -0.1, -0.0, -0.0], [0.0, -0.0, 0.0, 0.0, 0.0, -0.1, 0.0, -0.0, -0.1, -0.1, -0.1, -0.1], [0.0, 0.0, -0.0, -0.0, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, -0.1, -0.0, -0.1]]
    private static let deltaH: [[Double]] = [[0.0], [0.0, -21.5], [0.0, -27.7, -12.1], [0.0, 4.0, -0.3, -4.1], [0.0, -1.1, 4.1, 1.6, -4.4], [0.0, -0.5, 2.2, 0.4, 1.7, 1.9], [0.0, 0.3, -1.6, -0.4, 0.9, 0.7, 0.9], [0.0, 0.6, 0.5, -0.8, 0.0, -1.0, 0.6, -0.2], [0.0, -0.2, 0.5, -0.4, 0.4, -0.5, -0.6, 0.3, 0.2], [0.0, -0.3, 0.3, -0.3, 0.3, 0.2, -0.1, -0.2, 0.4, 0.1], [0.0, 0.0, -0.0, -0.2, 0.1, -0.1, 0.1, 0.0, -0.1, 0.2, -0.0], [0.0, -0.0, 0.1, -0.0, 0.1, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, 0.0], [0.0, -0.0, 0.0, -0.1, 0.1, -0.0, -0.0, -0.0, 0.0, -0.0, -0.0, 0.0, -0.1]]

    private let semiMajorAxis = 6378.137
    private let semiMinorAxis = 6356.7523142
    private let referenceRadius = 6371.2
    private let baseDate: Date = {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)
        c.year = 2025; c.month = 1; c.day = 1
        return c.date ?? Date(timeIntervalSince1970: 0)
    }()

    private init() {}

    /// Computes magnetic field at a WGS84 geodetic coordinate and date.
    /// Latitude is clamped away from the poles where the spherical equations
    /// become singular. Longitude is normalized internally by trigonometry.
    public func field(latitude: Double, longitude: Double, altitudeMeters: Double = 0, date: Date = Date()) -> GeomagneticField {
        let latDeg = min(90.0 - 1e-5, max(-90.0 + 1e-5, latitude.isFinite ? latitude : 0))
        // Core Location normally supplies [-180, 180], but callers can also
        // provide an unwrapped longitude. Normalize it before evaluating the
        // harmonics so very large values do not lose precision in sin/cos.
        let rawLon = longitude.isFinite ? longitude : 0
        let wrappedLon = rawLon.truncatingRemainder(dividingBy: 360.0)
        let lonDeg = wrappedLon > 180.0 ? wrappedLon - 360.0 : (wrappedLon < -180.0 ? wrappedLon + 360.0 : wrappedLon)
        let altitudeKm = (altitudeMeters.isFinite ? altitudeMeters : 0) / 1000.0
        let a2 = semiMajorAxis * semiMajorAxis
        let b2 = semiMinorAxis * semiMinorAxis
        let latRad = latDeg * .pi / 180.0
        let cosLat = cos(latRad)
        let sinLat = sin(latRad)
        let tanLat = sinLat / cosLat
        let earthRadius = sqrt(a2 * cosLat * cosLat + b2 * sinLat * sinLat)
        let centerLat = atan(tanLat * (earthRadius * altitudeKm + b2) / (earthRadius * altitudeKm + a2))
        let centerLon = lonDeg * .pi / 180.0
        let radiusSquared = altitudeKm * altitudeKm
            + 2.0 * altitudeKm * earthRadius
            + (a2 * a2 * cosLat * cosLat + b2 * b2 * sinLat * sinLat) / (a2 * cosLat * cosLat + b2 * sinLat * sinLat)
        let centerRadius = sqrt(radiusSquared)
        let legendre = LegendreTable(maxN: Self.g.count - 1, theta: .pi / 2.0 - centerLat)

        let maxN = Self.g.count
        var radiusPower = Array(repeating: 0.0, count: maxN + 2)
        radiusPower[0] = 1.0
        radiusPower[1] = referenceRadius / centerRadius
        if radiusPower.count > 2 {
            for i in 2..<radiusPower.count { radiusPower[i] = radiusPower[i - 1] * radiusPower[1] }
        }
        var sinMLon = Array(repeating: 0.0, count: maxN)
        var cosMLon = Array(repeating: 0.0, count: maxN)
        cosMLon[0] = 1.0
        if maxN > 1 {
            sinMLon[1] = sin(centerLon); cosMLon[1] = cos(centerLon)
            if maxN > 2 {
                for m in 2..<maxN {
                    sinMLon[m] = sin(Double(m) * centerLon)
                    cosMLon[m] = cos(Double(m) * centerLon)
                }
            }
        }
        let inverseCosLatitude = 1.0 / cos(centerLat)
        // WMM secular-variation coefficients are expressed per Julian year
        // (365.25 days). Using 365 days accumulates a small but avoidable date
        // error and makes the offline correction drift faster over time.
        let years = date.timeIntervalSince(baseDate) / (365.25 * 24.0 * 60.0 * 60.0)
        var gcX = 0.0, gcY = 0.0, gcZ = 0.0
        for n in 1..<maxN {
            for m in 0...n {
                let coeffG = Self.g[n][m] + years * Self.deltaG[n][m]
                let coeffH = Self.h[n][m] + years * Self.deltaH[n][m]
                let harmonic = coeffG * cosMLon[m] + coeffH * sinMLon[m]
                let schmidt = schmidtFactor(n: n, m: m)
                gcX += radiusPower[n + 2] * harmonic * legendre.derivative[n][m] * schmidt
                gcY += radiusPower[n + 2] * Double(m) * (coeffG * sinMLon[m] - coeffH * cosMLon[m]) * legendre.value[n][m] * schmidt * inverseCosLatitude
                gcZ -= Double(n + 1) * radiusPower[n + 2] * harmonic * legendre.value[n][m] * schmidt
            }
        }
        let latitudeDifference = latRad - centerLat
        let north = gcX * cos(latitudeDifference) + gcZ * sin(latitudeDifference)
        let east = gcY
        let down = -gcX * sin(latitudeDifference) + gcZ * cos(latitudeDifference)
        let horizontal = hypot(north, east)
        let total = sqrt(north * north + east * east + down * down)
        return GeomagneticField(north: north, east: east, down: down,
                                declination: atan2(east, north) * 180.0 / .pi,
                                inclination: atan2(down, horizontal) * 180.0 / .pi,
                                horizontalStrength: horizontal, fieldStrength: total)
    }

    public func declination(latitude: Double, longitude: Double, altitudeMeters: Double = 0, date: Date = Date()) -> Double {
        field(latitude: latitude, longitude: longitude, altitudeMeters: altitudeMeters, date: date).declination
    }

    public func fieldStrengthMicrotesla(latitude: Double, longitude: Double, altitudeMeters: Double = 0, date: Date = Date()) -> Double {
        field(latitude: latitude, longitude: longitude, altitudeMeters: altitudeMeters, date: date).fieldStrength / 1000.0
    }

    private func schmidtFactor(n: Int, m: Int) -> Double {
        var value = 1.0
        if n == 0 { return value }
        for degree in 1...n { value *= Double(2 * degree - 1) / Double(degree) }
        if m > 0 {
            for order in 1...m { value *= sqrt(Double(n - order + 1) * (order == 1 ? 2.0 : 1.0) / Double(n + order)) }
        }
        return value
    }

    private struct LegendreTable {
        let value: [[Double]]
        let derivative: [[Double]]
        init(maxN: Int, theta: Double) {
            let c = cos(theta), s = sin(theta)
            var p = Array(repeating: [Double](), count: maxN + 1)
            var d = Array(repeating: [Double](), count: maxN + 1)
            p[0] = [1.0]; d[0] = [0.0]
            if maxN > 0 {
                for n in 1...maxN {
                    p[n] = Array(repeating: 0.0, count: n + 1)
                    d[n] = Array(repeating: 0.0, count: n + 1)
                    for m in 0...n {
                        if n == m {
                            p[n][m] = s * p[n - 1][m - 1]
                            d[n][m] = c * p[n - 1][m - 1] + s * d[n - 1][m - 1]
                        } else if n == 1 || m == n - 1 {
                            p[n][m] = c * p[n - 1][m]
                            d[n][m] = -s * p[n - 1][m] + c * d[n - 1][m]
                        } else {
                            let k = Double((n - 1) * (n - 1) - m * m) / Double((2 * n - 1) * (2 * n - 3))
                            p[n][m] = c * p[n - 1][m] - k * p[n - 2][m]
                            d[n][m] = -s * p[n - 1][m] + c * d[n - 1][m] - k * d[n - 2][m]
                        }
                    }
                }
            }
            value = p; derivative = d
        }
    }
}
