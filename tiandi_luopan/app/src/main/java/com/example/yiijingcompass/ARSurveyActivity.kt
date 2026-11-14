package com.example.yiijingcompass

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.PointF
import android.graphics.RectF
import android.opengl.*
import android.os.Bundle
import android.view.*
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.CompassMotionManager
import com.example.yiijingcompass.ui.CameraLease
import com.example.yiijingcompass.ui.CaptureReviewView
import com.example.yiijingcompass.ui.ARCaptureSupport
import com.example.yiijingcompass.ui.NativeSharing
import androidx.appcompat.app.AlertDialog
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.*
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.*

/** AR Optional capture. Coordinates originate only from tracked plane/depth hits.
 * Android does not supply RoomPlan's room/furniture classification. */
class ARSurveyActivity: AppCompatActivity(), GLSurfaceView.Renderer {
    private var session: Session?=null
    private val cameraLease=UUID.randomUUID().toString()
    private var resumed=false
    private lateinit var gl: GLSurfaceView
    private lateinit var status: TextView
    private lateinit var overlay: SurveyOverlay
    private var background: CameraBackground?=null
    private enum class Tool {CORNERS,RULER,CEILING,ALIGN}
    private var tool=Tool.CORNERS
    private val rooms=mutableListOf<CapturedRoom>()
    private val rulerPoints=mutableListOf<Vec3f>()
    private var measuredHeight:Float?=null
    private var showPlanes=true
    private var showGround=false
    private var restoringMap:SpatialMapArchive?=null
    private val alignmentPoints=mutableListOf<Vec3f>()
    private var initialRevision=0L
    private var capturePurpose:String?=null
    private val captureFrames=mutableListOf<ARCapturedFrame>()
    private var lastCaptureNanos=0L
    private var captureGeneration=0
    private val points=mutableListOf<FloatArray>()
    private var pendingTap: Pair<Float,Float>?=null
    private var displayWidth=1;private var displayHeight=1
    private var coordinateHeading: Double?=null
    private val propertyID=ShaSurveyStore.instance.propertyID
    private var lastFrame=0L
    private var depthAvailable=false
    private var installRequested=false
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()) {granted->if(granted)resumeSession() else fail("native_camera_required")}
    private val lang get()=LocalizationManager.instance
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialRevision=FloorplanWorkspaceStore.get(this).snapshot.revision
        val root=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
        val area=FrameLayout(this)
        gl=GLSurfaceView(this).apply {setEGLContextClientVersion(2);preserveEGLContextOnPause=true;setRenderer(this@ARSurveyActivity)}
        overlay=SurveyOverlay(this)
        area.addView(gl);area.addView(overlay)
        root.addView(area,LinearLayout.LayoutParams(-1,0,1f))
        status=TextView(this).apply {setPadding(16,12,16,12);text=lang.t("native_ar_instruction")};root.addView(status)
        val controls=LinearLayout(this)
        fun button(key: String,action:()->Unit){controls.addView(Button(this).apply {text=lang.t(key);isAllCaps=false;setOnClickListener {action()}},LinearLayout.LayoutParams(0,-2,1f))}
        button("native_ar_add_corner") {gl.queueEvent {pendingTap=displayWidth/2f to displayHeight/2f}}
        button("native_undo") {gl.queueEvent {if(points.isNotEmpty())points.removeAt(points.lastIndex)}}
        button("native_save") {gl.queueEvent {val snapshot=points.map {it.copyOf()};runOnUiThread {saveRoom(snapshot)}}}
        root.addView(controls)
        val extra=LinearLayout(this)
        extra.addView(Button(this).apply {text=lang.t("native_ar_finish_room");setOnClickListener {finishRoom()}})
        extra.addView(Button(this).apply {text=lang.t("native_ar_tools");setOnClickListener {tools()}})
        root.addView(extra);setContentView(root)
        gl.setOnTouchListener {_,event->if(event.action==MotionEvent.ACTION_UP){val x=event.x;val y=event.y;gl.queueEvent {pendingTap=x to y};true}else true}
    }
    override fun onResume(){super.onResume();resumed=true;CompassMotionManager.instance.start(this);resumeSession()}
    private fun resumeSession() {
        if(ContextCompat.checkSelfPermission(this,Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED){permission.launch(Manifest.permission.CAMERA);return}
        if(!CameraLease.acquire(cameraLease)){fail("ar_camera_busy");return}
        try {
            if(session==null){
                val availability=ArCoreApk.getInstance().checkAvailability(this)
                if(availability.isTransient){CameraLease.release(cameraLease);status.postDelayed({if(!isFinishing)resumeSession()},500);return}
                if(!availability.isSupported){CameraLease.release(cameraLease);fail("native_ar_unavailable");return}
                if(ArCoreApk.getInstance().requestInstall(this,!installRequested)==ArCoreApk.InstallStatus.INSTALL_REQUESTED){installRequested=true;CameraLease.release(cameraLease);return}
                session=Session(this)
                val configuration=Config(session)
                depthAvailable=session!!.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                configuration.depthMode=if(depthAvailable)Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
                configuration.planeFindingMode=Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                session!!.configure(configuration)
            }
            session?.resume();gl.onResume()
        } catch(e:Exception){CameraLease.release(cameraLease);fail("native_ar_unavailable")}
    }
    override fun onPause(){resumed=false;captureGeneration++;gl.queueEvent {captureFrames.forEach {it.close()};captureFrames.clear();capturePurpose=null};gl.onPause();session?.pause();CameraLease.release(cameraLease);CompassMotionManager.instance.stop();super.onPause()}
    override fun onWindowFocusChanged(hasFocus:Boolean){super.onWindowFocusChanged(hasFocus);if(hasFocus&&resumed&&!CameraLease.owns(cameraLease))resumeSession()}
    override fun onDestroy(){CameraLease.release(cameraLease);session?.close();session=null;super.onDestroy()}
    private fun fail(key:String){status.text=lang.t(key);Toast.makeText(this,lang.t(key),Toast.LENGTH_LONG).show()}
    override fun onSurfaceCreated(unused:GL10?,config:EGLConfig?){background=CameraBackground()}
    override fun onSurfaceChanged(unused:GL10?,width:Int,height:Int){displayWidth=width;displayHeight=height;GLES20.glViewport(0,0,width,height)}
    override fun onDrawFrame(unused:GL10?){
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val session=this.session ?: return
        try {
            session.setDisplayGeometry(windowManager.defaultDisplay.rotation,displayWidth,displayHeight)
            background?.let {session.setCameraTextureName(it.texture)}
            val frame=session.update();background?.draw(frame)
            val camera=frame.camera
            if(camera.trackingState!=TrackingState.TRACKING){runOnUiThread {status.text=lang.t("ar_spatial_tracking_limited")};return}
            if(coordinateHeading==null && CompassMotionManager.instance.hasDeclination&&CompassMotionManager.instance.physicalCameraHeading()!=null){
                val z=camera.pose.zAxis
                coordinateHeading=SurveyCoordinateReference.heading(CompassMotionManager.instance.physicalCameraHeading(),Vec3f(-z[0],-z[1],-z[2]))
            }
            pendingTap?.let {(x,y)->
                val hit=frame.hitTest(x,y).firstOrNull {hit->
                    when(val trackable=hit.trackable){is Plane->trackable.isPoseInPolygon(hit.hitPose)&&(tool==Tool.RULER||tool==Tool.CEILING||trackable.type==Plane.Type.HORIZONTAL_UPWARD_FACING)
                        is DepthPoint->depthAvailable;else->false}
                }
                if(hit!=null){val p=hit.hitPose.translation
                    acceptPoint(Vec3f(p[0],p[1],p[2]))
                }else runOnUiThread {status.text=lang.t("native_ar_no_hit")}
                pendingTap=null
            }
            val view=FloatArray(16);val projection=FloatArray(16);val vp=FloatArray(16)
            camera.getViewMatrix(view,0);camera.getProjectionMatrix(projection,0,.1f,100f);Matrix.multiplyMM(vp,0,projection,0,view,0)
            fun project(p:Vec3f):PointF? {val clip=FloatArray(4);Matrix.multiplyMV(clip,0,vp,0,floatArrayOf(p.x,p.y,p.z,1f),0)
                return if(clip[3]<=0)null else PointF((clip[0]/clip[3]+1)*displayWidth/2,(1-clip[1]/clip[3])*displayHeight/2)}
            val screen=points.mapNotNull {project(Vec3f(it[0],it[1],it[2]))}
            val lines=mutableListOf<Pair<PointF,PointF>>()
            fun line(a:Vec3f,b:Vec3f){val aa=project(a);val bb=project(b);if(aa!=null&&bb!=null)lines.add(aa to bb)}
            rooms.forEach {room->room.points.indices.forEach {i->line(room.points[i],room.points[(i+1)%room.points.size])}}
            if(rulerPoints.size==2)line(rulerPoints[0],rulerPoints[1])
            if(showPlanes)session.getAllTrackables(Plane::class.java).filter {it.trackingState==TrackingState.TRACKING&&it.subsumedBy==null}.forEach {plane->
                val polygon=plane.polygon;val vertices=mutableListOf<Vec3f>()
                for(i in 0 until polygon.limit()/2){val a=plane.centerPose.transformPoint(floatArrayOf(polygon.get(i*2),0f,polygon.get(i*2+1)));vertices.add(Vec3f(a[0],a[1],a[2]))}
                vertices.indices.forEach {i->line(vertices[i],vertices[(i+1)%vertices.size])}
            }
            var standing=""
            if(showGround&&coordinateHeading!=null){
                val floor=rooms.firstOrNull()?.points ?: points.map {Vec3f(it[0],it[1],it[2])}
                if(floor.isNotEmpty()){
                    val origin=Vec3f(floor.map {it.x}.average().toFloat(),floor.map {it.y}.average().toFloat(),floor.map {it.z}.average().toFloat())
                    for(i in 0..7){val angle=(i*45-coordinateHeading!!)*PI/180;line(origin,origin+Vec3f((sin(angle)*2.5).toFloat(),0f,(-cos(angle)*2.5).toFloat()))}
                    val pos=camera.pose.translation;val bearing=(atan2((pos[0]-origin.x).toDouble(),-(pos[2]-origin.z).toDouble())*180/PI+coordinateHeading!!+720)%360
                    standing=Mountain24Data.find(bearing).localizedPalace
                }
            }
            capturePurpose?.let {purpose->
                if(coordinateHeading==null){capturePurpose=null;runOnUiThread {fail("native_ar_heading_required")}}
                else if(frame.timestamp-lastCaptureNanos>150_000_000L){
                    lastCaptureNanos=frame.timestamp
                    val count=session.getAllTrackables(Plane::class.java).count {it.type==Plane.Type.VERTICAL&&it.trackingState==TrackingState.TRACKING}
                    ARCaptureSupport.capture(frame,coordinateHeading!!,displayWidth,displayHeight,propertyID,depthAvailable,count)?.let {sample->
                        if(captureFrames.firstOrNull()?.pose?.isCompatible(sample.pose)==false){sample.close();captureFrames.forEach {it.close()};captureFrames.clear();capturePurpose=null;runOnUiThread {fail("native_candidate_moved")}}
                        else {captureFrames.add(sample);if(captureFrames.size>=if(purpose=="ai")3 else 1){val samples=captureFrames.toList();captureFrames.clear();capturePurpose=null;consumeFrames(purpose,samples,captureGeneration)}}
                    }
                }
            }
            val count=points.size;val planeCount=session.getAllTrackables(Plane::class.java).count {it.trackingState==TrackingState.TRACKING}
            if(System.currentTimeMillis()-lastFrame>250){lastFrame=System.currentTimeMillis();runOnUiThread {
                overlay.points=screen;overlay.lines=lines;overlay.invalidate()
                status.text=lang.t(if(depthAvailable)"native_ar_depth" else "native_ar_plane")+" · $planeCount · $count · ${rooms.size} · $standing\n"+lang.t("native_ar_instruction")
            }}
        }catch(e:CameraNotAvailableException){runOnUiThread {fail("native_camera_required")}}catch(_:SessionPausedException){}
    }
    private fun acceptPoint(point:Vec3f){
        when(tool){
            Tool.CORNERS->if(points.isEmpty()||(Vec3f(points.last()[0],points.last()[1],points.last()[2])-point).length()>.05f)points.add(floatArrayOf(point.x,point.y,point.z))
            Tool.RULER->{if(rulerPoints.size==2)rulerPoints.clear();rulerPoints.add(point);if(rulerPoints.size==2){val distance=(rulerPoints[1]-rulerPoints[0]).length();runOnUiThread {AlertDialog.Builder(this).setTitle(lang.t("native_ar_ruler")).setMessage(LubanRulerEvaluation.evaluate(distance).localizedSummary(lang.effectiveLanguage)).setPositiveButton(lang.t("done"),null).show()}}}
            Tool.CEILING->{val floor=(rooms.flatMap {it.points}.map {it.y}+points.map {it[1]}).minOrNull();val height=floor?.let {abs(point.y-it)}
                if(height!=null&&height in .5f..10f){measuredHeight=height;runOnUiThread {Toast.makeText(this,lang.t("native_ceiling_height")+" · $height m",Toast.LENGTH_LONG).show()}}
                else runOnUiThread {fail("native_ar_need_corners")}}
            Tool.ALIGN->{alignmentPoints.add(point);if(alignmentPoints.size==3){
                val archive=restoringMap ?: return;val registration=SpatialMapRegistration.fit(archive.landmarks,alignmentPoints)
                if(registration==null){alignmentPoints.clear();runOnUiThread {fail("native_map_alignment_failed")}}
                else {rooms.clear();rooms.addAll(archive.rooms.map {it.copy(points=it.points.map(registration::point))});rulerPoints.clear();rulerPoints.addAll(archive.rulerPoints.map(registration::point));coordinateHeading=registration.heading(archive.coordinateHeading);points.clear();restoringMap=null;tool=Tool.CORNERS
                    runOnUiThread {Toast.makeText(this,lang.t("native_saved"),Toast.LENGTH_LONG).show()}}
            }else runOnUiThread {Toast.makeText(this,"${alignmentPoints.size}/3",Toast.LENGTH_SHORT).show()}}
        }
    }
    private fun finishRoom(){gl.queueEvent {
        if(points.size<3){runOnUiThread {fail("native_ar_need_corners")};return@queueEvent}
        val snapshot=points.map {Vec3f(it[0],it[1],it[2])}
        runOnUiThread {AlertDialog.Builder(this).setItems(FloorplanRoomType.values().filter {it!=FloorplanRoomType.MISSING_CORNER&&it!=FloorplanRoomType.DOOR}.map {it.localizedName}.toTypedArray()){_,index->
            val type=FloorplanRoomType.values().filter {it!=FloorplanRoomType.MISSING_CORNER&&it!=FloorplanRoomType.DOOR}[index]
            gl.queueEvent {rooms.add(CapturedRoom(name=type.localizedName,type=type,points=snapshot,height=measuredHeight ?: 2.8f));points.clear()}
        }.show()}
    }}
    private fun tools(){
        val keys=listOf("native_ar_corner_mode","native_ar_ruler","native_ceiling_height","native_ar_planes","native_ar_ground","native_scan_candidate","native_manual_mark","native_ar_snapshot","native_map_save","native_map_load","native_auto_planes","native_reset")
        AlertDialog.Builder(this).setItems(keys.map(lang::t).toTypedArray()){_,index->when(index){
            0->gl.queueEvent {tool=Tool.CORNERS};1->gl.queueEvent {tool=Tool.RULER};2->gl.queueEvent {tool=Tool.CEILING}
            3->gl.queueEvent {showPlanes=!showPlanes};4->gl.queueEvent {showGround=!showGround}
            5,6,7->gl.queueEvent {captureFrames.forEach {it.close()};captureFrames.clear();capturePurpose=when(index){5->"ai";6->"manual";else->"photo"}}
            8->gl.queueEvent {saveMap()};9->loadMap()
            10->gl.queueEvent {extractPlaneRooms()}
            11->AlertDialog.Builder(this).setMessage(lang.t("native_replace_workspace")).setPositiveButton(lang.t("done")){_,_->gl.queueEvent {rooms.clear();points.clear();rulerPoints.clear();measuredHeight=null;coordinateHeading=null}}.setNegativeButton(lang.t("cancel"),null).show()
        }}.show()
    }
    private fun extractPlaneRooms(){
        val candidates=session?.getAllTrackables(Plane::class.java)?.filter {it.type==Plane.Type.HORIZONTAL_UPWARD_FACING&&it.trackingState==TrackingState.TRACKING&&it.subsumedBy==null&&it.extentX*it.extentZ>=1.0f}?.sortedByDescending {it.extentX*it.extentZ}?.take(30)?.mapNotNull {plane->
            val vertices=mutableListOf<Vec3f>();val buffer=plane.polygon
            for(i in 0 until buffer.limit()/2){val p=plane.centerPose.transformPoint(floatArrayOf(buffer.get(i*2),0f,buffer.get(i*2+1)));vertices.add(Vec3f(p[0],p[1],p[2]))}
            vertices.takeIf {it.size>=3}?.let {CapturedRoom(name=lang.t("native_measured_room"),type=FloorplanRoomType.UNKNOWN,points=it,height=measuredHeight ?: 2.8f)}
        } ?: emptyList()
        runOnUiThread {
            if(candidates.isEmpty()){fail("native_no_candidate");return@runOnUiThread}
            val checked=BooleanArray(candidates.size)
            AlertDialog.Builder(this).setTitle(lang.t("native_confirm_candidate")).setMessage(lang.t("native_plane_candidate_note"))
                .setMultiChoiceItems(candidates.mapIndexed {index,room->"${index+1} · ${GeometryUtils.polygonArea(room.points.map {PointF(it.x,it.z)})} m²"}.toTypedArray(),checked){_,i,v->checked[i]=v}
                .setPositiveButton(lang.t("native_save")){_,_->gl.queueEvent {rooms.addAll(candidates.filterIndexed {i,_->checked[i]})}}.setNegativeButton(lang.t("cancel"),null).show()
        }
    }
    private fun saveMap(){
        val all=rooms.toList()+if(points.size>=3)listOf(CapturedRoom(name=lang.t("native_measured_room"),type=FloorplanRoomType.LIVING_ROOM,points=points.map {Vec3f(it[0],it[1],it[2])},height=measuredHeight ?: 2.8f)) else emptyList()
        val references=all.firstOrNull()?.points?.take(3)
        if(coordinateHeading==null||references?.size!=3){runOnUiThread {fail("native_ar_need_corners")};return}
        val result=runCatching {SpatialMapStore.save(this,SpatialMapArchive(propertyKey=ShaSurveyStore.instance.propertyKey,coordinateHeading=coordinateHeading!!,landmarks=references,rooms=all,rulerPoints=rulerPoints.toList()))}
        runOnUiThread {result.onSuccess {file->NativeSharing.shareText(this,"spatial-map.json",file.readText(),"application/json")}.onFailure {fail("native_export_failed")}}
    }
    private fun loadMap(){
        val files=SpatialMapStore.files(this);AlertDialog.Builder(this).setItems(files.map {Date(it.lastModified()).toString()}.toTypedArray()){_,index->
            val archive=SpatialMapStore.read(files[index])
            if(archive==null||archive.propertyKey!=ShaSurveyStore.instance.propertyKey){fail("native_workspace_conflict");return@setItems}
            AlertDialog.Builder(this).setMessage(lang.t("native_map_alignment_note")).setPositiveButton(lang.t("done")){_,_->gl.queueEvent {restoringMap=archive;alignmentPoints.clear();tool=Tool.ALIGN}}.setNegativeButton(lang.t("cancel"),null).show()
        }.show()
    }
    private fun consumeFrames(purpose:String,frames:List<ARCapturedFrame>,generation:Int){
        Thread {
            if(purpose=="ai"){
                val results=frames.map {sample->var result:ShaAnalysisResult?=null;OnDeviceShaAnalyzer.instance.analyze(sample.bitmap,sample.evidence){result=it};result}
                val valid=results.all {it!=null}&&results.filterNotNull().all {OnDeviceShaAnalyzer.instance.isConsistent(results.first()!!,it)}
                if(!valid){frames.forEach {it.close()};runOnUiThread {if(generation==captureGeneration)fail("native_no_candidate")};return@Thread}
                val first=results.first()!!;val point=PointF(results.filterNotNull().map {it.targetX}.average().toFloat(),results.filterNotNull().map {it.targetY}.average().toFloat())
                val sample=frames.first();frames.drop(1).forEach {it.close()}
                runOnUiThread {if(generation==captureGeneration)reviewSample(sample,first.shaID,point,results.filterNotNull().minOf {it.confidence},ShaRecordSource.AI) else sample.close()}
            }else runOnUiThread {
                val sample=frames.first()
                if(generation!=captureGeneration){sample.close();return@runOnUiThread}
                if(purpose=="photo"){
                    runCatching {NativeSharing.openProof(this,sample.bitmap,"${sample.capturedAt}\n${sample.pose.heading}° · "+lang.t("native_candidate_note"))}.onFailure {fail("native_export_failed")};sample.close()
                }else {
                    val items=ExteriorShaEngine.instance.database
                    AlertDialog.Builder(this).setItems(items.map {it.localizedName}.toTypedArray()){_,index->reviewSample(sample,items[index].id,PointF(.5f,.5f),null,ShaRecordSource.MANUAL)}.setOnCancelListener {sample.close()}.show()
                }
            }
        }.start()
    }
    private fun reviewSample(sample:ARCapturedFrame,shaID:String,point:PointF,confidence:Double?,source:ShaRecordSource){
        val item=ExteriorShaEngine.instance.database.firstOrNull {it.id==shaID}
        val review=CaptureReviewView(this,sample.bitmap,point)
        val body=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
        val detail=TextView(this);body.addView(detail);body.addView(review,LinearLayout.LayoutParams(-1,(resources.displayMetrics.heightPixels*.45f).toInt()))
        fun update(p:PointF){val record=sample.exteriorRecord(shaID,p,confidence,source)
            detail.text=lang.t("native_target_drag")+"\n${record.bearingDegrees.toInt()}° · "+(record.distanceMeters?.let {"$it m"} ?: lang.t("native_distance_unavailable"))}
        update(point);review.onMoved=::update
        AlertDialog.Builder(this).setTitle(item?.localizedName ?: shaID).setView(body).setPositiveButton(lang.t("native_save")){_,_->
            confirmRecord(sample.exteriorRecord(shaID,review.target,confidence,source,lang.t("native_candidate_note")))
        }.setNegativeButton(lang.t("cancel"),null).setOnDismissListener {sample.close()}.show()
    }
    private fun confirmRecord(record:ExteriorShaRecord){
        val item=ExteriorShaEngine.instance.database.firstOrNull {it.id==record.shaID} ?: return
        AlertDialog.Builder(this).setTitle(item.localizedName).setMessage(lang.t("native_candidate_note")+"\n${record.bearingDegrees}° · "+(record.distanceMeters?.let {"$it m"} ?: lang.t("native_distance_unavailable")))
            .setPositiveButton(lang.t("native_save")){_,_->if(ShaSurveyStore.instance.isCurrentProperty(propertyID)){ShaSurveyStore.instance.addRecord(record);Toast.makeText(this,lang.t("native_saved"),Toast.LENGTH_LONG).show()}else fail("native_workspace_conflict")}.setNegativeButton(lang.t("cancel"),null).show()
    }
    private fun saveRoom(points:List<FloatArray>){
        if(coordinateHeading==null){
            val field=EditText(this).apply {inputType=android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL}
            AlertDialog.Builder(this).setTitle(lang.t("floorplan_manual_heading")).setMessage(lang.t("native_ar_heading_required")).setView(field)
                .setPositiveButton(lang.t("native_save")){_,_->field.text.toString().toDoubleOrNull()?.takeIf {it.isFinite()}?.let {coordinateHeading=(it%360+360)%360;saveRoom(points)}}.setNegativeButton(lang.t("cancel"),null).show();return
        }
        val captured=rooms.toList()+if(points.size>=3)listOf(CapturedRoom(name=lang.t("native_measured_room"),type=FloorplanRoomType.LIVING_ROOM,points=points.map {Vec3f(it[0],it[1],it[2])},height=measuredHeight ?: 2.8f)) else emptyList()
        if(captured.isEmpty()){fail("native_ar_need_corners");return}
        val property=ShaSurveyStore.instance
        if(!property.isCurrentProperty(propertyID)){fail("native_workspace_conflict");return}
        val all=captured.flatMap {it.points};val x0=all.minOf {it.x};val x1=all.maxOf {it.x};val z0=all.minOf {it.z};val z1=all.maxOf {it.z}
        val w=x1-x0;val d=z1-z0;if(w<=.1f||d<=.1f){fail("native_invalid_dimensions");return}
        val walls=captured.flatMap {room->room.points.indices.map {i->val a=room.points[i];val b=room.points[(i+1)%room.points.size];SpatialWall3D(start=Vec3f(a.x,0f,a.z),end=Vec3f(b.x,0f,b.z),height=room.height)}}
        val spatial=captured.map {room->val xx=room.points.map {it.x};val zz=room.points.map {it.z};val polygon=room.points.map {PointF(it.x,it.z)}
            SpatialRoom3D(room.id,room.name,room.type,center=Vec3f((xx.min()+xx.max())/2,room.height/2,(zz.min()+zz.max())/2),size=Vec3f(xx.max()-xx.min(),room.height,zz.max()-zz.min()),areaSqMeters=GeometryUtils.polygonArea(polygon))}
        val source=lang.t(if(measuredHeight!=null)"native_ar_full_measured_source" else "native_ar_measured_source")
        val model=HouseSpatialSurveyEngine.analyzeSpatialHouse(source,walls,emptyList(),emptyList(),spatial,emptyList(),coordinateHeading!!)
        val mapping=FloorplanSurveyMapping(model.id,x0.toDouble(),z0.toDouble(),w.toDouble(),d.toDouble(),0.0)
        val plans=captured.map {room->val polygon=room.points.map {mapping.point(it.x,it.z,model.id)!!};FloorplanRoom(room.id,room.name,room.type,GeometryUtils.polygonBounds(polygon)!!,polygon)}
        val plan=SavedFloorplanLayout(plans,centroidX=((model.centroidX-x0)/w).toDouble(),centroidY=((model.centroidZ-z0)/d).toDouble(),compassRotation=coordinateHeading!!,aspectRatio=w/d,widthMeters=w.toDouble(),depthMeters=d.toDouble(),surveyMapping=mapping)
        val workspace=FloorplanWorkspaceStore.get(this)
        if(!workspace.save(plan,null,UUID.randomUUID().toString(),initialRevision,propertyID)){fail("native_workspace_conflict");return}
        property.saveSurvey(model,SpatialSurveyArchiveKeys.MEASURED,propertyID)
        Toast.makeText(this,lang.t("native_saved"),Toast.LENGTH_LONG).show();finish()
    }

}

private class SurveyOverlay(context:android.content.Context):View(context){
    var points:List<PointF> = emptyList();var lines:List<Pair<PointF,PointF>> = emptyList();private val paint=android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(canvas:android.graphics.Canvas){paint.color=android.graphics.Color.YELLOW;paint.strokeWidth=4f
        canvas.drawLine(width/2f-15,height/2f,width/2f+15,height/2f,paint);canvas.drawLine(width/2f,height/2f-15,width/2f,height/2f+15,paint)
        lines.forEach {canvas.drawLine(it.first.x,it.first.y,it.second.x,it.second.y,paint)}
        points.forEachIndexed {i,p->canvas.drawCircle(p.x,p.y,8f,paint);if(i>0)canvas.drawLine(points[i-1].x,points[i-1].y,p.x,p.y,paint)}
    }
}

private class CameraBackground {
    val texture:Int
    private val program:Int
    private val vertices:FloatBuffer=buffer(floatArrayOf(-1f,-1f,1f,-1f,-1f,1f,1f,1f))
    private val uv:FloatBuffer=buffer(FloatArray(8))
    init {
        val names=IntArray(1);GLES20.glGenTextures(1,names,0);texture=names[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,texture)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,GLES20.GL_TEXTURE_MIN_FILTER,GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,GLES20.GL_TEXTURE_MAG_FILTER,GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,GLES20.GL_TEXTURE_WRAP_S,GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,GLES20.GL_TEXTURE_WRAP_T,GLES20.GL_CLAMP_TO_EDGE)
        fun shader(type:Int,source:String):Int {val id=GLES20.glCreateShader(type);GLES20.glShaderSource(id,source);GLES20.glCompileShader(id);return id}
        program=GLES20.glCreateProgram()
        GLES20.glAttachShader(program,shader(GLES20.GL_VERTEX_SHADER,"attribute vec2 p;attribute vec2 t;varying vec2 uv;void main(){gl_Position=vec4(p,0.,1.);uv=t;}"))
        GLES20.glAttachShader(program,shader(GLES20.GL_FRAGMENT_SHADER,"#extension GL_OES_EGL_image_external : require\nprecision mediump float;uniform samplerExternalOES camera;varying vec2 uv;void main(){gl_FragColor=texture2D(camera,uv);}"))
        GLES20.glLinkProgram(program)
    }
    fun draw(frame:Frame){
        frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,vertices,Coordinates2d.TEXTURE_NORMALIZED,uv)
        vertices.position(0);uv.position(0)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST);GLES20.glUseProgram(program);GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,texture);GLES20.glUniform1i(GLES20.glGetUniformLocation(program,"camera"),0)
        val position=GLES20.glGetAttribLocation(program,"p");val coordinate=GLES20.glGetAttribLocation(program,"t")
        GLES20.glEnableVertexAttribArray(position);GLES20.glVertexAttribPointer(position,2,GLES20.GL_FLOAT,false,0,vertices)
        GLES20.glEnableVertexAttribArray(coordinate);GLES20.glVertexAttribPointer(coordinate,2,GLES20.GL_FLOAT,false,0,uv)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP,0,4);GLES20.glDisableVertexAttribArray(position);GLES20.glDisableVertexAttribArray(coordinate)
    }
    companion object {fun buffer(values:FloatArray):FloatBuffer=ByteBuffer.allocateDirect(values.size*4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply {put(values);position(0)}}
}
