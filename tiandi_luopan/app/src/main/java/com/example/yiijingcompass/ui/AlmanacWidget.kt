package com.example.yiijingcompass.ui

import android.app.PendingIntent
import android.app.AlarmManager
import java.util.Date
import android.appwidget.*
import android.content.*
import android.widget.RemoteViews
import com.example.yiijingcompass.MainActivity
import com.example.yiijingcompass.R
import com.example.yiijingcompass.model.*

class AlmanacWidget:AppWidgetProvider(){
    override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray){
        LocalizationManager.instance.init(context)
        val prefs=context.getSharedPreferences("almanac_widget",Context.MODE_PRIVATE)
        val sitting=if(prefs.getBoolean("locked",false))Mountain24Data.instance.resolveHeadingState(prefs.getFloat("heading",0f).toDouble()).sittingMountain else null
        val snapshot=WidgetAlmanacBuilder.make(sitting=sitting);val lang=LocalizationManager.instance
        ids.forEach {id->val view=RemoteViews(context.packageName,R.layout.almanac_widget)
            view.setTextViewText(R.id.widget_title,snapshot.localizedDayPillar+" · "+snapshot.termName)
            val options=manager.getAppWidgetOptions(id)
            val spacious=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,180)>=180
            view.setTextViewText(R.id.widget_body,snapshot.fourPillarsText+"\n"+snapshot.yiActivities.joinToString(" · ")+(if(spacious)"\n"+snapshot.jiActivities.joinToString(" · ")+"\n"+snapshot.yearStarName+" / "+snapshot.monthStarName else ""))
            view.setProgressBar(R.id.widget_term_progress,100,(snapshot.termProgress*100).toInt(),false)
            view.setTextViewText(R.id.widget_detail,(snapshot.sittingMountainBadge ?: lang.t("native_general_day_note"))+" · "+snapshot.wealthJoyBadge+(if(snapshot.hasSittingClash)" · "+lang.t("sitting_mountain_clash") else ""))
            val open=PendingIntent.getActivity(context,id,Intent(context,MainActivity::class.java).putExtra("tab",3).putExtra("route","dates"),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            view.setOnClickPendingIntent(R.id.widget_root,open);manager.updateAppWidget(id,view)
        }
        if(ids.isNotEmpty()){
            val next=WidgetAlmanacBuilder.refreshDates(Date()).firstOrNull {it.after(Date())}
            val pending=PendingIntent.getBroadcast(context,7712,Intent(context,AlmanacWidget::class.java).setAction(BOUNDARY),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            if(next!=null)(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(AlarmManager.RTC_WAKEUP,next.time,pending)
        }
    }
    companion object {
        private const val BOUNDARY="com.example.yiijingcompass.ALMANAC_BOUNDARY"
        fun refresh(context:Context){val manager=AppWidgetManager.getInstance(context);AlmanacWidget().onUpdate(context,manager,manager.getAppWidgetIds(ComponentName(context,AlmanacWidget::class.java)))}
    }
    override fun onAppWidgetOptionsChanged(context:Context,manager:AppWidgetManager,id:Int,options:android.os.Bundle){onUpdate(context,manager,intArrayOf(id))}
    override fun onReceive(context:Context,intent:Intent){super.onReceive(context,intent)
        if(intent.action in listOf(Intent.ACTION_TIME_CHANGED,Intent.ACTION_TIMEZONE_CHANGED,Intent.ACTION_LOCALE_CHANGED,Intent.ACTION_BOOT_COMPLETED,BOUNDARY)){
            val manager=AppWidgetManager.getInstance(context);onUpdate(context,manager,manager.getAppWidgetIds(ComponentName(context,AlmanacWidget::class.java)))
        }
    }
}
