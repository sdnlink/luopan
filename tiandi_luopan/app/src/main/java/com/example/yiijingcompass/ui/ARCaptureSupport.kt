package com.example.yiijingcompass.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PointF
import com.example.yiijingcompass.model.*
import com.google.ar.core.*
import java.nio.ByteOrder
import kotlin.math.*

object ARCaptureSupport {
    fun capture(frame:Frame,coordinateHeading:Double,viewportWidth:Int,viewportHeight:Int,propertyID:String,depthAvailable:Boolean,verticalPlanes:Int):ARCapturedFrame?=runCatching {
        val bitmap=frame.acquireCameraImage().use {image->
            val factor=min(1.0,960.0/max(image.width,image.height));val w=max(1,(image.width*factor).toInt());val h=max(1,(image.height*factor).toInt())
            val planes=image.planes;val data=planes.map {it.buffer.duplicate()};val pixels=IntArray(w*h)
            for(y in 0 until h)for(x in 0 until w){val sx=(x/factor).toInt().coerceAtMost(image.width-1);val sy=(y/factor).toInt().coerceAtMost(image.height-1)
                val yy=(data[0].get(sy*planes[0].rowStride+sx*planes[0].pixelStride).toInt() and 255)-16
                val u=(data[1].get((sy/2)*planes[1].rowStride+(sx/2)*planes[1].pixelStride).toInt() and 255)-128
                val v=(data[2].get((sy/2)*planes[2].rowStride+(sx/2)*planes[2].pixelStride).toInt() and 255)-128
                val r=((298*yy+409*v+128) shr 8).coerceIn(0,255);val g=((298*yy-100*u-208*v+128) shr 8).coerceIn(0,255);val b=((298*yy+516*u+128) shr 8).coerceIn(0,255)
                pixels[y*w+x]=(255 shl 24) or (r shl 16) or (g shl 8) or b
            }
            val raw=Bitmap.createBitmap(pixels,w,h,Bitmap.Config.ARGB_8888)
            val width=min(960,viewportWidth).coerceAtLeast(1);val height=max(1,(width.toFloat()*viewportHeight/viewportWidth.coerceAtLeast(1)).toInt())
            val result=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
            val source=floatArrayOf(0f,0f,1f,0f,0f,1f);val target=FloatArray(6)
            frame.transformCoordinates2d(Coordinates2d.IMAGE_NORMALIZED,source,Coordinates2d.VIEW_NORMALIZED,target)
            val matrix=Matrix();matrix.setPolyToPoly(floatArrayOf(0f,0f,w.toFloat(),0f,0f,h.toFloat()),0,
                floatArrayOf(target[0]*width,target[1]*height,target[2]*width,target[3]*height,target[4]*width,target[5]*height),0,3)
            Canvas(result).drawBitmap(raw,matrix,Paint(Paint.FILTER_BITMAP_FLAG));raw.recycle();result
        }
        val matrix=FloatArray(16);frame.camera.displayOrientedPose.toMatrix(matrix,0)
        val projectionMatrix=FloatArray(16);frame.camera.getProjectionMatrix(projectionMatrix,0,.1f,100f)
        val fov=2*atan(1.0/projectionMatrix[0])*180/PI
        val projection=ARTargetProjection(fov,viewportWidth.toDouble()/viewportHeight.coerceAtLeast(1))
        val pose=ARCapturePose(matrix,coordinateHeading,projection)
        val depth=if(depthAvailable)runCatching {frame.acquireDepthImage16Bits().use {image->
            val plane=image.planes[0];val buffer=plane.buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN);val values=FloatArray(image.width*image.height)
            for(y in 0 until image.height)for(x in 0 until image.width)values[y*image.width+x]=(buffer.getShort(y*plane.rowStride+x*plane.pixelStride).toInt() and 65535)/1000f
            val source=floatArrayOf(0f,0f,1f,0f,0f,1f);val mapped=FloatArray(6)
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED,source,Coordinates2d.IMAGE_NORMALIZED,mapped)
            ARCapturedDepth(image.width,image.height,values,floatArrayOf(mapped[2]-mapped[0],mapped[4]-mapped[0],mapped[0],mapped[3]-mapped[1],mapped[5]-mapped[1],mapped[1]))
        }}.getOrNull() else null
        val coverage=depth?.let {it.meters.count {d->d in .1f..65f}.toDouble()/it.meters.size} ?: 0.0
        fun sample(x:Float,y:Float)=depth?.sample(PointF(x,y))?.toDouble()
        val evidence=ARSceneEvidence(frame.camera.trackingState==TrackingState.TRACKING,frame.getUpdatedTrackables(Plane::class.java).isNotEmpty(),depthAvailable,depth!=null,coverage,
            sample(.5f,.5f),sample(.25f,.5f),sample(.75f,.5f),sample(.5f,.25f),sample(.5f,.75f),verticalPlanes,0,fov)
        ARCapturedFrame(bitmap,pose,evidence,depth,propertyID)
    }.getOrNull()
}
