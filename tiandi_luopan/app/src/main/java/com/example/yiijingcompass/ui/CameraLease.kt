package com.example.yiijingcompass.ui

/** One in-process owner across native camera activities and split windows. */
object CameraLease {
    private var owner:String?=null
    @Synchronized fun acquire(id:String):Boolean {if(owner!=null&&owner!=id)return false;owner=id;return true}
    @Synchronized fun owns(id:String)=owner==id
    @Synchronized fun release(id:String){if(owner==id)owner=null}
}
