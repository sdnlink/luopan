package com.example.yiijingcompass.ui

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.example.yiijingcompass.MainActivity
import com.example.yiijingcompass.R
import com.example.yiijingcompass.model.LocalizationManager

object NativeDiscovery {
    fun register(context:Context){
        val lang=LocalizationManager.instance
        val shortcuts=listOf(0 to "daily_god_guide",3 to "native_daily_card",2 to "tab_floorplan",3 to "qimen_dunjia").mapIndexed {index,(tab,key)->
            ShortcutInfoCompat.Builder(context,"feature-$index").setShortLabel(lang.t(key)).setLongLabel(lang.t(key))
                .setIcon(IconCompat.createWithResource(context,R.mipmap.ic_launcher))
                .setIntent(Intent(context,MainActivity::class.java).setAction(Intent.ACTION_VIEW).putExtra("tab",tab).apply {if(index==1)putExtra("route","dates");if(index==3)putExtra("route","qimen");if(index==0)putExtra("guide",true)}).build()
        }
        runCatching {ShortcutManagerCompat.setDynamicShortcuts(context,shortcuts)}
    }
}
