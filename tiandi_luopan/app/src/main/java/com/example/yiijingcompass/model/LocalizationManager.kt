package com.example.yiijingcompass.model

import android.content.Context
import org.json.JSONObject
import java.io.InputStreamReader
import java.util.Locale

enum class AppLanguage(val rawValue: String, val displayName: String) {
    AUTO("auto", "跟随系统"),
    ZH_HANS("zh-Hans", "简体中文"),
    ZH_HANT("zh-Hant", "繁體中文"),
    EN("en", "English"),
    TH("th", "ภาษาไทย"),
    VI("vi", "Tiếng Việt"),
    ID("id", "Bahasa Indonesia"),
    JA("ja", "日本語"),
    KO("ko", "한국어")
}

class LocalizationManager private constructor() {
    companion object {
        val instance: LocalizationManager by lazy { LocalizationManager() }
        val shared: LocalizationManager get() = instance
        private const val PREFS_NAME = "tianji_localization"
        private const val KEY_LANGUAGE = "app_language"
    }

    var currentSetting: AppLanguage = AppLanguage.AUTO
        set(value) {
            field = value
            updateEffectiveLanguage()
        }

    var effectiveLanguage: AppLanguage = AppLanguage.ZH_HANS
        private set

    private val translations = mutableMapOf<String, Map<String, String>>()

    fun init(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val saved = prefs.getString(KEY_LANGUAGE, "auto") ?: "auto"
        currentSetting = AppLanguage.values().firstOrNull { it.rawValue == saved } ?: AppLanguage.AUTO
        updateEffectiveLanguage()

        try {
            context.assets.open("i18n.json").use { stream ->
                InputStreamReader(stream, "UTF-8").use { reader ->
                    val jsonStr = reader.readText()
                    val root = JSONObject(jsonStr)
                    val keys = root.keys()
                    while (keys.hasNext()) {
                        val langKey = keys.next()
                        val langObj = root.getJSONObject(langKey)
                        val dict = mutableMapOf<String, String>()
                        val innerKeys = langObj.keys()
                        while (innerKeys.hasNext()) {
                            val k = innerKeys.next()
                            dict[k] = langObj.getString(k)
                        }
                        translations[langKey] = dict
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateEffectiveLanguage() {
        effectiveLanguage = resolveLanguage(currentSetting)
    }

    fun setLanguage(context: Context, lang: AppLanguage) {
        currentSetting = lang
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_LANGUAGE, lang.rawValue).apply()
    }

    fun resolveLanguage(setting: AppLanguage): AppLanguage {
        if (setting == AppLanguage.AUTO) {
            val defaultLocale = Locale.getDefault()
            val tag = defaultLocale.toLanguageTag().lowercase()
            return when {
                tag.contains("hant") || tag.contains("tw") || tag.contains("hk") || tag.contains("mo") -> AppLanguage.ZH_HANT
                tag.startsWith("zh") -> AppLanguage.ZH_HANS
                tag.startsWith("th") -> AppLanguage.TH
                tag.startsWith("vi") -> AppLanguage.VI
                tag.startsWith("id") || tag.startsWith("in") -> AppLanguage.ID
                tag.startsWith("ja") -> AppLanguage.JA
                tag.startsWith("ko") -> AppLanguage.KO
                else -> AppLanguage.EN
            }
        }
        return setting
    }

    fun t(key: String): String {
        val langKey = when (effectiveLanguage) {
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> "zhHans"
            AppLanguage.ZH_HANT -> "zhHant"
            AppLanguage.EN -> "en"
            AppLanguage.TH -> "th"
            AppLanguage.VI -> "vi"
            AppLanguage.ID -> "id"
            AppLanguage.JA -> "ja"
            AppLanguage.KO -> "ko"
        }
        return translations[langKey]?.get(key)
            ?: translations["zhHans"]?.get(key)
            ?: key
    }
}

