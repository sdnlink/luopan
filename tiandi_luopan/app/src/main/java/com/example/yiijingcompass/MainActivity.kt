package com.example.yiijingcompass

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.webkit.*
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.bridge.AppWebBridge
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.CompassMotionManager

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "YiJingCompass"
        private const val PERMISSION_REQUEST_LOCATION = 1002
        private const val PERMISSION_REQUEST_CAMERA = 1003
        private const val PERMISSION_REQUEST_STORAGE = 1004
    }

    private lateinit var webView: WebView
    private val motion = CompassMotionManager.instance
    private lateinit var bridge: AppWebBridge

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_main)

        // Initialize core models and persistence
        LocalizationManager.instance.init(this)
        ShaSurveyStore.instance.init(this)
        CompassLayerManager.instance.init(this)
        UserEntitlementsManager.instance.init(this)
        com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.init(this)

        webView = findViewById(R.id.webview)
        webView.setBackgroundColor(android.graphics.Color.parseColor("#121216"))
        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false

        // WebView configuration
        val settings: WebSettings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.allowFileAccess = true
        settings.allowContentAccess = false
        @Suppress("DEPRECATION")
        settings.allowFileAccessFromFileURLs = false
        @Suppress("DEPRECATION")
        settings.allowUniversalAccessFromFileURLs = false
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.mediaPlaybackRequiresUserGesture = false
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

        bridge = AppWebBridge(this, webView)
        webView.addJavascriptInterface(bridge, "AndroidCompass")
        webView.addJavascriptInterface(bridge, "AndroidBridge")
        webView.addJavascriptInterface(CompassJsInterfaceCompat(), "AndroidCompat")

        checkAndRequestLocation()

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false
                if (url.startsWith("alipays://") || url.startsWith("weixin://") || url.startsWith("upwallet://")) {
                    return try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        startActivity(intent)
                        true
                    } catch (e: Exception) {
                        Log.w(TAG, "External payment app not found for $url", e)
                        true
                    }
                }
                return super.shouldOverrideUrlLoading(view, request)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                val hasSensor = motion.hasSensors(this@MainActivity)
                val initHeading = motion.heading
                val declFormatted = String.format(java.util.Locale.US, "%.2f", motion.currentDeclination)
                val escapedCoords = motion.coordsDesc.replace("'", "\\'")
                val speedFormatted = String.format(java.util.Locale.US, "%.1f", motion.speedKmH)
                val pitchStr = String.format(java.util.Locale.US, "%.1f", motion.pitch)
                val rollStr = String.format(java.util.Locale.US, "%.1f", motion.roll)

                webView.evaluateJavascript("if(window.onNativeCompassAvailable){window.onNativeCompassAvailable($hasSensor);}", null)
                webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy(${motion.accuracyLevel});}", null)
                webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($initHeading);}", null)
                webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declFormatted, ${motion.hasDeclination}, '磁偏角 $declFormatted°');}", null)
                webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate(${motion.latitude}, ${motion.longitude}, ${motion.altitude}, true, '$escapedCoords');}", null)
                webView.evaluateJavascript("if(window.onNativeSpeedUpdate){window.onNativeSpeedUpdate($speedFormatted);}", null)
                webView.evaluateJavascript("if(window.onNativeTiltUpdate){window.onNativeTiltUpdate($pitchStr, $rollStr);}", null)
                val sysLang = LocalizationManager.instance.effectiveLanguage.rawValue
                webView.evaluateJavascript("if(window.onSystemLanguageUpdate){window.onSystemLanguageUpdate('$sysLang');}", null)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                consoleMessage?.let {
                    Log.d(TAG, "JS [${it.messageLevel()}]: ${it.message()} (${it.sourceId()}:${it.lineNumber()})")
                }
                return true
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?
            ) {
                val trustedOrigin = origin?.startsWith("file:///android_asset/") == true
                callback?.invoke(origin, trustedOrigin, false)
            }

            override fun onPermissionRequest(request: PermissionRequest?) {
                if (request == null) return
                val trustedOrigin = request.origin?.toString()?.startsWith("file:///android_asset/") == true
                val cameraRequested = request.resources?.contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE) == true
                val cameraGranted = ContextCompat.checkSelfPermission(
                    this@MainActivity,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                if (trustedOrigin && cameraRequested && cameraGranted) {
                    request.grant(arrayOf(PermissionRequest.RESOURCE_VIDEO_CAPTURE))
                } else {
                    request.deny()
                }
            }
        }

        motion.start(this)

        try {
            val htmlContent = assets.open("yiijing_map.html").bufferedReader().use { it.readText() }
            webView.loadDataWithBaseURL("file:///android_asset/", htmlContent, "text/html", "UTF-8", null)
            Log.i(TAG, "HTML asset loaded via loadDataWithBaseURL (length=${htmlContent.length})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load HTML asset via loadDataWithBaseURL, fallback to loadUrl", e)
            webView.loadUrl("file:///android_asset/yiijing_map.html")
        }
    }

    override fun onResume() {
        super.onResume()
        motion.start(this)
    }

    override fun onPause() {
        super.onPause()
        motion.stop()
    }

    override fun onDestroy() {
        super.onDestroy()
        bridge.destroy()
        motion.stop()
    }

    fun checkAndRequestLocation() {
        val fineLocationGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseLocationGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fineLocationGranted && !coarseLocationGranted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                PERMISSION_REQUEST_LOCATION
            )
        }
    }

    fun checkAndRequestCamera() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                PERMISSION_REQUEST_CAMERA
            )
        } else {
            webView.evaluateJavascript("if(window.onNativeCameraGranted){window.onNativeCameraGranted();}", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            PERMISSION_REQUEST_LOCATION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    motion.start(this)
                } else {
                    webView.evaluateJavascript("if(window.onNativeLocationDisabled){window.onNativeLocationDisabled();}", null)
                }
            }
            PERMISSION_REQUEST_CAMERA -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    webView.evaluateJavascript("if(window.onNativeCameraGranted){window.onNativeCameraGranted();}", null)
                } else {
                    webView.evaluateJavascript("if(window.onNativeCameraDenied){window.onNativeCameraDenied();}", null)
                }
            }
        }
    }

    inner class CompassJsInterfaceCompat {
        @JavascriptInterface
        fun requestLocationPermission() {
            runOnUiThread { checkAndRequestLocation() }
        }

        @JavascriptInterface
        fun requestCameraPermission() {
            runOnUiThread { checkAndRequestCamera() }
        }

        @JavascriptInterface
        fun hasCameraPermission(): Boolean {
            return ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        }

        @JavascriptInterface
        fun saveImageToGallery(base64Data: String): Boolean {
            return try {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                    ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                ) {
                    runOnUiThread {
                        ActivityCompat.requestPermissions(
                            this@MainActivity,
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            PERMISSION_REQUEST_STORAGE
                        )
                        Toast.makeText(this@MainActivity, "请允许存储权限后再次保存图片。", Toast.LENGTH_SHORT).show()
                    }
                    return false
                }
                val cleanBase64 = if (base64Data.contains(",")) base64Data.substringAfter(",") else base64Data
                val bytes = Base64.decode(cleanBase64, Base64.DEFAULT)
                val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return false
                TianJiShuEngine.instance.saveToGallery(this@MainActivity, bitmap)
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }

        @JavascriptInterface
        fun requestNativePayment(channel: String, orderJson: String) {
            runOnUiThread {
                Log.i(TAG, "Native payment requested: channel=$channel, order=$orderJson")
                var launched = false
                when (channel) {
                    "alipay" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("alipays://platformapi/startapp"))
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {
                            Log.w(TAG, "Alipay not installed", e)
                        }
                    }
                    "wechat" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("weixin://"))
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {
                            Log.w(TAG, "WeChat not installed", e)
                        }
                    }
                    "unionpay" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upwallet://"))
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {
                            Log.w(TAG, "UnionPay app not installed", e)
                        }
                    }
                }
                if (launched) {
                    webView.evaluateJavascript("if(window.onNativePaymentPending){window.onNativePaymentPending('$channel');}", null)
                } else {
                    webView.evaluateJavascript("if(window.onNativePaymentResult){window.onNativePaymentResult('$channel', false, '');}", null)
                }
            }
        }
    }
}
