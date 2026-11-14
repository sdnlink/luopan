package com.example.yiijingcompass.model

import android.content.Intent
import android.net.Uri

data class AppNavigationRoute(val tab:Int,val feature:String?=null,val dailyGuide:Boolean=false){
    companion object {
        private val features=setOf("flyingStars","xuankong","bazhai","sanhe","purpleWhite","purplewhite","qimen","dates","owner","profile","report","paywall")
        fun resolve(intent:Intent):AppNavigationRoute? {
            val uri=intent.data
            if(uri!=null){
                if(uri.scheme !in setOf("tiandiluopan","yanxiang"))return null
                return when(uri.host){
                    "almanac"->AppNavigationRoute(3,"dates")
                    "compass"->AppNavigationRoute(0,if(uri.getQueryParameter("sheet") in setOf("dailySign","dailyCard"))"dates" else null,true)
                    "floorplan"->AppNavigationRoute(2)
                    "qimen"->AppNavigationRoute(3,"qimen")
                    "analysis"->uri.getQueryParameter("feature")?.takeIf {it in features}?.let {AppNavigationRoute(3,it)}
                    "tab"->if(uri.getQueryParameter("sub")=="qimen")AppNavigationRoute(3,"qimen") else uri.getQueryParameter("index")?.toIntOrNull()?.let {AppNavigationRoute(if(it==3)2 else it.coerceIn(0,4))}
                    else->null
                }
            }
            val route=intent.getStringExtra("route")
            return AppNavigationRoute(intent.getIntExtra("tab",0).coerceIn(0,4),route?.takeIf {it in features},intent.getBooleanExtra("guide",false))
        }
    }
}
