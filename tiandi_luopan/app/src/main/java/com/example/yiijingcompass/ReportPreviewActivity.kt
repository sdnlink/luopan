package com.example.yiijingcompass

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.*
import android.os.Bundle
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.ui.NativeSharing
import java.io.File

/** Frozen report preview; exporting reserves a credit, refunds any failed render
 * or write, and never reconstructs analysis from a subsequently opened property. */
class ReportPreviewActivity:AppCompatActivity(){
    data class Request(val snapshot:TianJiAnalysisSnapshot,val coords:String,val solar:String,val language:AppLanguage)
    private lateinit var request:Request
    private lateinit var image:ZoomReportView
    private lateinit var progress:TextView
    private var bitmap:Bitmap?=null
    private var busy=false
    private var pendingLease:String?=null
    private var sharingLease:String?=null
    private var shareHasLeft=false
    private val lang get()=LocalizationManager.instance
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()){if(it)export(true)}
    override fun onCreate(state:Bundle?){
        super.onCreate(state)
        lang.init(this);UserEntitlementsManager.instance.init(this)
        cacheDir.listFiles()?.filter {it.name.startsWith("report-request-")&&System.currentTimeMillis()-it.lastModified()>7*86400000L}?.forEach {it.delete()}
        sharingLease=state?.getString("sharingLease")
        shareHasLeft=state?.getBoolean("shareHasLeft",false) ?: false
        val file=intent.getStringExtra("request")?.let {File(cacheDir,it).canonicalFile}
        if(file==null||file.parentFile!=cacheDir.canonicalFile||!file.name.startsWith("report-request-")){finish();return}
        request=runCatching {ProjectCodec.gson.fromJson(file.readText(),Request::class.java)}.getOrNull() ?: run {finish();return}
        val root=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.rgb(18,18,22))}
        progress=TextView(this).apply {setTextColor(Color.WHITE);text=lang.t("native_report_preview");setPadding(16,12,16,12)};root.addView(progress)
        image=ZoomReportView(this);root.addView(image,LinearLayout.LayoutParams(-1,0,1f))
        root.addView(Button(this).apply {text=lang.t("native_custom_signature");setOnClickListener {signatureEditor()}})
        root.addView(Button(this).apply {text=lang.t("native_share");setOnClickListener {export(false)}})
        root.addView(Button(this).apply {text=lang.t("native_save_gallery");setOnClickListener {
            if(android.os.Build.VERSION.SDK_INT<29&&ContextCompat.checkSelfPermission(this@ReportPreviewActivity,Manifest.permission.WRITE_EXTERNAL_STORAGE)!=PackageManager.PERMISSION_GRANTED)permission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE) else export(true)
        }})
        setContentView(root);generate(false,{rendered->replaceBitmap(rendered)})
    }
    private fun signatureEditor(){
        if(busy)return
        val prefs=getSharedPreferences("report_signature",MODE_PRIVATE)
        val panel=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
        fun field(key:String,value:String)=EditText(this).apply {hint=lang.t(key);setText(value);filters=arrayOf(android.text.InputFilter.LengthFilter(120));panel.addView(this)}
        val client=field("native_client_name",request.snapshot.signature.client)
        val master=field("native_master_name",request.snapshot.signature.master)
        val seal=field("native_seal_text",request.snapshot.signature.seal)
        androidx.appcompat.app.AlertDialog.Builder(this).setTitle(lang.t("native_custom_signature")).setView(panel)
            .setPositiveButton(lang.t("done")){_,_->val value=ReportSignature(client.text.toString().trim(),master.text.toString().trim(),seal.text.toString().trim().take(60))
                prefs.edit().putString("value",ProjectCodec.gson.toJson(value)).apply();request=request.copy(snapshot=request.snapshot.copy(signature=value))
                intent.getStringExtra("request")?.let {File(cacheDir,it).writeText(ProjectCodec.gson.toJson(request))}
                generate(false,{replaceBitmap(it)})
            }.setNegativeButton(lang.t("cancel"),null).show()
    }
    private fun replaceBitmap(value:Bitmap){val previous=bitmap;bitmap=value;image.bitmap=value;image.reset();previous?.takeIf {it!==value}?.recycle()}
    private fun generate(paid:Boolean,complete:(Bitmap)->Unit,onFailure:(()->Unit)?=null){
        if(busy)return;busy=true;progress.text=lang.t("native_report_rendering")
        Thread {val result=runCatching {TianJiShuEngine.instance.generateScrollImage(this,request.snapshot.heading,request.coords,request.solar,
            language=request.language,isPro=paid,analysis=request.snapshot)}
            runOnUiThread {busy=false;progress.text=lang.t("native_report_preview")
                if(isFinishing||isDestroyed){result.getOrNull()?.recycle();onFailure?.invoke();return@runOnUiThread}
                result.onSuccess(complete).onFailure {onFailure?.invoke();Toast.makeText(this,lang.t("native_export_failed"),Toast.LENGTH_LONG).show()}
            }
        }.start()
    }
    private fun export(gallery:Boolean){
        if(busy)return
        val entitlement=UserEntitlementsManager.instance
        if(!entitlement.isVip&&entitlement.exportCredits==0){
            startActivity(android.content.Intent(this,MainActivity::class.java).putExtra("tab",4).putExtra("route","paywall"));return
        }
        val lease=if(entitlement.isVip)null else entitlement.reserveTianjiCredit() ?: return
        pendingLease=lease
        fun refund(){lease?.let(entitlement::refundTianjiCreditReservation);pendingLease=null}
        generate(true,{rendered->
            runCatching {if(gallery)NativeSharing.saveBitmapToGallery(this,rendered) else NativeSharing.shareBitmap(this,rendered,lease)}
                .onSuccess {if(gallery)lease?.let(entitlement::commitTianjiCreditReservation) else {sharingLease=lease;shareHasLeft=false};pendingLease=null;replaceBitmap(rendered);com.example.yiijingcompass.ui.NativeRetention.recordMilestone(this,"export_tianji");Toast.makeText(this,lang.t("native_saved"),Toast.LENGTH_SHORT).show()}
                .onFailure {rendered.recycle();refund();Toast.makeText(this,lang.t("native_export_failed"),Toast.LENGTH_LONG).show()}
        },::refund)
    }
    override fun onSaveInstanceState(state:Bundle){state.putString("sharingLease",sharingLease);state.putBoolean("shareHasLeft",shareHasLeft);super.onSaveInstanceState(state)}
    override fun onPause(){if(sharingLease!=null)shareHasLeft=true;super.onPause()}
    override fun onResume(){super.onResume();if(shareHasLeft){sharingLease?.let(UserEntitlementsManager.instance::refundTianjiCreditReservation);sharingLease=null;shareHasLeft=false}}
    override fun onDestroy(){pendingLease?.let(UserEntitlementsManager.instance::refundTianjiCreditReservation);if(::image.isInitialized)image.bitmap=null;bitmap?.recycle();bitmap=null;super.onDestroy()}
}

internal class ZoomReportView(context:android.content.Context):View(context){
    init {setLayerType(View.LAYER_TYPE_SOFTWARE,null)}
    var bitmap:Bitmap?=null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private var zoom=1f;private var x=0f;private var y=0f;private var lastX=0f;private var lastY=0f
    private val detector=ScaleGestureDetector(context,object:ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(detector:ScaleGestureDetector):Boolean {
            val old=zoom;zoom=(zoom*detector.scaleFactor).coerceIn(.5f,6f)
            x=detector.focusX-(detector.focusX-x)*zoom/old;y=detector.focusY-(detector.focusY-y)*zoom/old;invalidate();return true
        }
    })
    fun reset(){zoom=1f;x=0f;y=0f;invalidate()}
    override fun onDraw(canvas:Canvas){val image=bitmap ?: return;val scale=width.toFloat()/image.width*zoom
        canvas.save();canvas.translate(x,y);canvas.scale(scale,scale);canvas.drawBitmap(image,0f,0f,paint);canvas.restore()}
    override fun onTouchEvent(event:MotionEvent):Boolean {
        detector.onTouchEvent(event)
        if(event.actionMasked==MotionEvent.ACTION_DOWN){lastX=event.x;lastY=event.y}
        if(event.actionMasked==MotionEvent.ACTION_MOVE&&!detector.isInProgress){x+=event.x-lastX;y+=event.y-lastY;invalidate()}
        lastX=event.x;lastY=event.y
        if(event.actionMasked==MotionEvent.ACTION_UP)performClick()
        return true
    }
    override fun performClick():Boolean {super.performClick();return true}
}
