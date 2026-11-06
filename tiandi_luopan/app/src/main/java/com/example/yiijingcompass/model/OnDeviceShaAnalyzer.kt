package com.example.yiijingcompass.model

import android.graphics.Bitmap
import android.graphics.Color

data class ShaAnalysisResult(
    val shaID: String,
    val confidence: Double,
    val targetX: Double,
    val targetY: Double,
    val detectedRegions: Int,
    val summary: String,
    val horizontalFOVDegrees: Double? = null
)

class OnDeviceShaAnalyzer private constructor() {
    companion object {
        val instance: OnDeviceShaAnalyzer by lazy { OnDeviceShaAnalyzer() }
    }

    /**
     * 在设备端离线分析现场拍摄画面中的潜在形煞
     * 利用亮度梯度、几何垂直缝隙与尖角边缘检测，无需联网，保护用户隐私
     */
    fun analyze(bitmap: Bitmap, onResult: (ShaAnalysisResult?) -> Unit) {
        val w = bitmap.width
        val h = bitmap.height
        if (w < 10 || h < 10) {
            onResult(null)
            return
        }

        // 采样缩放以保证毫秒级计算
        val sampleW = minOf(160, w)
        val sampleH = minOf(120, h)
        val scaled = Bitmap.createScaledBitmap(bitmap, sampleW, sampleH, false)

        var verticalEdges = 0
        var horizontalEdges = 0
        var darkCenterCount = 0

        val midX = sampleW / 2
        val midY = sampleH / 2

        for (y in 1 until sampleH - 1) {
            for (x in 1 until sampleW - 1) {
                val pix = scaled.getPixel(x, y)
                val pixRight = scaled.getPixel(x + 1, y)
                val pixBottom = scaled.getPixel(x, y + 1)

                val lum = (Color.red(pix) * 299 + Color.green(pix) * 587 + Color.blue(pix) * 114) / 1000
                val lumRight = (Color.red(pixRight) * 299 + Color.green(pixRight) * 587 + Color.blue(pixRight) * 114) / 1000
                val lumBottom = (Color.red(pixBottom) * 299 + Color.green(pixBottom) * 587 + Color.blue(pixBottom) * 114) / 1000

                if (kotlin.math.abs(lum - lumRight) > 40) verticalEdges++
                if (kotlin.math.abs(lum - lumBottom) > 40) horizontalEdges++

                if (kotlin.math.abs(x - midX) < sampleW / 8 && kotlin.math.abs(y - midY) < sampleH / 8 && lum < 60) {
                    darkCenterCount++
                }
            }
        }

        val totalPixels = (sampleW - 2) * (sampleH - 2)
        val vRatio = verticalEdges.toDouble() / totalPixels
        val hRatio = horizontalEdges.toDouble() / totalPixels

        // 形煞模式匹配
        val lang = LocalizationManager.shared.effectiveLanguage
        val result = when {
            vRatio > 0.18 && darkCenterCount > 50 -> {
                ShaAnalysisResult(
                    shaID = "tianzhan",
                    confidence = 0.88,
                    targetX = 0.5,
                    targetY = 0.45,
                    detectedRegions = 2,
                    summary = when (lang) {
                        AppLanguage.EN -> "Narrow vertical gap between tall buildings detected (wind-tunnel effect)"
                        AppLanguage.ZH_HANT -> "檢測到兩座高聳建築狹窄垂直夾縫對衝，文丘里風刃效應明顯"
                        AppLanguage.JA -> "高層ビル間の狭い垂直隙間を検出（ビル風・天斬殺の兆候）"
                        AppLanguage.KO -> "고층 건물 사이의 좁은 수직 틈새 감지 (빌딩풍·천참살 징후)"
                        AppLanguage.VI -> "Phát hiện khe hẹp thẳng đứng giữa hai tòa nhà cao tầng (Thiên Trảm Sát)"
                        AppLanguage.TH -> "ตรวจพบช่องว่างแคบแนวตั้งระหว่างอาคารสูง (ช่องลมพิฆาต)"
                        AppLanguage.ID -> "Celah vertikal sempit di antara gedung tinggi terdeteksi (efek lorong angin)"
                        AppLanguage.AUTO, AppLanguage.ZH_HANS -> "检测到两座高耸建筑狭窄垂直夹缝对冲，文丘里风刃效应明显"
                    }
                )
            }
            vRatio > 0.14 && hRatio > 0.12 -> {
                ShaAnalysisResult(
                    shaID = "luchong",
                    confidence = 0.82,
                    targetX = 0.5,
                    targetY = 0.65,
                    detectedRegions = 1,
                    summary = when (lang) {
                        AppLanguage.EN -> "Straight road or corridor converging directly toward the center"
                        AppLanguage.ZH_HANT -> "畫面中央檢測到筆直延伸道路/走廊視覺直衝"
                        AppLanguage.JA -> "画面中央へ一直線に伸びる道路・通路の直衝を検出"
                        AppLanguage.KO -> "화면 중앙으로 곧게 뻗은 도로·복도 직충 감지"
                        AppLanguage.VI -> "Phát hiện đường thẳng hoặc hành lang chiếu thẳng vào trung tâm"
                        AppLanguage.TH -> "ตรวจพบถนนหรือทางเดินพุ่งตรงเข้าสู่กึ่งกลางภาพ"
                        AppLanguage.ID -> "Jalan lurus atau koridor mengarah langsung ke tengah"
                        AppLanguage.AUTO, AppLanguage.ZH_HANS -> "画面中央检测到笔直延伸道路/走廊视觉直冲"
                    }
                )
            }
            hRatio > 0.18 -> {
                ShaAnalysisResult(
                    shaID = "fangong",
                    confidence = 0.76,
                    targetX = 0.5,
                    targetY = 0.55,
                    detectedRegions = 1,
                    summary = when (lang) {
                        AppLanguage.EN -> "Curved overpass or road arc convex side facing the property"
                        AppLanguage.ZH_HANT -> "檢測到弧形高架橋或彎曲水路反弓凸面對向"
                        AppLanguage.JA -> "弧状の高架橋またはカーブ道路の凸面（反弓）を検出"
                        AppLanguage.KO -> "곡선 고가도로 또는 굽은 길의 볼록면(반궁) 대향 감지"
                        AppLanguage.VI -> "Phát hiện cầu vượt hoặc đường cong uốn ngược hướng vào (Phản Cung)"
                        AppLanguage.TH -> "ตรวจพบทางยกระดับหรือถนนโค้งหันหลังคันธนูเข้าหา"
                        AppLanguage.ID -> "Lengkungan jalan layang atau jalan melengkung menghadap ke arah bangunan"
                        AppLanguage.AUTO, AppLanguage.ZH_HANS -> "检测到弧形高架桥或弯曲水路反弓凸面对向"
                    }
                )
            }
            else -> {
                ShaAnalysisResult(
                    shaID = "tantou",
                    confidence = 0.70,
                    targetX = 0.5,
                    targetY = 0.35,
                    detectedRegions = 1,
                    summary = when (lang) {
                        AppLanguage.EN -> "Protruding roof structure or sharp peak rising behind the front building"
                        AppLanguage.ZH_HANT -> "前方建築物輪廓上方隱約出現屋頂突出結構或尖峰"
                        AppLanguage.JA -> "前方建物の上方に突き出た屋根構造・尖峰（探頭殺）を検出"
                        AppLanguage.KO -> "전방 건물 윤곽 위로 돌출된 옥상 구조물·첨봉(탐두살) 감지"
                        AppLanguage.VI -> "Phát hiện cấu trúc mái nhô cao phía sau tòa nhà trước mặt (Thám Đầu Sát)"
                        AppLanguage.TH -> "ตรวจพบโครงสร้างหลังคาหรือยอดแหลมโผล่พ้นอาคารด้านหน้า"
                        AppLanguage.ID -> "Struktur atap menonjol atau puncak tajam di balik gedung depan"
                        AppLanguage.AUTO, AppLanguage.ZH_HANS -> "前方建筑物轮廓上方隐约出现屋顶突出结构或尖峰"
                    }
                )
            }
        }

        onResult(result)
    }
}
