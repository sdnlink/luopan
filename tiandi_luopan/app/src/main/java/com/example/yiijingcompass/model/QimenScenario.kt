package com.example.yiijingcompass.model

import java.util.*
import kotlin.math.*

enum class QimenScenarioType(val rawValue:String) {
    CONTRACT("contract"),WEALTH("wealth"),ROMANCE("romance"),EXAM("exam"),MEDICAL("medical"),TRAVEL("travel");
    val localizedTitle get()=LocalizationManager.instance.t("native_qimen_scenario_$rawValue")
}
data class QimenScenarioRecommendation(val scenario:QimenScenarioType,val recommendedPalaceId:Int,
    val directionTitle:String,val keyPattern:String,val actionGuide:String)
data class QimenChartTimeKey(val year:Int,val month:Int,val day:Int,val hour:Int,val solarTerm:Int,val utcOffset:Int)
fun QimenEngine.chartTimeKey(date:Date,timeZone:TimeZone=TimeZone.getDefault()):QimenChartTimeKey {
    val calendar=java.util.GregorianCalendar(timeZone).apply {time=date}
    return QimenChartTimeKey(calendar.get(Calendar.YEAR),calendar.get(Calendar.MONTH)+1,calendar.get(Calendar.DAY_OF_MONTH),
        calendar.get(Calendar.HOUR_OF_DAY),SolarTimeCalculator.instance.solarTermIndex(date),timeZone.getOffset(date.time)/1000)
}
fun QimenEngine.evaluateScenario(scenario:QimenScenarioType,chart:QimenChart,heading:Double=0.0):QimenScenarioRecommendation {
    val candidates=chart.cells.filterNot {it.isCenter}
    require(candidates.isNotEmpty())
    fun score(cell:QimenPalaceCell):Int {
        var score=when(cell.doorName){"开门","生门"->30;"休门"->25;"景门"->12;"杜门"->5;"死门","惊门","伤门"->-40;else->0}
        if(cell.tianStem in setOf("乙","丙","丁"))score+=18
        if(cell.tianStem=="戊")score+=12
        if(cell.tianStem=="庚")score-=15
        when(scenario){
            QimenScenarioType.CONTRACT->{if(cell.doorName in setOf("开门","景门"))score+=25;if(cell.godName in setOf("值符","六合","太阴"))score+=22;if(cell.starName in setOf("天辅","天心"))score+=12}
            QimenScenarioType.WEALTH->{if(cell.doorName=="生门")score+=35;if(cell.doorName=="开门")score+=22;if(cell.tianStem=="戊"||cell.diStem=="戊")score+=20;if(cell.starName=="天任")score+=15}
            QimenScenarioType.ROMANCE->{if(cell.godName=="六合")score+=35;if(cell.godName=="太阴")score+=20;if(cell.doorName in setOf("休门","生门"))score+=20;if(cell.tianStem in setOf("乙","丁"))score+=15}
            QimenScenarioType.MEDICAL->{if(cell.starName in setOf("天心","天任"))score+=35;if(cell.doorName in setOf("休门","生门","开门"))score+=22;if(cell.tianStem=="乙")score+=18}
            QimenScenarioType.EXAM->{if(cell.starName in setOf("天辅","天英"))score+=32;if(cell.doorName in setOf("景门","开门"))score+=28;if(cell.godName in setOf("值符","九天"))score+=18}
            QimenScenarioType.TRAVEL->{if(cell.doorName in setOf("开门","休门","生门"))score+=28;if(cell.godName in setOf("九天","值符","太阴"))score+=20}
        };return score
    }
    val best=candidates.maxByOrNull(::score)!!
    var turn=(best.angleCenter-heading)%360
    if(turn>180)turn-=360
    if(turn< -180)turn+=360
    val lang=LocalizationManager.instance
    val hint=if(heading.isFinite()&&abs(turn)>=2) " · "+lang.t(if(turn>0)"native_turn_right" else "native_turn_left")+" ${abs(turn).roundToInt()}°" else ""
    return QimenScenarioRecommendation(scenario,best.id,best.localizedPalaceName+hint,
        best.localizedDoorName+" · "+best.localizedStarName+" · "+best.localizedGodName+" · "+best.localizedTianStem+"/"+best.localizedDiStem,
        lang.t("native_qimen_action_template").replace("{scenario}",scenario.localizedTitle).replace("{palace}",best.localizedPalaceName)
            .replace("{door}",best.localizedDoorName).replace("{star}",best.localizedStarName).replace("{god}",best.localizedGodName))
}
