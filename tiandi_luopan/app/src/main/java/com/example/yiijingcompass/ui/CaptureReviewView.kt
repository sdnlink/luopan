package com.example.yiijingcompass.ui

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import com.example.yiijingcompass.model.GeometryUtils

/** Reticle edits always stay attached to the frozen exposure and its depth. */
class CaptureReviewView(context:Context,val image:Bitmap,initial:PointF):View(context){
    var target=PointF(initial.x,initial.y);private set
    var onMoved:((PointF)->Unit)?=null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private fun bounds()=GeometryUtils.aspectFitRect(image.width.toFloat()/image.height,RectF(0f,0f,width.toFloat(),height.toFloat()))
    override fun onDraw(canvas:Canvas){
        canvas.drawColor(Color.BLACK);val rect=bounds();paint.color=Color.WHITE;canvas.drawBitmap(image,null,rect,paint)
        val x=rect.left+rect.width()*target.x;val y=rect.top+rect.height()*target.y
        paint.color=Color.YELLOW;paint.strokeWidth=3f;paint.style=Paint.Style.STROKE;canvas.drawCircle(x,y,18f,paint)
        canvas.drawLine(x-28,y,x+28,y,paint);canvas.drawLine(x,y-28,x,y+28,paint);paint.style=Paint.Style.FILL
    }
    override fun onTouchEvent(event:MotionEvent):Boolean {
        val rect=bounds();if(rect.width()<=0||rect.height()<=0)return false
        target=PointF(((event.x-rect.left)/rect.width()).coerceIn(.02f,.98f),((event.y-rect.top)/rect.height()).coerceIn(.02f,.98f))
        onMoved?.invoke(target);invalidate();if(event.action==MotionEvent.ACTION_UP)performClick();return true
    }
    override fun performClick():Boolean{super.performClick();return true}
}
