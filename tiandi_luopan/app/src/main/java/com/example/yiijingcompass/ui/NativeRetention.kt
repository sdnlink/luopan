package com.example.yiijingcompass.ui

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory

/** Uses the platform review sheet after the same milestones as main iOS.
 * Google Play controls availability and may choose not to show a prompt. */
object NativeRetention {
    fun recordMilestone(activity:Activity,reason:String){
        if(android.os.Build.FINGERPRINT.contains("robolectric",true))return
        val prefs=activity.getSharedPreferences("retention",Context.MODE_PRIVATE)
        val count=prefs.getInt("milestones",0)+1;val now=System.currentTimeMillis()
        prefs.edit().putInt("milestones",count).putString("last_reason",reason).apply()
        if(count !in setOf(2,6)&&count%15!=0||now-prefs.getLong("last_review",0)<14*86400000L)return
        prefs.edit().putLong("last_review",now).apply()
        activity.window.decorView.postDelayed({if(!activity.isFinishing&&!activity.isDestroyed)requestImmediateReview(activity)},1200)
    }
    fun requestImmediateReview(activity:Activity){
        val manager=ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener {task->if(task.isSuccessful&&!activity.isFinishing&&!activity.isDestroyed)manager.launchReviewFlow(activity,task.result)}
    }
}
