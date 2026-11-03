package com.example.yiijingcompass.model

import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.*

enum class SpatialShaSeverity(val rawValue: String, val badgeColorHex: String) {
    AUSPICIOUS("吉", "#34C759"),
    WARNING("轻微", "#FF9500"),
    CRITICAL("严重", "#FF3B30")
}

enum class SpatialOpeningType(val rawValue: String) {
    ENTRANCE_DOOR("入户门"),
    INTERIOR_DOOR("房门"),
    WINDOW("采光窗"),
    OPENING("洞口"),
    BALCONY_DOOR("阳台门")
}

data class SpatialWall3D(
    val id: String = UUID.randomUUID().toString(),
    val startX: Float,
    val startY: Float,
    val startZ: Float,
    val endX: Float,
    val endY: Float,
    val endZ: Float,
    val height: Float = 2.8f,
    val thickness: Float = 0.2f,
    val isLoadBearing: Boolean = false
) {
    val length: Float
        get() = sqrt((endX - startX) * (endX - startX) + (endZ - startZ) * (endZ - startZ))
}

data class SpatialOpening3D(
    val id: String = UUID.randomUUID().toString(),
    val type: SpatialOpeningType,
    val posX: Float,
    val posY: Float,
    val posZ: Float,
    val width: Float,
    val height: Float,
    val normalX: Float = 0f,
    val normalZ: Float = 1f
)

data class SpatialBeam3D(
    val id: String = UUID.randomUUID().toString(),
    val startX: Float,
    val startY: Float,
    val startZ: Float,
    val endX: Float,
    val endY: Float,
    val endZ: Float,
    val dropHeight: Float = 0.4f,
    val width: Float = 0.3f
)

data class SpatialRoom3D(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: String, // "客厅", "主卧", "厨房", "卫生间", etc.
    val centerX: Float,
    val centerY: Float,
    val centerZ: Float,
    val width: Float,
    val depth: Float,
    val height: Float = 2.8f,
    val areaSqMeters: Float = width * depth
)

data class SpatialObject3D(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val posX: Float,
    val posY: Float,
    val posZ: Float,
    val width: Float,
    val depth: Float,
    val height: Float
)

data class HouseDimensions(
    val totalWidth: Float,
    val totalDepth: Float,
    val maxCeilingHeight: Float,
    val grossFloorAreaSqMeters: Float,
    val aspectRatio: Float = if (totalWidth > 0f) totalDepth / totalWidth else 1f
)

data class HouseSpatialShaItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val severity: SpatialShaSeverity,
    val locationName: String,
    val detail: String,
    val fengshuiLore: String,
    val solution: String,
    val coordinateX: Float? = null,
    val coordinateY: Float? = null,
    val coordinateZ: Float? = null
)

data class HouseSpatialSurvey(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Date = Date(),
    val scanMethod: String = "AR_LiDAR",
    val dimensions: HouseDimensions,
    val walls: List<SpatialWall3D>,
    val openings: List<SpatialOpening3D>,
    val beams: List<SpatialBeam3D>,
    val rooms: List<SpatialRoom3D>,
    val objects: List<SpatialObject3D>,
    val centroidX: Float,
    val centroidY: Float,
    val centroidZ: Float,
    val compassHeading: Double,
    val shaItems: List<HouseSpatialShaItem>,
    val fengshuiScore: Int,
    val isCentroidIndirect: Boolean? = false
) {
    fun generateCAD_DXF(): String {
        val s = StringBuilder()
        s.append("0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n6\n9\n\$ANGBASE\n50\n0.0\n0\nENDSEC\n")
        s.append("0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n7\n")

        val layers = listOf(
            Pair("WALLS_BEARING", 5),
            Pair("WALLS_PARTITION", 4),
            Pair("DOORS", 2),
            Pair("WINDOWS", 3),
            Pair("BEAMS", 1),
            Pair("ROOM_LABELS", 7),
            Pair("TAIJI_CENTER", 40)
        )
        for (l in layers) {
            s.append("0\nLAYER\n2\n${l.first}\n70\n0\n62\n${l.second}\n6\nCONTINUOUS\n")
        }
        s.append("0\nENDTAB\n0\nENDSEC\n")
        s.append("0\nSECTION\n2\nENTITIES\n")

        for (wall in walls) {
            val layer = if (wall.isLoadBearing) "WALLS_BEARING" else "WALLS_PARTITION"
            s.append("0\nLINE\n8\n$layer\n")
            s.append("10\n${String.format(Locale.US, "%.3f", wall.startX)}\n20\n${String.format(Locale.US, "%.3f", -wall.startZ)}\n30\n0.0\n")
            s.append("11\n${String.format(Locale.US, "%.3f", wall.endX)}\n21\n${String.format(Locale.US, "%.3f", -wall.endZ)}\n31\n0.0\n")
        }

        for (op in openings) {
            val layer = if (op.type == SpatialOpeningType.ENTRANCE_DOOR || op.type == SpatialOpeningType.INTERIOR_DOOR) "DOORS" else "WINDOWS"
            val halfW = op.width * 0.5f
            val p1X = op.posX - op.normalZ * halfW
            val p1Y = -(op.posZ + op.normalX * halfW)
            val p2X = op.posX + op.normalZ * halfW
            val p2Y = -(op.posZ - op.normalX * halfW)
            s.append("0\nLINE\n8\n$layer\n")
            s.append("10\n${String.format(Locale.US, "%.3f", p1X)}\n20\n${String.format(Locale.US, "%.3f", p1Y)}\n30\n0.0\n")
            s.append("11\n${String.format(Locale.US, "%.3f", p2X)}\n21\n${String.format(Locale.US, "%.3f", p2Y)}\n31\n0.0\n")
        }

        for (beam in beams) {
            s.append("0\nLINE\n8\nBEAMS\n")
            s.append("10\n${String.format(Locale.US, "%.3f", beam.startX)}\n20\n${String.format(Locale.US, "%.3f", -beam.startZ)}\n30\n0.0\n")
            s.append("11\n${String.format(Locale.US, "%.3f", beam.endX)}\n21\n${String.format(Locale.US, "%.3f", -beam.endZ)}\n31\n0.0\n")
        }

        s.append("0\nCIRCLE\n8\nTAIJI_CENTER\n")
        s.append("10\n${String.format(Locale.US, "%.3f", centroidX)}\n20\n${String.format(Locale.US, "%.3f", -centroidZ)}\n30\n0.0\n40\n0.5\n")
        s.append("0\nTEXT\n8\nTAIJI_CENTER\n")
        s.append("10\n${String.format(Locale.US, "%.3f", centroidX + 0.6f)}\n20\n${String.format(Locale.US, "%.3f", -centroidZ)}\n30\n0.0\n40\n0.35\n1\nTaiJi Center\n")

        for (room in rooms) {
            s.append("0\nTEXT\n8\nROOM_LABELS\n")
            s.append("10\n${String.format(Locale.US, "%.3f", room.centerX - 0.4f)}\n20\n${String.format(Locale.US, "%.3f", -room.centerZ)}\n30\n0.0\n")
            s.append("40\n0.30\n1\n${room.name} ${String.format(Locale.US, "%.1f", room.areaSqMeters)}m2\n")
        }

        s.append("0\nENDSEC\n0\nEOF\n")
        return s.toString()
    }
}

object HouseSpatialSurveyEngine {
    fun analyzeSpatialHouse(
        scanMethod: String,
        walls: List<SpatialWall3D>,
        openings: List<SpatialOpening3D>,
        beams: List<SpatialBeam3D>,
        rooms: List<SpatialRoom3D>,
        objects: List<SpatialObject3D>,
        compassHeading: Double,
        centroidOverride: Triple<Float, Float, Float>? = null
    ): HouseSpatialSurvey {
        var minX = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var minZ = Float.MAX_VALUE
        var maxZ = -Float.MAX_VALUE
        var maxH = 2.8f

        for (w in walls) {
            minX = min(minX, min(w.startX, w.endX))
            maxX = max(maxX, max(w.startX, w.endX))
            minZ = min(minZ, min(w.startZ, w.endZ))
            maxZ = max(maxZ, max(w.startZ, w.endZ))
            maxH = max(maxH, w.height)
        }

        val totalW = if (maxX > minX) maxX - minX else 10f
        val totalD = if (maxZ > minZ) maxZ - minZ else 10f
        val totalArea = rooms.map { it.areaSqMeters }.sum().let { if (it > 0f) it else totalW * totalD * 0.75f }

        val dim = HouseDimensions(
            totalWidth = totalW,
            totalDepth = totalD,
            maxCeilingHeight = maxH,
            grossFloorAreaSqMeters = totalArea
        )

        val cx = centroidOverride?.first ?: ((minX + maxX) * 0.5f)
        val cy = centroidOverride?.second ?: 0f
        val cz = centroidOverride?.third ?: ((minZ + maxZ) * 0.5f)

        val shaItems = mutableListOf<HouseSpatialShaItem>()
        var score = 92

        // 1. 横梁压顶检测
        for (b in beams) {
            for (obj in objects) {
                if (obj.name.contains("床") || obj.name.contains("沙发") || obj.name.contains("办公桌")) {
                    val dist = distancePointToSegment(obj.posX, obj.posZ, b.startX, b.startZ, b.endX, b.endZ)
                    if (dist < 0.6f) {
                        shaItems.add(
                            HouseSpatialShaItem(
                                title = "横梁压顶煞",
                                severity = SpatialShaSeverity.CRITICAL,
                                locationName = obj.name,
                                detail = "横梁投影经过${obj.name}正上方（垂直间距小于 2.4 米），形成下压气场煞",
                                fengshuiLore = "《八宅明镜》云：梁压床头神气衰，主头痛失眠、事业受制",
                                solution = "建议通过局部吊顶包裹横梁，或移动${obj.name}避开横梁垂直正下方投影",
                                coordinateX = obj.posX,
                                coordinateY = obj.posY,
                                coordinateZ = obj.posZ
                            )
                        )
                        score -= 8
                    }
                }
            }
        }

        // 2. 门冲煞检测（对门相冲）
        for (i in openings.indices) {
            val d1 = openings[i]
            if (d1.type != SpatialOpeningType.ENTRANCE_DOOR && d1.type != SpatialOpeningType.INTERIOR_DOOR) continue
            for (j in i + 1 until openings.size) {
                val d2 = openings[j]
                if (d2.type != SpatialOpeningType.ENTRANCE_DOOR && d2.type != SpatialOpeningType.INTERIOR_DOOR) continue
                val dx = d2.posX - d1.posX
                val dz = d2.posZ - d1.posZ
                val dist = sqrt(dx * dx + dz * dz)
                if (dist in 1.0f..4.0f) {
                    val dot = d1.normalX * d2.normalX + d1.normalZ * d2.normalZ
                    if (dot < -0.7f) {
                        shaItems.add(
                            HouseSpatialShaItem(
                                title = "对门直冲煞",
                                severity = SpatialShaSeverity.WARNING,
                                locationName = "${d1.type.rawValue} ↔ ${d2.type.rawValue}",
                                detail = "两门直线相对（间距约 ${String.format(Locale.US, "%.1fm", dist)}），气流直穿形成穿堂门冲",
                                fengshuiLore = "《相宅经》云：两门相对谓之骂门，主口舌是非、家宅不安",
                                solution = "建议在房门悬挂过膝布帘，或门槛内安放五帝钱阻隔气流直射",
                                coordinateX = (d1.posX + d2.posX) * 0.5f,
                                coordinateY = (d1.posY + d2.posY) * 0.5f,
                                coordinateZ = (d1.posZ + d2.posZ) * 0.5f
                            )
                        )
                        score -= 5
                    }
                }
            }
        }

        // 3. 中宫水土污染（卫生间在中心）
        for (r in rooms) {
            if (r.type.contains("卫") || r.type.contains("厕")) {
                val dx = r.centerX - cx
                val dz = r.centerZ - cz
                val distFromCenter = sqrt(dx * dx + dz * dz)
                if (distFromCenter < totalW * 0.15f) {
                    shaItems.add(
                        HouseSpatialShaItem(
                            title = "中宫受污大煞",
                            severity = SpatialShaSeverity.CRITICAL,
                            locationName = r.name,
                            detail = "卫生间位于整屋几何中宫核心（太极点），秽气渗透全宅八宫",
                            fengshuiLore = "《水龙经》云：太极受污全家病，中宫见水散千金",
                            solution = "保持卫生间门常闭，排气扇常开，放置黄金葛水生绿植并用粗盐吸纳湿秽",
                            coordinateX = r.centerX,
                            coordinateY = r.centerY,
                            coordinateZ = r.centerZ
                        )
                    )
                    score -= 10
                }
            }
        }

        return HouseSpatialSurvey(
            scanMethod = scanMethod,
            dimensions = dim,
            walls = walls,
            openings = openings,
            beams = beams,
            rooms = rooms,
            objects = objects,
            centroidX = cx,
            centroidY = cy,
            centroidZ = cz,
            compassHeading = compassHeading,
            shaItems = shaItems,
            fengshuiScore = max(50, score)
        )
    }

    private fun distancePointToSegment(px: Float, pz: Float, x1: Float, z1: Float, x2: Float, z2: Float): Float {
        val dx = x2 - x1
        val dz = z2 - z1
        val lenSq = dx * dx + dz * dz
        if (lenSq < 1e-6f) {
            val ddx = px - x1
            val ddz = pz - z1
            return sqrt(ddx * ddx + ddz * ddz)
        }
        val t = max(0f, min(1f, ((px - x1) * dx + (pz - z1) * dz) / lenSq))
        val projX = x1 + t * dx
        val projZ = z1 + t * dz
        val diffX = px - projX
        val diffZ = pz - projZ
        return sqrt(diffX * diffX + diffZ * diffZ)
    }
}
