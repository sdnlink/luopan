package com.example.yiijingcompass.model

import android.content.Context
import java.io.File
import java.util.Date
import java.util.UUID
import kotlin.math.*

data class CapturedRoom(val id:String=UUID.randomUUID().toString(),val name:String,val type:FloorplanRoomType,
    val points:List<Vec3f>,val height:Float=2.8f)
data class SpatialMapArchive(val format:String="android-landmark-map-v1",val propertyKey:String,val coordinateHeading:Double,
    val landmarks:List<Vec3f>,val rooms:List<CapturedRoom>,val rulerPoints:List<Vec3f> = emptyList(),val createdAt:Date=Date())

/** Gravity-aligned rigid registration from user-confirmed physical landmarks.
 * This restores annotations after a new session; it does not serialize an
 * unsupported ARKit world map or pretend ARCore relocalized automatically. */
data class SpatialMapRegistration(val radians:Double,val oldOrigin:Vec3f,val newOrigin:Vec3f,val errorMeters:Double){
    fun point(old:Vec3f):Vec3f {
        val x=old.x-oldOrigin.x;val z=old.z-oldOrigin.z
        return Vec3f((newOrigin.x+x*cos(radians)-z*sin(radians)).toFloat(),old.y-oldOrigin.y+newOrigin.y,
            (newOrigin.z+x*sin(radians)+z*cos(radians)).toFloat())
    }
    fun heading(old:Double)=(old-radians*180/PI+720)%360
    companion object {
        fun fit(old:List<Vec3f>,current:List<Vec3f>):SpatialMapRegistration? {
            if(old.size!=current.size||old.size<3||old.any {!it.x.isFinite()||!it.y.isFinite()||!it.z.isFinite()}||current.any {!it.x.isFinite()||!it.y.isFinite()||!it.z.isFinite()})return null
            fun center(p:List<Vec3f>)=Vec3f(p.map {it.x}.average().toFloat(),p.map {it.y}.average().toFloat(),p.map {it.z}.average().toFloat())
            val a=center(old);val b=center(current);var dot=0.0;var cross=0.0;var size=0.0
            old.indices.forEach {i->val ax=(old[i].x-a.x).toDouble();val az=(old[i].z-a.z).toDouble();val bx=(current[i].x-b.x).toDouble();val bz=(current[i].z-b.z).toDouble();dot+=ax*bx+az*bz;cross+=ax*bz-az*bx;size+=ax*ax+az*az}
            if(size<.1)return null
            val transform=SpatialMapRegistration(atan2(cross,dot),a,b,0.0)
            val error=sqrt(old.indices.map {i->val p=transform.point(old[i]);val q=current[i];((p.x-q.x).pow(2)+(p.y-q.y).pow(2)+(p.z-q.z).pow(2)).toDouble()}.average())
            return transform.copy(errorMeters=error).takeIf {error<=.15}
        }
    }
}
object SpatialMapStore {
    fun files(context:Context)=File(context.filesDir,"spatial-maps").apply {mkdirs()}.listFiles()?.filter {it.extension=="json"}?.sortedByDescending {it.lastModified()} ?: emptyList()
    fun save(context:Context,archive:SpatialMapArchive):File {
        require(archive.coordinateHeading.isFinite()&&archive.landmarks.size==3&&archive.rooms.size<=100)
        val folder=File(context.filesDir,"spatial-maps").apply {mkdirs()};val file=File(folder,"map-${UUID.randomUUID()}.json")
        val tmp=File(folder,file.name+".tmp");tmp.writeText(ProjectCodec.gson.toJson(archive));check(tmp.renameTo(file))
        val all=files(context);var total=all.sumOf {it.length()}
        all.drop(8).forEach {total-=it.length();it.delete()}
        all.take(8).reversed().filter {it!=file}.forEach {if(total>64L*1024*1024){total-=it.length();it.delete()}}
        return file
    }
    fun read(file:File):SpatialMapArchive?=runCatching {
        require(file.length()<=8*1024*1024)
        ProjectCodec.gson.fromJson(file.readText(),SpatialMapArchive::class.java).also {require(it.format=="android-landmark-map-v1"&&it.landmarks.size==3&&it.coordinateHeading.isFinite()&&it.rooms.size<=100&&it.rooms.all {r->r.points.size in 3..1000})}
    }.getOrNull()
}
