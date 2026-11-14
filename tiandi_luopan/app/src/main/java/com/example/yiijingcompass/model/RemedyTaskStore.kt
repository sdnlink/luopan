package com.example.yiijingcompass.model

import android.content.Context
import java.util.Date

data class RemedyTask(val id:String,val propertyKey:String,val palaceDirection:String,val title:String,
    val remedyAction:String,val createdAt:Date=Date(),val completed:Boolean=false)
class RemedyTaskStore(context:Context) {
    private val prefs=context.getSharedPreferences("remedy_tasks",Context.MODE_PRIVATE)
    var tasks:List<RemedyTask> = prefs.getString("tasks",null)?.let {runCatching {ProjectCodec.gson.fromJson(it,Array<RemedyTask>::class.java).toList()}.getOrNull()} ?: emptyList()
        private set
    @Synchronized fun toggleRemedyTask(id:String,propertyKey:String,palaceDirection:String,title:String,remedyAction:String):Boolean {
        val existing=tasks.any {it.id==id&&it.propertyKey==propertyKey}
        return persist(if(existing)tasks.filterNot {it.id==id&&it.propertyKey==propertyKey} else tasks+RemedyTask(id,propertyKey,palaceDirection,title,remedyAction))
    }
    @Synchronized fun toggleRemedyCompletion(id:String,propertyKey:String)=persist(tasks.map {if(it.id==id&&it.propertyKey==propertyKey)it.copy(completed=!it.completed)else it})
    @Synchronized fun removeRemedyTask(id:String,propertyKey:String)=persist(tasks.filterNot {it.id==id&&it.propertyKey==propertyKey})
    private fun persist(next:List<RemedyTask>):Boolean {if(!prefs.edit().putString("tasks",ProjectCodec.gson.toJson(next)).commit())return false;tasks=next;return true}
}
