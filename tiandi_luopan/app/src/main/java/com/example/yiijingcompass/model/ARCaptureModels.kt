package com.example.yiijingcompass.model

import android.graphics.Bitmap
import android.graphics.PointF
import java.util.Date

/** Copied depth for one exposure, independent of the next ARCore frame. */
data class ARCapturedDepth(val width:Int,val height:Int,val meters:FloatArray,val viewToImage:FloatArray){
    fun sample(point:PointF):Float? {
        if(width<=0||height<=0||meters.size!=width*height||viewToImage.size!=6)return null
        val u=viewToImage[0]*point.x+viewToImage[1]*point.y+viewToImage[2]
        val v=viewToImage[3]*point.x+viewToImage[4]*point.y+viewToImage[5]
        if(!u.isFinite()||!v.isFinite()||u !in 0f..1f||v !in 0f..1f)return null
        val x=(u*(width-1)).toInt();val y=(v*(height-1)).toInt()
        val samples=mutableListOf<Float>()
        for(yy in maxOf(0,y-1)..minOf(height-1,y+1))for(xx in maxOf(0,x-1)..minOf(width-1,x+1)){
            val depth=meters[yy*width+xx];if(depth.isFinite()&&depth in .1f..65f)samples.add(depth)
        }
        return samples.sorted().let {it.getOrNull(it.size/2)}
    }
}

data class ARCapturedFrame(val bitmap:Bitmap,val pose:ARCapturePose,val evidence:ARSceneEvidence,
    val depth:ARCapturedDepth?,val propertyID:String,val capturedAt:Date=Date()):AutoCloseable {
    fun exteriorRecord(shaID:String,point:PointF,confidence:Double?,source:ShaRecordSource,note:String?=null)=
        ExteriorShaRecord(shaID=shaID,bearingDegrees=pose.bearing(point),capturedHeadingDegrees=pose.heading,
            elevationDegrees=pose.elevation(point),distanceMeters=depth?.sample(point),confidence=confidence,
            capturedAt=Date(capturedAt.time),source=source,note=note)
    override fun close(){if(!bitmap.isRecycled)bitmap.recycle()}
}
