package com.example.yiijingcompass.ui

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.MainActivity
import com.example.yiijingcompass.R
import com.example.yiijingcompass.model.*
import com.google.gson.Gson
import java.util.*

object NativeReminders {
    const val CHANNEL="calendar-reminders"
    data class Entry(val id:Int,val time:Long,val title:String,val text:String,val contextKey:String?=null)
    private fun prefs(context:Context)=context.getSharedPreferences("calendar_reminders",Context.MODE_PRIVATE)
    fun entries(context:Context):List<Entry> = prefs(context).getString("entries",null)?.let {runCatching {Gson().fromJson(it,Array<Entry>::class.java).toList()}.getOrNull()} ?: emptyList()
    private fun store(context:Context,rows:List<Entry>){prefs(context).edit().putString("entries",Gson().toJson(rows)).apply()}
    fun scheduleDay(context:Activity,day:UpcomingAuspiciousDay,identity:AuspiciousReminderContext=AuspiciousReminderContext(ShaSurveyStore.instance.propertyKey,com.example.yiijingcompass.sensor.CompassMotionManager.instance.headingState.sittingMountain.name)):Boolean{
        val time=Calendar.getInstance().apply {this.time=day.date;set(Calendar.HOUR_OF_DAY,8);set(Calendar.MINUTE,0);set(Calendar.SECOND,0)}.timeInMillis
        if(time<=System.currentTimeMillis())return false
        val key=identity.key(day.date)
        val existing=entries(context).firstOrNull {it.contextKey==key}
        if(existing!=null){cancel(context,existing.id);return true}
        val entry=Entry(key.hashCode(),time,LocalizationManager.instance.t("bz_tool_dates"),day.dateLabel+" · "+day.yiSummary,key)
        save(context,entry);requestPermission(context);return true
    }
    fun scheduleSolarTerms(context:Activity){
        val terms=SolarTimeCalculator.instance.upcomingSolarTerms(Date(),24)
        terms.forEach {term->save(context,Entry(("term-"+term.date.time).hashCode(),term.date.time,SolarTermsData.instance.terms.firstOrNull {it.name==term.name}?.localizedName ?: term.name,LocalizationManager.instance.t("native_solar_reminders")))}
        requestPermission(context)
    }
    private fun requestPermission(activity:Activity){
        if(Build.VERSION.SDK_INT>=33&&ContextCompat.checkSelfPermission(activity,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),4001)
    }
    private fun intent(context:Context,entry:Entry)=PendingIntent.getBroadcast(context,entry.id,
        Intent(context,ReminderReceiver::class.java).setData(android.net.Uri.parse("yanxiang-reminder:"+(entry.contextKey ?: entry.id.toString()))).putExtra("id",entry.id).putExtra("title",entry.title).putExtra("text",entry.text).putExtra("date",entry.time),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun save(context:Context,entry:Entry){val next=entries(context).filter {it.time>System.currentTimeMillis()&&it.id!=entry.id}+entry;store(context,next);schedule(context,entry)}
    private fun schedule(context:Context,entry:Entry){(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,entry.time,intent(context,entry))}
    fun restore(context:Context){val next=entries(context).filter {it.time>System.currentTimeMillis()};store(context,next);next.forEach {schedule(context,it)}}
    fun cancel(context:Context,id:Int){val entry=entries(context).firstOrNull {it.id==id} ?: return;(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(intent(context,entry));store(context,entries(context).filterNot {it.id==id})}
    fun cancelAll(context:Context){val alarms=context.getSystemService(Context.ALARM_SERVICE) as AlarmManager;entries(context).forEach {alarms.cancel(intent(context,it))};store(context,emptyList())}
}

class ReminderReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        LocalizationManager.instance.init(context)
        if(intent.action==Intent.ACTION_BOOT_COMPLETED||intent.action==Intent.ACTION_TIMEZONE_CHANGED||intent.action==Intent.ACTION_TIME_CHANGED){NativeReminders.restore(context);return}
        if(Build.VERSION.SDK_INT>=33&&ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(NativeReminders.CHANNEL,LocalizationManager.instance.t("bz_tool_dates"),NotificationManager.IMPORTANCE_DEFAULT))
        val open=PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java).putExtra("tab",3).putExtra("route","dates").putExtra("date",intent.getLongExtra("date",0)),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification=NotificationCompat.Builder(context,NativeReminders.CHANNEL).setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(intent.getStringExtra("title")).setContentText(intent.getStringExtra("text"))
            .setStyle(NotificationCompat.BigTextStyle().bigText(intent.getStringExtra("text"))).setContentIntent(open).setAutoCancel(true).build()
        manager.notify(intent.getIntExtra("id",0),notification)
        NativeReminders.restore(context)
    }
}
