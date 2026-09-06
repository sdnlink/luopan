package com.example.yiijingcompass

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.GeolocationPermissions
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity(), SensorEventListener {

    companion object {
        private const val TAG = "YiJingCompass"
        private const val PERMISSION_REQUEST_LOCATION = 1002
    }

    private lateinit var webView: WebView
    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var magnetometer: Sensor? = null
    private var gyroscope: Sensor? = null
    @Suppress("DEPRECATION")
    private var orientationSensor: Sensor? = null

    private var locationManager: LocationManager? = null
    private var currentDeclination: Float = 0f
    private var hasDeclination: Boolean = false
    private var locationDesc: String = ""
    private var currentLatitude: Double = 0.0
    private var currentLongitude: Double = 0.0
    private var currentAltitude: Double = 0.0
    private var hasAltitude: Boolean = false
    private var coordsDesc: String = ""
    private var currentSpeedKmH: Float = 0f
    private var lastLocationForSpeed: Location? = null
    private var currentPitch: Float = 0f
    private var currentRoll: Float = 0f
    private var lastPushedPitch: Float = 0f
    private var lastPushedRoll: Float = 0f
    private var lastTiltUpdateTimestamp: Long = 0L

    private val accelerometerReading = FloatArray(3)
    private val magnetometerReading = FloatArray(3)
    private var hasAccData = false
    private var hasMagData = false
    private val rotationMatrix = FloatArray(9)
    private val orientationAngles = FloatArray(3)

    private var isSensorListening = false
    private var lastHeading = -1f
    private var lastUpdateTimestamp = 0L

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webview)
        webView.setBackgroundColor(android.graphics.Color.parseColor("#121216"))
        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false

        // 传感器初始化（优先旋转矢量，其次加速度+地磁，备用旧版方向传感器）
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        @Suppress("DEPRECATION")
        orientationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ORIENTATION)

        Log.i(TAG, "Sensors initialized: rotation=$rotationSensor, acc=$accelerometer, mag=$magnetometer, ori=$orientationSensor")

        // WebView 配置
        val settings: WebSettings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.allowFileAccess = true
        settings.allowContentAccess = true
        @Suppress("DEPRECATION")
        settings.allowFileAccessFromFileURLs = true
        @Suppress("DEPRECATION")
        settings.allowUniversalAccessFromFileURLs = true
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.mediaPlaybackRequiresUserGesture = false
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

        webView.addJavascriptInterface(CompassJsInterface(), "AndroidCompass")

        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        checkAndRequestLocation()

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                val hasSensor = hasCompassSensor()
                val initHeading = if (lastHeading >= 0) lastHeading else 0f
                val declFormatted = String.format(java.util.Locale.US, "%.2f", currentDeclination)
                val escapedDesc = locationDesc.replace("'", "\\'")
                val escapedCoords = coordsDesc.replace("'", "\\'")
                Log.i(TAG, "onPageFinished: pushing hasSensor=$hasSensor, initHeading=$initHeading, declination=$declFormatted, coords=$coordsDesc")
                val speedFormatted = String.format(java.util.Locale.US, "%.1f", currentSpeedKmH)
                val pitchStr = String.format(java.util.Locale.US, "%.1f", currentPitch)
                val rollStr = String.format(java.util.Locale.US, "%.1f", currentRoll)
                webView.evaluateJavascript("if(window.onNativeCompassAvailable){window.onNativeCompassAvailable($hasSensor);}", null)
                webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy($currentAccuracy);}", null)
                webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($initHeading);}", null)
                webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declFormatted, $hasDeclination, '$escapedDesc');}", null)
                webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate($currentLatitude, $currentLongitude, $currentAltitude, $hasAltitude, '$escapedCoords');}", null)
                webView.evaluateJavascript("if(window.onNativeSpeedUpdate){window.onNativeSpeedUpdate($speedFormatted);}", null)
                webView.evaluateJavascript("if(window.onNativeTiltUpdate){window.onNativeTiltUpdate($pitchStr, $rollStr);}", null)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: android.webkit.ConsoleMessage?): Boolean {
                consoleMessage?.let {
                    Log.d(TAG, "JS [${it.messageLevel()}]: ${it.message()} (${it.sourceId()}:${it.lineNumber()})")
                }
                return true
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?
            ) {
                callback?.invoke(origin, true, false)
            }

            override fun onPermissionRequest(request: PermissionRequest?) {
                request?.grant(request.resources)
            }
        }

        startListeningSensors()

        // 优先使用 loadDataWithBaseURL 加载，秒开且不受限于系统 WebView 资产访问限制
        try {
            val htmlContent = assets.open("yiijing_map.html").bufferedReader().use { it.readText() }
            webView.loadDataWithBaseURL("file:///android_asset/", htmlContent, "text/html", "UTF-8", null)
            Log.i(TAG, "HTML asset loaded via loadDataWithBaseURL (length=${htmlContent.length})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load HTML asset via loadDataWithBaseURL, fallback to loadUrl", e)
            webView.loadUrl("file:///android_asset/yiijing_map.html")
        }
    }

    private fun hasCompassSensor(): Boolean {
        return rotationSensor != null || (accelerometer != null && magnetometer != null) || orientationSensor != null
    }

    private var currentAccuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH

    inner class CompassJsInterface {
        @JavascriptInterface
        fun isCompassAvailable(): Boolean {
            return hasCompassSensor()
        }

        @JavascriptInterface
        fun startCompass() {
            runOnUiThread {
                startListeningSensors()
            }
        }

        @JavascriptInterface
        fun stopCompass() {
            runOnUiThread {
                stopListeningSensors()
            }
        }

        @JavascriptInterface
        fun resetCalibration() {
            runOnUiThread {
                hasSmoothHeading = false
                stopListeningSensors()
                startListeningSensors()
                webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy(1);}", null)
            }
        }

        @JavascriptInterface
        fun getDeclination(): Float {
            return currentDeclination
        }

        @JavascriptInterface
        fun hasDeclination(): Boolean {
            return hasDeclination
        }

        @JavascriptInterface
        fun getCoordsDesc(): String {
            return coordsDesc
        }

        @JavascriptInterface
        fun getLatitude(): Double {
            return currentLatitude
        }

        @JavascriptInterface
        fun getLongitude(): Double {
            return currentLongitude
        }

        @JavascriptInterface
        fun getSpeed(): Float {
            return currentSpeedKmH
        }

        @JavascriptInterface
        fun getPitch(): Float {
            return currentPitch
        }

        @JavascriptInterface
        fun getRoll(): Float {
            return currentRoll
        }

        @JavascriptInterface
        fun requestLocationPermission() {
            runOnUiThread {
                checkAndRequestLocation()
            }
        }

        @JavascriptInterface
        fun refreshLocation() {
            runOnUiThread {
                if (hasLocationPermission()) {
                    startLocationUpdates()
                } else {
                    checkAndRequestLocation()
                }
            }
        }
    }

    private var lastKnownBestLocation: Location? = null
    private var isLocationListening = false

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fineGranted || coarseGranted
    }

    private fun checkAndRequestLocation() {
        if (hasLocationPermission()) {
            startLocationUpdates()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                PERMISSION_REQUEST_LOCATION
            )
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_LOCATION) {
            val anyGranted = grantResults.isNotEmpty() && grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            if (anyGranted) {
                startLocationUpdates()
            } else {
                Log.w(TAG, "Location permissions denied by user")
            }
        }
    }

    private fun calculateSpeed(location: Location) {
        if (location.hasSpeed()) {
            currentSpeedKmH = Math.max(0f, location.speed * 3.6f)
        } else {
            val prev = lastLocationForSpeed
            if (prev != null && location.time > prev.time) {
                val dtSec = (location.time - prev.time) / 1000.0f
                if (dtSec in 0.5f..10.0f) {
                    val distMeters = location.distanceTo(prev)
                    if (distMeters > 1.2f) {
                        currentSpeedKmH = (distMeters / dtSec) * 3.6f
                    } else {
                        currentSpeedKmH = 0f
                    }
                }
            }
        }
        lastLocationForSpeed = location
    }

    private fun pushSpeedUpdate() {
        val speedFormatted = String.format(java.util.Locale.US, "%.1f", currentSpeedKmH)
        webView.post {
            webView.evaluateJavascript("if(window.onNativeSpeedUpdate){window.onNativeSpeedUpdate($speedFormatted);}", null)
        }
    }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            calculateSpeed(location)
            pushSpeedUpdate()

            if (isBetterLocation(location, lastKnownBestLocation)) {
                lastKnownBestLocation = location
                updateLocationAndDeclination(location)
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

        override fun onProviderEnabled(provider: String) {
            Log.i(TAG, "Location provider enabled: $provider")
            if (hasLocationPermission()) {
                startLocationUpdates()
            }
        }

        override fun onProviderDisabled(provider: String) {
            Log.i(TAG, "Location provider disabled: $provider")
        }
    }

    /**
     * 判断新定位是否优于或新鲜于当前最佳定位
     */
    private fun isBetterLocation(location: Location, currentBestLocation: Location?): Boolean {
        if (currentBestLocation == null) {
            return true
        }

        val timeDelta: Long = location.time - currentBestLocation.time
        val isSignificantlyNewer: Boolean = timeDelta > 15000L // 15秒后新坐标优先
        val isSignificantlyOlder: Boolean = timeDelta < -15000L
        val isNewer: Boolean = timeDelta > 0L

        if (isSignificantlyNewer) {
            return true
        } else if (isSignificantlyOlder) {
            return false
        }

        val accuracyDelta: Float = location.accuracy - currentBestLocation.accuracy
        val isLessAccurate: Boolean = accuracyDelta > 0f
        val isMoreAccurate: Boolean = accuracyDelta < 0f
        val isSignificantlyLessAccurate: Boolean = accuracyDelta > 50f

        val isFromSameProvider: Boolean = location.provider == currentBestLocation.provider

        return when {
            isMoreAccurate -> true
            isNewer && !isLessAccurate -> true
            isNewer && !isSignificantlyLessAccurate && isFromSameProvider -> true
            isNewer && location.provider == LocationManager.GPS_PROVIDER -> true
            else -> false
        }
    }

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates() {
        if (!hasLocationPermission()) return
        try {
            val mgr = locationManager ?: getSystemService(LOCATION_SERVICE) as? LocationManager ?: return
            locationManager = mgr

            // 1. 获取现有缓存中最佳的位置用于即时显示
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
            for (p in providers) {
                try {
                    if (mgr.isProviderEnabled(p)) {
                        val loc = mgr.getLastKnownLocation(p)
                        if (loc != null && (lastKnownBestLocation == null || isBetterLocation(loc, lastKnownBestLocation))) {
                            lastKnownBestLocation = loc
                            if (loc.hasSpeed()) {
                                currentSpeedKmH = Math.max(0f, loc.speed * 3.6f)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "getLastKnownLocation error for $p: ${e.message}")
                }
            }
            lastKnownBestLocation?.let {
                updateLocationAndDeclination(it)
            }

            // 2. 移除旧监听，防止重复注册
            try {
                mgr.removeUpdates(locationListener)
            } catch (_: Exception) {}

            // 3. 同时向 GPS_PROVIDER 和 NETWORK_PROVIDER 注册实时高频监听（1秒 / 0米）
            var registeredCount = 0
            if (mgr.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                try {
                    mgr.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, locationListener)
                    registeredCount++
                    Log.i(TAG, "Registered GPS_PROVIDER location updates (1000ms, 0m)")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to register GPS_PROVIDER", e)
                }
            } else {
                Log.w(TAG, "GPS_PROVIDER is disabled on device")
            }

            if (mgr.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                try {
                    mgr.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0f, locationListener)
                    registeredCount++
                    Log.i(TAG, "Registered NETWORK_PROVIDER location updates (1000ms, 0m)")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to register NETWORK_PROVIDER", e)
                }
            }

            try {
                if (mgr.isProviderEnabled(LocationManager.PASSIVE_PROVIDER)) {
                    mgr.requestLocationUpdates(LocationManager.PASSIVE_PROVIDER, 1000L, 0f, locationListener)
                    registeredCount++
                    Log.i(TAG, "Registered PASSIVE_PROVIDER location updates")
                }
            } catch (_: Exception) {}

            isLocationListening = registeredCount > 0
            Log.i(TAG, "startLocationUpdates completed, active providers: $registeredCount")
        } catch (e: Exception) {
            Log.e(TAG, "Failed in startLocationUpdates", e)
        }
    }

    private fun stopLocationUpdates() {
        if (!isLocationListening && locationManager == null) return
        try {
            locationManager?.removeUpdates(locationListener)
            isLocationListening = false
            Log.i(TAG, "stopLocationUpdates completed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop location updates", e)
        }
    }

    private fun updateLocationAndDeclination(location: Location) {
        try {
            val altitude = if (location.hasAltitude()) location.altitude.toFloat() else 0f
            val field = GeomagneticField(
                location.latitude.toFloat(),
                location.longitude.toFloat(),
                altitude,
                System.currentTimeMillis()
            )
            currentDeclination = field.declination
            hasDeclination = true

            currentLatitude = location.latitude
            currentLongitude = location.longitude
            hasAltitude = location.hasAltitude()
            currentAltitude = if (hasAltitude) location.altitude else 0.0

            // 5位小数精度（约1.1米分辨率），让走动或微移时能直观看到坐标实时刷新
            val latStr = String.format(java.util.Locale.US, "%.5f°%s", Math.abs(currentLatitude), if (currentLatitude >= 0) "N" else "S")
            val lonStr = String.format(java.util.Locale.US, "%.5f°%s", Math.abs(currentLongitude), if (currentLongitude >= 0) "E" else "W")
            val altStr = if (hasAltitude) String.format(java.util.Locale.US, " · 海拔 %.0fm", currentAltitude) else ""
            val accStr = if (location.hasAccuracy() && location.accuracy > 0f) String.format(java.util.Locale.US, " (±%.0fm)", location.accuracy) else ""
            coordsDesc = "$latStr, $lonStr$altStr$accStr"

            val dirStr = if (currentDeclination < 0) "西偏" else if (currentDeclination > 0) "东偏" else "无偏"
            locationDesc = "$latStr, $lonStr · 磁偏角 ${String.format(java.util.Locale.US, "%.1f", Math.abs(currentDeclination))}°($dirStr)"
            Log.i(TAG, "Location & declination updated: $coordsDesc (provider=${location.provider})")

            val declinationFormatted = String.format(java.util.Locale.US, "%.2f", currentDeclination)
            val escapedDesc = locationDesc.replace("'", "\\'")
            val escapedCoords = coordsDesc.replace("'", "\\'")
            val speedFormatted = String.format(java.util.Locale.US, "%.1f", currentSpeedKmH)
            webView.post {
                webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declinationFormatted, $hasDeclination, '$escapedDesc');}", null)
                webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate($currentLatitude, $currentLongitude, $currentAltitude, $hasAltitude, '$escapedCoords');}", null)
                webView.evaluateJavascript("if(window.onNativeSpeedUpdate){window.onNativeSpeedUpdate($speedFormatted);}", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating GeomagneticField or updating location", e)
        }
    }

    private var smoothSin = 0.0
    private var smoothCos = 0.0
    private var hasSmoothHeading = false
    private val adjustedMatrix = FloatArray(9)
    private var currentMagStrength = 0f
    private var lastDistortionNoticeTime = 0L

    // 陀螺仪角速度融合与抗突变状态
    private var gyroAngularSpeed = 0f // 物理角速度 (rad/s)
    private var lastGyroTimestamp = 0L

    private fun startListeningSensors() {
        if (isSensorListening) return
        var registered = false
        if (rotationSensor != null) {
            // 优先注册高精度旋转矢量传感器
            sensorManager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME)
            registered = true
            Log.i(TAG, "Registered rotationSensor")
        }
        // 注册物理陀螺仪以实现角速度惯性锁与抗突发磁干扰
        if (gyroscope != null) {
            sensorManager.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_GAME)
            Log.i(TAG, "Registered gyroscope for anti-magnetic-jolt fusion")
        }
        // 始终监听磁场传感器以实时监测环境硬磁/软磁干扰强度(μT)
        if (magnetometer != null) {
            sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_NORMAL)
        }
        if (rotationSensor == null && accelerometer != null && magnetometer != null) {
            sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
            registered = true
            Log.i(TAG, "Registered accelerometer & magnetometer")
        } else if (rotationSensor == null && orientationSensor != null) {
            sensorManager.registerListener(this, orientationSensor, SensorManager.SENSOR_DELAY_GAME)
            registered = true
            Log.i(TAG, "Registered fallback orientationSensor")
        }
        if (registered) {
            isSensorListening = true
        }
    }

    private fun stopListeningSensors() {
        if (!isSensorListening) return
        sensorManager.unregisterListener(this)
        isSensorListening = false
        hasSmoothHeading = false
        gyroAngularSpeed = 0f
        Log.i(TAG, "Stopped sensor listening")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val now = System.currentTimeMillis()

        var azimuthDegrees: Float? = null

        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            // 陀螺仪测量机身真实旋转角速度，完全不受铁磁干扰！
            val gx = event.values[0]
            val gy = event.values[1]
            val gz = event.values[2]
            gyroAngularSpeed = Math.sqrt((gx * gx + gy * gy + gz * gz).toDouble()).toFloat()
            lastGyroTimestamp = now
            return
        }

        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            updateTiltAngles(now)
            if (now - lastUpdateTimestamp < 16) return // ~60fps 刷新
            azimuthDegrees = getAccurateAzimuth(rotationMatrix)
        } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            System.arraycopy(event.values, 0, accelerometerReading, 0, accelerometerReading.size)
            hasAccData = true
            if (rotationSensor == null) {
                updateTiltAnglesFromAcc(now)
            }
            if (now - lastUpdateTimestamp < 20) return
            if (hasMagData && rotationSensor == null) {
                azimuthDegrees = calculateOrientationFromAccMag()
            }
        } else if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            System.arraycopy(event.values, 0, magnetometerReading, 0, magnetometerReading.size)
            hasMagData = true
            // 计算环境磁场总强度 (μT)
            val mx = event.values[0]
            val my = event.values[1]
            val mz = event.values[2]
            currentMagStrength = Math.sqrt((mx * mx + my * my + mz * mz).toDouble()).toFloat()
            // 正常地球表面地磁约为 30~65 μT，若靠近钢筋铁窗或强磁体常突增至 75~200+ μT
            val isDistorted = currentMagStrength > 75f || currentMagStrength < 20f
            if (now - lastDistortionNoticeTime > 800) {
                lastDistortionNoticeTime = now
                val strengthFormatted = String.format(java.util.Locale.US, "%.0f", currentMagStrength)
                webView.post {
                    webView.evaluateJavascript("if(window.onNativeMagneticFieldUpdate){window.onNativeMagneticFieldUpdate($isDistorted, $strengthFormatted);}", null)
                }
            }

            if (hasAccData && rotationSensor == null) {
                if (now - lastUpdateTimestamp < 20) return
                azimuthDegrees = calculateOrientationFromAccMag()
            }
        } else {
            @Suppress("DEPRECATION")
            if (event.sensor.type == Sensor.TYPE_ORIENTATION && rotationSensor == null) {
                if (now - lastUpdateTimestamp < 20) return
                azimuthDegrees = (event.values[0] + 360f) % 360f
            }
        }

        azimuthDegrees?.let { rawDeg ->
            val rad = Math.toRadians(rawDeg.toDouble())
            val sinVal = Math.sin(rad)
            val cosVal = Math.cos(rad)

            if (!hasSmoothHeading) {
                smoothSin = sinVal
                smoothCos = cosVal
                hasSmoothHeading = true
            } else {
                // 陀螺仪角速度自适应滤波抗磁跳变核心：
                // 如果陀螺仪显示手机基本静止（角速度 < 0.08 rad/s），但磁场出现异常或跳变，
                // 启动惯性锁保护（降低跟随权重至 0.06），牢牢压制靠近窗框时的突发磁吸偏；
                // 当手真正转动手机（角速度 >= 0.08 rad/s）时，放行高动态跟随（权重 0.38），即转即随！
                val isStatic = gyroAngularSpeed < 0.08f
                val isFieldAbnormal = currentMagStrength > 75f || currentMagStrength < 20f
                val adaptiveAlpha = when {
                    isStatic && isFieldAbnormal -> 0.04 // 靠近铁窗且静止：极大压制磁突变
                    isStatic -> 0.18                    // 原地微停：极致沉稳平滑
                    gyroAngularSpeed > 0.4f -> 0.45     // 快速转身：极速跟随
                    else -> 0.32                        // 常规旋转：兼顾平滑与极速响应
                }

                smoothSin += adaptiveAlpha * (sinVal - smoothSin)
                smoothCos += adaptiveAlpha * (cosVal - smoothCos)
            }

            val filteredDeg = (Math.toDegrees(Math.atan2(smoothSin, smoothCos)).toFloat() + 360f) % 360f
            val diff = Math.abs(filteredDeg - lastHeading)
            if (diff > 0.08f || lastHeading < 0) {
                lastHeading = filteredDeg
                lastUpdateTimestamp = now
                val formatted = String.format(java.util.Locale.US, "%.1f", filteredDeg)
                webView.post {
                    webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($formatted);}", null)
                }
            }
        }
    }

    private fun updateTiltAngles(now: Long) {
        SensorManager.getOrientation(rotationMatrix, orientationAngles)
        currentPitch = Math.toDegrees(orientationAngles[1].toDouble()).toFloat()
        currentRoll = Math.toDegrees(orientationAngles[2].toDouble()).toFloat()
        pushTiltUpdate(now)
    }

    private fun updateTiltAnglesFromAcc(now: Long) {
        val ax = accelerometerReading[0].toDouble()
        val ay = accelerometerReading[1].toDouble()
        val az = accelerometerReading[2].toDouble()
        currentPitch = Math.toDegrees(Math.atan2(-ay, Math.sqrt(ax * ax + az * az))).toFloat()
        currentRoll = Math.toDegrees(Math.atan2(ax, az)).toFloat()
        pushTiltUpdate(now)
    }

    private fun pushTiltUpdate(now: Long) {
        if (now - lastTiltUpdateTimestamp > 40) { // ~25fps 倾角更新
            val pitchDiff = Math.abs(currentPitch - lastPushedPitch)
            val rollDiff = Math.abs(currentRoll - lastPushedRoll)
            if (pitchDiff > 0.15f || rollDiff > 0.15f || now - lastTiltUpdateTimestamp > 350) {
                lastTiltUpdateTimestamp = now
                lastPushedPitch = currentPitch
                lastPushedRoll = currentRoll
                val pitchStr = String.format(java.util.Locale.US, "%.1f", currentPitch)
                val rollStr = String.format(java.util.Locale.US, "%.1f", currentRoll)
                webView.post {
                    webView.evaluateJavascript("if(window.onNativeTiltUpdate){window.onNativeTiltUpdate($pitchStr, $rollStr);}", null)
                }
            }
        }
    }

    /**
     * 水平面三维向量投影算法：彻底消除手持倾角（30°~60°）下的欧拉角万向锁与剧烈偏航跳变
     */
    private fun getAccurateAzimuth(matrix: FloatArray): Float {
        // matrix[7] 是手机 Y 轴在垂直天空方向（Z轴）上的分量 = sin(pitch)
        val sinPitch = matrix[7]
        val rad: Double
        if (Math.abs(sinPitch) > 0.85f) {
            // 当手机几乎直立立起时，重映射坐标系将 Z 轴变换为视线方向
            if (SensorManager.remapCoordinateSystem(matrix, SensorManager.AXIS_X, SensorManager.AXIS_Z, adjustedMatrix)) {
                rad = Math.atan2(adjustedMatrix[1].toDouble(), adjustedMatrix[4].toDouble())
            } else {
                rad = Math.atan2(matrix[1].toDouble(), matrix[4].toDouble())
            }
        } else {
            // 平放及自然手持（倾角 0° ~ 60°）：手机顶部轴在世界东向和北向的真实水平投影
            rad = Math.atan2(matrix[1].toDouble(), matrix[4].toDouble())
        }
        return ((Math.toDegrees(rad).toFloat() % 360f) + 360f) % 360f
    }

    private fun calculateOrientationFromAccMag(): Float? {
        val success = SensorManager.getRotationMatrix(
            rotationMatrix,
            null,
            accelerometerReading,
            magnetometerReading
        )
        if (success) {
            return getAccurateAzimuth(rotationMatrix)
        }
        return null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_ROTATION_VECTOR || sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) {
            currentAccuracy = accuracy
            webView.post {
                webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy($accuracy);}", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
        enterFullScreen()
        startListeningSensors()
        if (hasLocationPermission()) {
            startLocationUpdates()
        }
    }

    override fun onPause() {
        super.onPause()
        webView.onPause()
        stopListeningSensors()
        stopLocationUpdates()
    }

    override fun onDestroy() {
        stopListeningSensors()
        stopLocationUpdates()
        webView.destroy()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    private fun enterFullScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                )
        }
    }
}
