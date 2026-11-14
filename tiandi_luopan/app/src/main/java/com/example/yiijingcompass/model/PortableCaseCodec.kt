package com.example.yiijingcompass.model

import com.google.gson.*
import java.util.Date
import java.util.UUID

/** Reads both Android backups and main-iOS JSONEncoder backups. Apple dates
 * are seconds from 2001; CGRect/CGPoint use unkeyed arrays. Paid grants remain
 * local to their store ledger and are never imported as Android purchases. */
object PortableCaseCodec {
    private const val APPLE_EPOCH=978307200000L
    fun decode(json:String):FloorplanCaseRecord {
        require(json.length<=12_000_000)
        val root=JsonParser.parseString(json).asJsonObject
        val ios=root.get("createdAt")?.let {it.isJsonPrimitive&&it.asJsonPrimitive.isNumber}==true||root.has("backupImageData")||root.getAsJsonObject("layout")?.getAsJsonArray("rooms")?.firstOrNull()?.asJsonObject?.get("rect")?.isJsonArray==true
        val layoutTree=if(root.has("layout"))root.getAsJsonObject("layout") else root
        if(ios)normalize(layoutTree)
        for(key in listOf("spatialSurvey","virtualSpatialSurvey","exteriorRecords","siteFacts"))root.get(key)?.takeIf {!it.isJsonNull}?.let {if(ios)normalize(it)}
        if(ios)root.get("createdAt")?.takeIf {it.isJsonPrimitive&&it.asJsonPrimitive.isNumber}?.let {root.add("createdAt",ProjectCodec.gson.toJsonTree(Date(APPLE_EPOCH+(it.asDouble*1000).toLong())))}
        val layout=ProjectCodec.gson.fromJson(layoutTree,SavedFloorplanLayout::class.java)
        require(ProjectCodec.valid(layout))
        if(root.has("layout")){
            val defaults=ProjectCodec.gson.toJsonTree(FloorplanCaseRecord(title=LocalizationManager.instance.t("native_untitled"),layout=layout)).asJsonObject
            defaults.entrySet().forEach {(key,value)->if(!root.has(key)||root.get(key).isJsonNull)root.add(key,value)}
        }
        val record=if(root.has("layout"))ProjectCodec.gson.fromJson(root,FloorplanCaseRecord::class.java) else FloorplanCaseRecord(title=LocalizationManager.instance.t("native_untitled"),layout=layout)
        val image=if(ios)root.get("backupImageData")?.takeIf {!it.isJsonNull}?.asString else record.backupImageBase64
        return record.copy(id=record.id.takeIf {it.isNotBlank()} ?: UUID.randomUUID().toString(),title=record.title.take(500),
            layout=layout.copy(hasFloorplanAccess=false,floorplanAccessGrantID=null,floorplanAccessGrantSignature=null),
            imageFileName=null,backupImageBase64=image).also {value->
            for(model in listOfNotNull(value.spatialSurvey,value.virtualSpatialSurvey))require(validSurvey(model))
            require(value.exteriorRecords?.all {it.shaID.isNotBlank()&&it.bearingDegrees.isFinite()&&it.elevationDegrees.isFinite()&&(it.distanceMeters==null||it.distanceMeters.isFinite()&&it.distanceMeters>0)}!=false)
            require(value.siteFacts?.all {it.palaceID in 0..8}!=false)
        }
    }
    fun encode(record:FloorplanCaseRecord):String=ProjectCodec.gson.toJson(record)
    private fun validSurvey(model:HouseSpatialSurvey):Boolean=runCatching {
        require(model.rooms.size<=200&&model.walls.size<=5000&&model.objects.size<=3000&&model.openings.size<=3000&&model.beams.size<=3000)
        require(model.compassHeading.isFinite()&&model.centroidX.isFinite()&&model.centroidZ.isFinite())
        model.rooms.forEach {require(it.type in FloorplanRoomType.values()&&listOf(it.centerX,it.centerY,it.centerZ,it.sizeX,it.sizeY,it.sizeZ).all {v->v.isFinite()&&kotlin.math.abs(v)<1000})}
        model.openings.forEach {require(it.type in SpatialOpeningType.values()&&it.width.isFinite()&&it.height.isFinite())}
        model.shaItems.forEach {require(it.severity in SpatialShaSeverity.values())};true
    }.getOrDefault(false)
    private fun normalize(value:JsonElement){
        if(value.isJsonArray){value.asJsonArray.forEach(::normalize);return}
        if(!value.isJsonObject)return
        val objectValue=value.asJsonObject
        objectValue.entrySet().toList().forEach {(key,child)->
            if(child.isJsonNull)return@forEach
            when {
                key=="rect"&&child.isJsonArray->{val rows=child.asJsonArray;require(rows.size()==2)
                    val origin=rows[0].asJsonArray;val size=rows[1].asJsonArray
                    objectValue.add(key,JsonObject().apply {addProperty("left",origin[0].asDouble);addProperty("top",origin[1].asDouble);addProperty("right",origin[0].asDouble+size[0].asDouble);addProperty("bottom",origin[1].asDouble+size[1].asDouble)})}
                key=="polygonPoints"&&child.isJsonArray->{objectValue.add(key,JsonArray().apply {child.asJsonArray.forEach {point->val p=point.asJsonArray;add(JsonObject().apply {addProperty("x",p[0].asDouble);addProperty("y",p[1].asDouble)})}})}
                key in setOf("timestamp","capturedAt","createdAt")&&child.isJsonPrimitive&&child.asJsonPrimitive.isNumber->objectValue.add(key,ProjectCodec.gson.toJsonTree(Date(APPLE_EPOCH+(child.asDouble*1000).toLong())))
                key=="type"&&child.isJsonPrimitive->{val raw=child.asString;val type=FloorplanRoomType.values().firstOrNull {it.rawValue==raw}?.name ?: SpatialOpeningType.values().firstOrNull {it.rawValue==raw}?.name;type?.let {objectValue.addProperty(key,it)}}
                key=="severity"&&child.isJsonPrimitive->SpatialShaSeverity.values().firstOrNull {it.rawValue==child.asString}?.let {objectValue.addProperty(key,it.name)}
                key=="source"&&child.isJsonPrimitive->objectValue.addProperty(key,child.asString.uppercase())
                key=="kind"&&child.isJsonPrimitive->{val names=mapOf("openBright" to "OPEN_BRIGHT","solidBacking" to "SOLID_BACKING","movingWater" to "MOVING_WATER","noise" to "NOISE","glare" to "GLARE","blockedAccess" to "BLOCKED_ACCESS");names[child.asString]?.let {objectValue.addProperty(key,it)}}
                else->normalize(child)
            }
        }
    }
}
