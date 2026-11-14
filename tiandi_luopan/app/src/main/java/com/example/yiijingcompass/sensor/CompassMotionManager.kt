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
import com.example.yiijingcompass.model.AppLanguage
import com.example.yiijingcompass.model.CompassHeadingState
import com.example.yiijingcompass.model.LocalizationManager
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

    var hasLocationFix=false;private set
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
            appContext?.getSharedPreferences("compass_prefs",Context.MODE_PRIVATE)?.edit()?.putBoolean("locked",value)?.putFloat("locked_heading",heading.toFloat())?.apply()
            appContext?.getSharedPreferences("almanac_widget",Context.MODE_PRIVATE)?.edit()?.putBoolean("locked",value)?.putFloat("heading",heading.toFloat())?.apply()
            if(!value)physicalHeading()?.let {heading=it;headingState=Mountain24Data.instance.resolveHeadingState(it)}
            if (isHapticEnabled) {
                triggerClick()
            }
        }
    var manualOffset: Double = 0.0
        set(value){if(value.isFinite()){field=value;appContext?.getSharedPreferences("compass_prefs",Context.MODE_PRIVATE)?.edit()?.putFloat("manual_offset",value.toFloat())?.apply()}}
    private var running=false
    private var initialized=false
    private var liveHeadingDate=0L
    private var cameraBearing:Double?=null
    private var cameraElevation:Double?=null
    private var cameraRoll:Double?=null
    var liveSensorHeading=0.0;private set
    var hasLiveSensorHeading=false;private set
    fun physicalHeading(now:Long=System.currentTimeMillis()):Double?=liveSensorHeading.takeIf {hasLiveSensorHeading&&now-liveHeadingDate in 0..3000}
    fun physicalCameraHeading(now:Long=System.currentTimeMillis()):Double?=cameraBearing?.takeIf {now-liveHeadingDate in 0..3000}
    fun physicalCameraElevation(now:Long=System.currentTimeMillis()):Double?=cameraElevation?.takeIf {now-liveHeadingDate in 0..3000}
    fun physicalCameraRoll(now:Long=System.currentTimeMillis()):Double?=cameraRoll?.takeIf {now-liveHeadingDate in 0..3000}
    fun lockAtFacingAngle(angle:Double){
        if(!angle.isFinite())return
        heading=(angle%360+360)%360;headingState=Mountain24Data.instance.resolveHeadingState(heading);isLocked=true
        for(l in listeners)l.onHeadingUpdate(heading,trueHeading,magneticHeading,headingState)
    }
    fun toggleLock(){isLocked=!isLocked}

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
        if(running)return
        running=true
        appContext = context.applicationContext
        val prefs = context.getSharedPreferences("compass_prefs", Context.MODE_PRIVATE)
        northReference = CompassNorthReference.from(prefs.getString("compass_north_reference", "true_north") ?: "true_north")
        isHapticEnabled = prefs.getBoolean("compass_haptic_enabled", true)
        if(!initialized){initialized=true;manualOffset=prefs.getFloat("manual_offset",0f).toDouble()
            if(prefs.getBoolean("locked",false))lockAtFacingAngle(prefs.getFloat("locked_heading",0f).toDouble())
        }
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            @Suppress("DEPRECATION")
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
                magnetometer?.let {sm.registerListener(this,it,SENSOR_RATE)}
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
        running=false
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

    internal fun processRotationMatrix(rMatrix: FloatArray) {
        if(rMatrix.size<9||rMatrix.any {!it.isFinite()})return
        val rotation=(appContext?.getSystemService(Context.WINDOW_SERVICE) as? android.view.WindowManager)?.defaultDisplay?.rotation ?: android.view.Surface.ROTATION_0
        val remapped=FloatArray(9)
        val axes=when(rotation){android.view.Surface.ROTATION_90->SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            android.view.Surface.ROTATION_180->SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            android.view.Surface.ROTATION_270->SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else->SensorManager.AXIS_X to SensorManager.AXIS_Y}
        SensorManager.remapCoordinateSystem(rMatrix,axes.first,axes.second,remapped)
        SensorManager.getOrientation(remapped, orientationAngles)
        val east=-rMatrix[2].toDouble();val north=-rMatrix[5].toDouble();val up=-rMatrix[8].toDouble()
        cameraBearing=if(kotlin.math.hypot(east,north)>.01)(Math.toDegrees(atan2(east,north))+currentDeclination+manualOffset+720)%360 else null
        cameraElevation=Math.toDegrees(kotlin.math.asin(up.coerceIn(-1.0,1.0)))
        cameraRoll=Math.toDegrees(atan2(-remapped[6].toDouble(),remapped[7].toDouble()))
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
        liveSensorHeading=if(hasDeclination)trueHeading else magneticHeading
        hasLiveSensorHeading=true;liveHeadingDate=System.currentTimeMillis()
        if(isLocked){
            for(l in listeners)l.onHeadingUpdate(heading,trueHeading,magneticHeading,headingState)
            if(System.currentTimeMillis()-lastSolarTimeUpdate>=1000){lastSolarTimeUpdate=System.currentTimeMillis();updateSolarTime()}
            return
        }

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
        val solarResult = SolarTimeCalculator.instance.calculate(Date(), longitude)
        for (l in listeners) {
            l.onSolarTimeUpdate(if(hasLocationFix)solarResult.trueSolarTimeString else "--:--:--", solarResult.solarTermName)
        }
    }

    override fun onLocationChanged(loc: Location) {
        if(!loc.latitude.isFinite()||!loc.longitude.isFinite()||loc.latitude !in -90.0..90.0||loc.longitude !in -180.0..180.0)return
        hasLocationFix=true
        latitude = loc.latitude
        longitude = loc.longitude
        altitude = if (loc.hasAltitude()) loc.altitude else 0.0
        speedKmH = if (loc.hasSpeed()) loc.speed * 3.6f else 0f

        val lang = LocalizationManager.instance.effectiveLanguage
        val suffixHemisphere = lang == AppLanguage.EN || lang == AppLanguage.ID || lang == AppLanguage.VI || lang == AppLanguage.TH
        val latHem = (if (latitude >= 0) LocalizationManager.instance.t("lat_north") else LocalizationManager.instance.t("lat_south")).trim()
        val lonHem = (if (longitude >= 0) LocalizationManager.instance.t("lon_east") else LocalizationManager.instance.t("lon_west")).trim()
        val latDeg = String.format(Locale.US, "%.4f°", abs(latitude))
        val lonDeg = String.format(Locale.US, "%.4f°", abs(longitude))
        val latStr = if (suffixHemisphere) "$latDeg $latHem" else "$latHem $latDeg"
        val lonStr = if (suffixHemisphere) "$lonDeg $lonHem" else "$lonHem $lonDeg"
        coordsDesc = "$latStr, $lonStr"

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

