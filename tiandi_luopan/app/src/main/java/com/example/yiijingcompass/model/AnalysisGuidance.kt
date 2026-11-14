package com.example.yiijingcompass.model

enum class BaZhaiSuggestedUse(val raw:String){
    ACTIVITY("activity"),REST("rest"),STUDY("study"),REVIEW("review");
    val titleKey get()="bz_use_$raw"
    val actionKey get()="bz_action_$raw"
    val avoidKey get()="bz_avoid_$raw"
}
val StarLuckType.suggestedHouseUse:BaZhaiSuggestedUse get()=when(this){
    StarLuckType.SHENG_QI->BaZhaiSuggestedUse.ACTIVITY
    StarLuckType.YAN_NIAN,StarLuckType.TIAN_YI->BaZhaiSuggestedUse.REST
    StarLuckType.FU_WEI->BaZhaiSuggestedUse.STUDY
    else->BaZhaiSuggestedUse.REVIEW
}
enum class XuanKongPattern(val raw:String){
    BALANCED("balanced"),BOTH_AT_FACING("front"),BOTH_AT_SITTING("back"),REVERSED("reversed"),DISTRIBUTED("distributed");
    val titleKey get()="xk_pattern_${raw}_title"
    val explanationKey get()="xk_pattern_${raw}_body"
}
val XuanKongChart.pattern:XuanKongPattern get(){
    patternKind?.takeIf {it in 0..4}?.let {return XuanKongPattern.values()[it]}
    val guaToID=mapOf("坎" to 0,"坤" to 1,"震" to 2,"巽" to 3,"乾" to 5,"兑" to 6,"艮" to 7,"离" to 8)
    val sitting=Mountain24Data.mountains.firstOrNull {(it.name==sittingMountain||it.localizedName==sittingMountain)}
    val facing=Mountain24Data.mountains.firstOrNull {(it.name==facingMountain||it.localizedName==facingMountain)}
    val back=palaces.firstOrNull {it.id==guaToID[sitting?.palace]};val front=palaces.firstOrNull {it.id==guaToID[facing?.palace]}
    return when {back?.mountainStar==period&&front?.facingStar==period->XuanKongPattern.BALANCED
        front?.mountainStar==period&&front?.facingStar==period->XuanKongPattern.BOTH_AT_FACING
        back?.mountainStar==period&&back?.facingStar==period->XuanKongPattern.BOTH_AT_SITTING
        front?.mountainStar==period&&back?.facingStar==period->XuanKongPattern.REVERSED
        else->XuanKongPattern.DISTRIBUTED}
}
val XuanKongChart.patternSourceReferences:List<TraditionalEvidence> get(){
    val context="$sittingMountain/$facingMountain · $period"
    val references=mutableListOf(TraditionalEvidence("classic.mountain_water",TraditionalEvidence.Kind.CLASSIC,"ref_mountain_water",listOf("山上龍神不下水，水裏龍神不上山。"),listOf(context),TraditionalEvidenceCatalog.mountainWaterURL),
        TraditionalEvidence("pattern.${pattern.ordinal}",TraditionalEvidence.Kind.RULE,"ref_pattern_rule",matches=listOf(context+" · "+LocalizationManager.instance.t(pattern.explanationKey))))
    if(isSanBanGua)references.add(TraditionalEvidence("pattern.sanban",TraditionalEvidence.Kind.RULE,"ref_sanban",matches=listOf(context)))
    if(isQiXingDaJie)references.add(TraditionalEvidence("pattern.qixing",TraditionalEvidence.Kind.RULE,"ref_qixing",matches=XuanKongDeepAnalyzer.qiXingSectorGroups(this).map {group->group.mapNotNull {id->palaces.firstOrNull {it.id==id}?.localizedPalaceName}.joinToString(" / ")}))
    return references
}
fun XuanKongChart.sourceReferences(palaceID:Int,yearStar:Int?=null,monthStar:Int?=null):List<TraditionalEvidence>{
    val cell=palaces.firstOrNull {it.id==palaceID} ?: return emptyList()
    val references=patternSourceReferences.filter {it.id!="pattern.qixing"||XuanKongDeepAnalyzer.qiXingSectorGroups(this).any {palaceID in it}}.toMutableList()
    references+=TraditionalEvidenceCatalog.pair(cell.mountainStar,cell.facingStar,cell.localizedPalaceName+" · "+LocalizationManager.instance.t("xkd_pair_natal"))
    fun add(a:Int,b:Int?,key:String){if(b!=null&&b in 1..9)references+=TraditionalEvidenceCatalog.pair(a,b,cell.localizedPalaceName+" · "+LocalizationManager.instance.t(key))}
    add(cell.mountainStar,yearStar,"xkd_pair_m_year");add(cell.facingStar,yearStar,"xkd_pair_f_year")
    add(cell.mountainStar,monthStar,"xkd_pair_m_month");add(cell.facingStar,monthStar,"xkd_pair_f_month")
    if(yearStar!=null&&yearStar in 1..9)add(yearStar,monthStar,"xkd_pair_guests")
    return TraditionalEvidenceCatalog.merged(references)
}
val HuangQuanWaterResult.sourceReference:TraditionalEvidence get(){
    val key=when(facingMountain){"庚","丁","坤"->"kun";"乙","丙","巽"->"xun";"甲","癸","艮"->"gen";"辛","壬","乾"->"qian";else->"other"}
    return TraditionalEvidence("huangquan.$facingMountain",TraditionalEvidence.Kind.RULE,"ref_hq_$key",matches=listOf("$facingMountain · $badgeText"))
}
val BaShaResult.sourceReference:TraditionalEvidence get()=TraditionalEvidence("basha.$sittingPalace",TraditionalEvidence.Kind.RULE,"ref_basha",matches=listOf("$sittingMountain · $sittingPalace → $shaZhi"))
val StarLuckType.sourceReference:TraditionalEvidence get(){
    val raw=when(this){StarLuckType.SHENG_QI->"shengqi";StarLuckType.YAN_NIAN->"yannian";StarLuckType.TIAN_YI->"tianyi";StarLuckType.FU_WEI->"fuwei";StarLuckType.JUE_MING->"jueming";StarLuckType.WU_GUI->"wugui";StarLuckType.LIU_SHA->"liusha";StarLuckType.HUO_HAI->"huohai"}
    return TraditionalEvidence("bazhai.$name",TraditionalEvidence.Kind.RULE,"ref_bz_$raw",matches=listOf(localizedName))
}
val QimenDoor.sourceReference:TraditionalEvidence get(){
    val key=when(name){"休门","生门","开门"->"good";"死门","惊门","伤门"->"bad";"杜门","景门"->"neutral";else->"unknown"}
    return TraditionalEvidence("qimen.$name",TraditionalEvidence.Kind.RULE,"ref_qimen_$key",matches=listOf("$localizedName · $palace"))
}
val PurpleWhitePalaceItem.sourceReferences:List<TraditionalEvidence> get()=TraditionalEvidenceCatalog.purpleWhite(yearGuestStar,monthGuestStar,palaceName)
