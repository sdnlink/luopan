package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences

enum class EntitlementLevel {
    FREE,
    PRO_MONTHLY,
    PRO_YEARLY,
    LIFETIME
}

enum class InAppProductId(val productId: String, val titleZh: String) {
    VIP_YEARLY("com.yanxiang.compass.vip.yearly", "太学高阶会员 (年度订阅)"),
    PRO_LIFETIME("com.yanxiang.compass.pro.lifetime", "乾坤·大师版 (终身买断)"),
    FLOORPLAN_SINGLE("com.yanxiang.compass.floorplan.case", "户型空间全案立极 (单次)"),
    TIANJI_SINGLE("com.yanxiang.compass.tianji.single", "福宅宣纸长卷高清导出 (单次)");

    val localizedTitle: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.EN -> when (this) {
                VIP_YEARLY -> "Imperial Academy VIP (Annual)"
                PRO_LIFETIME -> "Qiankun Master Edition (Lifetime)"
                FLOORPLAN_SINGLE -> "Floorplan Full Audit (Single)"
                TIANJI_SINGLE -> "HD Xuan Paper Scroll Export (Single)"
            }
            AppLanguage.ZH_HANT -> when (this) {
                VIP_YEARLY -> "太學高階會員 (年度訂閱)"
                PRO_LIFETIME -> "乾坤·大師版 (終身買斷)"
                FLOORPLAN_SINGLE -> "戶型空間全案立極 (單次)"
                TIANJI_SINGLE -> "福宅宣紙長卷高清導出 (單次)"
            }
            AppLanguage.JA -> when (this) {
                VIP_YEARLY -> "太学上級会員（年間購読）"
                PRO_LIFETIME -> "乾坤・マスター版（永久買い切り）"
                FLOORPLAN_SINGLE -> "間取り空間鑑定（単回）"
                TIANJI_SINGLE -> "宣紙長巻HD書き出し（単回）"
            }
            AppLanguage.KO -> when (this) {
                VIP_YEARLY -> "태학 고급 멤버십 (연간 구독)"
                PRO_LIFETIME -> "건곤 · 마스터판 (평생 소장)"
                FLOORPLAN_SINGLE -> "평면 공간 입극 감정 (1회)"
                TIANJI_SINGLE -> "화선지 장권 HD 내보내기 (1회)"
            }
            AppLanguage.VI -> when (this) {
                VIP_YEARLY -> "Hội Viên Thái Học Cao Cấp (Theo Năm)"
                PRO_LIFETIME -> "Bản Đại Sư Càn Khôn (Trọn Đời)"
                FLOORPLAN_SINGLE -> "Lập Cực Toàn Án Mặt Bằng (1 Lần)"
                TIANJI_SINGLE -> "Xuất Trường Quyển Giấy Tuyên HD (1 Lần)"
            }
            AppLanguage.TH -> when (this) {
                VIP_YEARLY -> "สมาชิกระดับสูงไท่เสวีย (รายปี)"
                PRO_LIFETIME -> "รุ่นปรมาจารย์เฉียนคุน (ตลอดชีพ)"
                FLOORPLAN_SINGLE -> "วิเคราะห์ผังบ้านเต็มรูปแบบ (รายครั้ง)"
                TIANJI_SINGLE -> "ส่งออกม้วนคัมภีร์กระดาษเซวียน HD (รายครั้ง)"
            }
            AppLanguage.ID -> when (this) {
                VIP_YEARLY -> "Anggota VIP Tai Xue (Tahunan)"
                PRO_LIFETIME -> "Edisi Master Qiankun (Seumur Hidup)"
                FLOORPLAN_SINGLE -> "Analisis Penuh Denah Rumah (Sekali)"
                TIANJI_SINGLE -> "Ekspor HD Gulungan Kertas Xuan (Sekali)"
            }
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> titleZh
        }
}

class UserEntitlementsManager private constructor() {
    companion object {
        val instance: UserEntitlementsManager by lazy { UserEntitlementsManager() }
        private const val PREFS_NAME = "tianji_entitlements"
        private const val KEY_LEVEL = "entitlement_level"
        private const val KEY_CREDITS = "export_credits"
        private const val KEY_FLOORPLAN_UNLOCKED = "floorplan_unlocked"
    }

    private var prefs: SharedPreferences? = null
    private val activeReservations=mutableSetOf<String>()

    var level: EntitlementLevel = EntitlementLevel.FREE
        private set

    var exportCredits: Int = 0
        private set

    var floorplanCredits: Int = 0
        private set

    var isFloorplanUnlocked: Boolean = false
        private set

    val isVip: Boolean
        get() = level != EntitlementLevel.FREE

    @Synchronized fun init(context: Context,recoverReservations:Boolean=true) {
        prefs=runCatching {com.example.yiijingcompass.billing.SignedEntitlementPreferences.open(context)}.getOrNull()
        if(prefs==null){level=EntitlementLevel.FREE;exportCredits=0;floorplanCredits=0;isFloorplanUnlocked=false;return}
        prefs?.let {
            val levelStr = it.getString(KEY_LEVEL, EntitlementLevel.FREE.name) ?: EntitlementLevel.FREE.name
            level = try { EntitlementLevel.valueOf(levelStr) } catch (_: Exception) { EntitlementLevel.FREE }
            exportCredits = it.getInt(KEY_CREDITS, 0)
            floorplanCredits=it.getInt("floorplan_credits",0)
            isFloorplanUnlocked = floorplanCredits>0
            if(recoverReservations){
                val pending=reservations();val abandoned=pending.filterNot {it in activeReservations}
                if(abandoned.isNotEmpty()&&it.edit().putInt(KEY_CREDITS,exportCredits+abandoned.size).putStringSet("export_reservations",pending.minus(abandoned.toSet())).commit())exportCredits+=abandoned.size
            }
        }
    }

    fun storageReady():Boolean=runCatching {prefs?.edit()?.putBoolean("ledger_ready",true)?.commit()==true}.getOrDefault(false)
    @Synchronized internal fun applyVerifiedPurchase(productId: String,token: String): Boolean {
        if(token.isBlank())return false
        val key="token-"+java.security.MessageDigest.getInstance("SHA-256").digest((token+productId).toByteArray()).joinToString(""){"%02x".format(it)}
        if(prefs?.getBoolean(key,false)==true && productId in setOf(InAppProductId.TIANJI_SINGLE.productId,InAppProductId.FLOORPLAN_SINGLE.productId))return true
        if(productId==InAppProductId.TIANJI_SINGLE.productId){
            val next=exportCredits+1
            if(prefs?.edit()?.putInt(KEY_CREDITS,next)?.putBoolean(key,true)?.commit()!=true)return false
            exportCredits=next;return true
        }
        if(productId==InAppProductId.FLOORPLAN_SINGLE.productId){
            val next=floorplanCredits+1
            if(prefs?.edit()?.putInt("floorplan_credits",next)?.putBoolean(key,true)?.commit()!=true)return false
            floorplanCredits=next;isFloorplanUnlocked=true;return true
        }
        val result=applyPurchase(productId)
        if(result&&prefs?.edit()?.putBoolean(key,true)?.commit()!=true)return false
        return result
    }

    @Synchronized internal fun reconcileMembership(productIDs:Set<String>) {
        level=when {InAppProductId.PRO_LIFETIME.productId in productIDs->EntitlementLevel.LIFETIME
            InAppProductId.VIP_YEARLY.productId in productIDs->EntitlementLevel.PRO_YEARLY;else->EntitlementLevel.FREE}
        isFloorplanUnlocked=floorplanCredits>0
        prefs?.edit()?.putString(KEY_LEVEL,level.name)?.putBoolean(KEY_FLOORPLAN_UNLOCKED,isFloorplanUnlocked)?.apply()
    }

    fun hasFloorplanAccess(propertyKey:String):Boolean = isVip||prefs?.getBoolean("floorplan-grant-$propertyKey",false)==true
    /** Balance and project grant commit together; imported JSON cannot create a grant. */
    @Synchronized fun acquireFloorplanAccess(propertyKey:String,persist:()->Boolean={true}):Boolean {
        if(hasFloorplanAccess(propertyKey))return true
        if(propertyKey.isBlank()||floorplanCredits<=0)return false
        if(!persist())return false
        if(prefs?.edit()?.putInt("floorplan_credits",floorplanCredits-1)?.putBoolean("floorplan-grant-$propertyKey",true)?.commit()!=true)return false
        floorplanCredits--;isFloorplanUnlocked=floorplanCredits>0;return true
    }

    private fun applyPurchase(productId: String): Boolean {
        return when (productId) {
            InAppProductId.VIP_YEARLY.productId -> {
                upgradeTo(EntitlementLevel.PRO_YEARLY)
                true
            }
            InAppProductId.PRO_LIFETIME.productId -> {
                upgradeTo(EntitlementLevel.LIFETIME)
                true
            }
            InAppProductId.FLOORPLAN_SINGLE.productId -> {
                isFloorplanUnlocked = true
                prefs?.edit()?.putBoolean(KEY_FLOORPLAN_UNLOCKED, true)?.apply()
                true
            }
            InAppProductId.TIANJI_SINGLE.productId -> {
                addCredits(1)
                true
            }
            else -> false
        }
    }

    private fun upgradeTo(newLevel: EntitlementLevel) {
        if(level==EntitlementLevel.LIFETIME&&newLevel!=EntitlementLevel.LIFETIME)return
        level = newLevel
        prefs?.edit()?.putString(KEY_LEVEL, newLevel.name)?.apply()
    }

    @Synchronized fun consumeCredit(): Boolean {
        if (isVip) return true
        if (exportCredits > 0) {
            if(prefs?.edit()?.putInt(KEY_CREDITS, exportCredits-1)?.commit()!=true)return false
            exportCredits--
            return true
        }
        return false
    }

    private fun reservations():Set<String> = prefs?.getStringSet("export_reservations",emptySet())?.toSet() ?: emptySet()
    @Synchronized fun reserveTianjiCredit():String? {
        if(exportCredits<=0)return null
        val token=java.util.UUID.randomUUID().toString()
        if(prefs?.edit()?.putInt(KEY_CREDITS,exportCredits-1)?.putStringSet("export_reservations",reservations()+token)?.commit()!=true)return null
        exportCredits--;activeReservations.add(token);return token
    }
    @Synchronized fun commitTianjiCreditReservation(token:String){
        if(token !in reservations()){activeReservations.remove(token);return}
        if(prefs?.edit()?.putStringSet("export_reservations",reservations()-token)?.commit()==true)activeReservations.remove(token)
    }
    @Synchronized fun refundTianjiCreditReservation(token:String){
        if(token !in reservations()){activeReservations.remove(token);return}
        if(prefs?.edit()?.putInt(KEY_CREDITS,exportCredits+1)?.putStringSet("export_reservations",reservations()-token)?.commit()==true){exportCredits++;activeReservations.remove(token)}
    }
    @Synchronized internal fun refundExportCredit() {
        val next=exportCredits+1
        if(prefs?.edit()?.putInt(KEY_CREDITS,next)?.commit()==true)exportCredits=next
    }
    private fun addCredits(amount: Int) {
        exportCredits += amount
        prefs?.edit()?.putInt(KEY_CREDITS, exportCredits)?.apply()
    }

    fun getStatusJson(): String {
        val obj = org.json.JSONObject().apply {
            put("isVip", isVip)
            put("level", level.name)
            put("exportCredits", exportCredits)
            put("isFloorplanUnlocked", isFloorplanUnlocked)
            put("floorplanCredits",floorplanCredits)
            val purchasedArr = org.json.JSONArray()
            if (level == EntitlementLevel.PRO_YEARLY) purchasedArr.put(InAppProductId.VIP_YEARLY.productId)
            if (level == EntitlementLevel.LIFETIME) purchasedArr.put(InAppProductId.PRO_LIFETIME.productId)
            if (isFloorplanUnlocked) purchasedArr.put(InAppProductId.FLOORPLAN_SINGLE.productId)
            put("purchasedProductIds", purchasedArr)
        }
        return obj.toString()
    }
}

