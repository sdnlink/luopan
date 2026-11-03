package com.example.yiijingcompass.model

import android.graphics.PointF
import android.graphics.RectF
import java.io.File
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

enum class FloorplanRoomType(val rawValue: String) {
    LIVING_ROOM("客厅"),
    MASTER_BEDROOM("主卧"),
    SECOND_BEDROOM("次卧"),
    KITCHEN("厨房"),
    BATHROOM("卫生间"),
    STUDY("书房"),
    DINING_ROOM("餐厅"),
    BALCONY("阳台"),
    ENTRANCE("玄关"),
    STORAGE("储藏室"),
    MISSING_CORNER("缺角标记"),
    UNKNOWN("其他空间")
}

data class FloorplanRoom(
    val id: String,
    val name: String,
    val type: FloorplanRoomType,
    val rect: RectF,
    var palaceName: String = "",
    var inspectionTitle: String = "",
    var inspectionLevel: String = "",
    var inspectionLore: String = "",
    var inspectionAdvice: String = ""
) {
    val area: Float get() = rect.width() * rect.height()
    val center: PointF get() = PointF(rect.centerX(), rect.centerY())
}

data class FloorplanAuditItem(
    val id: String,
    val title: String,
    val palace: String,
    val severity: String,
    val lore: String,
    val solution: String
)

class FloorplanEngine private constructor() {
    companion object {
        val instance: FloorplanEngine by lazy { FloorplanEngine() }
    }

    fun generateSampleRooms(): List<FloorplanRoom> {
        return listOf(
            FloorplanRoom("r1", "客厅", FloorplanRoomType.LIVING_ROOM, RectF(100f, 100f, 300f, 300f)),
            FloorplanRoom("r2", "主卧", FloorplanRoomType.MASTER_BEDROOM, RectF(300f, 100f, 500f, 250f)),
            FloorplanRoom("r3", "厨房", FloorplanRoomType.KITCHEN, RectF(100f, 300f, 200f, 450f)),
            FloorplanRoom("r4", "卫生间", FloorplanRoomType.BATHROOM, RectF(200f, 300f, 300f, 450f)),
            FloorplanRoom("r5", "阳台", FloorplanRoomType.BALCONY, RectF(100f, 50f, 300f, 100f))
        )
    }

    fun computeCentroid(rooms: List<FloorplanRoom>): PointF {
        if (rooms.isEmpty()) return PointF(250f, 250f)
        var totalArea = 0f
        var cx = 0f
        var cy = 0f
        for (r in rooms) {
            val a = r.area
            totalArea += a
            cx += r.center.x * a
            cy += r.center.y * a
        }
        return if (totalArea > 0f) PointF(cx / totalArea, cy / totalArea) else PointF(250f, 250f)
    }

    fun auditFloorplan(
        rooms: List<FloorplanRoom>,
        centroid: PointF,
        heading: Double
    ): Pair<List<FloorplanRoom>, List<FloorplanAuditItem>> {
        val updatedRooms = mutableListOf<FloorplanRoom>()
        val report = mutableListOf<FloorplanAuditItem>()

        for (room in rooms) {
            val palace = palaceForPoint(room.center, centroid, heading)
            val r = room.copy(palaceName = "${palace.first} (${palace.second}宫)")

            val audit = evaluateRoom(r.type, palace.second, palace.first)
            r.inspectionTitle = audit.first
            r.inspectionLevel = audit.second
            r.inspectionLore = audit.third
            r.inspectionAdvice = audit.fourth

            updatedRooms.add(r)
            report.add(
                FloorplanAuditItem(
                    id = "room-${r.id}",
                    title = "${r.name} · ${audit.first}",
                    palace = r.palaceName,
                    severity = audit.second,
                    lore = audit.third,
                    solution = audit.fourth
                )
            )
        }

        return Pair(updatedRooms, report)
    }

    private fun palaceForPoint(point: PointF, centroid: PointF, heading: Double): Pair<String, String> {
        val dx = point.x - centroid.x
        val dy = -(point.y - centroid.y)
        var angleRad = atan2(dx.toDouble(), dy.toDouble())
        var angleDeg = Math.toDegrees(angleRad)
        if (angleDeg < 0) angleDeg += 360.0

        val geoAngle = (angleDeg + heading + 360.0) % 360.0
        return when (geoAngle) {
            in 22.5..67.5 -> Pair("东北", "艮")
            in 67.5..112.5 -> Pair("正东", "震")
            in 112.5..157.5 -> Pair("东南", "巽")
            in 157.5..202.5 -> Pair("正南", "离")
            in 202.5..247.5 -> Pair("西南", "坤")
            in 247.5..292.5 -> Pair("正西", "兑")
            in 292.5..337.5 -> Pair("西北", "乾")
            else -> Pair("正北", "坎")
        }
    }

    private fun evaluateRoom(type: FloorplanRoomType, palaceGua: String, palaceDir: String): Quad<String, String, String, String> {
        return when (type) {
            FloorplanRoomType.KITCHEN -> {
                if (palaceGua == "乾") {
                    Quad("火烧天门大煞", "大凶", "乾宫属金为天门、男主人与事业核心，厨房属火直克乾金，主破耗、头部心脑疾厄。", "炉灶下方铺设黄色耐火防油地垫，悬挂天然木葫芦或陶土摆件化火生土生金。")
                } else if (palaceGua == "坎") {
                    Quad("水火相战", "中凶", "坎宫属水，厨房属火，水火未济，注意肠胃与心肾水火不调。", "多用木质元素装潢或绿植通关水火。")
                } else {
                    Quad("厨房安位", "吉", "厨房安于${palaceDir}${palaceGua}宫，火木相生或火土相生，灶位安宁。", "保持台面通风整洁即可。")
                }
            }
            FloorplanRoomType.BATHROOM -> {
                if (palaceGua == "中" || palaceGua == "乾") {
                    Quad("水土受污", "大凶", "卫浴落于核心宫位，浊气外泄污损宅运根基，主退财病滞。", "保持常关门排风，放置黄金葛绿植与粗盐陶罐吸纳湿秽。")
                } else if (palaceGua == "离") {
                    Quad("水火相激", "中凶", "离火受坎水秽气冲激，注意目疾与心火虚旺。", "浴室门常闭，门槛处加铺绿地垫。")
                } else {
                    Quad("卫浴安位", "吉", "卫浴落于泄煞位，排浊合宜。", "注意除湿排风。")
                }
            }
            FloorplanRoomType.MASTER_BEDROOM -> {
                if (palaceGua == "乾" || palaceGua == "坤" || palaceGua == "艮") {
                    Quad("主卧得位", "大吉", "主卧坐于生旺福德宫位，地气沉稳，丁财两旺。", "床头朝吉方，避免梁压或镜子对床。")
                } else {
                    Quad("主卧安宁", "吉", "卧室气场温和，利于休息调养。", "避免强烈杂色光污染。")
                }
            }
            FloorplanRoomType.LIVING_ROOM -> {
                Quad("明堂开阔", "大吉", "客厅坐落纳气开阳之方，明堂宽敞容纳万家吉瑞。", "保持沙发靠山稳固，电视动线流畅。")
            }
            FloorplanRoomType.STUDY -> {
                if (palaceGua == "巽" || palaceGua == "震") {
                    Quad("文昌显贵", "大吉", "文昌木星得位，聪明秀发，利学业考运功名。", "书桌面向开阔门窗，桌上置文昌塔或四支毛笔。")
                } else {
                    Quad("书房静养", "吉", "适宜安坐研习。", "采光充足为宜。")
                }
            }
            else -> {
                Quad("空间均和", "吉", "气场顺遂，动线适度。", "常保明亮清洁。")
            }
        }
    }

    fun exportDXF(rooms: List<FloorplanRoom>, centroid: PointF): String {
        val sb = StringBuilder()
        sb.append("0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n6\n0\nENDSEC\n")
        sb.append("0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n4\n")
        sb.append("0\nLAYER\n2\nROOMS\n70\n0\n62\n7\n6\nCONTINUOUS\n")
        sb.append("0\nLAYER\n2\nTAIJI\n70\n0\n62\n1\n6\nCONTINUOUS\n")
        sb.append("0\nENDTAB\n0\nENDSEC\n")
        sb.append("0\nSECTION\n2\nENTITIES\n")

        for (r in rooms) {
            val left = r.rect.left / 100f
            val top = -r.rect.top / 100f
            val right = r.rect.right / 100f
            val bottom = -r.rect.bottom / 100f

            sb.append("0\nLINE\n8\nROOMS\n10\n$left\n20\n$top\n30\n0.0\n11\n$right\n21\n$top\n31\n0.0\n")
            sb.append("0\nLINE\n8\nROOMS\n10\n$right\n20\n$top\n30\n0.0\n11\n$right\n21\n$bottom\n31\n0.0\n")
            sb.append("0\nLINE\n8\nROOMS\n10\n$right\n20\n$bottom\n30\n0.0\n11\n$left\n21\n$bottom\n31\n0.0\n")
            sb.append("0\nLINE\n8\nROOMS\n10\n$left\n20\n$bottom\n30\n0.0\n11\n$left\n21\n$top\n31\n0.0\n")

            sb.append("0\nTEXT\n8\nROOMS\n10\n${(left + right) / 2f}\n20\n${(top + bottom) / 2f}\n30\n0.0\n40\n0.3\n1\n${r.name}\n")
        }

        val cx = centroid.x / 100f
        val cy = -centroid.y / 100f
        sb.append("0\nCIRCLE\n8\nTAIJI\n10\n$cx\n20\n$cy\n30\n0.0\n40\n0.5\n")
        sb.append("0\nTEXT\n8\nTAIJI\n10\n${cx + 0.6f}\n20\n$cy\n30\n0.0\n40\n0.35\n1\nTaiJi Center\n")

        sb.append("0\nENDSEC\n0\nEOF\n")
        return sb.toString()
    }

    private data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
}

