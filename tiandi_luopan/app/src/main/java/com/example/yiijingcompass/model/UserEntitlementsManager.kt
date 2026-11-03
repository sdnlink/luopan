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
    TIANJI_SINGLE("com.yanxiang.compass.tianji.single", "福宅宣纸长卷高清导出 (单次)")
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

    var level: EntitlementLevel = EntitlementLevel.FREE
        private set

    var exportCredits: Int = 3
        private set

    var isFloorplanUnlocked: Boolean = false
        private set

    val isVip: Boolean
        get() = level != EntitlementLevel.FREE

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs?.let {
            val levelStr = it.getString(KEY_LEVEL, EntitlementLevel.FREE.name) ?: EntitlementLevel.FREE.name
            level = try { EntitlementLevel.valueOf(levelStr) } catch (_: Exception) { EntitlementLevel.FREE }
            exportCredits = it.getInt(KEY_CREDITS, 3)
            isFloorplanUnlocked = it.getBoolean(KEY_FLOORPLAN_UNLOCKED, false)
        }
    }

    fun applyPurchase(productId: String): Boolean {
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

    fun upgradeTo(newLevel: EntitlementLevel) {
        level = newLevel
        prefs?.edit()?.putString(KEY_LEVEL, newLevel.name)?.apply()
    }

    fun consumeCredit(): Boolean {
        if (isVip) return true
        if (exportCredits > 0) {
            exportCredits--
            prefs?.edit()?.putInt(KEY_CREDITS, exportCredits)?.apply()
            return true
        }
        return false
    }

    fun addCredits(amount: Int) {
        exportCredits += amount
        prefs?.edit()?.putInt(KEY_CREDITS, exportCredits)?.apply()
    }

    fun getStatusJson(): String {
        val obj = org.json.JSONObject().apply {
            put("isVip", isVip)
            put("level", level.name)
            put("exportCredits", exportCredits)
            put("isFloorplanUnlocked", isFloorplanUnlocked)
            val purchasedArr = org.json.JSONArray()
            if (level == EntitlementLevel.PRO_YEARLY) purchasedArr.put(InAppProductId.VIP_YEARLY.productId)
            if (level == EntitlementLevel.LIFETIME) purchasedArr.put(InAppProductId.PRO_LIFETIME.productId)
            if (isFloorplanUnlocked) purchasedArr.put(InAppProductId.FLOORPLAN_SINGLE.productId)
            put("purchasedProductIds", purchasedArr)
        }
        return obj.toString()
    }
}

