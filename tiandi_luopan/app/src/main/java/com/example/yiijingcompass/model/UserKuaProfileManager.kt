package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

enum class FamilyRole(val rawValue: String) {
    SPOUSE("spouse"), FATHER("father"), MOTHER("mother"), ELDER("elder"), SON("son"),
    DAUGHTER("daughter"), CHILD1("child1"), CHILD2("child2"), OTHER("other");
    val localizedTitle get() = LocalizationManager.instance.t("native_family_role_$rawValue")
}

data class FamilyMemberProfile(val id: String = UUID.randomUUID().toString(), var role: FamilyRole,
    var customName: String? = null, var birthDate: Date? = null, var birthYear: Int, var isMale: Boolean) {
    val effectiveFengShuiYear get() = birthDate?.let { UserKuaProfileManager.fengShuiYear(it) } ?: birthYear
    val lifeGuaNumber get() = UserKuaProfileManager.calcGuaNumber(effectiveFengShuiYear, isMale)
    val guaKey get() = UserKuaProfileManager.guaKey(lifeGuaNumber)
    val isEastLife get() = lifeGuaNumber in listOf(1, 3, 4, 9)
    val displayName get() = customName?.trim()?.takeIf { it.isNotEmpty() } ?: role.localizedTitle
    fun toJson() = JSONObject().apply {
        put("id", id); put("role", role.rawValue); put("customName", customName)
        put("birthDate", birthDate?.time); put("birthYear", birthYear); put("isMale", isMale)
    }
}

data class HouseKuaCompatibility(val ownerGua: String, val houseGua: String,
    val isMatched: Boolean, val houseStar: StarLuckType, val personalDirections: List<BaZhaiPalaceItem>,
    val localizedOwnerGuaName:String="",val localizedLifeGroup:String="",val zodiacBranch:String="",val localizedZodiacName:String="",val matchBadgeTitle:String="",val matchAdvice:String="") {
    val isMatchedWithHouse get()=isMatched
    val isEastLife get()=ownerGua in setOf("坎","震","巽","离")
    val wealthDirection get()=direction(StarLuckType.SHENG_QI)
    val healthDirection get()=direction(StarLuckType.TIAN_YI)
    val harmonyDirection get()=direction(StarLuckType.YAN_NIAN)
    val studyDirection get()=direction(StarLuckType.FU_WEI)
    private fun direction(star:StarLuckType)=personalDirections.firstOrNull {it.star==star}?.localizedDirection ?: "—"
}

class UserKuaProfileManager private constructor() {
    companion object {
        val instance by lazy { UserKuaProfileManager() }
        val shared get() = instance
        fun fengShuiYear(date: Date, timeZone: TimeZone = TimeZone.getDefault()): Int =
            java.util.GregorianCalendar(timeZone).apply { time = date }.get(Calendar.YEAR) -
                if (SolarTimeCalculator.instance.isBeforeLiChun(date, timeZone)) 1 else 0
        fun calcGuaNumber(birthYear: Int, isMale: Boolean): Int {
            var sum = birthYear
            while (sum >= 10) { var next = 0; var remainder = sum
                while (remainder > 0) { next += remainder % 10; remainder /= 10 }; sum = next }
            var number = if (isMale) (11 - sum) % 9 else (sum + 4) % 9
            if (number <= 0) number += 9
            return if (number == 5) (if (isMale) 2 else 8) else number
        }
        fun guaKey(number: Int) = mapOf(1 to "坎", 2 to "坤", 3 to "震", 4 to "巽", 6 to "乾", 7 to "兑", 8 to "艮", 9 to "离")[number] ?: "坎"
        fun restoringFamilyMembers(json: JSONArray): List<FamilyMemberProfile> {
            val seen = mutableSetOf<String>()
            return (0 until json.length()).map { index ->
                val row = json.getJSONObject(index)
                var id = row.optString("id").trim()
                if (id.isEmpty() || id in seen) id = UUID.randomUUID().toString()
                seen.add(id)
                FamilyMemberProfile(id, FamilyRole.values().firstOrNull { it.rawValue == row.optString("role") } ?: FamilyRole.OTHER,
                    row.optString("customName").takeIf { it.isNotBlank() && it != "null" },
                    if (row.has("birthDate") && !row.isNull("birthDate")) Date(row.getLong("birthDate")) else null,
                    row.optInt("birthYear", 1990).coerceIn(1920, 2035), row.optBoolean("isMale", true))
            }
        }
    }
    private var preferences: SharedPreferences? = null
    var isProfileEnabled = false
        set(value) { field = value; persist() }
    var birthYear = 1990
        private set
    var birthDate: Date? = null
        private set
    var isMale = true
        private set
    var familyMembers: List<FamilyMemberProfile> = emptyList()
        private set
    val ownerGuaKey get() = guaKey(calcGuaNumber(birthDate?.let { fengShuiYear(it) } ?: birthYear, isMale))
    val ownerLifeKua get() = calcGuaNumber(birthDate?.let { fengShuiYear(it) } ?: birthYear, isMale)

    fun init(context: Context) {
        val prefs = context.getSharedPreferences("tianji_personal_profile", Context.MODE_PRIVATE)
        birthYear = prefs.getInt("birthYear", 1990)
        birthDate = if (prefs.contains("birthDate")) Date(prefs.getLong("birthDate", 0)) else null
        isMale = prefs.getBoolean("isMale", true)
        isProfileEnabled = prefs.getBoolean("enabled", false)
        familyMembers = runCatching { restoringFamilyMembers(JSONArray(prefs.getString("family", "[]"))) }.getOrDefault(emptyList())
        preferences = prefs; persist() // Persist repaired legacy IDs exactly once.
    }
    private fun persist() {
        preferences?.edit()?.apply {
            putBoolean("enabled", isProfileEnabled); putInt("birthYear", birthYear); putBoolean("isMale", isMale)
            if (birthDate != null) putLong("birthDate", birthDate!!.time) else remove("birthDate")
            putString("family", JSONArray(familyMembers.map { it.toJson() }).toString())
        }?.apply()
    }
    fun updateOwnerBirth(date: Date, isMale: Boolean) {
        birthDate = Date(date.time); birthYear = fengShuiYear(date); this.isMale = isMale; isProfileEnabled = true; persist()
    }
    fun updateOwnerBirthYear(year: Int, isMale: Boolean) {
        val date = java.util.GregorianCalendar().apply { clear(); set(year.coerceIn(1920, 2035), Calendar.JUNE, 15, 12, 0, 0) }.time
        updateOwnerBirth(date, isMale)
    }
    fun addFamilyMember(role: FamilyRole, customName: String? = null, birthDate: Date? = null, birthYear: Int, isMale: Boolean) {
        val profile = FamilyMemberProfile(role = role, customName = customName, birthDate = birthDate,
            birthYear = birthDate?.let { fengShuiYear(it) } ?: birthYear.coerceIn(1920, 2035), isMale = isMale)
        familyMembers = familyMembers + profile; isProfileEnabled = true; persist()
    }
    fun updateFamilyMember(id: String, role: FamilyRole? = null, customName: String? = null,
        birthDate: Date? = null, birthYear: Int? = null, isMale: Boolean? = null) {
        familyMembers = familyMembers.map { member ->
            if (member.id != id) member else member.copy(role = role ?: member.role,
                customName = customName ?: member.customName,
                birthDate = birthDate ?: if (birthYear != null) null else member.birthDate,
                birthYear = birthDate?.let { fengShuiYear(it) } ?: birthYear?.coerceIn(1920, 2035) ?: member.birthYear,
                isMale = isMale ?: member.isMale)
        }; persist()
    }
    fun removeFamilyMember(id: String) { familyMembers = familyMembers.filterNot { it.id == id }; persist() }
    fun addOrUpdateFamilyMember(role: FamilyRole, birthYear: Int, isMale: Boolean) {
        familyMembers.firstOrNull { it.role == role }?.let { updateFamilyMember(it.id, birthYear = birthYear, isMale = isMale) }
            ?: addFamilyMember(role, birthYear = birthYear, isMale = isMale)
    }
    fun deleteAllPersonalProfiles() {
        familyMembers = emptyList(); birthYear = 1990; birthDate = null; isMale = true
        isProfileEnabled = false
        preferences?.edit()?.clear()?.putBoolean("enabled", false)?.apply()
    }
    fun evaluateCompatibility(sittingPalace: String): HouseKuaCompatibility {
        val chart = BaZhaiEngine.instance.analyze(ownerGuaKey, sittingPalace)
        val matched=(ownerGuaKey in listOf("坎","震","巽","离"))==(sittingPalace in listOf("坎","震","巽","离"))
        val lang=LocalizationManager.instance
        val group=lang.t("native_kua_group_"+if(ownerLifeKua in setOf(1,3,4,9))"yes" else "no")
        val wealth=chart.items.firstOrNull {it.star==StarLuckType.SHENG_QI}?.localizedDirection ?: "—"
        val health=chart.items.firstOrNull {it.star==StarLuckType.TIAN_YI}?.localizedDirection ?: "—"
        fun text(key:String)=lang.t(key).replace("{gua}",Mountain24Data.mountains.first {it.palace==ownerGuaKey}.localizedPalace)
            .replace("{number}",ownerLifeKua.toString()).replace("{group}",group).replace("{wealth}",wealth).replace("{health}",health)
        val index=Math.floorMod(birthYear-4,12)
        return HouseKuaCompatibility(ownerGuaKey,sittingPalace,matched,chart.gateStar,chart.items,text("native_kua_name"),group,
            "子丑寅卯辰巳午未申酉戌亥"[index].toString(),lang.t("native_zodiac_$index"),text("native_kua_badge_"+if(matched)"yes" else "no"),text("native_kua_advice_"+if(matched)"yes" else "no"))
    }
    val canUsePersonalAnalysis get()=isProfileEnabled&&UserEntitlementsManager.instance.isVip
    fun localizedLifeKuaName()=evaluateCompatibility("坎").let {it.localizedOwnerGuaName+" · "+it.localizedLifeGroup}
    fun localizedZodiac()=evaluateCompatibility("坎").localizedZodiacName
}
