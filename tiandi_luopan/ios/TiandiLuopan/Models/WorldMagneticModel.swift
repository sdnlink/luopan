import Foundation

/// WMM 2020-2025 geomagnetic field model, evaluated fully offline.
/// Coefficients and recurrence follow the AOSP GeomagneticField implementation
/// and the NOAA/NGA WMM 2020-2025 coefficient set.
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

    private static let g: [[Double]] = [[0.0], [-29404.5, -1450.7], [-2500.0, 2982.0, 1676.8], [1363.9, -2381.0, 1236.2, 525.7], [903.1, 809.4, 86.2, -309.4, 47.9], [-234.4, 363.1, 187.8, -140.7, -151.2, 13.7], [65.9, 65.6, 73.0, -121.5, -36.2, 13.5, -64.7], [80.6, -76.8, -8.3, 56.5, 15.8, 6.4, -7.2, 9.8], [23.6, 9.8, -17.5, -0.4, -21.1, 15.3, 13.7, -16.5, -0.3], [5.0, 8.2, 2.9, -1.4, -1.1, -13.3, 1.1, 8.9, -9.3, -11.9], [-1.9, -6.2, -0.1, 1.7, -0.9, 0.6, -0.9, 1.9, 1.4, -2.4, -3.9], [3.0, -1.4, -2.5, 2.4, -0.9, 0.3, -0.7, -0.1, 1.4, -0.6, 0.2, 3.1], [-2.0, -0.1, 0.5, 1.3, -1.2, 0.7, 0.3, 0.5, -0.2, -0.5, 0.1, -1.1, -0.3]]
    private static let h: [[Double]] = [[0.0], [0.0, 4652.9], [0.0, -2991.6, -734.8], [0.0, -82.2, 241.8, -542.9], [0.0, 282.0, -158.4, 199.8, -350.1], [0.0, 47.7, 208.4, -121.3, 32.2, 99.1], [0.0, -19.1, 25.0, 52.7, -64.4, 9.0, 68.1], [0.0, -51.4, -16.8, 2.3, 23.5, -2.2, -27.2, -1.9], [0.0, 8.4, -15.3, 12.8, -11.8, 14.9, 3.6, -6.9, 2.8], [0.0, -23.3, 11.1, 9.8, -5.1, -6.2, 7.8, 0.4, -1.5, 9.7], [0.0, 3.4, -0.2, 3.5, 4.8, -8.6, -0.1, -4.2, -3.4, -0.1, -8.8], [0.0, 0.0, 2.6, -0.5, -0.4, 0.6, -0.2, -1.7, -1.6, -3.0, -2.0, -2.6], [0.0, -1.2, 0.5, 1.3, -1.8, 0.1, 0.7, -0.1, 0.6, 0.2, -0.9, 0.0, 0.5]]
    private static let deltaG: [[Double]] = [[0.0], [6.7, 7.7], [-11.5, -7.1, -2.2], [2.8, -6.2, 3.4, -12.2], [-1.1, -1.6, -6.0, 5.4, -5.5], [-0.3, 0.6, -0.7, 0.1, 1.2, 1.0], [-0.6, -0.4, 0.5, 1.4, -1.4, 0.0, 0.8], [-0.1, -0.3, -0.1, 0.7, 0.2, -0.5, -0.8, 1.0], [-0.1, 0.1, -0.1, 0.5, -0.1, 0.4, 0.5, 0.0, 0.4], [-0.1, -0.2, 0.0, 0.4, -0.3, 0.0, 0.3, 0.0, 0.0, -0.4], [0.0, 0.0, 0.0, 0.2, -0.1, -0.2, 0.0, -0.1, -0.2, -0.1, 0.0], [0.0, -0.1, 0.0, 0.0, 0.0, -0.1, 0.0, 0.0, -0.1, -0.1, -0.1, -0.1], [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.1]]
    private static let deltaH: [[Double]] = [[0.0], [0.0, -25.1], [0.0, -30.2, -23.9], [0.0, 5.7, -1.0, 1.1], [0.0, 0.2, 6.9, 3.7, -5.6], [0.0, 0.1, 2.5, -0.9, 3.0, 0.5], [0.0, 0.1, -1.8, -1.4, 0.9, 0.1, 1.0], [0.0, 0.5, 0.6, -0.7, -0.2, -1.2, 0.2, 0.3], [0.0, -0.3, 0.7, -0.2, 0.5, -0.3, -0.5, 0.4, 0.1], [0.0, -0.3, 0.2, -0.4, 0.4, 0.1, 0.0, -0.2, 0.5, 0.2], [0.0, 0.0, 0.1, -0.3, 0.1, -0.2, 0.1, 0.0, -0.1, 0.2, 0.0], [0.0, 0.0, 0.1, 0.0, 0.2, 0.0, 0.0, 0.1, 0.0, -0.1, 0.0, 0.0], [0.0, 0.0, 0.0, -0.1, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, -0.1]]

    private let semiMajorAxis = 6378.137
    private let semiMinorAxis = 6356.7523142
    private let referenceRadius = 6371.2
    private let baseDate: Date = {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)
        c.year = 2020; c.month = 1; c.day = 1
        return c.date ?? Date(timeIntervalSince1970: 0)
    }()

    private init() {}

    /// Computes magnetic field at a WGS84 geodetic coordinate and date.
    /// Latitude is clamped away from the poles where the spherical equations
    /// become singular. Longitude is normalized internally by trigonometry.
    public func field(latitude: Double, longitude: Double, altitudeMeters: Double = 0, date: Date = Date()) -> GeomagneticField {
        let latDeg = min(90.0 - 1e-5, max(-90.0 + 1e-5, latitude.isFinite ? latitude : 0))
        let lonDeg = longitude.isFinite ? longitude : 0
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
        let years = date.timeIntervalSince(baseDate) / (365.0 * 24.0 * 60.0 * 60.0)
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
