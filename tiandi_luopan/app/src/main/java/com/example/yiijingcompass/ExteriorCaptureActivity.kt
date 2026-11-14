package com.example.yiijingcompass

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.graphics.Matrix
import android.graphics.RectF
import android.util.Size
import android.os.Looper
import android.hardware.camera2.*
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import android.view.TextureView
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.ui.CameraLease
import com.example.yiijingcompass.sensor.CompassMotionManager
import kotlin.math.*

class ExteriorCaptureActivity: AppCompatActivity(),TextureView.SurfaceTextureListener {
    private val cameraLease=java.util.UUID.randomUUID().toString()
    private var resumed=false
    private var opening=false
    private lateinit var preview:TextureView
    private lateinit var status:TextView
    private var camera:CameraDevice?=null
    private var capture:CameraCaptureSession?=null
    private var worker:HandlerThread?=null
    private var cameraHandler:Handler?=null
    private var fov=60.0
    private var sensorWidth=1f;private var sensorHeight=1f;private var focalLength=1f
    private var bufferSize=Size(1280,720)
    private var sensorOrientation=90
    private var scanning=false
    private val main=Handler(Looper.getMainLooper())
    private val propertyID=ShaSurveyStore.instance.propertyID
    private val lang get()=LocalizationManager.instance
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()) {if(it)openCamera() else finish()}
    override fun onCreate(savedInstanceState:Bundle?){
        super.onCreate(savedInstanceState)
        val root=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
        preview=TextureView(this).apply {surfaceTextureListener=this@ExteriorCaptureActivity};root.addView(preview,LinearLayout.LayoutParams(-1,0,1f))
        status=TextView(this).apply {text=lang.t("native_candidate_note");setPadding(16,12,16,12)};root.addView(status)
        root.addView(Button(this).apply {text=lang.t("native_scan_candidate");setOnClickListener {scan()}})
        root.addView(Button(this).apply {text=lang.t("native_manual_mark");setOnClickListener {manual()}})
        root.addView(Button(this).apply {text=lang.t("native_ar_snapshot");setOnClickListener {preview.bitmap?.let {image->runCatching {com.example.yiijingcompass.ui.NativeSharing.openProof(this@ExteriorCaptureActivity,image,"${java.util.Date()}\n${CompassMotionManager.instance.physicalCameraHeading() ?: 0.0}° · "+lang.t("native_candidate_note"))};image.recycle()}}})
        setContentView(root)
    }
    override fun onResume(){super.onResume();resumed=true;CompassMotionManager.instance.start(this);worker=HandlerThread("exterior-camera").apply {start()};cameraHandler=Handler(worker!!.looper);if(preview.isAvailable)openCamera()}
    override fun onPause(){resumed=false;opening=false;scanning=false;main.removeCallbacksAndMessages(null);capture?.close();capture=null;camera?.close();camera=null;CameraLease.release(cameraLease);worker?.quitSafely();worker=null;cameraHandler=null;CompassMotionManager.instance.stop();super.onPause()}
    override fun onSurfaceTextureAvailable(surface:SurfaceTexture,width:Int,height:Int){openCamera()}
    override fun onSurfaceTextureSizeChanged(surface:SurfaceTexture,width:Int,height:Int){configurePreview()}
    override fun onSurfaceTextureDestroyed(surface:SurfaceTexture):Boolean=true
    override fun onSurfaceTextureUpdated(surface:SurfaceTexture){}
    override fun onWindowFocusChanged(hasFocus:Boolean){super.onWindowFocusChanged(hasFocus);if(hasFocus&&resumed&&preview.isAvailable)openCamera()}
    private fun openCamera(){
        if(camera!=null||opening||!resumed)return
        if(ContextCompat.checkSelfPermission(this,Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED){permission.launch(Manifest.permission.CAMERA);return}
        if(!CameraLease.acquire(cameraLease)){status.text=lang.t("ar_camera_busy");return}
        val manager=getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id=manager.cameraIdList.firstOrNull {manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING)==CameraCharacteristics.LENS_FACING_BACK} ?: return
        val characteristics=manager.getCameraCharacteristics(id)
        val sensor=characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        val focal=characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull()
        if(sensor!=null&&focal!=null){sensorWidth=sensor.width;sensorHeight=sensor.height;focalLength=focal}
        sensorOrientation=characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        val sizes=characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?.getOutputSizes(SurfaceTexture::class.java)?.toList() ?: emptyList()
        bufferSize=sizes.filter {it.width<=1920&&it.height<=1080}.minByOrNull {abs(it.width.toFloat()/it.height-16f/9)} ?: sizes.firstOrNull() ?: return
        configurePreview()
        opening=true
        try{manager.openCamera(id,object:CameraDevice.StateCallback(){
            override fun onOpened(device:CameraDevice){
                opening=false;if(isFinishing||cameraHandler==null||!CameraLease.owns(cameraLease)){device.close();return};camera=device
                val texture=preview.surfaceTexture ?: return;texture.setDefaultBufferSize(bufferSize.width,bufferSize.height);val surface=Surface(texture)
                device.createCaptureSession(listOf(surface),object:CameraCaptureSession.StateCallback(){
                    override fun onConfigured(session:CameraCaptureSession){capture=session;val request=device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {addTarget(surface);set(CaptureRequest.CONTROL_AF_MODE,CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)}
                        session.setRepeatingRequest(request.build(),null,cameraHandler)}
                    override fun onConfigureFailed(session:CameraCaptureSession){session.close()}
                },cameraHandler)
            }
            override fun onDisconnected(device:CameraDevice){opening=false;device.close();camera=null;CameraLease.release(cameraLease)}
            override fun onError(device:CameraDevice,error:Int){opening=false;device.close();camera=null;CameraLease.release(cameraLease)}
        },cameraHandler)}catch(_:Exception){opening=false;CameraLease.release(cameraLease);status.text=lang.t("native_camera_required")}
    }
    private fun configurePreview(){
        if(preview.width==0||preview.height==0)return
        val displayRotation=when(windowManager.defaultDisplay.rotation){Surface.ROTATION_90->90;Surface.ROTATION_180->180;Surface.ROTATION_270->270;else->0}
        val rotation=(sensorOrientation-displayRotation+360)%360
        val swapped=rotation==90||rotation==270
        val bw=if(swapped)bufferSize.height.toFloat() else bufferSize.width.toFloat()
        val bh=if(swapped)bufferSize.width.toFloat() else bufferSize.height.toFloat()
        val view=RectF(0f,0f,preview.width.toFloat(),preview.height.toFloat())
        val buffer=RectF(0f,0f,bw,bh).apply {offset(view.centerX()-centerX(),view.centerY()-centerY())}
        val matrix=Matrix().apply {
            setRectToRect(view,buffer,Matrix.ScaleToFit.FILL)
            val scale=max(view.width()/bw,view.height()/bh)
            postScale(scale,scale,view.centerX(),view.centerY())
            postRotate(-displayRotation.toFloat(),view.centerX(),view.centerY())
        };preview.setTransform(matrix)
        val nativeAspect=bufferSize.width.toDouble()/bufferSize.height
        val cropWidth=min(sensorWidth.toDouble(),sensorHeight*nativeAspect)
        val cropHeight=cropWidth/nativeAspect
        val visibleWidth=if(swapped)cropHeight else cropWidth
        val visibleHeight=if(swapped)cropWidth else cropHeight
        val displayedAspect=preview.width.toDouble()/preview.height
        fov=2*atan(min(visibleWidth,visibleHeight*displayedAspect)/(2*focalLength))*180/PI
    }
    private fun physicalPose():ARCapturePose {
        val motion=CompassMotionManager.instance
        return ARCapturePose(motion.physicalCameraHeading() ?: motion.physicalHeading() ?: motion.trueHeading,motion.physicalCameraElevation() ?: 0.0,ARTargetProjection(fov,preview.width.toDouble()/preview.height.coerceAtLeast(1)),motion.physicalCameraRoll() ?: 0.0)
    }
    private fun scan(){
        if(scanning||!preview.isAvailable)return
        if(CompassMotionManager.instance.physicalCameraHeading()==null||!CompassMotionManager.instance.hasDeclination){status.text=lang.t("native_heading_unavailable");return}
        scanning=true
        val initialPose=physicalPose()
        val samples=mutableListOf<ShaAnalysisResult>()
        fun takeFrame(){
            if(!scanning||isFinishing)return
            if(!initialPose.isCompatible(physicalPose())){scanning=false;status.text=lang.t("native_candidate_moved");return}
            val bitmap=preview.getBitmap(640,max(1,640*preview.height/preview.width.coerceAtLeast(1))) ?: run {scanning=false;return}
            Thread {
                OnDeviceShaAnalyzer.instance.analyze(bitmap) {result->main.post {
                    if(!scanning||isFinishing)return@post
                    if(result==null){scanning=false;status.text=lang.t("native_no_candidate");return@post}
                    if(samples.any {it.shaID!=result.shaID||hypot(it.targetX-result.targetX,it.targetY-result.targetY)>.12}||!initialPose.isCompatible(physicalPose())){
                        scanning=false;status.text=lang.t("native_candidate_moved");return@post
                    }
                    samples.add(result)
                    if(samples.size<3){main.postDelayed({takeFrame()},150);return@post}
                    scanning=false;status.text=result.summary+"\n"+lang.t("native_candidate_note")
                    val point=android.graphics.PointF(samples.map {it.targetX}.average().toFloat(),samples.map {it.targetY}.average().toFloat())
                    val bearing=initialPose.bearing(point)
                    AlertDialog.Builder(this).setTitle(lang.t("native_confirm_candidate")).setMessage(status.text)
                        .setPositiveButton(lang.t("native_save")){_,_->save(result.shaID,bearing,ShaRecordSource.AI,samples.minOf {it.confidence})}
                        .setNegativeButton(lang.t("cancel"),null).show()
                }};bitmap.recycle()
            }.start()
        };takeFrame()
    }
    private fun manual(){
        val items=ExteriorShaEngine.instance.database
        AlertDialog.Builder(this).setItems(items.map {it.localizedName}.toTypedArray()){_,index->
            val input=EditText(this).apply {hint=lang.t("floorplan_manual_heading");inputType=8194;setText(CompassMotionManager.instance.physicalCameraHeading()?.toString() ?: "")}
            AlertDialog.Builder(this).setTitle(items[index].localizedName).setView(input).setPositiveButton(lang.t("native_save")){_,_->input.text.toString().toDoubleOrNull()?.takeIf {it.isFinite()}?.let {save(items[index].id,(it%360+360)%360,ShaRecordSource.MANUAL,null)}}.setNegativeButton(lang.t("cancel"),null).show()
        }.show()
    }
    private fun save(id:String,bearing:Double,source:ShaRecordSource,confidence:Double?){
        if(!ShaSurveyStore.instance.isCurrentProperty(propertyID)){status.text=lang.t("native_workspace_conflict");return}
        ShaSurveyStore.instance.addRecord(ExteriorShaRecord(shaID=id,bearingDegrees=bearing,capturedHeadingDegrees=CompassMotionManager.instance.physicalCameraHeading(),
            source=source,confidence=confidence,note=lang.t("native_candidate_note")))
        status.text=lang.t("native_saved")
    }
}
