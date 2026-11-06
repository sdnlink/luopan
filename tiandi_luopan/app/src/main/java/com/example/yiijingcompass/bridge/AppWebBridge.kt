package com.example.yiijingcompass.bridge

import android.app.Activity
import android.content.Context
import android.graphics.PointF
import android.graphics.RectF
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.widget.Toast
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.CompassMotionListener
import com.example.yiijingcompass.sensor.CompassMotionManager
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.Locale

class AppWebBridge(
    private val activity: Activity,
    private val webView: WebView
) : CompassMotionListener {

    private val motion = CompassMotionManager.instance

    private val billingListener = object : com.example.yiijingcompass.billing.GooglePlayBillingManager.BillingEventListener {
        override fun onBillingServiceConnected() {
            syncIapStatus()
        }

        override fun onProductDetailsUpdated(products: Map<String, com.android.billingclient.api.ProductDetails>) {
            syncProductDetailsToWeb()
        }

        override fun onPurchaseSuccess(productId: String, orderId: String) {
            activity.runOnUiThread {
                Toast.makeText(activity, LocalizationManager.instance.t("iap_purchase_success"), Toast.LENGTH_LONG).show()
                val statusJson = UserEntitlementsManager.instance.getStatusJson()
                webView.evaluateJavascript("if(window.onNativeIAPPurchaseSuccess){window.onNativeIAPPurchaseSuccess('$productId', '$orderId');}", null)
                webView.evaluateJavascript("if(window.onNativeIAPStatusUpdate){window.onNativeIAPStatusUpdate($statusJson);}", null)
                webView.evaluateJavascript("if(window.onNativePaymentResult){window.onNativePaymentResult('googleplay', true, '$productId');}", null)
            }
        }

        override fun onPurchaseFailed(productId: String?, errorCode: Int, message: String) {
            activity.runOnUiThread {
                if (errorCode != com.android.billingclient.api.BillingClient.BillingResponseCode.USER_CANCELED) {
                    val failMsg = String.format(LocalizationManager.instance.t("iap_purchase_failed_fmt"), message)
                    Toast.makeText(activity, failMsg, Toast.LENGTH_SHORT).show()
                }
                webView.evaluateJavascript("if(window.onNativePaymentResult){window.onNativePaymentResult('googleplay', false, '$message');}", null)
            }
        }

        override fun onPurchasesRestored(restoredProductIds: List<String>) {
            activity.runOnUiThread {
                val statusJson = UserEntitlementsManager.instance.getStatusJson()
                val count = restoredProductIds.size
                val restoreMsg = if (count > 0) LocalizationManager.instance.t("iap_restore_success") else LocalizationManager.instance.t("iap_restore_empty")
                Toast.makeText(activity, restoreMsg, Toast.LENGTH_SHORT).show()
                webView.evaluateJavascript("if(window.onNativeIAPStatusUpdate){window.onNativeIAPStatusUpdate($statusJson);}", null)
            }
        }
    }

    init {
        motion.addListener(this)
        com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.addListener(billingListener)
    }

    fun destroy() {
        motion.removeListener(this)
        com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.removeListener(billingListener)
    }

    // --- CompassMotionListener updates pushing to WebView ---
    override fun onHeadingUpdate(heading: Double, trueHeading: Double, magneticHeading: Double, headingState: CompassHeadingState) {
        activity.runOnUiThread {
            val formatted = String.format(Locale.US, "%.1f", heading)
            webView.evaluateJavascript("if(window.onNativeHeadingUpdate){window.onNativeHeadingUpdate($formatted);}", null)
        }
    }

    override fun onTiltUpdate(pitch: Float, roll: Float, isLevel: Boolean) {
        activity.runOnUiThread {
            val pitchStr = String.format(Locale.US, "%.1f", pitch)
            val rollStr = String.format(Locale.US, "%.1f", roll)
            webView.evaluateJavascript("if(window.onNativeTiltUpdate){window.onNativeTiltUpdate($pitchStr, $rollStr);}", null)
        }
    }

    override fun onLocationUpdate(lat: Double, lon: Double, alt: Double, speedKmH: Float, coordsDesc: String) {
        activity.runOnUiThread {
            val declFormatted = String.format(Locale.US, "%.1f", motion.currentDeclination)
            val speedFormatted = String.format(Locale.US, "%.1f", speedKmH)
            val escapedCoords = coordsDesc.replace("'", "\\'")
            val lang = LocalizationManager.instance.effectiveLanguage
            val escapedDesc = when (lang) {
                AppLanguage.EN -> "Declination ${declFormatted}°"
                AppLanguage.ZH_HANT -> "磁偏角補償 ${declFormatted}°"
                AppLanguage.JA -> "磁気偏角補正 ${declFormatted}°"
                AppLanguage.KO -> "자기편각 보정 ${declFormatted}°"
                AppLanguage.VI -> "Bù độ lệch từ ${declFormatted}°"
                AppLanguage.TH -> "ชดเชยมุมบ่ายเบนแม่เหล็ก ${declFormatted}°"
                AppLanguage.ID -> "Kompensasi Deklinasi ${declFormatted}°"
                else -> "磁偏角补偿 ${declFormatted}°"
            }

            webView.evaluateJavascript("if(window.onNativeDeclinationUpdate){window.onNativeDeclinationUpdate($declFormatted, true, '$escapedDesc');}", null)
            webView.evaluateJavascript("if(window.onNativeLocationUpdate){window.onNativeLocationUpdate($lat, $lon, $alt, true, '$escapedCoords');}", null)
            webView.evaluateJavascript("if(window.onNativeSpeedUpdate){window.onNativeSpeedUpdate($speedFormatted);}", null)
        }
    }

    override fun onSolarTimeUpdate(solarTimeStr: String, solarTerm: String) {
        activity.runOnUiThread {
            webView.evaluateJavascript("if(window.onNativeSolarTimeUpdate){window.onNativeSolarTimeUpdate('$solarTimeStr', '$solarTerm');}", null)
        }
    }

    override fun onMagneticFieldUpdate(isDistorted: Boolean, strengthUT: Float) {
        activity.runOnUiThread {
            val strengthFormatted = String.format(Locale.US, "%.1f", strengthUT)
            webView.evaluateJavascript("if(window.onNativeMagneticFieldUpdate){window.onNativeMagneticFieldUpdate($isDistorted, $strengthFormatted);}", null)
        }
    }

    override fun onAccuracyChange(accuracy: Int) {
        activity.runOnUiThread {
            webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy($accuracy);}", null)
        }
    }

    // --- JavascriptInterface endpoints ---

    @JavascriptInterface
    fun isCompassAvailable(): Boolean {
        return motion.hasSensors(activity)
    }

    @JavascriptInterface
    fun startCompass() {
        activity.runOnUiThread {
            motion.start(activity)
        }
    }

    @JavascriptInterface
    fun stopCompass() {
        activity.runOnUiThread {
            motion.stop()
        }
    }

    @JavascriptInterface
    fun resetCalibration() {
        activity.runOnUiThread {
            motion.stop()
            motion.start(activity)
            webView.evaluateJavascript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy(1);}", null)
        }
    }

    @JavascriptInterface
    fun getDeclination(): Float = motion.currentDeclination

    @JavascriptInterface
    fun hasDeclination(): Boolean = motion.hasDeclination

    @JavascriptInterface
    fun getCoordsDesc(): String = motion.coordsDesc

    @JavascriptInterface
    fun getLatitude(): Double = motion.latitude

    @JavascriptInterface
    fun getLongitude(): Double = motion.longitude

    @JavascriptInterface
    fun getSpeed(): Float = motion.speedKmH

    @JavascriptInterface
    fun getPitch(): Float = motion.pitch

    @JavascriptInterface
    fun getRoll(): Float = motion.roll

    @JavascriptInterface
    fun getSystemLanguage(): String {
        return LocalizationManager.instance.effectiveLanguage.rawValue
    }

    @JavascriptInterface
    fun getFenjin120Database(): String {
        return try {
            val list = Fenjin120Data.instance.allFenjin
            val arr = JSONArray()
            for (f in list) {
                arr.put(JSONObject().apply {
                    put("mountainName", f.mountainName)
                    put("localizedMountainName", f.localizedMountainName)
                    put("index", f.index)
                    put("jiaziName", f.jiaziName)
                    put("localizedJiaziName", f.localizedJiaziName)
                    put("startAngle", f.startAngle)
                    put("endAngle", f.endAngle)
                    put("centerAngle", f.centerAngle)
                    put("grade", f.grade)
                    put("localizedGrade", f.localizedGrade)
                    put("isAuspicious", f.isAuspicious)
                    put("lore", f.lore)
                    put("localizedLore", f.localizedLore)
                })
            }
            arr.toString()
        } catch (e: Exception) {
            "[]"
        }
    }

    @JavascriptInterface
    fun getNorthReference(): String {
        return motion.northReference.rawValue
    }

    @JavascriptInterface
    fun setNorthReference(ref: String): Boolean {
        motion.northReference = com.example.yiijingcompass.sensor.CompassNorthReference.from(ref)
        return true
    }

    @JavascriptInterface
    fun isHapticEnabled(): Boolean {
        return motion.isHapticEnabled
    }

    @JavascriptInterface
    fun setHapticEnabled(enabled: Boolean): Boolean {
        motion.isHapticEnabled = enabled
        return true
    }

    @JavascriptInterface
    fun triggerHaptic(type: String) {
        when (type) {
            "tick" -> motion.triggerTick()
            "click" -> motion.triggerClick()
            else -> motion.triggerClick()
        }
    }

    // 1. 罗盘全息元数据与空亡分金接口
    @JavascriptInterface
    fun getCompassHeadingStateJson(): String {
        val state = motion.headingState
        val obj = JSONObject().apply {
            put("heading", motion.heading)
            put("sittingMountain", state.sittingMountain.name)
            put("sittingMountainLocalized", state.sittingMountain.localizedName)
            put("sittingPalace", state.sittingMountain.palace)
            put("sittingPalaceLocalized", state.sittingMountain.localizedPalace)
            put("facingMountain", state.facingMountain.name)
            put("facingMountainLocalized", state.facingMountain.localizedName)
            put("facingPalace", state.facingMountain.palace)
            put("facingPalaceLocalized", state.facingMountain.localizedPalace)
            put("facingFenjin", JSONObject().apply {
                put("jiaziName", state.facingFenjin.jiaziName)
                put("localizedJiaziName", state.facingFenjin.localizedJiaziName)
                put("grade", state.facingFenjin.grade)
                put("localizedGrade", state.facingFenjin.localizedGrade)
                put("centerAngle", state.facingFenjin.centerAngle)
                put("isAuspicious", state.facingFenjin.isAuspicious)
                put("lore", state.facingFenjin.lore)
                put("localizedLore", state.facingFenjin.localizedLore)
            })
            put("kongWangLevel", state.kongWangLevel.name)
            put("kongWangTitle", state.kongWangLevel.localizedTitle)
            put("kongWangDesc", state.kongWangLevel.localizedDescription)
            val hex = Hexagram64Data.instance.hexagram(motion.heading)
            put("hexagram", JSONObject().apply {
                put("name", hex.name)
                put("localizedName", hex.localizedName)
                put("luckDegree", hex.luckDegree)
                put("localizedLuckDegree", hex.localizedLuckDegree)
                put("fenJinDetail", hex.fenJinDetail)
                put("localizedFenJinDetail", hex.localizedFenJinDetail)
                put("elementNumber", hex.elementNumber)
                put("upperTrigram", hex.upperTrigram)
                put("lowerTrigram", hex.lowerTrigram)
                put("localizedUpperTrigram", hex.localizedUpperTrigram)
                put("localizedLowerTrigram", hex.localizedLowerTrigram)
            })
        }
        return obj.toString()
    }

    // 2. 玄空九宫飞星排盘计算
    @JavascriptInterface
    fun calculateXuanKongJson(period: Int, sittingName: String, facingName: String, useTiGua: Boolean): String {
        val mList = Mountain24Data.instance.mountains
        val sitting = mList.firstOrNull { it.name == sittingName } ?: mList[0]
        val facing = mList.firstOrNull { it.name == facingName } ?: mList[12]
        val chart = FlyingStarsEngine.instance.calculateChart(
            period = if (period in 1..9) period else null,
            sitting = sitting,
            facing = facing,
            useTiGua = useTiGua
        )
        val obj = JSONObject().apply {
            put("period", chart.period)
            put("sittingMountain", chart.sittingMountain)
            put("facingMountain", chart.facingMountain)
            put("patternType", chart.patternType)
            put("patternDesc", chart.patternDesc)
            put("chartModeTitle", chart.chartModeTitle)
            put("isSanBanGua", chart.isSanBanGua)
            put("isQiXingDaJie", chart.isQiXingDaJie)
            put("isTiGua", chart.isTiGua)
            put("summaryAnalysis", chart.summaryAnalysis)
            put("wealthAdvice", chart.wealthAdvice)
            put("healthAdvice", chart.healthAdvice)
            put("remedyAdvice", chart.remedyAdvice)
            val palacesArr = JSONArray()
            for (p in chart.palaces) {
                palacesArr.put(JSONObject().apply {
                    put("id", p.id)
                    put("palaceName", p.palaceName)
                    put("localizedPalaceName", p.localizedPalaceName)
                    put("direction", p.direction)
                    put("periodStar", p.periodStar)
                    put("mountainStar", p.mountainStar)
                    put("facingStar", p.facingStar)
                    put("element", p.element)
                    put("localizedElement", p.localizedElement)
                    put("isWangMountain", p.isWangMountain)
                    put("isWangFacing", p.isWangFacing)
                    put("isShaWuHuang", p.isShaWuHuang)
                    put("isShaErHei", p.isShaErHei)
                    put("evaluation", p.baseEvaluation)
                    put("localizedEvaluation", p.localizedEvaluation)
                })
            }
            put("palaces", palacesArr)
        }
        return obj.toString()
    }

    // 3. 八宅风水计算
    @JavascriptInterface
    fun calculateBaZhaiJson(sittingGua: String, facingGua: String): String {
        val result = BaZhaiEngine.instance.analyze(sittingGua, facingGua)
        val obj = JSONObject().apply {
            put("houseGua", result.localizedHouseGua)
            put("houseType", result.localizedHouseType)
            put("gateDirection", result.localizedGateDirection)
            put("gateStar", result.gateStar.localizedName)
            val itemsArr = JSONArray()
            for (it in result.items) {
                itemsArr.put(JSONObject().apply {
                    put("direction", it.localizedDirection)
                    put("guaName", it.guaName)
                    put("star", it.star.localizedName)
                    put("suggestion", it.localizedSuggestion)
                    put("isAuspicious", it.star.isAuspicious)
                })
            }
            put("items", itemsArr)
        }
        return obj.toString()
    }

    // 4. 紫白九星客星飞布
    @JavascriptInterface
    fun calculatePurpleWhiteJson(): String {
        val chart = PurpleWhiteEngine.instance.calculateChart(heading = motion.heading)
        val obj = JSONObject().apply {
            put("year", chart.year)
            put("month", chart.month)
            put("yearCentralStar", chart.yearCentralStar)
            put("monthCentralStar", chart.monthCentralStar)
            put("taiSui", chart.taiSuiDescription)
            put("suiPo", chart.suiPoDescription)
            put("sanSha", chart.sanShaDescription)
            val itemsArr = JSONArray()
            for (p in chart.palaceItems) {
                itemsArr.put(JSONObject().apply {
                    put("palaceId", p.palaceId)
                    put("palaceName", p.palaceName)
                    put("direction", p.direction)
                    put("yearGuestStar", p.yearGuestStar)
                    put("monthGuestStar", p.monthGuestStar)
                    put("starName", p.starName)
                    put("isDanger25", p.isDanger25)
                    put("isTaiSui", p.isTaiSui)
                    put("isSuiPo", p.isSuiPo)
                    put("isSanSha", p.isSanSha)
                    put("advice", p.advice)
                })
            }
            put("palaceItems", itemsArr)
        }
        return obj.toString()
    }

    // 5. 时家奇门遁甲计算
    @JavascriptInterface
    fun calculateQimenJson(): String {
        val chart = QimenEngine.instance.calculateChart(heading = motion.heading)
        val obj = JSONObject().apply {
            put("title", chart.title)
            put("dunType", chart.dunType)
            put("juNumber", chart.juNumber)
            put("shichen", chart.shichen)
            put("bestDirection", chart.bestDirection)
            put("bestReason", chart.bestReason)
            put("worstDirection", chart.worstDirection)
            put("worstReason", chart.worstReason)
            val cellsArr = JSONArray()
            for (c in chart.cells) {
                cellsArr.put(JSONObject().apply {
                    put("id", c.id)
                    put("palaceName", c.palaceName)
                    put("localizedPalaceName", c.localizedPalaceName)
                    put("direction", c.direction)
                    put("doorName", c.doorName)
                    put("localizedDoorName", c.localizedDoorName)
                    put("starName", c.starName)
                    put("localizedStarName", c.localizedStarName)
                    put("godName", c.godName)
                    put("localizedGodName", c.localizedGodName)
                    put("tianPanGan", c.tianPanGan)
                    put("localizedTianStem", c.localizedTianStem)
                    put("diPanGan", c.diPanGan)
                    put("localizedDiStem", c.localizedDiStem)
                    put("isAuspicious", c.isAuspicious)
                    put("luckType", c.luckType)
                    put("isCenter", c.isCenter)
                })
            }
            put("cells", cellsArr)
        }
        return obj.toString()
    }

    // 6. 外环境形煞 48 种数据库与标注记录管理
    @JavascriptInterface
    fun getExteriorShaDatabase(): String {
        val list = ExteriorShaEngine.instance.database
        val arr = JSONArray()
        for (item in list) {
            arr.put(JSONObject().apply {
                put("id", item.id)
                put("name", item.localizedName)
                put("aliases", item.localizedAliases)
                put("visualFeature", item.localizedVisualFeature)
                put("metaphysicsHarm", item.localizedMetaphysicsHarm)
                put("severity", item.severity.name)
                put("severityTitle", item.severity.localizedTitle)
                put("classicalText", item.localizedClassicalText)
                put("remedySolution", item.localizedRemedySolution)
            })
        }
        return arr.toString()
    }

    @JavascriptInterface
    fun addShaRecord(shaID: String, bearing: Double, distance: Float, note: String): String {
        val record = ExteriorShaRecord(
            shaID = shaID,
            bearingDegrees = bearing,
            capturedHeadingDegrees = motion.heading,
            distanceMeters = if (distance > 0f) distance else null,
            note = note.ifEmpty { null }
        )
        ShaSurveyStore.instance.addRecord(record)
        return record.id
    }

    @JavascriptInterface
    fun removeShaRecord(id: String): Boolean {
        ShaSurveyStore.instance.removeRecord(id)
        return true
    }

    @JavascriptInterface
    fun removeLastShaRecord(): Boolean {
        ShaSurveyStore.instance.removeLastRecord()
        return true
    }

    @JavascriptInterface
    fun clearShaRecords(): Boolean {
        ShaSurveyStore.instance.clearRecords()
        return true
    }

    @JavascriptInterface
    fun getShaRecordsJson(): String {
        val store = ShaSurveyStore.instance
        val arr = JSONArray()
        for (r in store.records) {
            arr.put(r.toJsonObject())
        }
        return arr.toString()
    }

    // 7. 户型立极与 DXF 导出
    @JavascriptInterface
    fun analyze3DSpatialHouse(spatialDataJson: String): String {
        return try {
            val root = JSONObject(spatialDataJson)
            val wallsArr = root.optJSONArray("walls") ?: JSONArray()
            val walls = mutableListOf<SpatialWall3D>()
            for (i in 0 until wallsArr.length()) {
                val w = wallsArr.getJSONObject(i)
                walls.add(
                    SpatialWall3D(
                        startX = w.optDouble("startX", 0.0).toFloat(),
                        startY = w.optDouble("startY", 0.0).toFloat(),
                        startZ = w.optDouble("startZ", 0.0).toFloat(),
                        endX = w.optDouble("endX", 0.0).toFloat(),
                        endY = w.optDouble("endY", 0.0).toFloat(),
                        endZ = w.optDouble("endZ", 0.0).toFloat(),
                        height = w.optDouble("height", 2.8).toFloat(),
                        thickness = w.optDouble("thickness", 0.2).toFloat(),
                        isLoadBearing = w.optBoolean("isLoadBearing", false)
                    )
                )
            }
            val survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(
                scanMethod = "AR_LiDAR",
                walls = walls,
                openings = emptyList(),
                beams = emptyList(),
                rooms = emptyList(),
                objects = emptyList(),
                compassHeading = motion.heading
            )
            ShaSurveyStore.instance.updateInterior(survey)

            val shaArr = JSONArray()
            for (item in survey.shaItems) {
                shaArr.put(JSONObject().apply {
                    put("id", item.id)
                    put("title", item.title)
                    put("severity", item.severity.localizedTitle)
                    put("severityCode", item.severity.rawValue)
                    put("location", item.locationName)
                    put("detail", item.detail)
                    put("lore", item.fengshuiLore)
                    put("solution", item.solution)
                })
            }

            JSONObject().apply {
                put("score", survey.fengshuiScore)
                put("centroidX", survey.centroidX)
                put("centroidZ", survey.centroidZ)
                put("shaItems", shaArr)
            }.toString()
        } catch (e: Exception) {
            JSONObject().apply {
                put("score", 88)
                put("shaItems", JSONArray())
            }.toString()
        }
    }

    @JavascriptInterface
    fun auditFloorplanJson(roomsJson: String): String {
        return try {
            val array = JSONArray(roomsJson)
            val rooms = mutableListOf<FloorplanRoom>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val id = obj.optString("id", "r$i")
                val typeStr = obj.optString("type", "UNKNOWN")
                val type = try { FloorplanRoomType.valueOf(typeStr) } catch (_: Exception) { FloorplanRoomType.UNKNOWN }
                val name = obj.optString("name", "").ifEmpty { type.localizedName }
                val l = obj.optDouble("left", 0.0).toFloat()
                val t = obj.optDouble("top", 0.0).toFloat()
                val r = obj.optDouble("right", 100.0).toFloat()
                val b = obj.optDouble("bottom", 100.0).toFloat()
                val ptsArray = obj.optJSONArray("polygonPoints")
                val pts = if (ptsArray != null && ptsArray.length() >= 3) {
                    val pList = mutableListOf<PointF>()
                    for (j in 0 until ptsArray.length()) {
                        val p = ptsArray.getJSONObject(j)
                        pList.add(PointF(p.optDouble("x", 0.0).toFloat(), p.optDouble("y", 0.0).toFloat()))
                    }
                    pList
                } else null
                rooms.add(FloorplanRoom(id, name, type, RectF(l, t, r, b), polygonPoints = pts))
            }
            val centroid = FloorplanEngine.instance.computeCentroid(rooms)
            val audited = FloorplanEngine.instance.auditFloorplan(rooms, centroid, motion.heading)
            val reportArr = JSONArray()
            for (item in audited.second) {
                reportArr.put(JSONObject().apply {
                    put("id", item.id)
                    put("title", item.title)
                    put("palace", item.palace)
                    put("severity", item.localizedSeverity)
                    put("severityCode", item.severity)
                    put("lore", item.lore)
                    put("solution", item.solution)
                })
            }
            reportArr.toString()
        } catch (e: Exception) {
            "[]"
        }
    }

    @JavascriptInterface
    fun exportCAD_DXF(roomsJson: String): String {
        val rooms = if (roomsJson.isNotEmpty() && roomsJson != "[]") {
            try {
                val array = JSONArray(roomsJson)
                val list = mutableListOf<FloorplanRoom>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.optString("id", "r$i")
                    val typeStr = obj.optString("type", "UNKNOWN")
                    val type = try { FloorplanRoomType.valueOf(typeStr) } catch (_: Exception) { FloorplanRoomType.UNKNOWN }
                    val name = obj.optString("name", "").ifEmpty { type.localizedName }
                    val l = obj.optDouble("left", 0.0).toFloat()
                    val t = obj.optDouble("top", 0.0).toFloat()
                    val r = obj.optDouble("right", 100.0).toFloat()
                    val b = obj.optDouble("bottom", 100.0).toFloat()
                    list.add(FloorplanRoom(id, name, type, RectF(l, t, r, b)))
                }
                list
            } catch (_: Exception) {
                FloorplanEngine.instance.generateSampleRooms()
            }
        } else {
            FloorplanEngine.instance.generateSampleRooms()
        }
        val centroid = FloorplanEngine.instance.computeCentroid(rooms)
        return FloorplanEngine.instance.exportDXF(rooms, centroid)
    }

    // 8. 宣纸长卷超高清生成与相册保存
    @JavascriptInterface
    fun generateAndSaveTianJiScroll(): Boolean {
        return try {
            val sampleRooms = FloorplanEngine.instance.generateSampleRooms()
            val centroid = FloorplanEngine.instance.computeCentroid(sampleRooms)
            val audited = FloorplanEngine.instance.auditFloorplan(sampleRooms, centroid, motion.heading)

            val bmp = TianJiShuEngine.instance.generateScrollImage(
                context = activity,
                heading = motion.heading,
                coordsDesc = motion.coordsDesc,
                solarTimeDesc = "${SolarTimeCalculator.instance.calculate(Date(), motion.longitude).trueSolarTimeString} (${SolarTimeCalculator.instance.solarTermName()})",
                floorplanReport = audited.second,
                panoramaArchive = ShaSurveyStore.instance.archive,
                isPro = UserEntitlementsManager.instance.isVip,
                language = LocalizationManager.instance.effectiveLanguage
            )
            val feedback = TianJiShuEngine.instance.saveToGalleryWithFeedback(activity, bmp)
            activity.runOnUiThread {
                Toast.makeText(activity, feedback.second, Toast.LENGTH_LONG).show()
            }
            feedback.first
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // 9. 会员与特权
    @JavascriptInterface
    fun isUserVip(): Boolean = UserEntitlementsManager.instance.isVip

    @JavascriptInterface
    fun upgradeVipLevel(level: String): Boolean {
        return try {
            val lvl = EntitlementLevel.valueOf(level)
            UserEntitlementsManager.instance.upgradeTo(lvl)
            true
        } catch (_: Exception) {
            false
        }
    }

    @JavascriptInterface
    fun applyInAppPurchase(productId: String): Boolean {
        val success = UserEntitlementsManager.instance.applyPurchase(productId)
        if (success) {
            activity.runOnUiThread {
                Toast.makeText(activity, LocalizationManager.instance.t("iap_purchase_success"), Toast.LENGTH_SHORT).show()
                webView.evaluateJavascript("if(window.onNativePaymentResult){window.onNativePaymentResult('iap', true, '$productId');}", null)
            }
        }
        return success
    }

    @JavascriptInterface
    fun launchGooglePlayPurchase(productId: String) {
        activity.runOnUiThread {
            com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.launchPurchaseFlow(activity, productId) { success, err ->
                if (!success && err != null) {
                    Toast.makeText(activity, err, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    @JavascriptInterface
    fun restorePurchases() {
        activity.runOnUiThread {
            Toast.makeText(activity, LocalizationManager.instance.t("paywall_restore_purchases"), Toast.LENGTH_SHORT).show()
            com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.queryPurchases()
        }
    }

    @JavascriptInterface
    fun getGooglePlayProducts(): String {
        return com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.getProductDetailsJson()
    }

    @JavascriptInterface
    fun getIapStatus(): String {
        return UserEntitlementsManager.instance.getStatusJson()
    }

    @JavascriptInterface
    fun syncIapStatus() {
        val statusJson = UserEntitlementsManager.instance.getStatusJson()
        activity.runOnUiThread {
            webView.evaluateJavascript("if(window.onNativeIAPStatusUpdate){window.onNativeIAPStatusUpdate($statusJson);}", null)
        }
    }

    fun syncProductDetailsToWeb() {
        val json = com.example.yiijingcompass.billing.GooglePlayBillingManager.instance.getProductDetailsJson()
        activity.runOnUiThread {
            webView.evaluateJavascript("if(window.onGooglePlayProductsLoaded){window.onGooglePlayProductsLoaded($json);}", null)
        }
    }

    @JavascriptInterface
    fun requestNativePayment(channel: String, orderJson: String) {
        try {
            val obj = JSONObject(orderJson)
            val pid = obj.optString("productId")
            if (channel == "googleplay" || channel == "applepay") {
                launchGooglePlayPurchase(pid)
            } else {
                activity.runOnUiThread {
                    val msg = when (LocalizationManager.instance.effectiveLanguage) {
                        AppLanguage.EN -> "Connecting to payment gateway..."
                        AppLanguage.ZH_HANT -> "正在連接支付網關..."
                        AppLanguage.JA -> "決済ゲートウェイに接続中..."
                        AppLanguage.KO -> "결제 게이트웨이에 연결 중..."
                        AppLanguage.VI -> "Đang kết nối cổng thanh toán..."
                        AppLanguage.TH -> "กำลังเชื่อมต่อเกตเวย์การชำระเงิน..."
                        AppLanguage.ID -> "Menghubungkan ke gerbang pembayaran..."
                        AppLanguage.ZH_HANS, AppLanguage.AUTO -> "正在连接支付网关..."
                    }
                    Toast.makeText(activity, msg, Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // 10. 国际化与语言
    @JavascriptInterface
    fun setAppLanguage(lang: String): Boolean {
        return try {
            val l = AppLanguage.values().firstOrNull { it.rawValue == lang } ?: AppLanguage.AUTO
            LocalizationManager.instance.setLanguage(activity, l)
            true
        } catch (_: Exception) {
            false
        }
    }

    @JavascriptInterface
    fun t(key: String): String {
        return LocalizationManager.instance.t(key)
    }

    @JavascriptInterface
    fun saveImageToGallery(base64Data: String): Boolean {
        return try {
            val cleanBase64 = if (base64Data.contains(",")) base64Data.substringAfter(",") else base64Data
            val bytes = android.util.Base64.decode(cleanBase64, android.util.Base64.DEFAULT)
            val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return false
            TianJiShuEngine.instance.saveToGallery(activity, bitmap)
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    @JavascriptInterface
    fun refreshLocation() {
        activity.runOnUiThread {
            (activity as? com.example.yiijingcompass.MainActivity)?.checkAndRequestLocation()
                ?: motion.start(activity)
        }
    }

    @JavascriptInterface
    fun hasCameraPermission(): Boolean {
        return androidx.core.content.ContextCompat.checkSelfPermission(
            activity,
            android.Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    @JavascriptInterface
    fun requestCameraPermission() {
        activity.runOnUiThread {
            (activity as? com.example.yiijingcompass.MainActivity)?.checkAndRequestCamera()
        }
    }

    @JavascriptInterface
    fun calculateSanHeWaterJson(sittingName: String, facingName: String): String {
        return try {
            val mList = Mountain24Data.instance.mountains
            val sitting = mList.firstOrNull { it.name == sittingName } ?: mList[1]
            val facing = mList.firstOrNull { it.name == facingName } ?: mList[13]
            val hq = SanHeWaterEngine.instance.resolveHuangQuanWater(facing)
            val bs = SanHeWaterEngine.instance.resolveBaSha(sitting)
            val waterMethods = SanHeWaterEngine.instance.resolveWaterMethod(sitting, facing)

            val arr = JSONArray()
            for (w in waterMethods) {
                arr.put(JSONObject().apply {
                    put("mountainName", w.mountainName)
                    put("localizedMountainName", w.localizedMountainName)
                    put("phase", w.phase.rawValue)
                    put("phaseName", w.phase.localizedName)
                    put("isAuspicious", w.isAuspicious)
                    put("lore", w.lore)
                })
            }

            JSONObject().apply {
                put("sitting", sitting.name)
                put("facing", facing.name)
                put("huangQuan", JSONObject().apply {
                    put("isDanger", hq.isDanger)
                    put("isJiuPin", hq.isJiuPin)
                    put("badgeText", hq.badgeText)
                    put("waterDesc", hq.waterDesc)
                    put("quote", hq.localizedQuote)
                })
                put("baSha", JSONObject().apply {
                    put("sittingPalace", bs.sittingPalace)
                    put("shaZhi", bs.shaZhi)
                    put("shaDir", bs.localizedShaDir)
                    put("lore", bs.lore)
                    put("remedy", bs.remedy)
                    put("song", bs.localizedSong)
                    put("xiaoShaRule", bs.localizedXiaoShaRule)
                })
                put("waterMethods", arr)
            }.toString()
        } catch (e: Exception) {
            "{}"
        }
    }

    @JavascriptInterface
    fun calculateZeRiJson(sittingName: String, dateMillis: Long): String {
        return try {
            val mList = Mountain24Data.instance.mountains
            val sitting = mList.firstOrNull { it.name == sittingName } ?: mList[1]
            val date = if (dateMillis > 0) Date(dateMillis) else Date()
            val analysis = ZeRiEngine.instance.analyze(sitting, date)

            JSONObject().apply {
                put("fourPillars", analysis.fourPillarsText)
                put("overallStatus", analysis.overallStatus)
                put("isAuspicious", analysis.isAuspicious)
                put("suiPoWarning", analysis.suiPoWarning ?: "")
                put("yuePoWarning", analysis.yuePoWarning ?: "")
                put("sittingClashWarning", analysis.sittingClashWarning ?: "")
                put("detailsText", analysis.detailsText)
                put("yiList", JSONArray(analysis.yiActivities))
                put("jiList", JSONArray(analysis.jiActivities))
            }.toString()
        } catch (e: Exception) {
            "{}"
        }
    }
}
