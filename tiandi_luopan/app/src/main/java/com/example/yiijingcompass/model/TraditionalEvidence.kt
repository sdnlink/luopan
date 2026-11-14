package com.example.yiijingcompass.model

data class XuanKongStarPair(val first: Int, val second: Int) {
    enum class Relation(val titleKey: String) {
        SAME("xkd_pair_same"), FIRST_GENERATES_SECOND("xkd_pair_generate_forward"), SECOND_GENERATES_FIRST("xkd_pair_generate_back"),
        FIRST_CONTROLS_SECOND("xkd_pair_control_forward"), SECOND_CONTROLS_FIRST("xkd_pair_control_back")
    }
    private val elements = mapOf(1 to 4,2 to 2,3 to 0,4 to 0,5 to 2,6 to 3,7 to 3,8 to 2,9 to 1)
    val firstElementIndex get() = elements[first]
    val secondElementIndex get() = elements[second]
    val relation: Relation get() {
        val a = elements[first] ?: 2; val b = elements[second] ?: 2
        return when { a == b -> Relation.SAME; (a + 1) % 5 == b -> Relation.FIRST_GENERATES_SECOND
            (b + 1) % 5 == a -> Relation.SECOND_GENERATES_FIRST; (a + 2) % 5 == b -> Relation.FIRST_CONTROLS_SECOND
            else -> Relation.SECOND_CONTROLS_FIRST }
    }
    val hasEarthCaution get() = first in setOf(2,5) || second in setOf(2,5)
    val isStudy get() = setOf(first,second) in setOf(setOf(1,4),setOf(1,6))
    val isFriction get() = setOf(first,second) == setOf(3,7)
    val isHeat get() = setOf(first,second) == setOf(7,9) || first == 9 && second == 9
}

data class TraditionalEvidence(val id: String, val kind: Kind, val titleKey: String,
    val quotes: List<String> = emptyList(), val matches: List<String> = emptyList(), val sourceURL: String? = null) {
    enum class Kind { CLASSIC, RULE }
    val localizedTitle get() = LocalizationManager.instance.t(if(kind == Kind.CLASSIC) "ref_classic" else "ref_rule") + " · " + LocalizationManager.instance.t(titleKey)
    val localizedText get() = listOfNotNull(localizedTitle, quotes.takeIf { it.isNotEmpty() }?.joinToString("；", "“", "”"),
        matches.takeIf { it.isNotEmpty() }?.let { LocalizationManager.instance.t("ref_matches") + it.joinToString("；") },sourceURL).joinToString("\n")
}

object TraditionalEvidenceCatalog {
    const val mountainWaterURL = "https://zh.wikisource.org/w/index.php?oldid=1557328"
    const val elementsURL = "https://zh.wikisource.org/w/index.php?oldid=7915687"
    fun merged(references: List<TraditionalEvidence>): List<TraditionalEvidence> = references.groupBy { it.id }.values.map { group ->
        group.first().copy(quotes = group.flatMap { it.quotes }.distinct(), matches = group.flatMap { it.matches }.distinct())
    }
    fun text(references: List<TraditionalEvidence>) = merged(references).joinToString("\n\n") { it.localizedText }
    fun pair(first: Int, second: Int, context: String): List<TraditionalEvidence> {
        val pair = XuanKongStarPair(first,second)
        val a = pair.firstElementIndex ?: return emptyList(); val b = pair.secondElementIndex ?: return emptyList()
        val match = "$context $first/$second"; val result = mutableListOf<TraditionalEvidence>()
        when(pair.relation) {
            XuanKongStarPair.Relation.SAME -> result.add(TraditionalEvidence("elements.same",TraditionalEvidence.Kind.RULE,"ref_same_element",matches=listOf(match)))
            XuanKongStarPair.Relation.FIRST_GENERATES_SECOND, XuanKongStarPair.Relation.SECOND_GENERATES_FIRST -> {
                val index = if(pair.relation == XuanKongStarPair.Relation.FIRST_GENERATES_SECOND) a else b
                result.add(TraditionalEvidence("elements.generating",TraditionalEvidence.Kind.CLASSIC,"ref_elements_generating",listOf(listOf("木生火","火生土","土生金","金生水","水生木")[index]),listOf(match),elementsURL))
            }
            else -> {
                val index = if(pair.relation == XuanKongStarPair.Relation.FIRST_CONTROLS_SECOND) a else b
                result.add(TraditionalEvidence("elements.controlling",TraditionalEvidence.Kind.CLASSIC,"ref_elements_controlling",listOf(listOf("木剋土","火剋金","土剋水","金剋木","水剋火")[index]),listOf(match),elementsURL))
            }
        }
        fun rule(id: String,key: String) { result.add(TraditionalEvidence(id,TraditionalEvidence.Kind.RULE,key,matches=listOf(match))) }
        if(first == 2 || second == 2) rule("stars.two","ref_star_two")
        if(first == 5 || second == 5) rule("stars.five","ref_star_five")
        if(first == 5 && second == 5) rule("pair.five_five","ref_pair_five_five")
        val stars = setOf(first,second)
        mapOf(setOf(2,5) to ("two_five" to "ref_pair_two_five"),setOf(1,4) to ("one_four" to "ref_pair_one_four"),
            setOf(1,6) to ("one_six" to "ref_pair_one_six"),setOf(3,7) to ("three_seven" to "ref_pair_three_seven"),
            setOf(7,9) to ("seven_nine" to "ref_pair_seven_nine")).forEach { (pair,keys) -> if(stars == pair) rule("pair.${keys.first}",keys.second) }
        if(first == 9 && second == 9) rule("pair.nine_nine","ref_pair_nine_nine")
        return result
    }
    fun purpleWhite(year: Int,month: Int,palace: String): List<TraditionalEvidence> {
        val context = palace + " · " + LocalizationManager.instance.t("xkd_pair_guests")
        val match = "$context $year/$month"
        val result = pair(year,month,context).toMutableList()
        result.add(TraditionalEvidence("purplewhite.timing",TraditionalEvidence.Kind.RULE,"ref_guest_timing",matches=listOf(match)))
        if(year !in setOf(2,5) && month !in setOf(2,5)) {
            val key = when(year) { 9 -> "ref_year_nine";8 -> "ref_year_eight";1,4,6 -> "ref_year_study";else -> "ref_year_ordinary" }
            result.add(TraditionalEvidence("purplewhite.year.$year",TraditionalEvidence.Kind.RULE,key,matches=listOf(match)))
        }
        return merged(result)
    }
}
