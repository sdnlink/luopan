package com.example.yiijingcompass.model

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class TianJiShuEngine private constructor() {
    companion object {
        val instance: TianJiShuEngine by lazy { TianJiShuEngine() }
        val shared: TianJiShuEngine get() = instance
    }

    /**
     * 生成天机演象·福宅堪测全案长卷
     * 完全对齐 iOS TianJiShuEngine.generateScrollImage，具备 8 语种原生排版与全套数理勘测研判
     */
    private data class ScrollRender(val bitmap:Bitmap,val requiredHeight:Int)
    fun generateScrollImage(context:Context,heading:Double,coordsDesc:String,solarTimeDesc:String,
        language:AppLanguage?=null,isPro:Boolean=true,floorplanReport:List<FloorplanAuditItem> = emptyList(),
        panoramaArchive:PanoramaFengShuiArchive?=null,reportDate:Date=Date(),analysis:TianJiAnalysisSnapshot?=null):Bitmap = LocalizationManager.instance.withLanguage(language ?: LocalizationManager.instance.effectiveLanguage) {
        val snapshot=analysis ?: TianJiAnalysisSnapshot(heading,reportDate)
        val floor=if(snapshot.hasSpatialSnapshot)snapshot.capturedFloorplanReport else floorplanReport
        val panorama=if(snapshot.hasSpatialSnapshot)snapshot.capturedPanoramaArchive else panoramaArchive
        val probe=renderScrollImage(context,snapshot.heading,coordsDesc,solarTimeDesc,language,isPro,floor,panorama,snapshot.reportDate,snapshot,1)
        val height=maxOf(15000,probe.requiredHeight)
        probe.bitmap.recycle()
        renderScrollImage(context,snapshot.heading,coordsDesc,solarTimeDesc,language,isPro,floor,panorama,snapshot.reportDate,snapshot,height).bitmap
    }

    private fun renderScrollImage(
        @Suppress("UNUSED_PARAMETER") context: Context,
        heading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        language: AppLanguage? = null,
        isPro: Boolean = true,
        floorplanReport: List<FloorplanAuditItem> = emptyList(),
        panoramaArchive: PanoramaFengShuiArchive? = null,
        reportDate: Date = Date(),
        analysis: TianJiAnalysisSnapshot,
        canvasHeight: Int
    ): ScrollRender {
        val renderLanguage = language ?: LocalizationManager.instance.effectiveLanguage

        fun tr8(
            hans: String,
            hant: String,
            en: String,
            ja: String,
            ko: String,
            vi: String,
            th: String,
            id: String
        ): String {
            return when (renderLanguage) {
                AppLanguage.ZH_HANT -> hant
                AppLanguage.EN -> en
                AppLanguage.JA -> ja
                AppLanguage.KO -> ko
                AppLanguage.VI -> vi
                AppLanguage.TH -> th
                AppLanguage.ID -> id
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> hans
            }
        }

        val width = 1080
        val estimatedHeight = canvasHeight

        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 背景：宣纸色
        val bgPaint = Paint().apply {
            color = Color.rgb(249, 246, 238)
            style = Paint.Style.FILL
        }
        canvas.drawRect(0f, 0f, width.toFloat(), estimatedHeight.toFloat(), bgPaint)

        val vermilionColor = Color.rgb(178, 34, 34)

        // 字体样式
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(40, 20, 10)
            textSize = 52f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val subtitlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(100, 60, 40)
            textSize = 26f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
            textAlign = Paint.Align.CENTER
        }

        val bodyTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(40, 35, 30)
            textSize = 22f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }

        fun drawMeasuredText(
            text: String,
            atY: Float,
            paint: TextPaint = bodyTextPaint,
            x: Float = 100f,
            textWidth: Int = 880,
            minimumHeight: Float = 0f
        ): Float {
            val staticLayout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                StaticLayout.Builder.obtain(text, 0, text.length, paint, textWidth)
                    .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                    .setLineSpacing(0f, 1.15f)
                    .setIncludePad(false)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                StaticLayout(text, paint, textWidth, Layout.Alignment.ALIGN_NORMAL, 1.15f, 0f, false)
            }
            canvas.save()
            canvas.translate(x, atY)
            staticLayout.draw(canvas)
            canvas.restore()
            val measured = staticLayout.height.toFloat()
            return maxOf(measured, minimumHeight)
        }

        fun drawSectionHeader(title: String, atY: Float) {
            val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = vermilionColor
                strokeWidth = 2f
            }
            canvas.drawLine(90f, atY + 38f, 990f, atY + 38f, linePaint)

            val headPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = vermilionColor
                textSize = 28f
                typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
                letterSpacing = 0.08f
            }
            canvas.drawText(title, 95f, atY + 28f, headPaint)
        }

        // 1. 顶部标题与时空铭刻
        var curY = 110f
        val topTitle = tr8(
            "天机演象 · 福宅堪测全案长卷",
            "天機演象 · 福宅堪測全案長卷",
            "TIANJI YANXIANG · CELESTIAL FENG SHUI SCROLL",
            "天機演象・福宅風水鑑定全書長巻",
            "천기연상 · 복택 풍수 감여 전안 장권",
            "THIÊN CƠ DIỄN TƯỢNG · TRƯỜNG QUYỂN KHẢO SÁT PHONG THỦY",
            "คัมภีร์เทียนจียั่นเซี่ยง · ตรวจฮวงจุ้ยบ้านมงคลฉบับสมบูรณ์",
            "TIANJI YANXIANG · GULUNGAN FENG SHUI KELUARGA LENGKAP"
        )
        canvas.drawText(topTitle, width / 2f, curY, titlePaint)
        curY += 50f

        val df = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())
        val dateStr = df.format(reportDate)
        val topSubtitle = "Date: $dateStr · Solar Time: $solarTimeDesc"
        canvas.drawText(topSubtitle, width / 2f, curY, subtitlePaint)
        curY += 40f
        val locSubtitle = "Coordinates: $coordsDesc · Datum: True North"
        canvas.drawText(locSubtitle, width / 2f, curY, subtitlePaint)
        curY += 60f

        // 2. 第一卷 · 坐向立极与分金天心
        val sec1Title = tr8(
            "第一卷 · 坐向立极与分金天心",
            "第一卷 · 坐向立極與分金天心",
            "I · ORIENTATION & FENJIN CENTER",
            "第一巻・座向立極と分金天心",
            "제1권 · 좌향입극 및 분금천심",
            "QUYỂN I · TỌA HƯỚNG LẬP CỰC VÀ PHÂN KIM",
            "บทที่ ๑ · ทิศตั้งประธานและองศาแบ่งทอง",
            "BAGIAN I · ORIENTASI & PUSAT FENJIN"
        )
        drawSectionHeader(sec1Title, curY)
        curY += 65f

        if(analysis.signature.client.isNotBlank())curY+=drawMeasuredText(LocalizationManager.instance.t("native_client_name")+" · "+analysis.signature.client.take(120),curY)+20f
        val mFacing = Mountain24Data.instance.mountain(heading)
        val sitAngle = (heading + 180.0) % 360.0
        val mSitting = Mountain24Data.instance.mountain(sitAngle)
        val fenjin = Fenjin120Data.instance.resolveFenjin(heading)
        val hex = Hexagram64Data.instance.hexagram(heading)
        val facingDelta = ((heading - mFacing.centerAngle) % 360.0 + 540.0) % 360.0 - 180.0
        val useTiGua = analysis.useTiGua

        val p1Text = when (renderLanguage) {
            AppLanguage.EN -> """
                • Facing orientation: ${mFacing.localizedName} mountain (measured ${String.format(Locale.US, "%.1f", heading)}°) · ${mFacing.localizedPalace} Palace
                • Sitting mountain: ${mSitting.localizedName} (sitting ${String.format(Locale.US, "%.1f", sitAngle)}°) · ${mSitting.localizedPalace}
                • 120 Fenjin: ${fenjin.jiaziName} (center ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°) · [${fenjin.localizedGrade}]
                • 64 Hexagrams: ${hex.localizedName} · upper ${hex.localizedUpperTrigram}, lower ${hex.localizedLowerTrigram} · [${hex.localizedLuckDegree}]
                • Survey coordinates: $coordsDesc
                • Solar-term true time: $solarTimeDesc
            """.trimIndent()
            AppLanguage.ZH_HANT -> """
                • 物理向首方位：${mFacing.localizedName}山向首（實測 ${String.format(Locale.US, "%.1f", heading)}°）· ${mFacing.localizedPalace}宮
                • 住宅太極坐山：${mSitting.localizedName}山立極（坐 ${String.format(Locale.US, "%.1f", sitAngle)}°）· 屬${mSitting.localizedPalace}
                • 一百二十分金：${fenjin.jiaziName}分金（中心 ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°）· 【${fenjin.localizedGrade}】
                • 周易六十四卦：${hex.localizedName} · 外卦${hex.localizedUpperTrigram} 內卦${hex.localizedLowerTrigram} · 爻度【${hex.localizedLuckDegree}】
                • 堪輿定位座標：$coordsDesc
                • 節氣真太陽時：$solarTimeDesc
            """.trimIndent()
            AppLanguage.JA -> """
                • 向首方位：${mFacing.localizedName}山（実測 ${String.format(Locale.US, "%.1f", heading)}°）· ${mFacing.localizedPalace}宮
                • 坐山立極：${mSitting.localizedName}山（坐 ${String.format(Locale.US, "%.1f", sitAngle)}°）· ${mSitting.localizedPalace}
                • 百二十分金：${fenjin.jiaziName}分金（中心 ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°）· 【${fenjin.localizedGrade}】
                • 周易六十四卦：${hex.localizedName} · 外卦${hex.localizedUpperTrigram} 内卦${hex.localizedLowerTrigram} · 【${hex.localizedLuckDegree}】
                • 測位座標：$coordsDesc
                • 節気真太陽時：$solarTimeDesc
            """.trimIndent()
            AppLanguage.KO -> """
                • 향수 방위: ${mFacing.localizedName}산 (실측 ${String.format(Locale.US, "%.1f", heading)}°) · ${mFacing.localizedPalace}궁
                • 좌산 입극: ${mSitting.localizedName}산 (좌 ${String.format(Locale.US, "%.1f", sitAngle)}°) · ${mSitting.localizedPalace}
                • 120 분금: ${fenjin.jiaziName}분금 (중심 ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°) · 【${fenjin.localizedGrade}】
                • 주역 64괘: ${hex.localizedName} · 상괘 ${hex.localizedUpperTrigram} 하괘 ${hex.localizedLowerTrigram} · 【${hex.localizedLuckDegree}】
                • 감여 좌표: $coordsDesc
                • 절기 진태양시: $solarTimeDesc
            """.trimIndent()
            AppLanguage.VI -> """
                • Phương vị hướng: Sơn ${mFacing.localizedName} (thực đo ${String.format(Locale.US, "%.1f", heading)}°) · Cung ${mFacing.localizedPalace}
                • Tọa sơn lập cực: Sơn ${mSitting.localizedName} (tọa ${String.format(Locale.US, "%.1f", sitAngle)}°) · Cung ${mSitting.localizedPalace}
                • 120 Phân Kim: Phân kim ${fenjin.jiaziName} (tâm ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°) · 【${fenjin.localizedGrade}】
                • Chu Dịch 64 Quẻ: ${hex.localizedName} · Quẻ ngoại ${hex.localizedUpperTrigram} Quẻ nội ${hex.localizedLowerTrigram} · 【${hex.localizedLuckDegree}】
                • Tọa độ khảo sát: $coordsDesc
                • Chân thái dương thời: $solarTimeDesc
            """.trimIndent()
            AppLanguage.TH -> """
                • ทิศหันประธาน: เขา${mFacing.localizedName} (วัดจริง ${String.format(Locale.US, "%.1f", heading)}°) · วัง${mFacing.localizedPalace}
                • ทิศพิงหลังบ้าน: เขา${mSitting.localizedName} (พิง ${String.format(Locale.US, "%.1f", sitAngle)}°) · วัง${mSitting.localizedPalace}
                • แบ่งทอง 120: ${fenjin.jiaziName} (ศูนย์กลาง ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°) · [${fenjin.localizedGrade}]
                • คัมภีร์ 64 กว้า: ${hex.localizedName} · บน${hex.localizedUpperTrigram} ล่าง${hex.localizedLowerTrigram} · [${hex.localizedLuckDegree}]
                • พิกัดสำรวจ: $coordsDesc
                • เวลาสุริยคติแท้: $solarTimeDesc
            """.trimIndent()
            AppLanguage.ID -> """
                • Arah hadap utama: Gunung ${mFacing.localizedName} (terukur ${String.format(Locale.US, "%.1f", heading)}°) · Istana ${mFacing.localizedPalace}
                • Gunung sandaran: Gunung ${mSitting.localizedName} (sandar ${String.format(Locale.US, "%.1f", sitAngle)}°) · ${mSitting.localizedPalace}
                • 120 Fenjin: ${fenjin.jiaziName} (pusat ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°) · [${fenjin.localizedGrade}]
                • 64 Heksagram: ${hex.localizedName} · atas ${hex.localizedUpperTrigram}, bawah ${hex.localizedLowerTrigram} · [${hex.localizedLuckDegree}]
                • Koordinat survei: $coordsDesc
                • Waktu matahari sejati: $solarTimeDesc
            """.trimIndent()
            else -> """
                • 物理向首方位：${mFacing.localizedName}山向首（实测 ${String.format(Locale.US, "%.1f", heading)}°）· ${mFacing.localizedPalace}宫
                • 住宅太极坐山：${mSitting.localizedName}山立极（坐 ${String.format(Locale.US, "%.1f", sitAngle)}°）· 属${mSitting.localizedPalace}
                • 一百二十分金：${fenjin.jiaziName}分金（中心 ${String.format(Locale.US, "%.1f", fenjin.centerAngle)}°）· 【${fenjin.localizedGrade}】
                • 周易六十四卦：${hex.localizedName} · 外卦${hex.localizedUpperTrigram} 内卦${hex.localizedLowerTrigram} · 爻度【${hex.localizedLuckDegree}】
                • 堪舆定位坐标：$coordsDesc
                • 节气真太阳时：$solarTimeDesc
            """.trimIndent()
        }
        curY += drawMeasuredText(p1Text, curY) + 20f

        // 3. 第二卷 · 玄空飞星气运方阵
        val xkChart = FlyingStarsEngine.instance.calculateChart(
            period = analysis.period,
            sitting = mSitting,
            facing = mFacing,
            useTiGua = useTiGua,
            date = reportDate
        )
        curY += drawMeasuredText(analysis.guidanceText(xkChart),curY) + 20f
        val meta = xkChart.periodMeta
        val sec2Title = tr8(
            "第二卷 · ${meta.yuan}${meta.period}运玄空飞星气运方阵",
            "第二卷 · ${meta.yuan}${meta.period}運玄空飛星氣運方陣",
            "II · FLYING STARS & PERIOD ${meta.period}",
            "第二巻・${meta.yuan}${meta.period}運 玄空飛星気運盤",
            "제2권 · ${meta.yuan}${meta.period}운 현공비성 기운방진",
            "QUYỂN II · HUYỀN KHÔNG PHI TINH VẬN ${meta.period}",
            "บทที่ ๒ · ดาวเหินเสวียนคงยุค ${meta.period}",
            "BAGIAN II · BINTANG TERBANG & PERIODE ${meta.period}"
        )
        drawSectionHeader(sec2Title, curY)
        curY += 65f

        val p2Text = when (renderLanguage) {
            AppLanguage.EN -> """
                • Current period: ${meta.label}
                • Flying-star pattern: [${mSitting.localizedName} / ${mFacing.localizedName}] ${xkChart.patternType}
                • Ruling star qi: ${meta.starName} ${meta.element} star enters the center and illuminates the facing bright hall.
                • Overall analysis: ${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.ZH_HANT -> """
                • 當前地運：${meta.label}
                • 玄空格局判定：【${mSitting.localizedName}山${mFacing.localizedName}向】${xkChart.patternType}
                • 當令旺星氣場：${meta.starName}${meta.element}星入中當運，主星臨照向首明堂。
                • 綜合理氣研判：${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.JA -> """
                • 現在の地運：${meta.label}
                • 玄空格局判定：【${mSitting.localizedName}山${mFacing.localizedName}向】${xkChart.patternType}
                • 当令旺星の気：${meta.starName}${meta.element}星が中宮に入り、向首明堂を照らします。
                • 総合理気判断：${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.KO -> """
                • 현재 지운: ${meta.label}
                • 현공 격국 판정: 【${mSitting.localizedName}산 ${mFacing.localizedName}향】${xkChart.patternType}
                • 당령 왕성 기운: ${meta.starName} ${meta.element}성이 중궁에 들어 향수 명당을 밝힙니다.
                • 종합 이기 판단: ${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.VI -> """
                • Địa vận hiện tại: ${meta.label}
                • Huyền không cách cục: 【Tọa ${mSitting.localizedName} Hướng ${mFacing.localizedName}】${xkChart.patternType}
                • Khí trường đương vận: Sao ${meta.starName} hành ${meta.element} nhập trung cung chiếu sáng minh đường hướng thủ.
                • Phán đoán lý khí tổng hợp: ${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.TH -> """
                • ยุคพลังปัจจุบัน: ${meta.label}
                • รูปแบบผังดาวเหิน: 【พิง ${mSitting.localizedName} หัน ${mFacing.localizedName}】${xkChart.patternType}
                • พลังดาวครองยุค: ดาว ${meta.starName} ธาตุ${meta.element} เข้าสู่ใจกลาง ส่องสว่างลานสว่างหน้าบ้าน
                • การวิเคราะห์ภาพรวม: ${xkChart.summaryAnalysis}
            """.trimIndent()
            AppLanguage.ID -> """
                • Periode saat ini: ${meta.label}
                • Pola bintang terbang: [${mSitting.localizedName} / ${mFacing.localizedName}] ${xkChart.patternType}
                • Qi bintang berkuasa: Bintang ${meta.starName} berelemen ${meta.element} masuk ke pusat menerangi aula depan.
                • Analisis menyeluruh: ${xkChart.summaryAnalysis}
            """.trimIndent()
            else -> """
                • 当前地运：${meta.label}
                • 玄空格局判定：【${mSitting.localizedName}山${mFacing.localizedName}向】${xkChart.patternType}
                • 当令旺星气场：${meta.starName}${meta.element}星入中当运，主星临照向首明堂。
                • 综合理气研判：${xkChart.summaryAnalysis}
            """.trimIndent()
        }
        curY += drawMeasuredText(p2Text, curY) + 20f

        // 4. 第三卷 · 杨公形气八路黄泉与水法宜忌
        val sec3Title = tr8(
            "第三卷 · 杨公形气八路黄泉与水法宜忌",
            "第三卷 · 楊公形氣八路黃泉與水法宜忌",
            "III · YANG GONG WATER METHOD & HUANGQUAN",
            "第三巻・楊公八路黄泉と消砂納水法",
            "제3권 · 양공 팔로황천 및 소사납수법",
            "QUYỂN III · DƯƠNG CÔNG BÁT LỘ HOÀNG TUYỀN VÀ THỦY PHÁP",
            "บทที่ ๓ · วิชาสายน้ำหยางกงและน้ำฮวงเฉวียน",
            "BAGIAN III · METODE AIR YANG GONG & HUANGQUAN"
        )
        drawSectionHeader(sec3Title, curY)
        curY += 65f

        val hq = SanHeWaterEngine.instance.resolveHuangQuanWater(mFacing)
        val basha = SanHeWaterEngine.instance.resolveBaSha(mSitting)
        val sanHeItems = SanHeWaterEngine.instance.resolveWaterMethod(mSitting, mFacing)
        val lang = LocalizationManager.shared
        val mountainSuffix = lang.t("mountain_suffix")
        val hqLabel = tr8("向首八路黄泉判据", "向首八路黃泉判據", "Eight-Road Huangquan test", "向首八路黄泉判定", "향수 팔로황천 판별", "Phán định Bát Lộ Hoàng Tuyền", "เกณฑ์น้ำฮวงเฉวียนแปดทิศ", "Uji Huangquan Delapan Arah")
        val bashaLabel = tr8("坐山八煞曜位辨识", "坐山八煞曜位辨識", "Sitting-mountain Sha position", "坐山八煞曜位識別", "좌산 팔살요위 식별", "Nhận định Bát Sát Diệu vị", "ตำแหน่งดาวพิฆาตแปดทิศ", "Posisi Sha Delapan Arah")
        val waterLabel = tr8("十二长生纳水吉凶", "十二長生納水吉凶", "Twelve Changsheng water assessment", "十二長生納水吉凶", "십이장생 납수길흉", "Cát hung Thập Nhị Trường Sinh", "ประเมินน้ำสิบสองสภาวะฉางเซิง", "Penilaian Air Dua Belas Changsheng")

        val sbP3 = StringBuilder()
        sbP3.append("• ").append(hqLabel).append(": ").append(hq.badgeText).append(" · ").append(hq.waterDesc).append("\n")
        sbP3.append("• ").append(bashaLabel).append(": 【").append(basha.localizedShaDir).append("】 · ").append(basha.remedy).append("\n")
        sbP3.append("• ").append(waterLabel).append(":\n")
        for (item in sanHeItems) {
            val verdict = if (item.isAuspicious) {
                tr8("吉 · 宜来水纳气", "吉 · 宜來水納氣", "Auspicious · favorable inflow", "吉・来水歓迎", "길 · 내수 유입 권장", "Cát · nên đón nước vào tụ khí", "มงคล · ควรรับน้ำไหลเข้า", "Berkah · aliran masuk yang baik")
            } else {
                tr8("忌 · 防破局流破", "忌 · 防破局流破", "Avoid · prevent draining the pattern", "忌・破局流出注意", "기 · 파국 유출 방지", "Kỵ · đề phòng nước chảy thoát phá cục", "อัปมงคล · ป้องกันน้ำไหลรั่วทำลายผัง", "Hindari · cegah aliran menguras energi")
            }
            sbP3.append("  - ").append(item.localizedMountainName).append(mountainSuffix).append("【").append(item.stage).append("】: ").append(verdict).append(", ").append(item.lore).append("\n")
        }
        curY += drawMeasuredText(sbP3.toString(), curY) + 20f

        // 5. 第四卷 · 时家奇门时空与八宅大游年
        val sec4Title = tr8(
            "第四卷 · 时家奇门时空与八宅大游年",
            "第四卷 · 時家奇門時空與八宅大遊年",
            "IV · QIMEN TIME-SPACE & EIGHT MANSIONS",
            "第四巻・時家奇門時空と八宅大遊年",
            "제4권 · 시가기문 시공 및 팔택 대유년",
            "QUYỂN IV · THỜI GIA KỲ MÔN VÀ BÁT TRẠCH",
            "บทที่ ๔ · ขี่เหมินกาลอวกาศและแปดเรือน",
            "BAGIAN IV · RUANG-WAKTU QIMEN & DELAPAN RUMAH"
        )
        drawSectionHeader(sec4Title, curY)
        curY += 65f

        val qm = QimenEngine.instance.calculateChart(reportDate, heading)
        val bz = BaZhaiEngine.instance.analyze(mSitting.palace, mFacing.palace)

        val p4Text = when (renderLanguage) {
            AppLanguage.EN -> """
                • QiMen time-space: ${qm.title}
                • Best direction to move now: ${qm.bestNavDirection} (${qm.bestNavReason})
                • House gua: [${bz.localizedHouseGua}] · gate direction: ${bz.localizedGateDirection}, receiving [${bz.gateStar.localizedName}]
                • Sheng Qi direction: ${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "Sheng Qi"}; suitable for the master bedroom or altar.
            """.trimIndent()
            AppLanguage.ZH_HANT -> """
                • 時家奇門時空：${qm.title}
                • 當前天時最優動身方：${qm.bestNavDirection} (${qm.bestNavReason})
                • 住宅宅卦歸屬：【${bz.localizedHouseGua}】 · 向首開門方：${bz.localizedGateDirection}方納【${bz.gateStar.localizedName}】
                • 生氣大吉尊方：${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "生氣"}方，宜作主臥或安奉神位。
            """.trimIndent()
            AppLanguage.JA -> """
                • 時家奇門盤：${qm.title}
                • 現在の最適行動方位：${qm.bestNavDirection}（${qm.bestNavReason}）
                • 住宅本命卦：【${bz.localizedHouseGua}】 · 開門方位：${bz.localizedGateDirection} 方【${bz.gateStar.localizedName}】
                • 生気大吉方位：${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "生気"}方、主寝室や神仏のお祀りに最適。
            """.trimIndent()
            AppLanguage.KO -> """
                • 시가기문 시공: ${qm.title}
                • 현재 최적 출행 방위: ${qm.bestNavDirection} (${qm.bestNavReason})
                • 주택 택괘 귀속: 【${bz.localizedHouseGua}】 · 대문 방향: ${bz.localizedGateDirection}방【${bz.gateStar.localizedName}】
                • 생기 대길 존방: ${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "생기"}방, 주침실 또는 제단 배치에 적합.
            """.trimIndent()
            AppLanguage.VI -> """
                • Thời không Kỳ Môn: ${qm.title}
                • Hướng xuất hành tốt nhất: ${qm.bestNavDirection} (${qm.bestNavReason})
                • Trạch quái nhà ở: 【${bz.localizedHouseGua}】 · Hướng mở cửa: ${bz.localizedGateDirection} nạp 【${bz.gateStar.localizedName}】
                • Phương vị Sinh Khí: Phương ${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "Sinh Khí"}, thích hợp đặt phòng ngủ chính hoặc bàn thờ.
            """.trimIndent()
            AppLanguage.TH -> """
                • กาลอวกาศขี่เหมิน: ${qm.title}
                • ทิศทางที่ดีที่สุดในขณะนี้: ${qm.bestNavDirection} (${qm.bestNavReason})
                • กั้วประจำตัวบ้าน: 【${bz.localizedHouseGua}】 · ทิศเปิดประตู: ทิศ${bz.localizedGateDirection} รับพลัง【${bz.gateStar.localizedName}】
                • ทิศเซิงชี่มงคลเอก: ทิศ${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "เซิงชี่"} เหมาะสำหรับห้องนอนใหญ่หรือตั้งสิ่งศักดิ์สิทธิ์
            """.trimIndent()
            AppLanguage.ID -> """
                • Ruang-waktu QiMen: ${qm.title}
                • Arah terbaik saat ini: ${qm.bestNavDirection} (${qm.bestNavReason})
                • Gua rumah: [${bz.localizedHouseGua}] · arah pintu gerbang: ${bz.localizedGateDirection}, menyerap [${bz.gateStar.localizedName}]
                • Arah Sheng Qi: ${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "Sheng Qi"}; cocok untuk kamar tidur utama atau altar.
            """.trimIndent()
            else -> """
                • 时家奇门时空：${qm.title}
                • 当前天时最优动身方：${qm.bestNavDirection} (${qm.bestNavReason})
                • 住宅宅卦归属：【${bz.localizedHouseGua}】 · 向首开门方：${bz.localizedGateDirection}方纳【${bz.gateStar.localizedName}】
                • 生气大吉尊方：${bz.items.firstOrNull { it.star == StarLuckType.SHENG_QI }?.localizedDirection ?: "生气"}方，宜作主卧或安奉神位。
            """.trimIndent()
        }
        curY += drawMeasuredText(p4Text, curY) + 20f

        // 6. 第五卷 · 全屋空间调理与镇煞秘诀
        val sec5Title = tr8(
            "第五卷 · 全屋空间调理与镇煞秘诀",
            "第五卷 · 全屋空間調理與鎮煞秘訣",
            "V · WHOLE-HOME HARMONIZATION",
            "第五巻・全室空間調和と化煞の秘訣",
            "제5권 · 주택 공간 조율 및 비전 화살",
            "QUYỂN V · ĐIỀU HÒA KHÔNG GIAN VÀ HÓA SÁT",
            "บทที่ ๕ · การปรับสมดุลและเคล็ดลับสลายเคราะห์ทั่วบ้าน",
            "BAGIAN V · PENYELARASAN RUANG & PENANGKAL SHA"
        )
        drawSectionHeader(sec5Title, curY)
        curY += 65f

        val pwChart = PurpleWhiteEngine.instance.calculateChart(reportDate, heading)
        val zeri = ZeRiEngine.instance.analyze(reportDate, mSitting)
        val annualNote = tr8(
            "• 岁运太岁与择日：太岁在${pwChart.taiSuiDescription}、岁破在${pwChart.suiPoDescription}、三煞在${pwChart.sanShaDescription}；当前四柱【${zeri.fourPillarsText}】（${zeri.overallStatus}）。",
            "• 歲運太歲與擇日：太歲在${pwChart.taiSuiDescription}、歲破在${pwChart.suiPoDescription}、三煞在${pwChart.sanShaDescription}；當前四柱【${zeri.fourPillarsText}】（${zeri.overallStatus}）。",
            "• Annual Tai Sui & Date Selection: Tai Sui at ${pwChart.taiSuiDescription}, Sui Po at ${pwChart.suiPoDescription}, San Sha at ${pwChart.sanShaDescription}; Four Pillars [${zeri.fourPillarsText}] (${zeri.overallStatus}).",
            "• 歳運太歳と択日：太歳${pwChart.taiSuiDescription}・歳破${pwChart.suiPoDescription}・三煞${pwChart.sanShaDescription}；四柱【${zeri.fourPillarsText}】（${zeri.overallStatus}）。",
            "• 세운 태세 및 택일: 태세 ${pwChart.taiSuiDescription}, 세파 ${pwChart.suiPoDescription}, 삼살 ${pwChart.sanShaDescription}; 사주 【${zeri.fourPillarsText}】(${zeri.overallStatus}).",
            "• Thái Tuế & Trạch Nhật: Thái Tuế ${pwChart.taiSuiDescription}, Tuế Phá ${pwChart.suiPoDescription}, Tam Sát ${pwChart.sanShaDescription}; Tứ Trụ 【${zeri.fourPillarsText}】 (${zeri.overallStatus}).",
            "• ไท่ซุ่ยประจำปีและฤกษ์ยาม: ไท่ซุ่ย ${pwChart.taiSuiDescription}, ซุ่ยพั่ว ${pwChart.suiPoDescription}, ซานซ่า ${pwChart.sanShaDescription}; สี่เสา 【${zeri.fourPillarsText}】 (${zeri.overallStatus})",
            "• Tai Sui Tahunan & Pemilihan Hari: Tai Sui di ${pwChart.taiSuiDescription}, Sui Po di ${pwChart.suiPoDescription}, San Sha di ${pwChart.sanShaDescription}; Empat Pilar [${zeri.fourPillarsText}] (${zeri.overallStatus})."
        )
        val p5Text = """
            ${xkChart.wealthAdvice}
            ${xkChart.healthAdvice}
            ${xkChart.remedyAdvice}
            $annualNote
        """.trimIndent()
        curY += drawMeasuredText(p5Text, curY) + 20f

        // 7. 详细展开：玄空九宫全盘 · 山向星与逐宫锦囊
        curY = drawFlyingStarsDetails(canvas, curY, vermilionColor, renderLanguage, xkChart, bodyTextPaint)

        // 8. 详细展开：奇门九宫全盘 · 门星神干与趋避锦囊
        curY = drawQimenDetails(canvas, curY, vermilionColor, renderLanguage, qm, bodyTextPaint)

        // 9. 详细展开：择日全案 · 神煞警告与宜忌锦囊
        curY = drawZeRiDetails(canvas, curY, vermilionColor, renderLanguage, zeri, bodyTextPaint)

        // 10. 户型现场审计（若有）
        if (floorplanReport.isNotEmpty()) {
            curY = drawFloorplanAudit(canvas, curY, vermilionColor, renderLanguage, floorplanReport, bodyTextPaint)
        }

        // 11. 紫白流年 · 客星调理与催旺
        curY = drawPurpleWhiteRemedies(canvas, curY, vermilionColor, renderLanguage, pwChart, bodyTextPaint)

        // 12. 八宅八宫 · 吉凶化解安镇
        curY = drawBazhaiInjurious(canvas, curY, vermilionColor, renderLanguage, bz, bodyTextPaint)

        // 13. 形煞自查与化煞安宅
        curY = drawShaSelfCheck(canvas, curY, vermilionColor, renderLanguage, panoramaArchive, bodyTextPaint)

        // 14. 卷尾朱砂印鉴与落款
        val sealPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilionColor
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        val sealRect = RectF(780f, curY + 20f, 960f, curY + 200f)
        canvas.drawRect(sealRect, sealPaint)
        canvas.drawRect(sealRect.left + 6f, sealRect.top + 6f, sealRect.right - 6f, sealRect.bottom - 6f, sealPaint)

        val sealTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilionColor
            textSize = 28f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        val defaultSealText = tr8(
            "天机演象\n罗盘\n御印",
            "天機演象\n羅盤\n御印",
            "TIANJI\nYANXIANG\nCELESTIAL\nSEAL",
            "天機演象\n羅盤\n御印",
            "천기연상\n나경\n어인",
            "THIÊN CƠ\nLA BÀN\nNGỰ ẤN",
            "สวรรค์ลิขิต\nเข็มทิศ\nตราประทับ",
            "TIANJI\nKOMPAS\nSEGEL RESMI"
        )
        val rawSeal=analysis.signature.seal.trim().take(60)
        val sealText=if(rawSeal.isBlank())defaultSealText else if(rawSeal.length==4&&!rawSeal.contains(" "))rawSeal.take(2)+"\n"+rawSeal.drop(2) else rawSeal.replace(" ","\n")
        sealTextPaint.textSize=if(rawSeal.length>8)18f else if(rawSeal.length>4)22f else 28f
        drawMeasuredText(sealText, curY + 36f, sealTextPaint, 795f, 150)

        // 干支纪年推导
        val calendar = java.util.GregorianCalendar()
        calendar.time = reportDate
        val y = calendar.get(Calendar.YEAR)
        val isBeforeLichun = SolarTimeCalculator.instance.isBeforeLiChun(reportDate)
        val gzYear = if (isBeforeLichun) (y - 1) else y
        val stems = arrayOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
        val branches = arrayOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
        val yOffset = ((gzYear - 4) % 60 + 60) % 60
        val curGzYear = "${stems[yOffset % 10]}${branches[yOffset % 12]}"

        val signText = when (renderLanguage) {
            AppLanguage.EN -> "MASTER FENG SHUI\nTIANJI YANXIANG\nYEAR $curGzYear"
            AppLanguage.ZH_HANT -> "大 師 堪 輿 親 訂\n天 機 演 象 院\n歲 次 $curGzYear 謹 啟"
            AppLanguage.JA -> "監修 風水鑑定親定\n天 機 演 象 院\n歳 次 $curGzYear 謹 啓"
            AppLanguage.KO -> "풍수지리 감여 친정\n천 기 연 상 원\n세 차 $curGzYear 삼가 올림"
            AppLanguage.VI -> "PHONG THỦY ĐẠI SƯ ĐỊNH BẢN\nTHIÊN CƠ DIỄN TƯỢNG VIỆN\nTUẾ THỨ $curGzYear CẨN KHẢI"
            AppLanguage.TH -> "ปรมาจารย์ฮวงจุ้ยลิขิต\nสถาบันเทียนจียั่นเซี่ยง\nปี $curGzYear"
            AppLanguage.ID -> "MASTER FENG SHUI RESMI\nTIANJI YANXIANG ACADEMY\nTAHUN $curGzYear"
            else -> "大 师 堪 舆 亲 订\n天 机 演 象 院\n岁 次 $curGzYear 谨 启"
        }
        val signPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(70, 50, 35)
            textSize = 22f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        drawMeasuredText(analysis.signature.master.trim().take(120).ifBlank {signText}, curY + 45f, signPaint, 480f, 280)

        // 15. 卷尾免责合规声明
        val disclaimerTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(120, 100, 80)
            textSize = 20f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }
        val disclaimer = tr8(
            "温馨提示：本长卷依据传统堪舆文化整理，仅供文化研究与娱乐参考，不构成医疗、法律、金融或投资建议，亦不承诺任何实际效果。请理性看待，涉及健康、财产等重大事项请咨询相关专业人士。",
            "溫馨提示：本長卷依據傳統堪輿文化整理，僅供文化研究與娛樂參考，不構成醫療、法律、金融或投資建議，亦不承諾任何實際效果。請理性看待，涉及健康、財產等重大事項請諮詢相關專業人士。",
            "Note: This scroll is compiled from traditional Feng Shui culture and is provided for cultural study and entertainment only. It does not constitute medical, legal, financial or investment advice, nor does it promise any actual outcome. Please view it rationally and consult qualified professionals on matters of health, property and other major decisions.",
            "ご案内：本書は伝統的な風水文化に基づき編纂され、文化的な研究・娯楽の参考のみを目的としています。医療・法律・金融・投資に関する助言ではなく、いかなる実際の効果も保証するものではありません。理性をもってご覧いただき、健康・財産など重要な事項は専門家にご相談ください。",
            "안내: 본 장권은 전통 풍수 문화를 바탕으로 정리되었으며 문화 연구 및 오락 참고용일 뿐, 의료·법률·금융·투자 자문을 제공하지 않으며 어떠한 실제 효과도 보장하지 않습니다. 합리적으로 판단하시고 건강·재산 등 중대한 사항은 전문가와 상담하시기 바랍니다.",
            "Lưu ý: Trường quyển này được biên soạn theo văn hóa Phong Thủy truyền thống, chỉ để tham khảo nghiên cứu văn hóa và giải trí, không phải lời khuyên y tế, pháp lý, tài chính hay đầu tư, cũng không hứa hẹn bất kỳ kết quả thực tế nào. Hãy nhìn nhận hợp lý; các vấn đề quan trọng như sức khỏe, tài sản vui lòng tham vấn chuyên gia.",
            "หมายเหตุ: ม้วนนี้จัดทำขึ้นตามวัฒนธรรมฮวงจุ้ยโบราณ เพื่อการศึกษาวัฒนธรรมและความบันเทิงเท่านั้น ไม่ใช่คำแนะนำทางการแพทย์ กฎหมาย การเงินหรือการลงทุน และไม่รับประกันผลลัพธ์จริงใด ๆ โปรดพิจารณาอย่างมีสติ เรื่องสำคัญด้านสุขภาพและทรัพย์สินควรปรึกษาผู้เชี่ยวชาญ",
            "Catatan: Gulungan ini disusun berdasarkan budaya Feng Shui tradisional, hanya untuk kajian budaya dan hiburan; bukan nasihat medis, hukum, keuangan atau investasi, dan tidak menjanjikan hasil nyata apa pun. Harap disikapi secara rasional; untuk hal penting seperti kesehatan dan properti, konsultasikan dengan ahli."
        )
        curY += 260f
        curY += drawMeasuredText(disclaimer, curY, disclaimerTextPaint, 100f, 880) + 60f

        val finalHeight = curY.toInt() + 60

        // 绘制朱丝栏边框与回纹
        val borderPaint = Paint().apply {
            color = vermilionColor
            style = Paint.Style.STROKE
            strokeWidth = 6f
        }
        val innerBorderPaint = Paint().apply {
            color = vermilionColor
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        val margin = 36f
        canvas.drawRect(margin, margin, width - margin, finalHeight - margin, borderPaint)
        canvas.drawRect(margin + 12f, margin + 12f, width - margin - 12f, finalHeight - margin - 12f, innerBorderPaint)

        // 16. 非会员预览水印
        if (!isPro) {
            val watermark = tr8(
                "预览 · 解锁后导出无水印长卷",
                "預覽 · 解鎖後匯出無水印長卷",
                "PREVIEW · UNLOCK TO EXPORT WITHOUT WATERMARK",
                "プレビュー・解放すると透かしなしで出力",
                "미리보기 · 잠금 해제 후 워터마크 없이 내보내기",
                "XEM TRƯỚC · MỞ KHÓA ĐỂ XUẤT KHÔNG DẤU",
                "ตัวอย่าง · ปลดล็อกเพื่อส่งออกแบบไม่มีลายน้ำ",
                "PRATINJAU · BUKA KUNCI UNTUK EKSPOR TANPA TANDA AIR"
            )
            canvas.save()
            val wmPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = vermilionColor
                alpha = 40
                textSize = 34f
                typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            canvas.translate(width * 0.5f, finalHeight * 0.5f)
            canvas.rotate(-22.5f)
            var yOffsetWm = -finalHeight.toFloat()
            while (yOffsetWm <= finalHeight) {
                canvas.drawText(watermark, 0f, yOffsetWm, wmPaint)
                yOffsetWm += 180f
            }
            canvas.restore()
        }

        return ScrollRender(bitmap,finalHeight)
    }

    private fun drawSectionHeader(canvas: Canvas, title: String, atY: Float, vermilion: Int) {
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilion
            strokeWidth = 2f
        }
        canvas.drawLine(90f, atY + 38f, 990f, atY + 38f, linePaint)

        val headPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilion
            textSize = 28f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            letterSpacing = 0.08f
        }
        canvas.drawText(title, 95f, atY + 28f, headPaint)
    }

    private fun tr8(
        hans: String,
        hant: String,
        en: String,
        ja: String,
        ko: String,
        vi: String,
        th: String,
        id: String,
        renderLanguage: AppLanguage
    ): String {
        return when (renderLanguage) {
            AppLanguage.ZH_HANT -> hant
            AppLanguage.EN -> en
            AppLanguage.JA -> ja
            AppLanguage.KO -> ko
            AppLanguage.VI -> vi
            AppLanguage.TH -> th
            AppLanguage.ID -> id
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> hans
        }
    }

    private fun drawMeasuredTextDirect(
        canvas: Canvas,
        text: String,
        atY: Float,
        paint: TextPaint,
        x: Float = 100f,
        width: Int = 880,
        minimumHeight: Float = 0f
    ): Float {
        val staticLayout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setLineSpacing(0f, 1.15f)
                .setIncludePad(false)
                .build()
        } else {
            @Suppress("DEPRECATION")
            StaticLayout(text, paint, width, Layout.Alignment.ALIGN_NORMAL, 1.15f, 0f, false)
        }
        canvas.save()
        canvas.translate(x, atY)
        staticLayout.draw(canvas)
        canvas.restore()
        val measuredHeight = staticLayout.height.toFloat()
        return maxOf(measuredHeight, minimumHeight)
    }

    private fun drawFloorplanAudit(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        report: List<FloorplanAuditItem>,
        paint: TextPaint
    ): Float {
        val title = tr8(
            "户型现场审计 · 房间与缺角锦囊",
            "戶型現場審計 · 房間與缺角錦囊",
            "FLOORPLAN SURVEY · ROOM & CORNER REMEDIES",
            "間取り現場監査・部屋と欠角の化解",
            "평면 현장 감사 · 방과 결각 해법",
            "KIỂM TRA MẶT BẰNG · PHÒNG VÀ GÓC KHUYẾT",
            "ตรวจผังบ้าน · วิธีแก้ห้องและมุมเว้า",
            "AUDIT DENAH · SOLUSI RUANG & SUDUT HILANG",
            renderLanguage
        )
        drawSectionHeader(canvas, title, curY, vermilion)
        var y = curY + 62f
        for (item in report) {
            val line = "【${item.localizedSeverity}】${item.title} · ${item.palace}\n${item.lore}\n→ ${item.solution}"
            y += drawMeasuredTextDirect(canvas, line, y, paint) + 14f
        }
        return y + 10f
    }

    private fun drawFlyingStarsDetails(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        chart: XuanKongChart,
        paint: TextPaint
    ): Float {
        val title = tr8(
            "玄空九宫全盘 · 山向星与逐宫锦囊",
            "玄空九宮全盤 · 山向星與逐宮錦囊",
            "XUAN KONG NINE PALACES · FULL STAR REMEDIES",
            "玄空九宮全盤・山向星と各宮の化解",
            "현공 구궁 전체 · 산향성 및 궁별 해법",
            "CỬU CUNG HUYỀN KHÔNG · SAO VÀ CẨM NANG TỪNG CUNG",
            "เก้าวังเสวียนคง · ดาวและเคล็ดลับทุกวัง",
            "SEMBILAN ISTANA XUAN KONG · BINTANG & SOLUSI TIAP ISTANA",
            renderLanguage
        )
        drawSectionHeader(canvas, title, curY, vermilion)
        var y = curY + 62f
        for (cell in chart.palaces) {
            val mLabel = tr8("山星", "山星", "Mountain", "山星", "산성", "Sơn tinh", "ดาวภูเขา", "Gunung", renderLanguage)
            val fLabel = tr8("向星", "向星", "Facing", "向星", "향성", "Hướng tinh", "ดาวหัน", "Hadap", renderLanguage)
            val line = "【${cell.localizedPalaceName}】 · $mLabel ${cell.mountainStar} · $fLabel ${cell.facingStar} · ${cell.localizedEvaluation}"
            var displayLine = line
            if (cell.isShaWuHuang || cell.isShaErHei) {
                displayLine += " · " + if (cell.isShaWuHuang)
                    tr8("五黄", "五黃", "5-Yellow", "五黄", "오황", "Ngũ Hoàng", "5 เหลือง", "5-Kuning", renderLanguage)
                else
                    tr8("二黑", "二黑", "2-Black", "二黒", "이흑", "Nhị Hắc", "2 ดำ", "2-Hitam", renderLanguage)
            }
            y += drawMeasuredTextDirect(canvas, displayLine, y, paint) + 12f
        }
        return y + 18f
    }

    private fun drawQimenDetails(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        chart: QimenChart,
        paint: TextPaint
    ): Float {
        val title = tr8(
            "奇门九宫全盘 · 门星神干与趋避锦囊",
            "奇門九宮全盤 · 門星神干與趨避錦囊",
            "QIMEN NINE PALACES · DOOR, STAR, DEITY & GUIDANCE",
            "奇門九宮全盤・門星神干と吉凶",
            "기문 구궁 전체 · 문성신간 및 길흉",
            "CỬU CUNG KỲ MÔN · MÔN, TINH, THẦN, CAN VÀ CẨM NANG",
            "เก้าวังขี่เหมิน · ประตู ดาว เทพ ก้านฟ้า และคำแนะนำ",
            "SEMBILAN ISTANA QIMEN · GERBANG, BINTANG, DEWA & PETUNJUK",
            renderLanguage
        )
        drawSectionHeader(canvas, title, curY, vermilion)
        var y = curY + 62f
        for (cell in chart.cells) {
            val tLabel = tr8("天", "天", "Heaven ", "天", "천 ", "Thiên ", "ฟ้า ", "Langit ", renderLanguage)
            val dLabel = tr8("地", "地", "Earth ", "地", "지 ", "Địa ", "ดิน ", "Bumi ", renderLanguage)
            val line = "【${cell.localizedPalaceName}】${cell.localizedDoorName} · ${cell.localizedStarName} · ${cell.localizedGodName} · $tLabel${cell.localizedTianStem}/$dLabel${cell.localizedDiStem} · ${cell.doorLuck}"
            y += drawMeasuredTextDirect(canvas, line, y, paint) + 12f
        }
        val guidance = tr8(
            "趋吉：${chart.bestNavDirection}；避忌：${chart.tabooDirections}；${chart.bestNavReason}",
            "趨吉：${chart.bestNavDirection}；避忌：${chart.tabooDirections}；${chart.bestNavReason}",
            "Favorable: ${chart.bestNavDirection}; avoid: ${chart.tabooDirections}; ${chart.bestNavReason}",
            "吉方：${chart.bestNavDirection}；忌方：${chart.tabooDirections}；${chart.bestNavReason}",
            "길방: ${chart.bestNavDirection}; 금기: ${chart.tabooDirections}; ${chart.bestNavReason}",
            "Cát: ${chart.bestNavDirection}; tránh: ${chart.tabooDirections}; ${chart.bestNavReason}",
            "มงคล: ${chart.bestNavDirection}; หลีกเลี่ยง: ${chart.tabooDirections}; ${chart.bestNavReason}",
            "Baik: ${chart.bestNavDirection}; hindari: ${chart.tabooDirections}; ${chart.bestNavReason}",
            renderLanguage
        )
        y += drawMeasuredTextDirect(canvas, guidance, y, paint) + 18f
        return y
    }

    private fun drawZeRiDetails(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        analysis: ZeRiAnalysis,
        paint: TextPaint
    ): Float {
        val title = tr8(
            "择日全案 · 神煞警告与宜忌锦囊",
            "擇日全案 · 神煞警告與宜忌錦囊",
            "DATE SELECTION · WARNINGS, DO & AVOID",
            "擇日全案・神煞警告と宜忌",
            "택일 전체 · 신살 경고 및 의기",
            "TRẠCH NHẬT · CẢNH BÁO VÀ VIỆC NÊN/KHÔNG NÊN",
            "ฤกษ์ยาม · คำเตือนและกิจกรรมควร/ห้าม",
            "PEMILIHAN HARI · PERINGATAN DAN KEGIATAN",
            renderLanguage
        )
        drawSectionHeader(canvas, title, curY, vermilion)
        var y = curY + 62f
        val lines = mutableListOf<String>()
        lines.add(analysis.fourPillarsText)
        lines.add(analysis.overallStatus)
        analysis.suiPoWarning?.let { lines.add(it) }
        analysis.yuePoWarning?.let { lines.add(it) }
        analysis.sittingClashWarning?.let { lines.add(it) }
        analysis.sanShaWarning?.let { lines.add(it) }
        if (analysis.detailsText.isNotEmpty()) lines.add(analysis.detailsText)

        val yiLabel = tr8("宜：", "宜：", "Do: ", "宜：", "권장: ", "Nên: ", "ควร: ", "Anjuran: ", renderLanguage)
        val jiLabel = tr8("忌：", "忌：", "Avoid: ", "忌：", "금기: ", "Tránh: ", "ห้าม: ", "Hindari: ", renderLanguage)
        val sep = when (renderLanguage) {
            AppLanguage.EN, AppLanguage.KO, AppLanguage.VI, AppLanguage.TH, AppLanguage.ID -> ", "
            else -> "、"
        }
        if (analysis.yiActivities.isNotEmpty()) {
            lines.add(yiLabel + analysis.yiActivities.joinToString(sep))
        }
        if (analysis.jiActivities.isNotEmpty()) {
            lines.add(jiLabel + analysis.jiActivities.joinToString(sep))
        }
        for (line in lines) {
            y += drawMeasuredTextDirect(canvas, line, y, paint) + 12f
        }
        return y + 18f
    }

    private fun drawPurpleWhiteRemedies(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        pwChart: PurpleWhiteChart,
        paint: TextPaint
    ): Float {
        val secTitle = tr8(
            "紫白流年 · 客星调理与催旺",
            "紫白流年 · 客星調理與催旺",
            "PURPLE-WHITE YEAR · GUEST STAR REMEDIES",
            "紫白流年・客星の調理と催旺",
            "자백 유년 · 객성 조리와 최왕",
            "TỬ BẠCH LƯU NIÊN · ĐIỀU LÝ KHÁCH TINH",
            "ดาวม่วงขาวประจำปี · ปรับดาวเยือนและเสริมพลัง",
            "BINTANG UNGU-PUTIH · PENYESUAIAN BINTANG TAMU",
            renderLanguage
        )
        drawSectionHeader(canvas, secTitle, curY, vermilion)
        var y = curY + 62f
        for (item in pwChart.palaceItems) {
            val line = "「${item.palaceName}」${item.advice}"
            y += drawMeasuredTextDirect(canvas, line, y, paint) + 12f
        }
        return y + 10f
    }

    private fun drawBazhaiInjurious(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        bz: BaZhaiAnalysis,
        paint: TextPaint
    ): Float {
        val secTitle = tr8(
            "八宅八宫 · 吉凶化解安镇",
            "八宅八宮 · 吉凶化解安鎮",
            "EIGHT MANSIONS · ALL PALACE REMEDIES",
            "八宅八宮・吉凶の化解と安鎮",
            "팔택 팔궁 · 길흉 화해와 안진",
            "BÁT TRẠCH BÁT CUNG · HÓA GIẢI TOÀN BỘ",
            "แปดเรือนแปดวัง · แก้เคล็ดครบถ้วน",
            "DELAPAN ISTANA · SEMUA PENANGKAL",
            renderLanguage
        )
        drawSectionHeader(canvas, secTitle, curY, vermilion)
        var y = curY + 62f
        for (item in bz.items) {
            val line = "【${item.star.localizedName} · ${item.localizedDirection}】${item.star.localizedSuggestion}"
            y += drawMeasuredTextDirect(canvas, line, y, paint) + 12f
        }
        return y + 10f
    }

    private fun drawShaSelfCheck(
        canvas: Canvas,
        curY: Float,
        vermilion: Int,
        renderLanguage: AppLanguage,
        archive: PanoramaFengShuiArchive?,
        paint: TextPaint
    ): Float {
        val secTitle = tr8(
            if (archive == null) "形煞自查 · 通用锦囊" else "形煞自查 · 当前现场记录",
            if (archive == null) "形煞自查 · 通用錦囊" else "形煞自查 · 當前現場記錄",
            if (archive == null) "EXTERNAL SHA · GENERAL REMEDIES" else "EXTERNAL SHA · CURRENT SURVEY",
            if (archive == null) "形煞セルフチェック・一般的な化解" else "形煞セルフチェック・現場記録",
            if (archive == null) "형살 자점 · 일반 화해" else "형살 자점 · 현장 기록",
            if (archive == null) "TỰ TRA HÌNH SÁT · CẨM NANG CHUNG" else "TỰ TRA HÌNH SÁT · GHI NHẬN HIỆN TRƯỜNG",
            if (archive == null) "ตรวจสอบเครื่องหมายพิฆาต · เคล็ดลับทั่วไป" else "ตรวจสอบเครื่องหมายพิฆาต · บันทึกภาคสนาม",
            if (archive == null) "PEMERIKSAAN SHA · PENANGKAL UMUM" else "PEMERIKSAAN SHA · SURVEI SAAT INI",
            renderLanguage
        )
        drawSectionHeader(canvas, secTitle, curY, vermilion)
        var y = curY + 62f

        if (archive != null) {
            for (record in archive.exterior) {
                val sha = ExteriorShaEngine.instance.find(record.shaID)
                val name = sha?.localizedName ?: record.shaID
                val remedy = sha?.localizedRemedySolution ?: ""
                var metadata = String.format(Locale.US, "%.1f°", record.bearingDegrees)
                metadata += String.format(Locale.US, " · 仰角 %.1f°", record.elevationDegrees)
                record.distanceMeters?.let {
                    metadata += String.format(Locale.US, " · %.1f m", it)
                }
                record.confidence?.let {
                    metadata += String.format(Locale.US, " · %.0f%%", it * 100)
                }
                metadata += if (record.source == ShaRecordSource.AI) " · AI" else " · 手动"
                if (!record.note.isNullOrEmpty()) {
                    metadata += " · " + record.note
                }
                val line = "【$name · $metadata】$remedy"
                y += drawMeasuredTextDirect(canvas, line, y, paint) + 14f
            }

            archive.interior?.let { interior ->
                val interiorSummaryText = tr8(
                    "室内测绘：${interior.scanMethod} · 房间 ${interior.rooms.size} · 墙体 ${interior.walls.size} · 门窗 ${interior.openings.size} · 风水评分 ${interior.fengshuiScore}",
                    "室內測繪：${interior.scanMethod} · 房間 ${interior.rooms.size} · 牆體 ${interior.walls.size} · 門窗 ${interior.openings.size} · 風水評分 ${interior.fengshuiScore}",
                    "Interior survey: ${interior.scanMethod} · rooms ${interior.rooms.size} · walls ${interior.walls.size} · openings ${interior.openings.size} · score ${interior.fengshuiScore}",
                    "室内測量：${interior.scanMethod}・部屋 ${interior.rooms.size}・壁 ${interior.walls.size}・開口部 ${interior.openings.size}・スコア ${interior.fengshuiScore}",
                    "실내 측량: ${interior.scanMethod} · 방 ${interior.rooms.size} · 벽 ${interior.walls.size} · 개구부 ${interior.openings.size} · 점수 ${interior.fengshuiScore}",
                    "Khảo sát nội thất: ${interior.scanMethod} · phòng ${interior.rooms.size} · tường ${interior.walls.size} · cửa mở ${interior.openings.size} · điểm ${interior.fengshuiScore}",
                    "สำรวจภายใน: ${interior.scanMethod} · ห้อง ${interior.rooms.size} · ผนัง ${interior.walls.size} · ช่องเปิด ${interior.openings.size} · คะแนน ${interior.fengshuiScore}",
                    "Survei interior: ${interior.scanMethod} · ruang ${interior.rooms.size} · dinding ${interior.walls.size} · bukaan ${interior.openings.size} · skor ${interior.fengshuiScore}",
                    renderLanguage
                )
                val interiorSummary = interiorSummaryText + String.format(Locale.US, " · %.1f°", archive.compassHeading)
                y += drawMeasuredTextDirect(canvas, interiorSummary, y, paint) + 14f

                for (item in interior.shaItems) {
                    val line = "【${item.title} · ${item.severity.localizedTitle}】${item.solution}"
                    y += drawMeasuredTextDirect(canvas, line, y, paint) + 14f
                }
            }

            if (archive.exterior.isEmpty() && archive.interior?.shaItems?.isEmpty() != false) {
                val emptyLine = tr8(
                    "已建立现场档案，但当前没有可展示的形煞条目。",
                    "已建立現場檔案，但目前沒有可展示的形煞條目。",
                    "A survey archive exists, but it contains no sha findings.",
                    "現場記録はありますが、形煞の検出項目はありません。",
                    "현장 기록은 있지만 형살 항목이 없습니다.",
                    "Đã có hồ sơ khảo sát nhưng chưa có mục hình sát.",
                    "มีแฟ้มสำรวจแล้ว แต่ยังไม่มีรายการพิฆาต",
                    "Arsip survei ada, tetapi tidak ada temuan sha.",
                    renderLanguage
                )
                y += drawMeasuredTextDirect(canvas, emptyLine, y, paint) + 14f
            }
        } else {
            for (sha in ExteriorShaEngine.instance.database) {
                val line = "【${sha.localizedName}】${sha.localizedRemedySolution}"
                y += drawMeasuredTextDirect(canvas, line, y, paint) + 14f
            }
        }
        return y + 10f
    }

    /**
     * 保存长卷到系统相册并返回本地化提示文本
     */
    fun saveToGallery(context: Context, bitmap: Bitmap): Boolean {
        return saveToGalleryWithFeedback(context, bitmap).first
    }

    fun saveToGalleryWithFeedback(context: Context, bitmap: Bitmap): Pair<Boolean, String> {
        val lang = LocalizationManager.instance.effectiveLanguage
        val successMsg = when (lang) {
            AppLanguage.EN -> "Celestial scroll saved to Photos successfully."
            AppLanguage.ZH_HANT -> "天機宣紙勘測長卷已成功保存至系統相簿！"
            AppLanguage.JA -> "天機宣紙鑑定長巻がアルバムに保存されました！"
            AppLanguage.KO -> "천기 선지 감여 장권이 사진첩에 성공적으로 저장되었습니다!"
            AppLanguage.VI -> "Bản đồ phong thủy tuyên chỉ đã lưu vào album ảnh thành công!"
            AppLanguage.TH -> "บันทึกคัมภีร์ตรวจฮวงจุ้ยลงในอัลบั้มรูปเรียบร้อยแล้ว!"
            AppLanguage.ID -> "Gulungan Feng Shui berhasil disimpan ke galeri foto!"
            else -> "天机宣纸勘测长卷已成功保存至系统相册！"
        }
        val failureMsg = LocalizationManager.instance.t("save_failed")

        val filename = "TianJiYanXiang_Scroll_${System.currentTimeMillis()}.jpg"
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/YanXiang")
                }
                val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: return Pair(false, failureMsg)
                val stream: OutputStream? = context.contentResolver.openOutputStream(uri)
                val ok = stream?.use {
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
                } ?: false
                Pair(ok, if (ok) successMsg else failureMsg)
            } else {
                val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).toString() + "/YanXiang"
                val dir = java.io.File(imagesDir)
                if (!dir.exists()) dir.mkdirs()
                val image = java.io.File(dir, filename)
                val fos = java.io.FileOutputStream(image)
                fos.use {
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
                }
                Pair(true, successMsg)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Pair(false, e.localizedMessage ?: failureMsg)
        }
    }
}
