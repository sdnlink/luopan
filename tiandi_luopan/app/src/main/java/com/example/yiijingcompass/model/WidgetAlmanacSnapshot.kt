package com.example.yiijingcompass.model

import java.util.*
import kotlin.math.*

data class WidgetAlmanacSnapshot(val date:Date,val localizedDayPillar:String,val fourPillarsText:String,
    val yiActivities:List<String>,val jiActivities:List<String>,val termName:String,val termShortName:String,
    val termProgress:Double,val daysToNextTerm:Int,val yearCentralStar:Int,val monthCentralStar:Int,
    val yearStarName:String,val monthStarName:String,val dayOfficerIndex:Int,val isGeneralDay:Boolean,
    val sittingMountainBadge:String?,val hasSittingClash:Boolean,val wealthJoyBadge:String)

object WidgetAlmanacBuilder {
    fun resolveDayOfficerIndex(date:Date,dayPillar:String)=ZeRiEngine.instance.resolveDayOfficerIndex(date,dayPillar)
    fun make(date:Date=Date(),sitting:Mountain24Item?=null):WidgetAlmanacSnapshot {
        val solar=SolarTimeCalculator.instance;val analysis=ZeRiEngine.instance.analyze(date,sitting)
        val next=solar.upcomingSolarTerms(date,1).first()
        val lengthDays=15/.98564736;val progress=(solar.solarTermProgress(date)/lengthDays).coerceIn(0.0,1.0)
        val term=SolarTermsData.instance.terms.firstOrNull {it.name==solar.solarTermName(date)}
        val chart=PurpleWhiteEngine.instance.calculateChart(date)
        val direction=ZeRiEngine.instance.dailyCompassDirections(date)
        return WidgetAlmanacSnapshot(date,analysis.localizedDayPillar,analysis.fourPillarsText,analysis.yiActivities,analysis.jiActivities,
            term?.localizedName ?: solar.solarTermName(date),term?.localizedName ?: solar.solarTermName(date),progress,
            max(0,ceil((next.date.time-date.time)/86400000.0).toInt()),chart.yearCentralStar,chart.monthCentralStar,
            PurpleWhiteEngine.instance.starName(chart.yearCentralStar),PurpleWhiteEngine.instance.starName(chart.monthCentralStar),
            resolveDayOfficerIndex(date,analysis.dayPillar),sitting==null,sitting?.localizedName,analysis.sittingClashWarning!=null,
            direction.wealthDirection+" / "+direction.joyDirection)
    }
    fun refreshDates(date:Date,count:Int=3):List<Date> {
        val values=mutableSetOf(date.time)
        for(day in 0..count.coerceIn(1,7)) {
            val calendar=java.util.GregorianCalendar().apply {time=date;set(Calendar.HOUR_OF_DAY,0);set(Calendar.MINUTE,0);set(Calendar.SECOND,0);set(Calendar.MILLISECOND,0);add(Calendar.DAY_OF_YEAR,day)}
            if(calendar.time.after(date))values.add(calendar.timeInMillis)
            calendar.set(Calendar.HOUR_OF_DAY,23);if(calendar.time.after(date))values.add(calendar.timeInMillis)
        }
        solarBoundary(date)?.let {values.add(it.time)}
        return values.sorted().map(::Date)
    }
    private fun solarBoundary(date:Date)=SolarTimeCalculator.instance.upcomingSolarTerms(date,1).firstOrNull()?.date
}
