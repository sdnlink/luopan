package com.example.yiijingcompass.ui

import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.example.yiijingcompass.model.*
import java.text.DateFormat
import java.util.Date

object DailyCardRenderer {
    fun renderPoster(date:Date,state:CompassHeadingState):Bitmap {
        val lang=LocalizationManager.instance;val day=ZeRiEngine.instance.analyze(date,state.sittingMountain)
        val gods=ZeRiEngine.instance.dailyCompassDirections(date);val qimen=QimenEngine.instance.calculateChart(date,state.facingAngle)
        val term=SolarTermsData.instance.terms.firstOrNull {it.name==SolarTimeCalculator.instance.solarTermName(date)}?.localizedName ?: ""
        val rows=mutableListOf(DateFormat.getDateInstance().format(date)+" · "+term,day.localizedDayPillar,day.fourPillarsText,
            lang.t("native_wealth_direction")+" · "+gods.wealthDirection+" · ${gods.wealthAngle.toInt()}°",
            lang.t("native_joy_direction")+" · "+gods.joyDirection+" · ${gods.joyAngle.toInt()}°",qimen.bestNavDirection,
            state.sittingMountain.localizedName+" → "+state.facingMountain.localizedName+" · ${state.facingAngle.toInt()}°")
        if(UserKuaProfileManager.instance.canUsePersonalAnalysis)rows.add(UserKuaProfileManager.instance.localizedLifeKuaName())
        rows.addAll(listOf(day.overallStatus,day.yiActivities.joinToString(" · "),day.jiActivities.joinToString(" · "),lang.t("settings_safety_disclaimer")))
        val layouts=rows.mapIndexed {index,text->val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply {color=if(index<=1)Color.rgb(240,210,110) else Color.WHITE;textSize=if(index==1)64f else if(index==rows.lastIndex)18f else 26f}
            StaticLayout.Builder.obtain(text,0,text.length,paint,620).setAlignment(if(index<=2)Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL).setLineSpacing(0f,1.2f).setIncludePad(false).build()}
        val height=maxOf(1080,layouts.sumOf {it.height+28}+150)
        val bitmap=Bitmap.createBitmap(750,height,Bitmap.Config.ARGB_8888);val canvas=Canvas(bitmap);canvas.drawColor(Color.rgb(20,20,28))
        val border=Paint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.rgb(210,175,80);style=Paint.Style.STROKE;strokeWidth=3f};canvas.drawRect(28f,28f,722f,height-28f,border)
        var y=65f;layouts.forEach {layout->canvas.save();canvas.translate(65f,y);layout.draw(canvas);canvas.restore();y+=layout.height+28}
        return bitmap
    }
}
