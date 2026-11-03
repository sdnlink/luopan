package com.example.yiijingcompass.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.example.yiijingcompass.model.CompassHeadingState
import com.example.yiijingcompass.model.Mountain24Data
import com.example.yiijingcompass.model.SolarTimeCalculator
import com.example.yiijingcompass.model.WorldMagneticModel
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

enum class CompassNorthReference(val rawValue: String) {
    TRUE_NORTH("true_north"),
    MAGNETIC_NORTH("magnetic_north");

    companion object {
        fun from(value: String): CompassNorthReference {
            return values().firstOrNull { it.rawValue == value } ?: TRUE_NORTH
        }
    }
}

interface CompassMotionListener {
    fun onHeadingUpdate(heading: Double, trueHeading: Double, magneticHeading: Double, headingState: CompassHeadingState)
    fun onTiltUpdate(pitch: Float, roll: Float, isLevel: Boolean)
    fun onLocationUpdate(lat: Double, lon: Double, alt: Double, speedKmH: Float, coordsDesc: String)
    fun onSolarTimeUpdate(solarTimeStr: String, solarTerm: String)
    fun onMagneticFieldUpdate(isDistorted: Boolean, strengthUT: Float)
    fun onAccuracyChange(accuracy: Int)
}

class CompassMotionManager private constructor() : SensorEventListener, LocationListener {

    companion object {
        val instance: CompassMotionManager by lazy { CompassMotionManager() }
        private const val SENSOR_RATE = SensorManager.SENSOR_DELAY_GAME
    }

    private var sensorManager: SensorManager? = null
    private var locationManager: LocationManager? = null

    private var rotationSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var magnetometer: Sensor? = null

    private val listeners = mutableListOf<CompassMotionListener>()

    // State variables
    var heading: Double = 0.0
        private set
    var magneticHeading: Double = 0.0
        private set
    var trueHeading: Double = 0.0
        private set
    var currentDeclination: Float = 0f
        private set
    var hasDeclination: Boolean = false
        private set

    var pitch: Float = 0f
        private set
    var roll: Float = 0f
        private set
    var isLevel: Boolean = true
        private set

    var latitude: Double = 0.0
        private set
    var longitude: Double = 0.0
        private set
    var altitude: Double = 0.0
        private set
    var speedKmH: Float = 0f
        private set
    var coordsDesc: String = ""
        private set

    var isDistorted: Boolean = false
        private set
    var magneticStrengthUT: Float = 48f
        private set
    var accuracyLevel: Int = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
        private set

    var isLocked: Boolean = false
        set(value) {
            field = value
            if (isHapticEnabled) {
                triggerClick()
            }
        }
    var manualOffset: Double = 0.0

    var northReference: CompassNorthReference = CompassNorthReference.TRUE_NORTH
        set(value) {
            field = value
            hasSmoothHeading = false
            appContext?.getSharedPreferences("compass_prefs", Context.MODE_PRIVATE)
                ?.edit()?.putString("compass_north_reference", value.rawValue)?.apply()
        }

    var isHapticEnabled: Boolean = true
        set(value) {
            field = value
            appContext?.getSharedPreferences("compass_prefs", Context.MODE_PRIVATE)
                ?.edit()?.putBoolean("compass_haptic_enabled", value)?.apply()
        }

    private var vibrator: Vibrator? = null
    private var appContext: Context? = null
    private var lastMountainIndex: Int = -1
    private var wasLevel: Boolean = false

    var headingState: CompassHeadingState = Mountain24Data.instance.resolveHeadingState(0.0)
        private set

    private val accelerometerReading = FloatArray(3)
    private val magnetometerReading = FloatArray(3)
    private var hasAccelerometer = false
    private var hasMagnetometer = false

    private val rotationMatrix = FloatArray(9)
    private val orientationAngles = FloatArray(3)

    // Smooth filter
    private var hasSmoothHeading = false
    private var smoothHeadingSin = 0.0
    private var smoothHeadingCos = 1.0
    private val filterAlpha = 0.15

    private var lastHeadingTime = 0L
    private var lastSolarTimeUpdate = 0L

    fun addListener(listener: CompassMotionListener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
    }

    fun removeListener(listener: CompassMotionListener) {
        listeners.remove(listener)
    }

    fun hasSensors(context: Context): Boolean {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return false
        return sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null ||
                (sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null && sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null)
    }

    fun triggerTick() {
        if (!isHapticEnabled) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(12, 50))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(12)
            }
        } catch (_: Exception) {}
    }

    fun triggerClick() {
        if (!isHapticEnabled) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(25, 120))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(25)
            }
        } catch (_: Exception) {}
    }

    fun start(context: Context) {
        appContext = context.applicationContext
        val prefs = context.getSharedPreferences("compass_prefs", Context.MODE_PRIVATE)
        northReference = CompassNorthReference.from(prefs.getString("compass_north_reference", "true_north") ?: "true_north")
        isHapticEnabled = prefs.getBoolean("compass_haptic_enabled", true)
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibratorManager?.defaultVibrator ?: (context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

        sensorManager?.let { sm ->
            rotationSensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            magnetometer = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

            if (rotationSensor != null) {
                sm.registerListener(this, rotationSensor, SENSOR_RATE)
            } else {
                accelerometer?.let { sm.registerListener(this, it, SENSOR_RATE) }
                magnetometer?.let { sm.registerListener(this, it, SENSOR_RATE) }
            }
        }

        try {
            locationManager?.let { lm ->
                val gpsEnabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
                val netEnabled = lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                if (gpsEnabled) {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 2000L, 1f, this, Looper.getMainLooper())
                }
                if (netEnabled) {
                    lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 4000L, 5f, this, Looper.getMainLooper())
                }
            }
        } catch (_: SecurityException) {
        }
    }

    fun stop() {
        sensorManager?.unregisterListener(this)
        try {
            locationManager?.removeUpdates(this)
        } catch (_: SecurityException) {
        }
        hasSmoothHeading = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                processRotationMatrix(rotationMatrix)
            }
            Sensor.TYPE_ACCELEROMETER -> {
                System.arraycopy(event.values, 0, accelerometerReading, 0, 3)
                hasAccelerometer = true
                if (rotationSensor == null && hasMagnetometer) {
                    updateFallbackOrientation()
                }
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                System.arraycopy(event.values, 0, magnetometerReading, 0, 3)
                hasMagnetometer = true
                val magStrength = sqrt(
                    event.values[0] * event.values[0] +
                    event.values[1] * event.values[1] +
                    event.values[2] * event.values[2]
                )
                magneticStrengthUT = magStrength
                isDistorted = magStrength < 25f || magStrength > 75f
                for (l in listeners) l.onMagneticFieldUpdate(isDistorted, magneticStrengthUT)

                if (rotationSensor == null && hasAccelerometer) {
                    updateFallbackOrientation()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        accuracyLevel = accuracy
        for (l in listeners) l.onAccuracyChange(accuracy)
    }

    private fun updateFallbackOrientation() {
        val success = SensorManager.getRotationMatrix(rotationMatrix, null, accelerometerReading, magnetometerReading)
        if (success) {
            processRotationMatrix(rotationMatrix)
        }
    }

    private fun processRotationMatrix(rMatrix: FloatArray) {
        if (isLocked) return

        SensorManager.getOrientation(rMatrix, orientationAngles)
        var azimuthDeg = Math.toDegrees(orientationAngles[0].toDouble())
        if (azimuthDeg < 0) azimuthDeg += 360.0

        val pitchDeg = Math.toDegrees(orientationAngles[1].toDouble()).toFloat()
        val rollDeg = Math.toDegrees(orientationAngles[2].toDouble()).toFloat()

        pitch = pitchDeg
        roll = rollDeg
        val currentLevel = abs(pitchDeg) < 1.5f && abs(rollDeg) < 1.5f
        if (currentLevel && !wasLevel && isHapticEnabled) {
            triggerClick()
        }
        wasLevel = currentLevel
        isLevel = currentLevel

        for (l in listeners) l.onTiltUpdate(pitch, roll, isLevel)

        val magH = (azimuthDeg + manualOffset) % 360.0
        magneticHeading = if (magH >= 0) magH else magH + 360.0

        val decl = currentDeclination.toDouble()
        val trueH = (magneticHeading + decl + 360.0) % 360.0
        trueHeading = trueH

        val targetAngle = if (northReference == CompassNorthReference.TRUE_NORTH && hasDeclination) {
            trueHeading
        } else {
            magneticHeading
        }

        // Circular Low-pass filter
        val rad = Math.toRadians(targetAngle)
        val targetSin = kotlin.math.sin(rad)
        val targetCos = kotlin.math.cos(rad)

        if (!hasSmoothHeading) {
            smoothHeadingSin = targetSin
            smoothHeadingCos = targetCos
            hasSmoothHeading = true
        } else {
            smoothHeadingSin = smoothHeadingSin * (1.0 - filterAlpha) + targetSin * filterAlpha
            smoothHeadingCos = smoothHeadingCos * (1.0 - filterAlpha) + targetCos * filterAlpha
        }

        var smoothedDeg = Math.toDegrees(atan2(smoothHeadingSin, smoothHeadingCos))
        if (smoothedDeg < 0) smoothedDeg += 360.0
        heading = smoothedDeg

        val now = System.currentTimeMillis()
        if (now - lastHeadingTime >= 30) {
            lastHeadingTime = now
            headingState = Mountain24Data.instance.resolveHeadingState(heading)
            if (headingState.facingMountain.id != lastMountainIndex) {
                if (lastMountainIndex != -1 && isHapticEnabled) {
                    triggerTick()
                }
                lastMountainIndex = headingState.facingMountain.id
            }
            for (l in listeners) l.onHeadingUpdate(heading, trueHeading, magneticHeading, headingState)
        }

        if (now - lastSolarTimeUpdate >= 1000) {
            lastSolarTimeUpdate = now
            updateSolarTime()
        }
    }

    private fun updateSolarTime() {
        val solarResult = SolarTimeCalculator.instance.calculate(Date(), if (longitude != 0.0) longitude else 120.0)
        for (l in listeners) {
            l.onSolarTimeUpdate(solarResult.trueSolarTimeString, solarResult.solarTermName)
        }
    }

    override fun onLocationChanged(loc: Location) {
        latitude = loc.latitude
        longitude = loc.longitude
        altitude = if (loc.hasAltitude()) loc.altitude else 0.0
        speedKmH = if (loc.hasSpeed()) loc.speed * 3.6f else 0f

        val latHem = if (latitude >= 0) "北纬" else "南纬"
        val lonHem = if (longitude >= 0) "东经" else "西经"
        coordsDesc = "$latHem ${String.format(Locale.US, "%.4f°", abs(latitude))}, $lonHem ${String.format(Locale.US, "%.4f°", abs(longitude))}"

        // WMM geomagnetic declination calculation offline
        val dec = WorldMagneticModel.instance.declination(latitude, longitude, altitude)
        currentDeclination = dec.toFloat()
        hasDeclination = true

        for (l in listeners) {
            l.onLocationUpdate(latitude, longitude, altitude, speedKmH, coordsDesc)
        }
        updateSolarTime()
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
}

