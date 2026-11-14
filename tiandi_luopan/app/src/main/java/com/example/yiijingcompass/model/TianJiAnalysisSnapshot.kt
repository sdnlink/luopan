package com.example.yiijingcompass.model

import java.util.*

data class ReportSignature(val client:String="",val master:String="",val seal:String="")

data class TianJiAnalysisSnapshot(val heading:Double,val period:Int,val useTiGua:Boolean,val reportDate:Date=Date(),
    val homeContext:XuanKongHomeContext?=null,val propertyKey:String?=null,
    val capturedFloorplanReport:List<FloorplanAuditItem> = emptyList(),val capturedPanoramaArchive:PanoramaFengShuiArchive?=null,
    val hasSpatialSnapshot:Boolean=false,val signature:ReportSignature=ReportSignature()) {
    constructor(heading:Double,reportDate:Date=Date()):this(heading,FlyingStarsEngine.instance.currentPeriod(reportDate),
        Mountain24Data.instance.resolveHeadingState(heading).isJianXiang,Date(reportDate.time))
    fun flyingStarsChart()=FlyingStarsEngine.instance.calculateChart(period.coerceIn(1,9),
        Mountain24Data.instance.mountain((heading+180)%360),Mountain24Data.instance.mountain(heading),useTiGua,reportDate)
    fun capturing(context:XuanKongHomeContext?,propertyKey:String?,floorplanReport:List<FloorplanAuditItem>,panoramaArchive:PanoramaFengShuiArchive?)=
        copy(reportDate=Date(reportDate.time),homeContext=context?.let {ProjectCodec.gson.fromJson(ProjectCodec.gson.toJson(it),XuanKongHomeContext::class.java)},propertyKey=propertyKey,
            capturedFloorplanReport=floorplanReport.toList(),capturedPanoramaArchive=panoramaArchive?.let {ProjectCodec.gson.fromJson(ProjectCodec.gson.toJson(it),PanoramaFengShuiArchive::class.java)},hasSpatialSnapshot=true)
    fun deepAnalysis(chart:XuanKongChart=flyingStarsChart())=XuanKongDeepAnalyzer.analyze(chart,reportDate,homeContext)
    fun guidanceText(chart:XuanKongChart=flyingStarsChart(),analysis:XuanKongDeepAnalysis=deepAnalysis(chart)):String {
        val lang=LocalizationManager.instance
        val sectors=analysis.sectors.sortedWith(compareBy<XuanKongSectorAnalysis>{it.priority}.thenBy {it.use.ordinal}.thenBy {it.palaceID})
        val summary=when(sectors.firstOrNull()?.priority ?: 3){0->"xkd_summary_observed";1->"xkd_summary_occupied";2->"xkd_summary_quiet";else->"xkd_summary_uses"}
        return (listOf(lang.t(summary))+sectors.mapNotNull {sector->chart.palaces.firstOrNull {it.id==sector.palaceID}?.let {cell->
            val names=sector.places.map {it.name}.distinct().sorted().joinToString(" / ")
            (listOf(cell.localizedPalaceName+" · "+lang.t(sector.use.titleKey)+(if(names.isBlank())"" else " · $names"))+sector.actions.map {"• "+lang.t(it.textKey)}).joinToString("\n")
        }}).joinToString("\n\n")
    }
    fun ganzhiYear(timeZone:TimeZone=TimeZone.getDefault()):String {
        val calendar=java.util.GregorianCalendar(timeZone).apply {time=reportDate}
        val year=calendar.get(Calendar.YEAR)-if(SolarTimeCalculator.instance.isBeforeLiChun(reportDate,timeZone))1 else 0
        val offset=Math.floorMod(year-4,60)
        return "${"甲乙丙丁戊己庚辛壬癸"[offset%10]}${"子丑寅卯辰巳午未申酉戌亥"[offset%12]}"
    }
}
