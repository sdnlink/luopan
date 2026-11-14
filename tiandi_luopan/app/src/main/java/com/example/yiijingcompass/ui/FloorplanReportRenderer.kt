package com.example.yiijingcompass.ui

import android.content.Context
import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.example.yiijingcompass.model.*

object FloorplanReportRenderer {
    fun render(context:Context,layout:SavedFloorplanLayout,background:Bitmap?,report:List<FloorplanAuditItem>,labels:Map<String,String>):Bitmap {
        val lang=LocalizationManager.instance
        val paragraphs=listOf(lang.t("floorplan_title"),"${layout.widthMeters ?: "—"} × ${layout.depthMeters ?: "—"} m · ${layout.compassRotation}°")+
            report.flatMap {listOf(it.title+" · "+it.palace,it.lore,it.solution)}+lang.t("settings_safety_disclaimer")
        val layouts=paragraphs.mapIndexed {index,text->val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply {color=if(index==0)Color.rgb(220,190,100) else Color.WHITE;textSize=if(index==0)34f else 22f}
            StaticLayout.Builder.obtain(text,0,text.length,paint,960).setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(0f,1.2f).setIncludePad(false).build()}
        val height=1150+layouts.sumOf {it.height+25}
        val bitmap=Bitmap.createBitmap(1080,height,Bitmap.Config.ARGB_8888);val canvas=Canvas(bitmap);canvas.drawColor(Color.rgb(18,18,22))
        canvas.save();canvas.translate(40f,40f)
        NativeFloorplanView(context).apply {rooms=layout.rooms.toMutableList();centroid=layout.centroid;aspectRatio=layout.aspectRatio ?: 1f;backgroundImage=background;familyLabels=labels;layout(0,0,1000,1000);draw(canvas)}
        canvas.restore();var y=1090f
        layouts.forEach {text->canvas.save();canvas.translate(60f,y);text.draw(canvas);canvas.restore();y+=text.height+25}
        return bitmap
    }
}
