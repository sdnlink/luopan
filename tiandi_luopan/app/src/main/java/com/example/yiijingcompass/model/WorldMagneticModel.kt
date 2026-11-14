package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * WMM 2025-2030 geomagnetic field model, evaluated fully offline.
 * Coefficients and recurrence follow the AOSP GeomagneticField implementation
 * and NOAA/NCEI WMM2025 coefficient set (epoch 2025.0, valid 2025-2030).
 */
data class GeomagneticResult(
    val north: Double,             // nT
    val east: Double,              // nT
    val down: Double,              // nT
    val declination: Double,       // degrees; east positive, west negative
    val inclination: Double,       // degrees
    val horizontalStrength: Double, // nT
    val fieldStrength: Double      // nT
)

class WorldMagneticModel private constructor() {

    companion object {
        val instance: WorldMagneticModel by lazy { WorldMagneticModel() }

        private val g: Array<DoubleArray> = arrayOf(
            doubleArrayOf(0.0),
            doubleArrayOf(-29351.8, -1410.8),
            doubleArrayOf(-2556.6, 2951.1, 1649.3),
            doubleArrayOf(1361.0, -2404.1, 1243.8, 453.6),
            doubleArrayOf(895.0, 799.5, 55.7, -281.1, 12.1),
            doubleArrayOf(-233.2, 368.9, 187.2, -138.7, -142.0, 20.9),
            doubleArrayOf(64.4, 63.8, 76.9, -115.7, -40.9, 14.9, -60.7),
            doubleArrayOf(79.5, -77.0, -8.8, 59.3, 15.8, 2.5, -11.1, 14.2),
            doubleArrayOf(23.2, 10.8, -17.5, 2.0, -21.7, 16.9, 15.0, -16.8, 0.9),
            doubleArrayOf(4.6, 7.8, 3.0, -0.2, -2.5, -13.1, 2.4, 8.6, -8.7, -12.9),
            doubleArrayOf(-1.3, -6.4, 0.2, 2.0, -1.0, -0.6, -0.9, 1.5, 0.9, -2.7, -3.9),
            doubleArrayOf(2.9, -1.5, -2.5, 2.4, -0.6, -0.1, -0.6, -0.1, 1.1, -1.0, -0.2, 2.6),
            doubleArrayOf(-2.0, -0.2, 0.3, 1.2, -1.3, 0.6, 0.6, 0.5, -0.1, -0.4, -0.2, -1.3, -0.7)
        )

        private val h: Array<DoubleArray> = arrayOf(
            doubleArrayOf(0.0),
            doubleArrayOf(0.0, 4545.4),
            doubleArrayOf(0.0, -3133.6, -815.1),
            doubleArrayOf(0.0, -56.6, 237.5, -549.5),
            doubleArrayOf(0.0, 278.6, -133.9, 212.0, -375.6),
            doubleArrayOf(0.0, 45.4, 220.2, -122.9, 43.0, 106.1),
            doubleArrayOf(0.0, -18.4, 16.8, 48.8, -59.8, 10.9, 72.7),
            doubleArrayOf(0.0, -48.9, -14.4, -1.0, 23.4, -7.4, -25.1, -2.3),
            doubleArrayOf(0.0, 7.1, -12.6, 11.4, -9.7, 12.7, 0.7, -5.2, 3.9),
            doubleArrayOf(0.0, -24.8, 12.2, 8.3, -3.3, -5.2, 7.2, -0.6, 0.8, 10.0),
            doubleArrayOf(0.0, 3.3, 0.0, 2.4, 5.3, -9.1, 0.4, -4.2, -3.8, 0.9, -9.1),
            doubleArrayOf(0.0, 0.0, 2.9, -0.6, 0.2, 0.5, -0.3, -1.2, -1.7, -2.9, -1.8, -2.3),
            doubleArrayOf(0.0, -1.3, 0.7, 1.0, -1.4, -0.0, 0.6, -0.1, 0.8, 0.1, -1.0, 0.1, 0.2)
        )

        private val deltaG: Array<DoubleArray> = arrayOf(
            doubleArrayOf(0.0),
            doubleArrayOf(12.0, 9.7),
            doubleArrayOf(-11.6, -5.2, -8.0),
            doubleArrayOf(-1.3, -4.2, 0.4, -15.6),
            doubleArrayOf(-1.6, -2.4, -6.0, 5.6, -7.0),
            doubleArrayOf(0.6, 1.4, 0.0, 0.6, 2.2, 0.9),
            doubleArrayOf(-0.2, -0.4, 0.9, 1.2, -0.9, 0.3, 0.9),
            doubleArrayOf(-0.0, -0.1, -0.1, 0.5, -0.1, -0.8, -0.8, 0.8),
            doubleArrayOf(-0.1, 0.2, 0.0, 0.5, -0.1, 0.3, 0.2, -0.0, 0.2),
            doubleArrayOf(-0.0, -0.1, 0.1, 0.3, -0.3, 0.0, 0.3, -0.1, 0.1, -0.1),
            doubleArrayOf(0.1, 0.0, 0.1, 0.1, -0.0, -0.3, 0.0, -0.1, -0.1, -0.0, -0.0),
            doubleArrayOf(0.0, -0.0, 0.0, 0.0, 0.0, -0.1, 0.0, -0.0, -0.1, -0.1, -0.1, -0.1),
            doubleArrayOf(0.0, 0.0, -0.0, -0.0, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, -0.1, -0.0, -0.1)
        )

        private val deltaH: Array<DoubleArray> = arrayOf(
            doubleArrayOf(0.0),
            doubleArrayOf(0.0, -21.5),
            doubleArrayOf(0.0, -27.7, -12.1),
            doubleArrayOf(0.0, 4.0, -0.3, -4.1),
            doubleArrayOf(0.0, -1.1, 4.1, 1.6, -4.4),
            doubleArrayOf(0.0, -0.5, 2.2, 0.4, 1.7, 1.9),
            doubleArrayOf(0.0, 0.3, -1.6, -0.4, 0.9, 0.7, 0.9),
            doubleArrayOf(0.0, 0.6, 0.5, -0.8, 0.0, -1.0, 0.6, -0.2),
            doubleArrayOf(0.0, -0.2, 0.5, -0.4, 0.4, -0.5, -0.6, 0.3, 0.2),
            doubleArrayOf(0.0, -0.3, 0.3, -0.3, 0.3, 0.2, -0.1, -0.2, 0.4, 0.1),
            doubleArrayOf(0.0, 0.0, -0.0, -0.2, 0.1, -0.1, 0.1, 0.0, -0.1, 0.2, -0.0),
            doubleArrayOf(0.0, -0.0, 0.1, -0.0, 0.1, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, 0.0),
            doubleArrayOf(0.0, -0.0, 0.0, -0.1, 0.1, -0.0, -0.0, -0.0, 0.0, -0.0, -0.0, 0.0, -0.1)
        )
    }

    private val semiMajorAxis = 6378.137
    private val semiMinorAxis = 6356.7523142
    private val referenceRadius = 6371.2
    private val baseEpochMillis: Long = run {
        val cal = java.util.GregorianCalendar(TimeZone.getTimeZone("GMT"))
        cal.set(2025, Calendar.JANUARY, 1, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        cal.timeInMillis
    }

    fun field(latitude: Double, longitude: Double, altitudeMeters: Double = 0.0, date: Date = Date()): GeomagneticResult {
        val latDeg = (if (latitude.isFinite()) latitude else 0.0).coerceIn(-90.0 + 1e-5, 90.0 - 1e-5)
        val rawLon = if (longitude.isFinite()) longitude else 0.0
        val wrappedLon = rawLon % 360.0
        val lonDeg = when {
            wrappedLon > 180.0 -> wrappedLon - 360.0
            wrappedLon < -180.0 -> wrappedLon + 360.0
            else -> wrappedLon
        }
        val altitudeKm = (if (altitudeMeters.isFinite()) altitudeMeters else 0.0) / 1000.0
        val a2 = semiMajorAxis * semiMajorAxis
        val b2 = semiMinorAxis * semiMinorAxis
        val latRad = Math.toRadians(latDeg)
        val cosLat = cos(latRad)
        val sinLat = sin(latRad)
        val tanLat = sinLat / cosLat
        val earthRadius = sqrt(a2 * cosLat * cosLat + b2 * sinLat * sinLat)
        val centerLat = atan(tanLat * (earthRadius * altitudeKm + b2) / (earthRadius * altitudeKm + a2))
        val centerLon = Math.toRadians(lonDeg)
        val radiusSquared = altitudeKm * altitudeKm +
                2.0 * altitudeKm * earthRadius +
                (a2 * a2 * cosLat * cosLat + b2 * b2 * sinLat * sinLat) / (a2 * cosLat * cosLat + b2 * sinLat * sinLat)
        val centerRadius = sqrt(radiusSquared)
        val legendre = LegendreTable(g.size - 1, Math.PI / 2.0 - centerLat)

        val maxN = g.size
        val radiusPower = DoubleArray(maxN + 2)
        radiusPower[0] = 1.0
        radiusPower[1] = referenceRadius / centerRadius
        for (i in 2 until radiusPower.size) {
            radiusPower[i] = radiusPower[i - 1] * radiusPower[1]
        }

        val sinMLon = DoubleArray(maxN)
        val cosMLon = DoubleArray(maxN)
        cosMLon[0] = 1.0
        if (maxN > 1) {
            sinMLon[1] = sin(centerLon)
            cosMLon[1] = cos(centerLon)
            for (m in 2 until maxN) {
                sinMLon[m] = sin(m.toDouble() * centerLon)
                cosMLon[m] = cos(m.toDouble() * centerLon)
            }
        }
        val inverseCosLatitude = 1.0 / cos(centerLat)
        val years = (date.time - baseEpochMillis).toDouble() / (365.25 * 24.0 * 3600.0 * 1000.0)

        var gcX = 0.0
        var gcY = 0.0
        var gcZ = 0.0
        for (n in 1 until maxN) {
            for (m in 0..n) {
                val coeffG = g[n][m] + years * deltaG[n][m]
                val coeffH = h[n][m] + years * deltaH[n][m]
                val harmonic = coeffG * cosMLon[m] + coeffH * sinMLon[m]
                val schmidt = schmidtFactor(n, m)
                gcX += radiusPower[n + 2] * harmonic * legendre.derivative[n][m] * schmidt
                gcY += radiusPower[n + 2] * m.toDouble() * (coeffG * sinMLon[m] - coeffH * cosMLon[m]) * legendre.value[n][m] * schmidt * inverseCosLatitude
                gcZ -= (n + 1).toDouble() * radiusPower[n + 2] * harmonic * legendre.value[n][m] * schmidt
            }
        }
        val latitudeDifference = latRad - centerLat
        val north = gcX * cos(latitudeDifference) + gcZ * sin(latitudeDifference)
        val east = gcY
        val down = -gcX * sin(latitudeDifference) + gcZ * cos(latitudeDifference)
        val horizontal = hypot(north, east)
        val total = sqrt(north * north + east * east + down * down)
        return GeomagneticResult(
            north = north,
            east = east,
            down = down,
            declination = Math.toDegrees(atan2(east, north)),
            inclination = Math.toDegrees(atan2(down, horizontal)),
            horizontalStrength = horizontal,
            fieldStrength = total
        )
    }

    fun declination(latitude: Double, longitude: Double, altitudeMeters: Double = 0.0, date: Date = Date()): Double {
        return field(latitude, longitude, altitudeMeters, date).declination
    }

    fun fieldStrengthMicrotesla(latitude: Double, longitude: Double, altitudeMeters: Double = 0.0, date: Date = Date()): Double {
        return field(latitude, longitude, altitudeMeters, date).fieldStrength / 1000.0
    }

    private fun schmidtFactor(n: Int, m: Int): Double {
        var value = 1.0
        if (n == 0) return value
        for (degree in 1..n) {
            value *= (2 * degree - 1).toDouble() / degree.toDouble()
        }
        if (m > 0) {
            for (order in 1..m) {
                value *= sqrt((n - order + 1).toDouble() * (if (order == 1) 2.0 else 1.0) / (n + order).toDouble())
            }
        }
        return value
    }

    private class LegendreTable(maxN: Int, theta: Double) {
        val value: Array<DoubleArray> = Array(maxN + 1) { DoubleArray(it + 1) }
        val derivative: Array<DoubleArray> = Array(maxN + 1) { DoubleArray(it + 1) }

        init {
            val c = cos(theta)
            val s = sin(theta)
            value[0] = doubleArrayOf(1.0)
            derivative[0] = doubleArrayOf(0.0)
            if (maxN > 0) {
                for (n in 1..maxN) {
                    for (m in 0..n) {
                        when {
                            n == m -> {
                                value[n][m] = s * value[n - 1][m - 1]
                                derivative[n][m] = c * value[n - 1][m - 1] + s * derivative[n - 1][m - 1]
                            }
                            n == 1 || m == n - 1 -> {
                                value[n][m] = c * value[n - 1][m]
                                derivative[n][m] = -s * value[n - 1][m] + c * derivative[n - 1][m]
                            }
                            else -> {
                                val k = ((n - 1) * (n - 1) - m * m).toDouble() / ((2 * n - 1) * (2 * n - 3)).toDouble()
                                value[n][m] = c * value[n - 1][m] - k * value[n - 2][m]
                                derivative[n][m] = -s * value[n - 1][m] + c * derivative[n - 1][m] - k * derivative[n - 2][m]
                            }
                        }
                    }
                }
            }
        }
    }
}

