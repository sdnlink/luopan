package com.example.yiijingcompass.model

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TianJiShuEngine private constructor() {
    companion object {
        val instance: TianJiShuEngine by lazy { TianJiShuEngine() }
    }

    @Suppress("UNUSED_PARAMETER")
    fun generateScrollImage(
        context: Context,
        heading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        floorplanReport: List<FloorplanAuditItem> = emptyList(),
        shaReport: ShaPanoramaReport? = null,
        reportDate: Date = Date()
    ): Bitmap {
        val width = 1080
        val baseHeight = 3200
        val extraFloorplanHeight = maxOf(0, floorplanReport.size - 4) * 160
        val extraShaHeight = maxOf(0, (shaReport?.records?.size ?: 0) - 4) * 160
        val height = baseHeight + extraFloorplanHeight + extraShaHeight

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 背景：仿古宣纸色
        val bgPaint = Paint().apply {
            color = Color.rgb(249, 246, 238)
            style = Paint.Style.FILL
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

        // 朱丝栏边框与回纹
        val vermilionColor = Color.rgb(178, 34, 34)
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
        canvas.drawRect(margin, margin, width - margin, height - margin, borderPaint)
        canvas.drawRect(margin + 12f, margin + 12f, width - margin - 12f, height - margin - 12f, innerBorderPaint)

        // 字体样式
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(40, 20, 10)
            textSize = 56f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val subtitlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(100, 60, 40)
            textSize = 30f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
            textAlign = Paint.Align.CENTER
        }
        val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilionColor
            textSize = 38f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(30, 30, 30)
            textSize = 28f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }
        val notePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(120, 120, 120)
            textSize = 24f
            typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
        }

        var curY = 130f
        canvas.drawText("天机演象 · 福宅勘测全案长卷", width / 2f, curY, titlePaint)
        curY += 60f
        val df = SimpleDateFormat("yyyy年MM月dd日 HH:mm", Locale.getDefault())
        canvas.drawText("公历日期：${df.format(reportDate)}    真太阳时：$solarTimeDesc", width / 2f, curY, subtitlePaint)
        curY += 50f
        canvas.drawText("测绘坐标：$coordsDesc    罗盘基准：真北定向", width / 2f, curY, subtitlePaint)
        curY += 70f

        // 分割线
        canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
        curY += 60f

        // 模块一：时空罗盘与坐向立极
        canvas.drawText("【第一卷 · 空间立极与二十四山度数】", margin + 40f, curY, headerPaint)
        curY += 50f
        val headingState = Mountain24Data.instance.resolveHeadingState(heading)
        canvas.drawText("· 坐向定格：坐【${headingState.sittingMountain.name}】向【${headingState.facingMountain.name}】（度数：${String.format(Locale.US, "%.1f°", heading)}）", margin + 50f, curY, bodyPaint)
        curY += 44f
        canvas.drawText("· 分金状态：${headingState.facingFenjin.jiaziName}分金 · ${headingState.facingFenjin.grade} (${headingState.facingFenjin.centerAngle}°)", margin + 50f, curY, bodyPaint)
        curY += 44f
        val hexagram = Hexagram64Data.instance.hexagram(heading)
        canvas.drawText("· 易经六十四卦：第${hexagram.id + 1}卦【${hexagram.name}】(${hexagram.luckDegree}) · ${hexagram.fenJinDetail}", margin + 50f, curY, bodyPaint)
        curY += 44f
        canvas.drawText("· 空亡差错检验：${headingState.kongWangLevel.description}", margin + 50f, curY, bodyPaint)
        curY += 70f

        // 模块二：玄空理气九宫飞星排盘
        canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
        curY += 60f
        canvas.drawText("【第二卷 · 玄空九宫飞星大运研判】", margin + 40f, curY, headerPaint)
        curY += 50f
        val xkChart = FlyingStarsEngine.instance.calculateChart(
            sitting = headingState.sittingMountain,
            facing = headingState.facingMountain,
            date = reportDate
        )
        canvas.drawText("· 当令元运：${xkChart.periodMeta.label}", margin + 50f, curY, bodyPaint)
        curY += 44f
        canvas.drawText("· 理气格局：${xkChart.patternType}", margin + 50f, curY, bodyPaint)
        curY += 44f
        canvas.drawText("· 核心评述：${xkChart.summaryAnalysis}", margin + 50f, curY, bodyPaint)
        curY += 70f

        // 模块三：八宅游年与吉凶八方
        canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
        curY += 60f
        canvas.drawText("【第三卷 · 八宅大游年九星吉凶】", margin + 40f, curY, headerPaint)
        curY += 50f
        val bz = BaZhaiEngine.instance.analyze(headingState.sittingMountain.palace, headingState.facingMountain.palace)
        canvas.drawText("· 宅卦归属：${bz.houseGua} (${bz.houseType}) · 大门向首配星：${bz.gateStar.rawValue}", margin + 50f, curY, bodyPaint)
        curY += 50f
        for (item in bz.items.take(4)) {
            val starSign = if (item.star.isAuspicious) "[吉]" else "[凶]"
            canvas.drawText("  - ${item.direction}：${item.star.rawValue} $starSign", margin + 60f, curY, bodyPaint)
            curY += 40f
        }
        curY += 40f

        // 模块四：户型体检与缺角化解
        if (floorplanReport.isNotEmpty()) {
            canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
            curY += 60f
            canvas.drawText("【第四卷 · 户型空间体检与布局建议】", margin + 40f, curY, headerPaint)
            curY += 50f
            for (audit in floorplanReport) {
                canvas.drawText("· ${audit.title} [${audit.palace}]", margin + 50f, curY, bodyPaint)
                curY += 40f
                canvas.drawText("  化解方案：${audit.solution}", margin + 70f, curY, notePaint)
                curY += 46f
            }
            curY += 30f
        }

        // 模块五：外部形煞勘测存证
        if (shaReport != null && shaReport.records.isNotEmpty()) {
            canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
            curY += 60f
            canvas.drawText("【第五卷 · 外部形煞实测与法器化解】", margin + 40f, curY, headerPaint)
            curY += 50f
            for (rec in shaReport.records) {
                val sha = ExteriorShaEngine.instance.find(rec.shaID)
                val distStr = if (rec.distanceMeters != null) "距离约 ${String.format(Locale.US, "%.1fm", rec.distanceMeters)}" else "实测目标"
                canvas.drawText("· 方位 ${String.format(Locale.US, "%.1f°", rec.bearingDegrees)} 检出【${sha?.name ?: rec.shaID}】($distStr)", margin + 50f, curY, bodyPaint)
                curY += 40f
                if (sha != null) {
                    canvas.drawText("  化解：${sha.remedySolution.take(80)}...", margin + 70f, curY, notePaint)
                    curY += 46f
                }
            }
            curY += 30f
        }

        // 落款印章
        curY += 40f
        canvas.drawLine(margin + 30f, curY, width - margin - 30f, curY, innerBorderPaint)
        curY += 60f
        val sealPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilionColor
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        val sealFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = vermilionColor
            textSize = 28f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val sealRect = RectF(width - margin - 220f, curY, width - margin - 40f, curY + 120f)
        canvas.drawRoundRect(sealRect, 16f, 16f, sealPaint)
        canvas.drawText("天机演象", sealRect.centerX(), sealRect.centerY() - 10f, sealFill)
        canvas.drawText("勘测之印", sealRect.centerX(), sealRect.centerY() + 30f, sealFill)

        curY += 150f
        canvas.drawText("声明：本长卷报告基于传统易经堪舆数理模型生成，供建筑空间与环境美学参考。", width / 2f, curY, notePaint)

        return bitmap
    }

    fun saveToGallery(context: Context, bitmap: Bitmap): Boolean {
        val filename = "TianJiYanXiang_Scroll_${System.currentTimeMillis()}.jpg"
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/YanXiang")
                }
                val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: return false
                val stream: OutputStream? = context.contentResolver.openOutputStream(uri)
                stream?.use {
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
                } ?: false
            } else {
                val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).toString() + "/YanXiang"
                val file = java.io.File(imagesDir)
                if (!file.exists()) file.mkdirs()
                val image = java.io.File(imagesDir, filename)
                val fos = java.io.FileOutputStream(image)
                fos.use {
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
                }
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}

