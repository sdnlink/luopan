package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences
import android.graphics.PointF
import com.google.gson.Gson
import java.util.*

object ProjectCodec {
    val gson = Gson()
    fun valid(layout:SavedFloorplanLayout):Boolean = runCatching {
        require(layout.rooms.size<=200&&layout.rooms.map {it.id}.toSet().size==layout.rooms.size)
        require(layout.centroidX.isFinite()&&layout.centroidY.isFinite()&&layout.centroidX in 0.0..1.0&&layout.centroidY in 0.0..1.0)
        require(layout.compassRotation.isFinite()&&(layout.houseFacingDegrees?.isFinite()!=false))
        require(layout.aspectRatio==null||layout.aspectRatio.isFinite()&&layout.aspectRatio in .0025f..400f)
        listOfNotNull(layout.widthMeters,layout.depthMeters).forEach {require(it.isFinite()&&it in .5..200.0)}
        layout.rooms.forEach {room->
            require(room.id.isNotBlank()&&room.name.length<=500&&room.type in FloorplanRoomType.values())
            val rect=room.rect
            listOf(rect.left,rect.top,rect.right,rect.bottom).forEach {require(it.isFinite()&&it in 0f..1f)}
            require(rect.width()>0&&rect.height()>0)
            room.polygonPoints?.let {points->require(points.size in 3..4096);points.forEach {require(it.x.isFinite()&&it.y.isFinite()&&it.x in 0f..1f&&it.y in 0f..1f)}}
        };true
    }.getOrDefault(false)
    fun <T> decode(json: String?, type: Class<T>): T? = if (json == null) null else runCatching { gson.fromJson(json,type) }.getOrNull()
}

data class SavedFloorplanLayout(val rooms: List<FloorplanRoom> = emptyList(), val centroidX: Double = 0.5,
    val centroidY: Double = 0.5, val compassRotation: Double = 0.0, val isSyncWithCompass: Boolean = false,
    val hasFloorplanAccess: Boolean = false, val floorplanAccessGrantID: String? = null,
    val floorplanAccessGrantSignature: String? = null, val aspectRatio: Float? = null,
    val widthMeters: Double? = null, val depthMeters: Double? = null,
    val houseFacingDegrees: Double? = null, val houseFacingWasExplicit: Boolean? = null,
    val surveyMapping: FloorplanSurveyMapping? = null, val familyRoomAssignments: List<FamilyRoomAssignment>? = null) {
    val centroid get() = PointF(centroidX.toFloat(),centroidY.toFloat())
    val orientation get() = FloorplanOrientation(compassRotation,houseFacingDegrees)
}

data class FloorplanCaseRecord(val id: String = UUID.randomUUID().toString(), var title: String,
    val createdAt: Date = Date(), val sittingSummary: String = "", val layout: SavedFloorplanLayout,
    val imageFileName: String? = null, val spatialSurvey: HouseSpatialSurvey? = null,
    val virtualSpatialSurvey: HouseSpatialSurvey? = null, val exteriorRecords: List<ExteriorShaRecord>? = null,
    val siteFacts: List<XuanKongSiteFact>? = null, val propertyKey: String? = null, val backupImageBase64: String? = null)

data class FloorplanWorkspaceSnapshot(val revision: Long, val propertyID: String,
    val writerID: String?, val layout: SavedFloorplanLayout?, val imageFileName: String?)

class FloorplanWorkspaceStore(context: Context) {
    private val prefs = context.getSharedPreferences("floorplan_workspace",Context.MODE_PRIVATE)
    var snapshot = FloorplanWorkspaceSnapshot(0,ShaSurveyStore.instance.propertyID,null,
        ProjectCodec.decode(prefs.getString("layout",null),SavedFloorplanLayout::class.java),prefs.getString("image",null))
        private set
    @Synchronized fun save(layout: SavedFloorplanLayout, imageFileName: String?, writerID: String,
        expectedRevision: Long? = null, expectedPropertyID: String? = null): Boolean {
        if (expectedRevision != null && snapshot.revision != expectedRevision) return false
        if (expectedPropertyID != null && !ShaSurveyStore.instance.isCurrentProperty(expectedPropertyID)) return false
        val json = ProjectCodec.gson.toJson(layout)
        if(snapshot.propertyID==ShaSurveyStore.instance.propertyID&&snapshot.imageFileName==imageFileName&&prefs.getString("layout",null)==json)return true
        if (!prefs.edit().putString("layout",json).putString("image",imageFileName).commit()) return false
        snapshot = FloorplanWorkspaceSnapshot(snapshot.revision + 1,ShaSurveyStore.instance.propertyID,writerID,layout,imageFileName)
        return true
    }
    companion object {
        @Volatile private var shared: FloorplanWorkspaceStore? = null
        fun get(context: Context) = shared ?: synchronized(this) {
            shared ?: FloorplanWorkspaceStore(context.applicationContext).also { shared = it }
        }
    }
}

class FloorplanCaseStore(context: Context) {
    private val prefs = context.getSharedPreferences("floorplan_cases",Context.MODE_PRIVATE)
    val records:List<FloorplanCaseRecord> get()=prefs.getString("records",null)?.let {value->runCatching {ProjectCodec.gson.fromJson(value,Array<FloorplanCaseRecord>::class.java).toList()}.getOrNull()} ?: emptyList()
    fun insert(record:FloorplanCaseRecord):Boolean=synchronized(mutationLock){
        val current=records;val next=if(current.any {it.id==record.id})record.copy(id=UUID.randomUUID().toString()) else record
        persist(listOf(next)+current)
    }
    fun rename(id:String,title:String):Boolean=synchronized(mutationLock){if(title.isBlank())false else persist(records.map {if(it.id==id)it.copy(title=title.trim()) else it})}
    fun remove(id:String):Boolean=synchronized(mutationLock){persist(records.filterNot {it.id==id})}
    private fun persist(next:List<FloorplanCaseRecord>):Boolean=prefs.edit().putString("records",ProjectCodec.gson.toJson(next)).commit()
    companion object {
        private val mutationLock=Any()
        @Volatile private var shared: FloorplanCaseStore? = null
        fun get(context: Context) = shared ?: synchronized(this) {
            shared ?: FloorplanCaseStore(context.applicationContext).also { shared = it }
        }
    }
}

enum class XuanKongSiteFactKind(val titleKey: String) {
    OPEN_BRIGHT("xkd_fact_open"), SOLID_BACKING("xkd_fact_backing"), MOVING_WATER("xkd_fact_water"),
    NOISE("xkd_fact_noise"), GLARE("xkd_fact_glare"), BLOCKED_ACCESS("xkd_fact_blocked")
}
data class XuanKongSiteFact(val kind: XuanKongSiteFactKind, val palaceID: Int)
