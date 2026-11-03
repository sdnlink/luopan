package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences

enum class EntitlementLevel {
    FREE,
    PRO_MONTHLY,
    PRO_YEARLY,
    LIFETIME
}

class UserEntitlementsManager private constructor() {
    companion object {
        val instance: UserEntitlementsManager by lazy { UserEntitlementsManager() }
        private const val PREFS_NAME = "tianji_entitlements"
        private const val KEY_LEVEL = "entitlement_level"
        private const val KEY_CREDITS = "export_credits"
    }

    private var prefs: SharedPreferences? = null

    var level: EntitlementLevel = EntitlementLevel.FREE
        private set

    var exportCredits: Int = 3
        private set

    val isVip: Boolean
        get() = level != EntitlementLevel.FREE

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs?.let {
            val levelStr = it.getString(KEY_LEVEL, EntitlementLevel.FREE.name) ?: EntitlementLevel.FREE.name
            level = try { EntitlementLevel.valueOf(levelStr) } catch (_: Exception) { EntitlementLevel.FREE }
            exportCredits = it.getInt(KEY_CREDITS, 3)
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
}

