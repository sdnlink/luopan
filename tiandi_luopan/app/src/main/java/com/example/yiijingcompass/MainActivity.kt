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
                webView.evaluateJavascript("if(window.onNativeCompassAvailable){window.onNativeCompassAvailable($hasSensor);}", null)
                webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy($currentAccuracy);}", null)
                webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($initHeading);}", null)
                webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declFormatted, $hasDeclination, '$escapedDesc');}", null)
                webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate($currentLatitude, $currentLongitude, $currentAltitude, $hasAltitude, '$escapedCoords');}", null)
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

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
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
            webView.post {
                webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declinationFormatted, $hasDeclination, '$escapedDesc');}", null)
                webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate($currentLatitude, $currentLongitude, $currentAltitude, $hasAltitude, '$escapedCoords');}", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating GeomagneticField or updating location", e)
        }
    }

    private var smoothSin = 0.0
    private var smoothCos = 0.0
    private var hasSmoothHeading = false
    private val SMOOTHING_ALPHA = 0.12 // 0.12 带来丝滑阻尼滤波，彻底消除微抖动

    private fun startListeningSensors() {
        if (isSensorListening) return
        var registered = false
        if (rotationSensor != null) {
            // 优先且仅注册高精度旋转矢量传感器
            sensorManager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME)
            registered = true
            Log.i(TAG, "Registered rotationSensor")
        } else if (accelerometer != null && magnetometer != null) {
            // 无旋转矢量时才注册加速度计与地磁传感器
            sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
            sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_GAME)
            registered = true
            Log.i(TAG, "Registered accelerometer & magnetometer")
        } else if (orientationSensor != null) {
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
        Log.i(TAG, "Stopped sensor listening")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val now = System.currentTimeMillis()
        if (now - lastUpdateTimestamp < 20) return // ~50fps 均匀刷新

        var azimuthDegrees: Float? = null

        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientationAngles)
            val azimuthRad = orientationAngles[0]
            azimuthDegrees = (Math.toDegrees(azimuthRad.toDouble()).toFloat() + 360f) % 360f
        } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            System.arraycopy(event.values, 0, accelerometerReading, 0, accelerometerReading.size)
            hasAccData = true
            if (hasMagData) {
                azimuthDegrees = calculateOrientationFromAccMag()
            }
        } else if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            System.arraycopy(event.values, 0, magnetometerReading, 0, magnetometerReading.size)
            hasMagData = true
            if (hasAccData) {
                azimuthDegrees = calculateOrientationFromAccMag()
            }
        } else {
            @Suppress("DEPRECATION")
            if (event.sensor.type == Sensor.TYPE_ORIENTATION) {
                azimuthDegrees = (event.values[0] + 360f) % 360f
            }
        }

        azimuthDegrees?.let { rawDeg ->
            // 圆周平滑低通滤波（利用 sin/cos 分解解决 0°/360° 跨越跳变）
            val rad = Math.toRadians(rawDeg.toDouble())
            val sinVal = Math.sin(rad)
            val cosVal = Math.cos(rad)

            if (!hasSmoothHeading) {
                smoothSin = sinVal
                smoothCos = cosVal
                hasSmoothHeading = true
            } else {
                smoothSin += SMOOTHING_ALPHA * (sinVal - smoothSin)
                smoothCos += SMOOTHING_ALPHA * (cosVal - smoothCos)
            }

            val filteredDeg = (Math.toDegrees(Math.atan2(smoothSin, smoothCos)).toFloat() + 360f) % 360f
            val diff = Math.abs(filteredDeg - lastHeading)
            if (diff > 0.15f || lastHeading < 0) {
                lastHeading = filteredDeg
                lastUpdateTimestamp = now
                val formatted = String.format(java.util.Locale.US, "%.1f", filteredDeg)
                webView.post {
                    webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($formatted);}", null)
                }
            }
        }
    }

    private fun calculateOrientationFromAccMag(): Float? {
        val success = SensorManager.getRotationMatrix(
            rotationMatrix,
            null,
            accelerometerReading,
            magnetometerReading
        )
        if (success) {
            SensorManager.getOrientation(rotationMatrix, orientationAngles)
            val azimuthRad = orientationAngles[0]
            return (Math.toDegrees(azimuthRad.toDouble()).toFloat() + 360f) % 360f
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
