package com.example.yiijingcompass.model

import android.content.Context
import android.content.SharedPreferences

enum class CompassPreset(val rawValue: String) {
    COMPREHENSIVE("综合全息盘"),
    SAN_YUAN("三元玄空盘"),
    SAN_HE("三合水法盘"),
    MINIMALIST("极简勘测盘")
}

class CompassLayerManager private constructor() {
    companion object {
        val instance: CompassLayerManager by lazy { CompassLayerManager() }
        private const val PREFS_NAME = "compass_layers"
    }

    private var prefs: SharedPreferences? = null

    var showDegreeTicks: Boolean = true
    var showSolarTerms: Boolean = true
    var showHexagrams64: Boolean = true
    var showFenjin120: Boolean = true
    var showMountain24: Boolean = true
    var showEightGua: Boolean = true
    var showTrueNorthNeedle: Boolean = true
    var showLevelBubble: Boolean = true

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs?.let {
            showDegreeTicks = it.getBoolean("compass_layer_degree_ticks", true)
            showSolarTerms = it.getBoolean("compass_layer_solar_terms", true)
            showHexagrams64 = it.getBoolean("compass_layer_hexagrams64", true)
            showFenjin120 = it.getBoolean("compass_layer_fenjin120", true)
            showMountain24 = it.getBoolean("compass_layer_mountain24", true)
            showEightGua = it.getBoolean("compass_layer_eight_gua", true)
            showTrueNorthNeedle = it.getBoolean("compass_layer_true_north", true)
            showLevelBubble = it.getBoolean("compass_layer_level_bubble", true)
        }
    }

    fun applyPreset(preset: CompassPreset) {
        when (preset) {
            CompassPreset.COMPREHENSIVE -> {
                showDegreeTicks = true
                showSolarTerms = true
                showHexagrams64 = true
                showFenjin120 = true
                showMountain24 = true
                showEightGua = true
                showTrueNorthNeedle = true
                showLevelBubble = true
            }
            CompassPreset.SAN_YUAN -> {
                showDegreeTicks = true
                showSolarTerms = false
                showHexagrams64 = true
                showFenjin120 = true
                showMountain24 = true
                showEightGua = true
                showTrueNorthNeedle = true
                showLevelBubble = true
            }
            CompassPreset.SAN_HE -> {
                showDegreeTicks = true
                showSolarTerms = true
                showHexagrams64 = false
                showFenjin120 = true
                showMountain24 = true
                showEightGua = true
                showTrueNorthNeedle = true
                showLevelBubble = true
            }
            CompassPreset.MINIMALIST -> {
                showDegreeTicks = true
                showSolarTerms = false
                showHexagrams64 = false
                showFenjin120 = false
                showMountain24 = true
                showEightGua = true
                showTrueNorthNeedle = true
                showLevelBubble = true
            }
        }
        persist()
    }

    private fun persist() {
        prefs?.edit()?.apply {
            putBoolean("compass_layer_degree_ticks", showDegreeTicks)
            putBoolean("compass_layer_solar_terms", showSolarTerms)
            putBoolean("compass_layer_hexagrams64", showHexagrams64)
            putBoolean("compass_layer_fenjin120", showFenjin120)
            putBoolean("compass_layer_mountain24", showMountain24)
            putBoolean("compass_layer_eight_gua", showEightGua)
            putBoolean("compass_layer_true_north", showTrueNorthNeedle)
            putBoolean("compass_layer_level_bubble", showLevelBubble)
            apply()
        }
    }
}

