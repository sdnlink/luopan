package com.example.yiijingcompass.model

import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.*

object XuanKongHomeContextBuilder {
    fun facing(layout:SavedFloorplanLayout?,survey:HouseSpatialSurvey?)=listOfNotNull(layout?.houseFacingDegrees,survey?.resolvedHouseFacing).firstOrNull {it.isFinite()}
    fun build(layout:SavedFloorplanLayout?,survey:HouseSpatialSurvey?,exterior:List<ExteriorShaRecord>,facts:List<XuanKongSiteFact>):XuanKongHomeContext {
        val places=mutableListOf<XuanKongLocatedPlace>();val missing=mutableListOf<String>();val warnings=mutableListOf<String>()
        var accepted=survey
        val a=layout?.houseFacingDegrees;val b=survey?.resolvedHouseFacing
        if(a!=null&&b!=null&&a.isFinite()&&b.isFinite()){val delta=abs(a-b)%360;if(min(delta,360-delta)>7.5){accepted=null;warnings.add("xkd_orientation_conflict")}}
        if(layout!=null&&accepted!=null&&layout.rooms.isNotEmpty()&&layout.surveyMapping?.point(accepted.centroidX,accepted.centroidZ,accepted.id)==null){
            if(accepted.openings.isNotEmpty()||accepted.objects.isNotEmpty())warnings.add("xkd_alignment_missing");accepted=null
        }
        val rooms=layout?.rooms?.filter {it.rect.left.isFinite()&&it.rect.top.isFinite()&&it.rect.width().isFinite()&&it.rect.height().isFinite()&&it.rect.width()>0&&it.rect.height()>0} ?: emptyList()
        val bounds=RectF();var hasBounds=false
        rooms.filter {it.type!=FloorplanRoomType.MISSING_CORNER}.forEach {if(!hasBounds){bounds.set(it.rect);hasBounds=true}else bounds.union(it.rect)}
        val ratio=layout?.aspectRatio?.takeIf {it.isFinite()&&it>0} ?: 1f
        val radius=if(hasBounds)min(bounds.width()*ratio,bounds.height())*.12f else .03f
        fun planSector(point:PointF):Int? {
            val plan=layout ?: return null
            if(hypot((point.x-plan.centroid.x)*ratio,point.y-plan.centroid.y)<radius)return 4
            return XuanKongDeepAnalyzer.palaceID(GeometryUtils.bearing(plan.centroid,point,ratio)+plan.compassRotation)
        }
        if(layout!=null&&layout.compassRotation.isFinite()&&layout.centroidX.isFinite()&&layout.centroidY.isFinite())rooms.forEach {room->
            if(room.type in setOf(FloorplanRoomType.DOOR,FloorplanRoomType.MISSING_CORNER)){
                planSector(room.center)?.let {id->places.add(XuanKongLocatedPlace("plan-${room.id}-$id",id,room.name,if(room.type==FloorplanRoomType.DOOR)XuanKongPlaceKind.ENTRANCE else XuanKongPlaceKind.ROOM,room.type))}
            }else{
                val counts=mutableMapOf<Int,Int>()
                for(x in 0..10)for(y in 0..10){val point=PointF(room.rect.left+room.rect.width()*(x+.5f)/11,room.rect.top+room.rect.height()*(y+.5f)/11)
                    if(FloorplanEngine.roomContains(room,point))planSector(point)?.let {counts[it]=(counts[it] ?: 0)+1}}
                val total=counts.values.sum().coerceAtLeast(1)
                counts.toSortedMap().forEach {(id,count)->places.add(XuanKongLocatedPlace("plan-${room.id}-$id",id,room.name,XuanKongPlaceKind.ROOM,room.type,max(1,(count*100.0/total).roundToInt())))}
            }
        }
        accepted?.takeIf {it.compassHeading.isFinite()}?.let {model->
            val center=model.centroid;val r=min(model.dimensions.totalWidth,model.dimensions.totalDepth)*.12f
            fun sector(x:Float,z:Float):Int? {
                if(!x.isFinite()||!z.isFinite()||!center.x.isFinite()||!center.z.isFinite())return null
                if(layout!=null&&layout.rooms.isNotEmpty())return layout.surveyMapping?.point(x,z,model.id)?.let(::planSector)
                if(hypot(x-center.x,z-center.z)<r)return 4
                return XuanKongDeepAnalyzer.palaceID(atan2((x-center.x).toDouble(),-(z-center.z).toDouble())*180/PI+model.compassHeading)
            }
            if(layout==null||layout.rooms.isEmpty())model.rooms.forEach {room->
                val counts=mutableMapOf<Int,Int>();val angle=room.rotationY ?: 0f
                for(x in 0..10)for(z in 0..10){val lx=room.sizeX*(x+.5f)/11-room.sizeX/2;val lz=room.sizeZ*(z+.5f)/11-room.sizeZ/2
                    sector(room.centerX+lx*cos(angle)-lz*sin(angle),room.centerZ+lx*sin(angle)+lz*cos(angle))?.let {counts[it]=(counts[it] ?: 0)+1}}
                val total=counts.values.sum().coerceAtLeast(1)
                counts.toSortedMap().forEach {(id,count)->places.add(XuanKongLocatedPlace("room-${room.id}-$id",id,room.name,XuanKongPlaceKind.ROOM,room.type,max(1,(count*100.0/total).roundToInt())))}
            }
            model.openings.forEach {opening->sector(opening.posX,opening.posZ)?.let {id->places.add(XuanKongLocatedPlace("opening-${opening.id}",id,opening.type.localizedName,
                when(opening.type){SpatialOpeningType.ENTRANCE_DOOR->XuanKongPlaceKind.ENTRANCE;SpatialOpeningType.WINDOW,SpatialOpeningType.BALCONY_DOOR->XuanKongPlaceKind.WINDOW;else->XuanKongPlaceKind.INTERIOR_DOOR}))}}
            model.objects.filter {it.category in setOf("bed","stove","oven")}.forEach {obj->sector(obj.posX,obj.posZ)?.let {id->places.add(XuanKongLocatedPlace("object-${obj.id}",id,obj.localizedCategoryName,if(obj.category=="bed")XuanKongPlaceKind.BED else XuanKongPlaceKind.STOVE))}}
        }
        if(places.isEmpty())missing.add("xkd_missing_plan")
        if(places.none {it.kind==XuanKongPlaceKind.WINDOW})missing.add("xkd_missing_window")
        if(places.none {it.kind==XuanKongPlaceKind.BED})missing.add("xkd_missing_bed")
        if(places.none {it.kind==XuanKongPlaceKind.STOVE})missing.add("xkd_missing_stove")
        if(exterior.isEmpty()&&facts.isEmpty())missing.add("xkd_missing_exterior")
        return XuanKongHomeContext(places,exterior.filter {it.bearingDegrees.isFinite()},facts.filter {it.palaceID in 0..8},missing,warnings)
    }
}
