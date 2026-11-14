package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.UUID

enum class ShaRecordSource {
    AI,
    MANUAL
}

data class ExteriorShaRecord(
    val id: String = UUID.randomUUID().toString(),
    val shaID: String,
    val bearingDegrees: Double,
    val capturedHeadingDegrees: Double? = null,
    val elevationDegrees: Double = 0.0,
    val distanceMeters: Float? = null,
    val confidence: Double? = null,
    val capturedAt: Date = Date(),
    val source: ShaRecordSource = ShaRecordSource.MANUAL,
    val note: String? = null
) {
    val palaceIndex: Int
        get() = absolutePalaceIndex(bearingDegrees)

    fun palaceIndex(relativeTo: Double): Int {
        val relative = bearingDegrees - relativeTo
        return absolutePalaceIndex(relative)
    }

    private fun absolutePalaceIndex(bearing: Double): Int {
        if (!bearing.isFinite()) return 0
        val norm = (bearing % 360.0 + 360.0) % 360.0
        return ((norm / 45.0).toInt()) % 8
    }

    fun toJsonObject(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("shaID", shaID)
            put("bearingDegrees", bearingDegrees)
            if (capturedHeadingDegrees != null) put("capturedHeadingDegrees", capturedHeadingDegrees)
            put("elevationDegrees", elevationDegrees)
            if (distanceMeters != null) put("distanceMeters", distanceMeters.toDouble())
            if (confidence != null) put("confidence", confidence)
            put("capturedAt", capturedAt.time)
            put("source", source.name)
            if (note != null) put("note", note)
        }
    }

    companion object {
        fun fromJsonObject(obj: JSONObject): ExteriorShaRecord {
            return ExteriorShaRecord(
                id = obj.optString("id", UUID.randomUUID().toString()),
                shaID = obj.optString("shaID", "tianzhan"),
                bearingDegrees = obj.optDouble("bearingDegrees", 0.0),
                capturedHeadingDegrees = if (obj.has("capturedHeadingDegrees")) obj.optDouble("capturedHeadingDegrees") else null,
                elevationDegrees = obj.optDouble("elevationDegrees", 0.0),
                distanceMeters = if (obj.has("distanceMeters")) obj.optDouble("distanceMeters").toFloat() else null,
                confidence = if (obj.has("confidence")) obj.optDouble("confidence") else null,
                capturedAt = Date(obj.optLong("capturedAt", System.currentTimeMillis())),
                source = try { ShaRecordSource.valueOf(obj.optString("source", "MANUAL")) } catch (_: Exception) { ShaRecordSource.MANUAL },
                note = if (obj.has("note")) obj.optString("note") else null
            )
        }
    }
}

enum class ShaDistanceGrade {
    CRITICAL_NEAR,  // < 30m：加重一级
    STATIC_LEVEL,   // 30~100m：保持静态等级
    MITIGATED_FAR   // > 100m：减轻一级
}

object ExteriorShaSeverityResolver {
    fun grade(distanceMeters: Float?): ShaDistanceGrade {
        if (distanceMeters == null || distanceMeters <= 0f || !distanceMeters.isFinite()) return ShaDistanceGrade.STATIC_LEVEL
        return when {
            distanceMeters < 30.0f -> ShaDistanceGrade.CRITICAL_NEAR
            distanceMeters > 100.0f -> ShaDistanceGrade.MITIGATED_FAR
            else -> ShaDistanceGrade.STATIC_LEVEL
        }
    }

    fun effectiveSeverity(staticSeverity: ShaSeverity, distanceMeters: Float?): ShaSeverity {
        return when (grade(distanceMeters)) {
            ShaDistanceGrade.CRITICAL_NEAR -> when (staticSeverity) {
                ShaSeverity.NOTICE -> ShaSeverity.MINOR
                ShaSeverity.MINOR -> ShaSeverity.WARNING
                ShaSeverity.WARNING, ShaSeverity.CRITICAL -> ShaSeverity.CRITICAL
            }
            ShaDistanceGrade.MITIGATED_FAR -> when (staticSeverity) {
                ShaSeverity.CRITICAL -> ShaSeverity.WARNING
                ShaSeverity.WARNING -> ShaSeverity.MINOR
                ShaSeverity.MINOR -> ShaSeverity.MINOR
                ShaSeverity.NOTICE -> ShaSeverity.NOTICE
            }
            ShaDistanceGrade.STATIC_LEVEL -> staticSeverity
        }
    }
}

data class ShaPanoramaReport(
    val id: String = UUID.randomUUID().toString(),
    val capturedAt: Date = Date(),
    val headingDegrees: Double,
    val records: List<ExteriorShaRecord>
) {
    val palacesByIndex: List<List<ExteriorShaRecord>>
        get() {
            val result = MutableList(8) { mutableListOf<ExteriorShaRecord>() }
            for (record in records) {
                val idx = record.palaceIndex(headingDegrees)
                result[idx].add(record)
            }
            return result
        }

    val scannedPalaceCount: Int
        get() = palacesByIndex.count { it.isNotEmpty() }
}

data class PanoramaFengShuiArchive(
    val id: String = UUID.randomUUID().toString(),
    val createdAt: Date = Date(),
    val compassHeading: Double,
    val interior: HouseSpatialSurvey?,
    val exterior: List<ExteriorShaRecord>
) {
    val interiorShaCount: Int get() = interior?.shaItems?.size ?: 0
    val exteriorShaCount: Int get() = exterior.size
    val totalShaCount: Int get() = interiorShaCount + exteriorShaCount
}

class ShaSurveyStore private constructor() {
    companion object {
        val instance: ShaSurveyStore by lazy { ShaSurveyStore() }
        private const val PREFS_NAME = "tianji_sha_survey_prefs"
        private const val KEY_RECORDS = "survey_records"
    }

    private var prefs: SharedPreferences? = null
    var propertyID: String = UUID.randomUUID().toString()
        private set
    var propertyKey: String = UUID.randomUUID().toString()
        private set
    var interiorSource: InteriorSurveySource? = null
        private set
    var siteFacts: List<XuanKongSiteFact> = emptyList()
        private set
    val records: MutableList<ExteriorShaRecord> = mutableListOf()
    var latestInterior: HouseSpatialSurvey? = null

    val archive: PanoramaFengShuiArchive?
        get() {
            if (records.isEmpty() && latestInterior == null) return null
            return PanoramaFengShuiArchive(
                compassHeading = records.firstNotNullOfOrNull { it.capturedHeadingDegrees } ?: latestInterior?.compassHeading ?: 0.0,
                interior = latestInterior,
                exterior = ArrayList(records)
            )
        }

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        loadFromPrefs()
        propertyKey = prefs?.getString("propertyKey",null) ?: propertyKey
        prefs?.edit()?.putString("propertyKey",propertyKey)?.commit()
        latestInterior = ProjectCodec.decode(prefs?.getString("interior",null),HouseSpatialSurvey::class.java)
        interiorSource = prefs?.getString("source",null)?.let { runCatching { InteriorSurveySource.valueOf(it) }.getOrNull() }
        siteFacts = prefs?.getString("facts",null)?.let { runCatching { ProjectCodec.gson.fromJson(it,Array<XuanKongSiteFact>::class.java).toList() }.getOrNull() } ?: emptyList()
    }

    private fun loadFromPrefs() {
        records.clear()
        val json = prefs?.getString(KEY_RECORDS, null) ?: return
        try {
            val array = JSONArray(json)
            records.clear()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                records.add(ExteriorShaRecord.fromJsonObject(obj))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun persist() {
        try {
            val array = JSONArray()
            for (r in records) {
                array.put(r.toJsonObject())
            }
            prefs?.edit()?.putString(KEY_RECORDS, array.toString())?.putString("propertyKey",propertyKey)
                ?.putString("interior",latestInterior?.let { ProjectCodec.gson.toJson(it) })
                ?.putString("source",interiorSource?.name)?.putString("facts",ProjectCodec.gson.toJson(siteFacts))?.apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun addRecord(record: ExteriorShaRecord) {
        records.add(record)
        persist()
    }

    fun updateInterior(survey: HouseSpatialSurvey?) {
        latestInterior = survey
        interiorSource = survey?.let { InteriorSurveySource.PROJECTION }
        persist()
    }

    @Synchronized fun isCurrentProperty(id: String) = propertyID == id
    @Synchronized fun replaceProperty(measured: HouseSpatialSurvey?, virtual: HouseSpatialSurvey?, exterior: List<ExteriorShaRecord>,
        siteFacts: List<XuanKongSiteFact> = emptyList(), propertyKey: String? = null, expectedPropertyID: String? = null): Boolean {
        if(expectedPropertyID != null && !isCurrentProperty(expectedPropertyID)) return false
        if(expectedPropertyID == null) { propertyID=UUID.randomUUID().toString(); this.propertyKey=propertyKey ?: UUID.randomUUID().toString() }
        prefs?.edit()?.putString(SpatialSurveyArchiveKeys.MEASURED,measured?.let { ProjectCodec.gson.toJson(it) })
            ?.putString(SpatialSurveyArchiveKeys.VIRTUAL,virtual?.let { ProjectCodec.gson.toJson(it) })?.apply()
        records.clear(); records.addAll(exterior); this.siteFacts=siteFacts.filter { it.palaceID in 0..8 }
        latestInterior=measured ?: virtual
        interiorSource=if(measured != null) InteriorSurveySource.MEASURED else if(virtual != null) InteriorSurveySource.VIRTUAL else null
        persist(); return true
    }
    @Synchronized fun saveSurvey(survey: HouseSpatialSurvey,key: String,propertyID: String): Boolean {
        if(!isCurrentProperty(propertyID) || key !in setOf(SpatialSurveyArchiveKeys.MEASURED,SpatialSurveyArchiveKeys.VIRTUAL)) return false
        prefs?.edit()?.putString(key,ProjectCodec.gson.toJson(survey))?.apply()
        if(key == SpatialSurveyArchiveKeys.MEASURED || prefs?.contains(SpatialSurveyArchiveKeys.MEASURED) != true&&interiorSource!=InteriorSurveySource.PROJECTION) {
            latestInterior=survey; interiorSource=if(key == SpatialSurveyArchiveKeys.MEASURED) InteriorSurveySource.MEASURED else InteriorSurveySource.VIRTUAL; persist()
        }
        return true
    }
    fun projectModels(): Pair<HouseSpatialSurvey?,HouseSpatialSurvey?> =
        ProjectCodec.decode(prefs?.getString(SpatialSurveyArchiveKeys.MEASURED,null),HouseSpatialSurvey::class.java) to
            ProjectCodec.decode(prefs?.getString(SpatialSurveyArchiveKeys.VIRTUAL,null),HouseSpatialSurvey::class.java)
    fun refreshMeasuredSurvey(survey: HouseSpatialSurvey,propertyID: String) = replaceProperty(survey,null,records.toList(),siteFacts,expectedPropertyID=propertyID)
    fun setSiteFact(kind: XuanKongSiteFactKind,palaceID: Int,present: Boolean,propertyID: String) {
        if(!isCurrentProperty(propertyID) || palaceID !in 0..8) return
        siteFacts=siteFacts.filterNot { it.kind == kind && it.palaceID == palaceID } + if(present) listOf(XuanKongSiteFact(kind,palaceID)) else emptyList()
        persist()
    }

    fun clearRecords() {
        records.clear()
        persist()
    }

    fun removeRecord(id: String) {
        records.removeAll { it.id == id }
        persist()
    }

    fun removeLastRecord() {
        if (records.isNotEmpty()) {
            records.removeAt(records.size - 1)
            persist()
        }
    }

    fun createReport(headingDegrees: Double): ShaPanoramaReport {
        return ShaPanoramaReport(
            headingDegrees = headingDegrees,
            records = ArrayList(records)
        )
    }
}

enum class InteriorSurveySource { MEASURED, VIRTUAL, PROJECTION }
object SpatialSurveyArchiveKeys {
    const val MEASURED="latest_house_spatial_survey"
    const val VIRTUAL="latest_vr_house_spatial_survey"
}

