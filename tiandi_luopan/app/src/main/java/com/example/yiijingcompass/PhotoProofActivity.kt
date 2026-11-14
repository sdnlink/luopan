package com.example.yiijingcompass

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.model.LocalizationManager
import com.example.yiijingcompass.ui.NativeSharing
import java.io.File

/** Free local proof/daily-card preview, sharing and photo-library saving. */
class PhotoProofActivity:AppCompatActivity(){
    private var bitmap:Bitmap?=null
    private val lang get()=LocalizationManager.instance
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()){if(it)save()}
    override fun onCreate(state:Bundle?){
        super.onCreate(state);lang.init(this)
        val folder=File(cacheDir,"exports").canonicalFile
        val file=intent.getStringExtra("image")?.let {File(folder,it).canonicalFile}
        if(file==null||file.parentFile!=folder){finish();return}
        bitmap=BitmapFactory.decodeFile(file.path) ?: run {finish();return}
        val root=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
        root.addView(ZoomReportView(this).apply {bitmap=this@PhotoProofActivity.bitmap},LinearLayout.LayoutParams(-1,0,1f))
        root.addView(Button(this).apply {text=lang.t("native_share");setOnClickListener {bitmap?.let {image->runCatching {NativeSharing.shareBitmap(this@PhotoProofActivity,image)}.onFailure {toast("native_export_failed")}}}})
        root.addView(Button(this).apply {text=lang.t("native_save_gallery");setOnClickListener {
            if(android.os.Build.VERSION.SDK_INT<29&&ContextCompat.checkSelfPermission(this@PhotoProofActivity,Manifest.permission.WRITE_EXTERNAL_STORAGE)!=PackageManager.PERMISSION_GRANTED)permission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE) else save()
        }})
        setContentView(root)
    }
    private fun toast(key:String){Toast.makeText(this,lang.t(key),Toast.LENGTH_LONG).show()}
    private fun save(){bitmap?.let {image->runCatching {NativeSharing.saveBitmapToGallery(this,image)}.onSuccess {toast("native_saved")}.onFailure {toast("native_export_failed")}}}
    override fun onDestroy(){bitmap?.recycle();bitmap=null;super.onDestroy()}
}
