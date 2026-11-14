package com.example.yiijingcompass.model

import android.graphics.PointF
import java.util.Date
import kotlin.math.*

enum class XuanKongPlaceKind { ROOM,ENTRANCE,WINDOW,BED,STOVE,INTERIOR_DOOR }
data class XuanKongLocatedPlace(val id:String,val palaceID:Int,val name:String,val kind:XuanKongPlaceKind,
    val roomType:FloorplanRoomType?=null,val coverage:Int=100)
data class XuanKongHomeContext(val places:List<XuanKongLocatedPlace> = emptyList(),val exterior:List<ExteriorShaRecord> = emptyList(),
    val facts:List<XuanKongSiteFact> = emptyList(),val missingKeys:List<String> = emptyList(),val warningKeys:List<String> = emptyList())
enum class XuanKongSectorUse(val titleKey:String,val reasonKey:String,val actionKey:String,val avoidKey:String) {
    QUIET("xk_use_quiet","xk_reason_quiet","xk_action_quiet","xk_avoid_quiet"),
    SEPARATE_USES("xk_use_separate","xk_reason_separate","xk_action_separate","xk_avoid_separate"),
    ACTIVITY("xk_use_activity","xk_reason_activity","xk_action_activity","xk_avoid_activity"),
    REST("xk_use_rest","xk_reason_rest","xk_action_rest","xk_avoid_rest"),
    EVERYDAY("xk_use_everyday","xk_reason_everyday","xk_action_everyday","xk_avoid_everyday")
}
val PalaceCell.suggestedUse:XuanKongSectorUse get()=when {
    isShaWuHuang||isShaErHei->XuanKongSectorUse.QUIET
    mountainStar==activePeriod&&facingStar==activePeriod->XuanKongSectorUse.SEPARATE_USES
    facingStar==activePeriod->XuanKongSectorUse.ACTIVITY
    mountainStar==activePeriod->XuanKongSectorUse.REST
    else->XuanKongSectorUse.EVERYDAY
}
enum class XuanKongPracticalAction(val textKey:String) {
    CLEAR_ACCESS("xkd_action_access"),REDUCE_NOISE("xkd_action_noise"),REDUCE_GLARE("xkd_action_glare"),PROTECT_SLEEP("xkd_action_sleep"),
    KITCHEN("xkd_action_kitchen"),WINDOW("xkd_action_window"),STUDY("xkd_action_study"),EDGES("xkd_action_edges"),HEAT("xkd_action_heat"),
    WET_ROOM("xkd_action_wet"),VERIFY_CORNER("xkd_action_corner"),EXTERIOR_TRAFFIC("xkd_action_traffic"),EXTERIOR_WIND("xkd_action_wind"),
    EXTERIOR_PRIVACY("xkd_action_privacy"),EXTERIOR_STRUCTURE("xkd_action_structure"),WATER_REVIEW("xkd_action_water"),WORK_REVIEW("xkd_action_work"),
    SEPARATE_USES("xkd_action_separate"),REST("xkd_action_rest"),EVERYDAY("xkd_action_everyday"),SANBAN("xkd_action_sanban"),QIXING("xkd_action_qixing")
}
data class XuanKongSectorAnalysis(val palaceID:Int,val use:XuanKongSectorUse,val yearStar:Int,val monthStar:Int,
    val places:List<XuanKongLocatedPlace>,val exterior:List<ExteriorShaRecord>,val facts:List<XuanKongSiteFactKind>,
    val pairs:List<XuanKongStarPair>,val reasonKeys:List<String>,val actions:List<XuanKongPracticalAction>,val priority:Int)
data class XuanKongPatternCheck(val id:String,val titleKey:String,val statusKey:String,val palaceIDs:List<Int>,val actionKey:String)
data class XuanKongDeepAnalysis(val date:Date,val sectors:List<XuanKongSectorAnalysis>,val patternChecks:List<XuanKongPatternCheck>,
    val missingKeys:List<String>,val warningKeys:List<String>)
data class FlyingStarModeSelection(var manualOverride:Boolean?=null) {
    fun usesTiGua(automatic:Boolean)=manualOverride ?: automatic
    fun toggle(automatic:Boolean){manualOverride=!usesTiGua(automatic)}
    fun restoreAutomatic(){manualOverride=null}
}
object XuanKongDeepAnalyzer {
    fun palaceID(bearing:Double):Int?=if(!bearing.isFinite())null else listOf(0,7,2,3,8,1,6,5)[((((bearing%360+360)%360+22.5)%360)/45).toInt()]
    fun qiXingSectorGroups(chart:XuanKongChart):List<List<Int>> {
        if(!chart.isQiXingDaJie)return emptyList()
        val sets=setOf(setOf(1,4,7),setOf(2,5,8),setOf(3,6,9))
        return listOf(listOf(8,2,5),listOf(0,6,3)).filter {group->group.mapNotNull {id->chart.palaces.firstOrNull {it.id==id}?.facingStar}.toSet() in sets}
    }
    fun analyze(chart:XuanKongChart,date:Date,context:XuanKongHomeContext?=null,temporal:PurpleWhiteChart?=null):XuanKongDeepAnalysis {
        val time=temporal ?: PurpleWhiteEngine.instance.calculateChart(date)
        val home=context ?: XuanKongHomeContext(missingKeys=listOf("xkd_missing_home"))
        val groups=qiXingSectorGroups(chart);val linked=groups.flatten().toSet()
        val sectors=chart.palaces.map {cell->
            val guest=time.palaceItems.firstOrNull {it.palaceId==cell.id+1}
            val year=guest?.yearGuestStar ?: 0;val month=guest?.monthGuestStar ?: 0
            val natal=XuanKongStarPair(cell.mountainStar,cell.facingStar)
            val pairs=listOf(natal,XuanKongStarPair(cell.mountainStar,year),XuanKongStarPair(cell.facingStar,year),
                XuanKongStarPair(cell.mountainStar,month),XuanKongStarPair(cell.facingStar,month),XuanKongStarPair(year,month))
            val seasonal=year in setOf(2,5)||month in setOf(2,5);val caution=natal.hasEarthCaution||seasonal
            var use=if(caution)XuanKongSectorUse.QUIET else cell.suggestedUse
            val places=home.places.filter {it.palaceID==cell.id};val outside=home.exterior.filter {palaceID(it.bearingDegrees)==cell.id}
            val facts=home.facts.filter {it.palaceID==cell.id}.map {it.kind}
            val reasons=mutableListOf<String>();val actions=linkedSetOf<XuanKongPracticalAction>()
            val bed=places.any {it.kind==XuanKongPlaceKind.BED||it.roomType in setOf(FloorplanRoomType.MASTER_BEDROOM,FloorplanRoomType.SECOND_BEDROOM)}
            val kitchen=places.any {it.kind==XuanKongPlaceKind.STOVE||it.roomType==FloorplanRoomType.KITCHEN}
            val entrance=places.any {it.kind==XuanKongPlaceKind.ENTRANCE||it.roomType==FloorplanRoomType.DOOR}
            val window=places.any {it.kind==XuanKongPlaceKind.WINDOW};val wet=places.any {it.roomType==FloorplanRoomType.BATHROOM}
            val missing=places.isNotEmpty()&&places.all {it.roomType==FloorplanRoomType.MISSING_CORNER}
            val study=!bed&&!kitchen&&!wet&&places.any {it.roomType in setOf(FloorplanRoomType.STUDY,FloorplanRoomType.LIVING_ROOM)}
            val conflict=bed&&use in setOf(XuanKongSectorUse.ACTIVITY,XuanKongSectorUse.SEPARATE_USES)
            fun add(action:XuanKongPracticalAction){actions.add(action)}
            if(XuanKongSiteFactKind.NOISE in facts)use=XuanKongSectorUse.QUIET
            else if(conflict&&!caution)use=if(entrance)XuanKongSectorUse.SEPARATE_USES else XuanKongSectorUse.REST
            if(XuanKongSiteFactKind.BLOCKED_ACCESS in facts){reasons.add("xkd_reason_blocked");add(XuanKongPracticalAction.CLEAR_ACCESS)}
            if(XuanKongSiteFactKind.NOISE in facts){reasons.add("xkd_reason_noise");add(XuanKongPracticalAction.REDUCE_NOISE)}
            if(XuanKongSiteFactKind.GLARE in facts){reasons.add("xkd_reason_glare");add(XuanKongPracticalAction.REDUCE_GLARE)}
            outside.forEach {record->add(when(record.shaID){"luchong","fangong","gejiao"->XuanKongPracticalAction.EXTERIOR_TRAFFIC
                "tianzhan"->XuanKongPracticalAction.EXTERIOR_WIND;"tantou"->XuanKongPracticalAction.EXTERIOR_PRIVACY;"huoxing"->XuanKongPracticalAction.HEAT;else->XuanKongPracticalAction.EXTERIOR_STRUCTURE})}
            if(outside.isNotEmpty())reasons.add("xkd_reason_exterior")
            if(natal.hasEarthCaution)reasons.add("xkd_reason_natal")
            if(seasonal)reasons.add("xkd_reason_season")
            if(caution&&XuanKongSiteFactKind.MOVING_WATER in facts){reasons.add("xkd_reason_water");add(XuanKongPracticalAction.WATER_REVIEW)}
            if(bed){reasons.add(if(conflict)"xkd_reason_bed_active" else "xkd_reason_bed");add(XuanKongPracticalAction.PROTECT_SLEEP)}
            if(kitchen){reasons.add("xkd_reason_kitchen");add(XuanKongPracticalAction.KITCHEN)}
            if(entrance){reasons.add("xkd_reason_entrance");add(XuanKongPracticalAction.CLEAR_ACCESS);if(caution)add(XuanKongPracticalAction.REDUCE_NOISE)}
            if(window)add(XuanKongPracticalAction.WINDOW)
            if(natal.relation in setOf(XuanKongStarPair.Relation.FIRST_CONTROLS_SECOND,XuanKongStarPair.Relation.SECOND_CONTROLS_FIRST)){
                reasons.add("xkd_reason_control");if(!caution&&!bed&&!kitchen&&!wet&&!missing)add(XuanKongPracticalAction.SEPARATE_USES)
            }else if(!caution&&study)add(XuanKongPracticalAction.STUDY)
            if(wet)add(XuanKongPracticalAction.WET_ROOM)
            if(places.any {it.roomType==FloorplanRoomType.MISSING_CORNER})add(XuanKongPracticalAction.VERIFY_CORNER)
            if(pairs.any {it.isHeat}){reasons.add("xkd_reason_heat");if(!missing)add(XuanKongPracticalAction.HEAT)}
            if(pairs.any {it.isFriction}){reasons.add("xkd_reason_friction");if(!missing)add(XuanKongPracticalAction.EDGES)}
            if(pairs.any {it.isStudy}){reasons.add("xkd_reason_study");if(!caution&&study)add(XuanKongPracticalAction.STUDY)}
            if(guest?.let {it.isTaiSui||it.isSuiPo||it.isSanSha}==true){reasons.add("xkd_reason_works");add(XuanKongPracticalAction.WORK_REVIEW)}
            if(cell.id in linked)add(XuanKongPracticalAction.QIXING)
            if(chart.isSanBanGua)add(XuanKongPracticalAction.SANBAN)
            if(!missing)when(use){XuanKongSectorUse.QUIET->add(XuanKongPracticalAction.REDUCE_NOISE)
                XuanKongSectorUse.SEPARATE_USES->if(!kitchen&&!wet)add(XuanKongPracticalAction.SEPARATE_USES)
                XuanKongSectorUse.ACTIVITY->if(!bed&&!kitchen&&!wet)add(XuanKongPracticalAction.CLEAR_ACCESS)
                XuanKongSectorUse.REST->if(!kitchen&&!wet&&!bed)add(XuanKongPracticalAction.REST)
                else->Unit}
            if(actions.isEmpty())add(XuanKongPracticalAction.EVERYDAY)
            val outsidePriority=outside.minOfOrNull {record->ExteriorShaEngine.instance.database.firstOrNull {it.id==record.shaID}?.let {item->
                when(ExteriorShaSeverityResolver.effectiveSeverity(item.severity,record.distanceMeters)) {ShaSeverity.CRITICAL->0;ShaSeverity.WARNING->1;ShaSeverity.MINOR->2;ShaSeverity.NOTICE->3}}
                ?: 2} ?: 3
            val observed=facts.any {it in setOf(XuanKongSiteFactKind.NOISE,XuanKongSiteFactKind.GLARE,XuanKongSiteFactKind.BLOCKED_ACCESS)}||caution&&XuanKongSiteFactKind.MOVING_WATER in facts
            val roomPriority=when {observed->0;caution&&(bed||kitchen||entrance)->1;caution->2;pairs.any {it.isHeat}&&kitchen->1;else->3}
            XuanKongSectorAnalysis(cell.id,use,year,month,places,outside,facts,pairs,reasons,actions.toList(),min(outsidePriority,roomPriority))
        }
        val checks=mutableListOf<XuanKongPatternCheck>()
        fun check(id:String,title:String,ids:List<Int>,action:String){
            val relevant=sectors.filter {it.palaceID in ids}
            val conflict=relevant.any {it.priority<2||it.use==XuanKongSectorUse.QUIET&&XuanKongSiteFactKind.MOVING_WATER in it.facts}
            val observed=relevant.any {XuanKongSiteFactKind.OPEN_BRIGHT in it.facts||XuanKongSiteFactKind.SOLID_BACKING in it.facts}
            checks.add(XuanKongPatternCheck(id,title,if(conflict)"xkd_pattern_conflict" else if(observed)"xkd_pattern_partial" else "xkd_pattern_unknown",ids,action))
        }
        if(chart.isSanBanGua)check("sanban","xkd_sanban",(0..8).toList(),"xkd_action_sanban")
        if(chart.isQiXingDaJie)groups.forEachIndexed {i,ids->check("qixing-$i","xkd_qixing",ids,"xkd_action_qixing")}
        return XuanKongDeepAnalysis(date,sectors,checks,home.missingKeys,home.warningKeys)
    }
}
