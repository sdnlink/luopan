package com.example.yiijingcompass

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.*
import android.net.Uri
import android.os.Bundle
import android.view.*
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.OnBackPressedCallback
import com.android.billingclient.api.ProductDetails
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.*
import com.example.yiijingcompass.billing.GooglePlayBillingManager
import com.example.yiijingcompass.ui.*
import java.io.File
import java.util.*

/** Native counterpart to the main-branch SwiftUI tabs. The legacy WebView is
 * retained as a non-exported migration fallback, never the primary interface. */
class MainActivity : AppCompatActivity(), CompassMotionListener, GooglePlayBillingManager.BillingEventListener {
    private val lang get() = LocalizationManager.instance
    private val motion = CompassMotionManager.instance
    private lateinit var root: LinearLayout
    private lateinit var content: FrameLayout
    private val tabButtons=mutableListOf<Button>()
    private val gold=Color.rgb(235,205,110)
    private fun dp(value:Int)=(value*resources.displayMetrics.density).toInt()
    private var tab = 0
    private var atRoot=true
    private var showingPaywall=false
    private var compass: NativeCompassView? = null
    private var headingLabel: TextView? = null
    private var sensorLabel: TextView? = null
    private var editor: NativeFloorplanView? = null
    private var editorHeading = 0.0
    private var editorSync=false
    private val planHistory=mutableListOf<SavedFloorplanLayout>()
    private var period = 9
    private var useTiGua: Boolean? = null
    private var selectedFlyingMountain:Int?=null
    private var analyzeHome=false
    private var dayCategory=ZeRiActivityCategory.ALL
    private var referenceDate = Date()
    private var customDate=false
    private var liveRefresh:(()->Unit)?=null
    private val clock=android.os.Handler(android.os.Looper.getMainLooper())
    private val clockTick=object:Runnable {override fun run(){
        if(!customDate&&hasWindowFocus()){referenceDate=Date();liveRefresh?.let {refresh->val y=(content.getChildAt(0) as? ScrollView)?.scrollY ?: 0;refresh();content.post {(content.getChildAt(0) as? ScrollView)?.scrollTo(0,y)}}}
        clock.postDelayed(this,30000)
    }}
    private var workspaceRevision = 0L
    private var workspaceProperty = ""
    private val writer = UUID.randomUUID().toString()
    private val workspace get() = FloorplanWorkspaceStore.get(this)
    private val cases get() = FloorplanCaseStore.get(this)
    private var frame: LinearLayout? = null
    private val requestLocation = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { if(tab in 0..2) {motion.stop();motion.start(this)} }
    private val importImage = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if(uri != null) runCatching {
            val file = File(filesDir,"plan-${UUID.randomUUID()}.jpg")
            contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use {output->val bytes=ByteArray(16384);var total=0L;while(true){val count=input.read(bytes);if(count<0)break;total+=count;require(total<=20_000_000);output.write(bytes,0,count)}} } ?: error(t("native_import_failed"))
            val bounds=BitmapFactory.Options().apply {inJustDecodeBounds=true};BitmapFactory.decodeFile(file.path,bounds)
            require(bounds.outWidth>0&&bounds.outHeight>0&&bounds.outWidth.toLong()*bounds.outHeight<=40_000_000)
            val options=BitmapFactory.Options().apply {while(bounds.outWidth/inSampleSize.coerceAtLeast(1)>2400||bounds.outHeight/inSampleSize.coerceAtLeast(1)>2400)inSampleSize=if(inSampleSize<1)2 else inSampleSize*2}
            val bitmap=BitmapFactory.decodeFile(file.path,options) ?: error(t("native_import_failed"))
            editor?.backgroundImage=bitmap; editor?.backgroundPath=file.name
            saveEditor(); render(2)
        }.onFailure { toast(it.localizedMessage ?: t("native_import_failed")) }
    }
    private val importProject = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if(uri != null) runCatching {
            val json=contentResolver.openInputStream(uri)?.bufferedReader()?.use {reader->val text=StringBuilder();val buffer=CharArray(16384);while(true){val count=reader.read(buffer);if(count<0)break;require(text.length+count<=12_000_000);text.append(buffer,0,count)};text.toString()} ?: error(t("native_import_failed"))
            val record=PortableCaseCodec.decode(json)
            require(ProjectCodec.valid(record.layout))
            val image=record.backupImageBase64?.let { bytes ->
                val file=File(filesDir,"plan-${UUID.randomUUID()}.jpg")
                val decoded=android.util.Base64.decode(bytes,android.util.Base64.DEFAULT)
                val bounds=BitmapFactory.Options().apply {inJustDecodeBounds=true};BitmapFactory.decodeByteArray(decoded,0,decoded.size,bounds)
                require(bounds.outWidth in 1..12000&&bounds.outHeight in 1..12000&&bounds.outWidth.toLong()*bounds.outHeight<=40_000_000)
                file.writeBytes(decoded); file.name
            }
            require(cases.insert(record.copy(id=UUID.randomUUID().toString(),imageFileName=image,backupImageBase64=null)))
            projects()
        }.onFailure { toast(t("native_import_failed")) }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lang.init(this); ShaSurveyStore.instance.init(this); CompassLayerManager.instance.init(this)
        UserEntitlementsManager.instance.init(this); UserKuaProfileManager.instance.init(this)
        GooglePlayBillingManager.instance.init(this)
        GooglePlayBillingManager.instance.addListener(this)
        NativeDiscovery.register(this)
        window.statusBarColor=Color.rgb(18,18,22); window.navigationBarColor=Color.rgb(18,18,22)
        root=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setBackgroundColor(Color.rgb(18,18,22)) }
        content=FrameLayout(this)
        root.addView(content,LinearLayout.LayoutParams(-1,0,1f))
        val tabs=LinearLayout(this)
        listOf("tab_compass","tab_ar","tab_floorplan","tab_analysis","tab_settings").forEachIndexed { index,key ->
            val item=Button(this).apply {text=t(key);textSize=10f;isAllCaps=false;setTextColor(Color.LTGRAY);minWidth=0;minimumWidth=0;minimumHeight=dp(58)
                background=android.graphics.drawable.GradientDrawable().apply {setColor(Color.rgb(25,26,31));cornerRadius=dp(10).toFloat()}
                val icon=listOf(android.R.drawable.ic_menu_compass,android.R.drawable.ic_menu_camera,android.R.drawable.ic_menu_mapmode,android.R.drawable.ic_menu_sort_by_size,android.R.drawable.ic_menu_preferences)[index]
                setCompoundDrawablesWithIntrinsicBounds(0,icon,0,0);compoundDrawables[1]?.setTint(Color.LTGRAY)
                setPadding(dp(2),dp(6),dp(2),dp(4));setOnClickListener {render(index)}}
            tabButtons.add(item);tabs.addView(item,LinearLayout.LayoutParams(0,-2,1f).apply {setMargins(dp(3),dp(5),dp(3),dp(5))})
        }
        root.addView(tabs); setContentView(root)
        motion.addListener(this)
        analyzeHome=savedInstanceState?.getBoolean("analyzeHome",false) ?: false
        tab=savedInstanceState?.getInt("tab") ?: AppNavigationRoute.resolve(intent)?.tab ?: 0
        savedInstanceState?.let {period=it.getInt("period",9);referenceDate=Date(it.getLong("date",System.currentTimeMillis()));customDate=it.getBoolean("customDate",false);if(it.containsKey("tiGua"))useTiGua=it.getBoolean("tiGua")}
        onBackPressedDispatcher.addCallback(this,object:OnBackPressedCallback(true){override fun handleOnBackPressed(){if(!atRoot)render(tab) else finish()}})
        if(savedInstanceState!=null)selectedFlyingMountain=motion.headingState.facingMountain.id
        render(tab)
        route(intent)
        val intro=getSharedPreferences("native_onboarding",MODE_PRIVATE)
        if(!intro.getBoolean("completed",false))onboarding(0)

    }
    override fun onSaveInstanceState(outState: Bundle) { saveEditor(); outState.putInt("tab",tab);outState.putInt("period",period);outState.putBoolean("analyzeHome",analyzeHome);outState.putLong("date",referenceDate.time);outState.putBoolean("customDate",customDate);useTiGua?.let {outState.putBoolean("tiGua",it)}; super.onSaveInstanceState(outState) }
    override fun onResume() { super.onResume();clock.removeCallbacks(clockTick);clock.postDelayed(clockTick,30000)
        if(editor!=null&&workspace.snapshot.revision!=workspaceRevision){editor=null;render(2)} else if(tab==1)render(1)
        if(tab in 0..2) motion.start(this)
    }
    override fun onPause() { clock.removeCallbacks(clockTick);saveEditor(); motion.stop(); super.onPause() }
    override fun onDestroy() { motion.removeListener(this);GooglePlayBillingManager.instance.removeListener(this); super.onDestroy() }
    override fun onNewIntent(intent:Intent){super.onNewIntent(intent);setIntent(intent);route(intent)}
    private fun route(intent:Intent){
        val route=AppNavigationRoute.resolve(intent) ?: return
        if(route.dailyGuide){CompassLayerManager.instance.showDailyGodMarkers=true;CompassLayerManager.instance.save()}
        if(tab!=route.tab)render(route.tab)
        intent.getLongExtra("date",0).takeIf {it>0}?.let {referenceDate=Date(it);customDate=true}
        when(route.feature){"dates"->dates();"qimen"->qimen();"flyingStars","xuankong"->flyingStars();"bazhai"->bazhai();"sanhe"->sanhe();"purpleWhite","purplewhite"->purpleWhite();"owner","profile"->profile();"report"->exportScroll();"paywall"->paywall()}
    }
    private fun t(key: String)=lang.t(key)
    private fun toast(message: String) { Toast.makeText(this,message,Toast.LENGTH_LONG).show() }
    private fun page(title: String): LinearLayout {
        atRoot=false;showingPaywall=false;liveRefresh=null
        val body=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setPadding(dp(18),dp(16),dp(18),dp(24)) }
        val scroll=ScrollView(this).apply { isFillViewport=true; addView(body) }
        content.removeAllViews(); content.addView(scroll); frame=body
        label(title,22f)
        return body
    }
    private fun label(value: String,size: Float=15f): TextView = TextView(this).apply {
        text=value; textSize=size;autoLinkMask=android.text.util.Linkify.WEB_URLS;movementMethod=android.text.method.LinkMovementMethod.getInstance(); setTextColor(Color.rgb(230,228,220)); setPadding(0,dp(8),0,dp(8)); frame?.addView(this)
    }
    private fun button(key: String, action: () -> Unit): Button=Button(this).apply {
        text=if(lang.t(key)==key) key else t(key);isAllCaps=false;textSize=14f;setTextColor(gold);minimumHeight=dp(48);setPadding(dp(14),dp(10),dp(14),dp(10));gravity=Gravity.CENTER_VERTICAL or Gravity.START
        val shape=android.graphics.drawable.GradientDrawable().apply {setColor(Color.rgb(30,31,38));cornerRadius=dp(12).toFloat();setStroke(dp(1),Color.rgb(65,60,44))}
        background=android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(Color.argb(60,235,205,110)),shape,null)
        setOnClickListener {action()};frame?.addView(this,LinearLayout.LayoutParams(-1,-2).apply {setMargins(0,dp(4),0,dp(4))})
    }
    private fun input(key: String,value: String="",numeric: Boolean=false): EditText=EditText(this).apply {
        hint=t(key); setText(value); setTextColor(Color.WHITE); setHintTextColor(Color.LTGRAY)
        if(numeric) inputType=android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
        frame?.addView(this)
    }
    private fun choice(title: String,items: List<String>,selected: Int=0,onSelect: (Int)->Unit) {
        label(t(title)); val spinner=Spinner(this)
        spinner.adapter=ArrayAdapter(this,android.R.layout.simple_spinner_dropdown_item,items)
        spinner.setSelection(selected.coerceIn(0,maxOf(0,items.lastIndex)))
        spinner.onItemSelectedListener=object: AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?,view: View?,position: Int,id: Long) { (view as? TextView)?.setTextColor(Color.WHITE); onSelect(position) }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }; frame?.addView(spinner)
    }
    private fun render(index: Int) {
        if(editor!=null && !saveEditor()) return
        editor=null; compass=null; headingLabel=null; sensorLabel=null; tab=index.coerceIn(0,4)
        if(tab in 0..2) motion.start(this) else motion.stop()
        when(tab) { 0 -> compassPage();1 -> surveyPage();2 -> floorplanPage();3 -> analysisPage();else -> settingsPage() }
        atRoot=true
        tabButtons.forEachIndexed {index,button->val active=index==tab;button.setTextColor(if(active)gold else Color.LTGRAY);button.compoundDrawables[1]?.setTint(if(active)gold else Color.LTGRAY)
            (button.background as? android.graphics.drawable.GradientDrawable)?.setColor(if(active)Color.rgb(57,49,30) else Color.rgb(25,26,31))}
    }
    private fun adaptPanels(primary:View){
        if(resources.configuration.screenWidthDp<840)return
        val body=frame ?: return;val children=(0 until body.childCount).map {body.getChildAt(it)}
        val heading=children.firstOrNull();val primaryIndex=children.indexOf(primary)
        if(primaryIndex<0)return
        body.removeAllViews();val row=LinearLayout(this);val left=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL};val right=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL;setPadding(18,0,0,0)}
        if(heading!=null)body.addView(heading)
        children.drop(1).forEachIndexed {index,child->if(index+1<=primaryIndex)left.addView(child) else right.addView(child)}
        row.addView(left,LinearLayout.LayoutParams(0,-2,1f));row.addView(right,LinearLayout.LayoutParams(0,-2,1f));body.addView(row)
        primary.layoutParams.height=(resources.displayMetrics.widthPixels/2-48).coerceAtMost(900)
    }
    private fun compassPage() {
        page(t("tab_compass")); headingLabel=label("",25f); sensorLabel=label("",13f)
        compass=NativeCompassView(this).apply { heading=motion.heading; layers=CompassLayerManager.instance }
        frame?.addView(compass,LinearLayout.LayoutParams(-1,resources.displayMetrics.widthPixels.coerceAtMost(900)))
        button("native_lock") { motion.toggleLock();NativeRetention.recordMilestone(this,"lock_heading")
            getSharedPreferences("almanac_widget",MODE_PRIVATE).edit().putBoolean("locked",motion.isLocked).putFloat("heading",motion.heading.toFloat()).apply();AlmanacWidget.refresh(this)
        }
        choice("native_north",listOf(t("native_true_north"),t("native_magnetic_north")),if(motion.northReference==CompassNorthReference.TRUE_NORTH) 0 else 1) {
            motion.northReference=if(it==0) CompassNorthReference.TRUE_NORTH else CompassNorthReference.MAGNETIC_NORTH
        }
        button("native_layers") { layers() }
        button("settings_calib_title") {
            val offset=EditText(this).apply { inputType=android.text.InputType.TYPE_CLASS_NUMBER or 4096 or 8192; setText(motion.manualOffset.toString()) }
            AlertDialog.Builder(this).setTitle(t("settings_calib_title")).setMessage(t("native_calibration_note"))
                .setView(offset).setPositiveButton(t("done")) { _,_-> offset.text.toString().toDoubleOrNull()?.takeIf { it.isFinite() }?.let { motion.manualOffset=it } }
                .setNeutralButton(t("native_reset")) { _,_->motion.manualOffset=0.0 }.setNegativeButton(t("cancel"),null).show()
        }
        button("native_location_permission") { requestLocation.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION)) }
        button("native_daily_card") { dates() }
        button("native_select_mountain"){AlertDialog.Builder(this).setItems(Mountain24Data.mountains.map {it.localizedName}.toTypedArray()){_,index->motion.lockAtFacingAngle(Mountain24Data.mountains[index].angleCenter);AlmanacWidget.refresh(this);updateCompass()}.show()}
        button("daily_god_guide"){CompassLayerManager.instance.showDailyGodMarkers=!CompassLayerManager.instance.showDailyGodMarkers;CompassLayerManager.instance.save();compass?.invalidate()}
        button("native_haptic"){motion.isHapticEnabled=!motion.isHapticEnabled}
        button("native_layer_fenjin") {val item=Fenjin120Data.instance.resolveFenjin(motion.heading);AlertDialog.Builder(this).setTitle(item.localizedMountainName+" · "+item.localizedJiaziName).setMessage(item.localizedGrade+"\n\n"+item.localizedLore).setPositiveButton(t("done"),null).show()}
        button("native_layer_hexagrams") {val item=Hexagram64Data.instance.hexagram(motion.heading);AlertDialog.Builder(this).setTitle(item.localizedName).setMessage(item.localizedUpperTrigram+" / "+item.localizedLowerTrigram+"\n"+item.localizedLuckDegree+"\n\n"+item.localizedFenJinDetail).setPositiveButton(t("done"),null).show()}
        button("kw_small_title") {val level=motion.headingState.kongWangLevel;AlertDialog.Builder(this).setTitle(level.localizedTitle).setMessage(level.localizedDescription).setPositiveButton(t("done"),null).show()}
        button("preset_section_title") {AlertDialog.Builder(this).setItems(CompassPreset.values().map {it.localizedTitle}.toTypedArray()){_,i->CompassLayerManager.instance.applyPreset(CompassPreset.values()[i]);compass?.invalidate()}.show()}
        compass?.let {adaptPanels(it)}
        updateCompass()
    }
    private fun updateCompass() {
        val state=motion.headingState
        headingLabel?.text=String.format(Locale.getDefault(),"%.1f° · %s / %s",motion.heading,state.sittingMountain.localizedName,state.facingMountain.localizedName)
        sensorLabel?.text=(if(motion.northReference==CompassNorthReference.TRUE_NORTH&&!motion.hasDeclination)t("native_true_north_unavailable") else motion.coordsDesc)+"\n"+String.format(Locale.getDefault(),"%.1f μT · %.1f° / %.1f°",motion.magneticStrengthUT,motion.pitch,motion.roll)+
            "\n"+String.format(Locale.getDefault(),"%.1f km/h · %.0f m · ",motion.speedKmH,motion.altitude)+(if(motion.isDistorted)t("mag_warning_tap")+" · " else "")+state.kongWangLevel.localizedTitle+" · "+(if(motion.hasLocationFix)SolarTimeCalculator.instance.computeNow(motion.longitude).trueSolarTimeString else "--:--:--")
        compass?.heading=motion.heading;compass?.invalidate()
    }
    private fun layers() {
        val manager=CompassLayerManager.instance
        val values=booleanArrayOf(manager.showDegreeTicks,manager.showMountain24,manager.showFenjin120,manager.showHexagrams64,manager.showSolarTerms,manager.showEightGua,manager.showTrueNorthNeedle,manager.showLevelBubble)
        val keys=listOf("native_layer_ticks","native_layer_mountains","native_layer_fenjin","native_layer_hexagrams","native_layer_terms","native_layer_gua","native_layer_north","native_layer_level")
        AlertDialog.Builder(this).setTitle(t("native_layers")).setMultiChoiceItems(keys.map(::t).toTypedArray(),values) { _,i,v->values[i]=v }
            .setPositiveButton(t("done")) { _,_->
                manager.showDegreeTicks=values[0];manager.showMountain24=values[1];manager.showFenjin120=values[2];manager.showHexagrams64=values[3]
                manager.showSolarTerms=values[4];manager.showEightGua=values[5];manager.showTrueNorthNeedle=values[6];manager.showLevelBubble=values[7]
                manager.save();compass?.invalidate()
            }.show()
    }
    private fun surveyPage() {
        page(t("tab_ar"))
        button("ar_spatial_survey") { startActivity(Intent(this,ARSurveyActivity::class.java)) }
        button("native_exterior_capture") { startActivity(Intent(this,ExteriorCaptureActivity::class.java)) }
        button("native_exterior_archive"){exteriorArchive()}
        button("ar_sha_steps_title"){exteriorKnowledge()}
        button("vr_survey_title") { manualModel() }
        val models=ShaSurveyStore.instance.projectModels()
        models.first?.let { model-> button("floorplan_3d_recent_actual") { showModel(model) } }
        models.second?.let { model-> button("floorplan_3d_recent_vr") { showModel(model) } }
        ShaSurveyStore.instance.latestInterior?.let { label(it.scanMethod+" · "+it.timestamp) }
        button("native_projects") { projects() }
        label(t("settings_safety_disclaimer"),12f)
    }
    private fun exteriorKnowledge(selected:ExteriorShaItem?=null){
        val items=ExteriorShaEngine.instance.database
        page(t("ar_sha_steps_title"))
        choice("native_manual_mark",items.map {it.localizedName},items.indexOfFirst {it.id==selected?.id}.coerceAtLeast(0)){index->if(items[index].id!=selected?.id)exteriorKnowledge(items[index])}
        val item=selected ?: items.first()
        label(item.localizedName,22f);label(item.localizedAliases);label(item.severity.localizedTitle)
        label(item.localizedVisualFeature);label(item.localizedMetaphysicsHarm);label(item.localizedClassicalText,13f)
        label(t("ar_sha_steps_desc"));label(item.localizedRemedySolution)
        listOf("xuankong","zeri","place").forEach {key->label(t("ar_sha_adv_${key}_tag"),18f);label(t("ar_sha_adv_${key}_desc"))}
        label(t("ar_sha_talisman_section"),18f)
        if(UserEntitlementsManager.instance.isVip){label(t("ar_sha_talisman_material_desc"));label(t("ar_sha_talisman_hang_desc"))}else button("ar_vip_remedy_title"){paywall()}
        button("tab_ar"){render(1)}
    }
    private fun exteriorArchive(){
        page(t("native_exterior_archive"));val store=ShaSurveyStore.instance
        val archive=store.archive ?: PanoramaFengShuiArchive(compassHeading=motion.heading,interior=null,exterior=emptyList())
        archive.exterior.groupBy {it.palaceIndex(archive.compassHeading)}.toSortedMap().forEach {(palace,records)->
            label("${palace*45}°–${palace*45+45}°",20f)
            records.forEach {record->val item=ExteriorShaEngine.instance.database.firstOrNull {it.id==record.shaID}
                label((item?.localizedName ?: record.shaID)+" · ${record.bearingDegrees.toInt()}°",18f)
                item?.let {label(ExteriorShaSeverityResolver.effectiveSeverity(it.severity,record.distanceMeters).localizedTitle)}
                label(record.distanceMeters?.let {"$it m"} ?: t("native_distance_unavailable"))
                label(record.capturedAt.toString()+" · "+record.source.name,12f)
                item?.let {button("ar_sha_steps_title"){exteriorKnowledge(it)}}
                button("delete"){store.removeRecord(record.id);exteriorArchive()}
            }
        }
        button("native_export_json"){NativeSharing.shareText(this,"panorama.json",ProjectCodec.gson.toJson(archive),"application/json")}
        button("native_export_scroll"){exportScroll(true)}
        button("native_clear_records"){AlertDialog.Builder(this).setMessage(t("native_clear_records")).setPositiveButton(t("done")){_,_->store.clearRecords();exteriorArchive()}.setNegativeButton(t("cancel"),null).show()}
    }
    private fun floorplanPage() {
        page(t("floorplan_title"))
        val snapshot=workspace.snapshot
        if(workspaceProperty!=ShaSurveyStore.instance.propertyID)planHistory.clear()
        workspaceRevision=snapshot.revision;workspaceProperty=ShaSurveyStore.instance.propertyID
        val layout=snapshot.layout ?: SavedFloorplanLayout();editorHeading=layout.compassRotation;editorSync=layout.isSyncWithCompass
        val view=NativeFloorplanView(this).apply {
            rooms=layout.rooms.map { it.copy(rect=RectF(it.rect),polygonPoints=it.polygonPoints?.map { p->PointF(p.x,p.y) }) }.toMutableList()
            centroid=layout.centroid;aspectRatio=layout.aspectRatio ?: 1f
            backgroundPath=snapshot.imageFileName
            backgroundImage=snapshot.imageFileName?.let { BitmapFactory.decodeFile(File(filesDir,it).path) }
            onChanged={ saveEditor() };onSelected={ room->editRoom(room) }
        }
        editor=view
        fun refreshPeople(){
            val current=workspace.snapshot.layout ?: layout
            val include=getSharedPreferences("family_export",MODE_PRIVATE).getBoolean("include",false)
            view.familyLabels=FamilyRoomExportSnapshot.capture(current.familyRoomAssignments,view.rooms,FamilyRoomAllocationEngine.people(),view.centroid,editorHeading,view.aspectRatio,UserEntitlementsManager.instance.isVip,include).labels
            view.invalidate()
        }
        refreshPeople()
        frame?.addView(view,LinearLayout.LayoutParams(-1,650))
        button("native_add_room") {
            val types=FloorplanRoomType.values().filter { it!=FloorplanRoomType.UNKNOWN }
            AlertDialog.Builder(this).setItems(types.map { it.localizedName }.toTypedArray()) { _,i->
                view.rooms.add(FloorplanRoom(UUID.randomUUID().toString(),types[i].localizedName,types[i],RectF(.1f,.1f,.35f,.35f)));view.invalidate();saveEditor()
            }.show()
        }
        button("native_import_image") { importImage.launch(arrayOf("image/*")) }
        button("floorplan_auto_detect") {
            val image=view.backgroundImage ?: run {toast(t("native_import_image"));return@button}
            val revision=workspace.snapshot.revision
            Thread {val candidates=FloorplanImageDetector.detect(image)
                runOnUiThread {
                    if(workspace.snapshot.revision!=revision||editor!==view){toast(t("native_workspace_conflict"));return@runOnUiThread}
                    if(candidates.isEmpty()){toast(t("native_no_candidate"));return@runOnUiThread}
                    val checked=BooleanArray(candidates.size){true}
                    AlertDialog.Builder(this).setTitle(t("native_confirm_candidate"))
                        .setMultiChoiceItems(candidates.mapIndexed {i,r->"${i+1}. ${r.name}"}.toTypedArray(),checked){_,i,enabled->checked[i]=enabled}
                        .setPositiveButton(t("native_save")){_,_->view.rooms.addAll(candidates.filterIndexed {i,_->checked[i]});view.invalidate();saveEditor()}
                        .setNegativeButton(t("cancel"),null).show()
                }
            }.start()
        }
        val width=input("floorplan_width_hint",layout.widthMeters?.toString() ?: "10",true)
        val depth=input("floorplan_depth_hint",layout.depthMeters?.toString() ?: "10",true)
        val heading=input("floorplan_manual_heading",editorHeading.toString(),true)
        val facing=input("native_house_facing",layout.houseFacingDegrees?.toString() ?: "",true)
        button("native_apply_dimensions") {
            val w=width.text.toString().toDoubleOrNull();val d=depth.text.toString().toDoubleOrNull();val h=heading.text.toString().toDoubleOrNull()
            if(w==null||d==null||h==null||!w.isFinite()||!d.isFinite()||!h.isFinite()||w !in .5..200.0||d !in .5..200.0) {toast(t("native_invalid_dimensions"));return@button}
            val beforeHeading=editorHeading
            editorHeading=(h%360+360)%360;view.aspectRatio=(w/d).toFloat()
            if(beforeHeading!=editorHeading&&facing.text.toString().toDoubleOrNull()==layout.houseFacingDegrees)layout.orientation.facingAfterCalibratingTo(editorHeading)?.let {facing.setText(it.toString())}
            if(facing.text.isNotBlank()&&facing.text.toString().toDoubleOrNull()?.isFinite()!=true){toast(t("native_invalid_dimensions"));return@button}
            if(saveEditor(w,d))workspace.snapshot.layout?.let {current->workspace.save(current.copy(houseFacingDegrees=facing.text.toString().toDoubleOrNull()?.let {(it%360+360)%360},houseFacingWasExplicit=facing.text.isNotBlank()),workspace.snapshot.imageFileName,writer);workspaceRevision=workspace.snapshot.revision}
            view.invalidate()
        }
        button("floorplan_heading_use_compass") { editorHeading=motion.heading;heading.setText(editorHeading.toString());saveEditor() }
        val sync=CheckBox(this).apply {text=t("native_sync_compass");setTextColor(Color.WHITE);isChecked=editorSync;setOnCheckedChangeListener {_,enabled->editorSync=enabled;if(enabled)editorHeading=motion.heading;saveEditor()}};frame?.addView(sync)
        button("native_undo"){if(saveEditor()){val history=planHistory;if(history.isNotEmpty()){val state=history.removeAt(history.lastIndex);workspace.save(state,workspace.snapshot.imageFileName,writer);editor=null;render(2)}}}
        button("native_reset"){AlertDialog.Builder(this).setMessage(t("native_replace_workspace")).setPositiveButton(t("done")){_,_->editor=null;ShaSurveyStore.instance.replaceProperty(null,null,emptyList());workspace.save(SavedFloorplanLayout(),null,writer);render(2)}.setNegativeButton(t("cancel"),null).show()}
        button("native_set_center") { view.selectCenter=true;toast(t("native_tap_center")) }
        button("native_audit") { if(saveEditor()) audit() }
        button("floorplan_3d_current") { if(saveEditor()) manualModel() }
        button("fra_title") { if(saveEditor()) allocation() }
        val peopleToggle=CheckBox(this).apply {text=t("fra_show_labels");setTextColor(Color.WHITE);isChecked=getSharedPreferences("family_export",MODE_PRIVATE).getBoolean("include",false)
            setOnCheckedChangeListener {_,checked->getSharedPreferences("family_export",MODE_PRIVATE).edit().putBoolean("include",checked).apply();refreshPeople()}};frame?.addView(peopleToggle)
        button("native_export_report"){if(saveEditor())exportFloorplanReport()}
        button("native_save_case") { if(saveEditor()) saveCase() }
        button("native_projects") { if(saveEditor()) projects() }
        button("native_export_json") { if(saveEditor()) workspace.snapshot.layout?.let { NativeSharing.shareText(this,"floorplan.json",ProjectCodec.gson.toJson(it),"application/json") } }
        button("native_export_dxf") { if(saveEditor()) NativeSharing.shareText(this,"floorplan.dxf",FloorplanEngine.instance.exportMetricDXF(view.rooms,view.centroid,workspace.snapshot.layout?.widthMeters ?: 10.0,workspace.snapshot.layout?.depthMeters ?: 10.0),"application/dxf") }
        adaptPanels(view)
    }
    private fun editRoom(room: FloorplanRoom) {
        val box=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL }
        val name=EditText(this).apply { setText(room.name) };box.addView(name)
        val types=FloorplanRoomType.values();val type=Spinner(this).apply { adapter=ArrayAdapter(this@MainActivity,android.R.layout.simple_spinner_dropdown_item,types.map { it.localizedName });setSelection(types.indexOf(room.type)) };box.addView(type)
        AlertDialog.Builder(this).setTitle(t("native_edit_room")).setView(box).setPositiveButton(t("done")) { _,_->
            val before=room.type
            room.name=name.text.toString();room.type=types[type.selectedItemPosition];editor?.invalidate();saveEditor()
            workspace.snapshot.layout?.let {layout->workspace.save(layout.copy(familyRoomAssignments=FamilyRoomAllocationEngine.afterChangingRoomUse(layout.familyRoomAssignments,room.id,before,room.type)),workspace.snapshot.imageFileName,writer);workspaceRevision=workspace.snapshot.revision}
        }.setNeutralButton(t("delete")) { _,_->editor?.rooms?.removeAll { it.id==room.id };editor?.invalidate();saveEditor() }.setNegativeButton(t("cancel"),null).show()
    }
    private fun saveEditor(width: Double?=null,depth: Double?=null): Boolean {
        val editor=this.editor ?: return true
        val previous=workspace.snapshot.layout ?: SavedFloorplanLayout()
        val layout=previous.copy(rooms=editor.rooms.map {it.copy(rect=RectF(it.rect),polygonPoints=it.polygonPoints?.map {p->PointF(p.x,p.y)})},centroidX=editor.centroid.x.toDouble(),centroidY=editor.centroid.y.toDouble(),
            houseFacingDegrees=if(previous.compassRotation!=editorHeading)previous.orientation.facingAfterCalibratingTo(editorHeading) else previous.houseFacingDegrees,
            compassRotation=editorHeading,isSyncWithCompass=editorSync,aspectRatio=editor.aspectRatio,widthMeters=width ?: previous.widthMeters,depthMeters=depth ?: previous.depthMeters)
        val changed=ProjectCodec.gson.toJson(previous)!=ProjectCodec.gson.toJson(layout)
        if(!workspace.save(layout,editor.backgroundPath,writer,workspaceRevision,workspaceProperty)) {toast(t("native_workspace_conflict"));return false}
        if(changed){planHistory.add(previous);if(planHistory.size>20)planHistory.removeAt(0)}
        workspaceRevision=workspace.snapshot.revision;return true
    }
    private fun audit() {
        editor=null
        val layout=workspace.snapshot.layout ?: return
        if(!UserEntitlementsManager.instance.hasFloorplanAccess(ShaSurveyStore.instance.propertyKey)&&UserEntitlementsManager.instance.floorplanCredits==0){paywall();return}
        val result=FloorplanEngine.instance.auditFloorplan(layout.rooms,layout.centroid,layout.compassRotation,aspectRatio=layout.aspectRatio ?: 1f)
        if(!UserEntitlementsManager.instance.acquireFloorplanAccess(ShaSurveyStore.instance.propertyKey){workspace.save(layout.copy(rooms=result.first),workspace.snapshot.imageFileName,writer)}){toast(t("iap_storage_unavailable"));return}
        if(UserEntitlementsManager.instance.isVip)workspace.save(layout.copy(rooms=result.first),workspace.snapshot.imageFileName,writer)
        page(t("native_audit"));result.second.forEach { label(it.title,18f);label(it.palace+" · "+it.severity);label(it.lore);label(it.solution) }
        button("tab_floorplan") { render(2) }
    }
    private fun exportFloorplanReport(){
        val layout=workspace.snapshot.layout ?: return
        if(!UserEntitlementsManager.instance.hasFloorplanAccess(ShaSurveyStore.instance.propertyKey)){paywall();return}
        val language=lang.effectiveLanguage
        val frozen=ProjectCodec.gson.fromJson(ProjectCodec.gson.toJson(layout),SavedFloorplanLayout::class.java)
        val people=FamilyRoomAllocationEngine.people().toList();val include=getSharedPreferences("family_export",MODE_PRIVATE).getBoolean("include",false)
        val family=FamilyRoomExportSnapshot.capture(frozen.familyRoomAssignments,frozen.rooms,people,frozen.centroid,frozen.compassRotation,frozen.aspectRatio ?: 1f,UserEntitlementsManager.instance.isVip,include)
        val image=workspace.snapshot.imageFileName?.let {BitmapFactory.decodeFile(File(filesDir,it).path)}
        val date=Date(referenceDate.time)
        Thread {val result=runCatching {lang.withLanguage(language){val report=FloorplanEngine.instance.auditFloorplan(frozen.rooms,frozen.centroid,frozen.compassRotation,frozen.aspectRatio ?: 1f,date).second
            FloorplanReportRenderer.render(this,frozen,image,report+family.report,family.labels)}};image?.recycle()
            runOnUiThread {result.onSuccess {bitmap->runCatching {NativeSharing.openProof(this,bitmap)}.onFailure {toast(t("native_export_failed"))};bitmap.recycle()}.onFailure {toast(t("native_export_failed"))}}
        }.start()
    }
    private fun saveCase() {
        val name=EditText(this)
        AlertDialog.Builder(this).setTitle(t("native_save_case")).setView(name).setPositiveButton(t("done")) { _,_->
            val layout=workspace.snapshot.layout ?: return@setPositiveButton
            val models=ShaSurveyStore.instance.projectModels()
            if(cases.insert(FloorplanCaseRecord(title=name.text.toString().ifBlank { t("native_untitled") },layout=layout,
                imageFileName=workspace.snapshot.imageFileName,spatialSurvey=models.first,virtualSpatialSurvey=models.second,
                exteriorRecords=ShaSurveyStore.instance.records.toList(),siteFacts=ShaSurveyStore.instance.siteFacts,propertyKey=ShaSurveyStore.instance.propertyKey))) {toast(t("native_saved"));NativeRetention.recordMilestone(this,"save_floorplan_case")}
        }.setNegativeButton(t("cancel"),null).show()
    }
    private fun projects() {
        editor=null;page(t("native_projects"));button("native_import_project") {importProject.launch(arrayOf("application/json"))}
        cases.records.forEach { record->
            label(record.title,19f);label(record.createdAt.toString(),12f)
            button("native_edit_room") {val title=EditText(this).apply {setText(record.title)};AlertDialog.Builder(this).setTitle(t("native_name")).setView(title).setPositiveButton(t("done")){_,_->cases.rename(record.id,title.text.toString());projects()}.setNegativeButton(t("cancel"),null).show()}
            button("native_open") {
                AlertDialog.Builder(this).setMessage(t("native_replace_workspace")).setPositiveButton(t("done")) { _,_->
                    ShaSurveyStore.instance.replaceProperty(record.spatialSurvey,record.virtualSpatialSurvey,record.exteriorRecords ?: emptyList(),record.siteFacts ?: emptyList(),record.propertyKey)
                    workspace.save(record.layout,record.imageFileName,writer);render(2)
                }.setNegativeButton(t("cancel"),null).show()
            }
            button("native_export_json") {
                val image=record.imageFileName?.let { File(filesDir,it).takeIf { file->file.isFile }?.readBytes() }
                val portable=record.copy(backupImageBase64=image?.let { android.util.Base64.encodeToString(it,android.util.Base64.NO_WRAP) })
                NativeSharing.shareText(this,"project.json",PortableCaseCodec.encode(portable),"application/json")
            }
            button("delete") {AlertDialog.Builder(this).setMessage(record.title).setPositiveButton(t("delete")) { _,_->cases.remove(record.id);projects() }.setNegativeButton(t("cancel"),null).show()}
        }
        button("tab_floorplan") {render(2)}
    }
    private fun manualModel() {
        if(!saveEditor()) return
        editor=null
        val layout=workspace.snapshot.layout ?: SavedFloorplanLayout()
        page(t("vr_survey_title"));label(t("vr_survey_hint"))
        val width=input("floorplan_width_hint",(layout.widthMeters ?: 10.0).toString(),true)
        val depth=input("floorplan_depth_hint",(layout.depthMeters ?: 10.0).toString(),true)
        val height=input("native_ceiling_height","2.8",true)
        button("vr_survey_generate") {
            val w=width.text.toString().toFloatOrNull();val d=depth.text.toString().toFloatOrNull();val h=height.text.toString().toFloatOrNull()
            if(w==null||d==null||h==null||!w.isFinite()||!d.isFinite()||!h.isFinite()||w !in .5f..200f||d !in .5f..200f||h !in .5f..10f) {toast(t("native_invalid_dimensions"));return@button}
            if(layout.rooms.isEmpty()) {toast(t("native_add_room"));return@button}
            val rooms=layout.rooms.filter {it.type!=FloorplanRoomType.MISSING_CORNER && it.type!=FloorplanRoomType.DOOR}.map { room ->
                SpatialRoom3D(id=room.id,name=room.name,type=room.type,center=Vec3f(room.rect.centerX()*w,h/2,room.rect.centerY()*d),
                    size=Vec3f(room.rect.width()*w,h,room.rect.height()*d),areaSqMeters=room.area*w*d)
            }
            val walls=layout.rooms.filter {it.type !in setOf(FloorplanRoomType.MISSING_CORNER,FloorplanRoomType.DOOR)}.flatMap {room->
                val vertices=room.polygonPoints ?: listOf(PointF(room.rect.left,room.rect.top),PointF(room.rect.right,room.rect.top),PointF(room.rect.right,room.rect.bottom),PointF(room.rect.left,room.rect.bottom))
                vertices.indices.map {i->val a=vertices[i];val b=vertices[(i+1)%vertices.size];SpatialWall3D(start=Vec3f(a.x*w,0f,a.y*d),end=Vec3f(b.x*w,0f,b.y*d),height=h)}
            }
            val model=HouseSpatialSurveyEngine.analyzeSpatialHouse(t("native_manual_source"),walls,emptyList(),emptyList(),rooms,emptyList(),layout.compassRotation,
                Vec3f(layout.centroid.x*w,0f,layout.centroid.y*d),layout.houseFacingDegrees)
            if(ShaSurveyStore.instance.saveSurvey(model,SpatialSurveyArchiveKeys.VIRTUAL,ShaSurveyStore.instance.propertyID)) showModel(model)
        }
    }
    private fun showModel(model: HouseSpatialSurvey) {
        editor=null;page(t("native_model"));label(model.scanMethod);label(t("3d_score_label")+" · ${model.fengshuiScore} / 100");label(t("3d_metric_area")+" · ${model.dimensions.usableFloorArea} m²");label(t("3d_metric_ceiling")+" · ${model.dimensions.ceilingHeight} m")
        val modelView=NativeHouse3DView(this).apply {survey=model}
        frame?.addView(modelView,LinearLayout.LayoutParams(-1,650))
        choice("native_view_mode",listOf(t("3d_view_perspective"),t("3d_view_topdown"),t("3d_view_entrance"))){modelView.viewMode=it;modelView.invalidate()}
        choice("native_layers",listOf(t("3d_grid_bazhai"),t("3d_grid_xuankong"),t("3d_grid_off"))){modelView.gridMode=it;modelView.invalidate()}
        button("3d_metric_depth_width"){modelView.showDimensions=!modelView.showDimensions;modelView.invalidate()}
        button("ar_sha_analysis_prefix"){modelView.showShaAlerts=!modelView.showShaAlerts;modelView.invalidate()}
        button("3d_reset_camera"){modelView.yaw=.5f;modelView.invalidate()}
        modelView.onInspect={description->AlertDialog.Builder(this).setMessage(description).setPositiveButton(t("done"),null).show()}
        if(model.centroidIndirect)label(t("3d_centroid_warning"))
        label(String.format(Locale.getDefault(),"%.2f × %.2f m",model.dimensions.totalWidth,model.dimensions.totalDepth))
        model.shaItems.forEach {item->button(item.title){modelView.selectedSha=item;modelView.invalidate()};label(item.detail);label(item.solution)}
        button("native_edit_room"){
            AlertDialog.Builder(this).setItems(model.rooms.map {it.name}.toTypedArray()){_,roomIndex->
                AlertDialog.Builder(this).setItems(FloorplanRoomType.values().map {it.localizedName}.toTypedArray()){_,typeIndex->
                    val rooms=model.rooms.mapIndexed {index,room->if(index==roomIndex)room.copy(type=FloorplanRoomType.values()[typeIndex]) else room}
                    val revised=HouseSpatialSurveyEngine.analyzeSpatialHouse(model.scanMethod,model.walls,model.openings,model.beams,rooms,model.objects,model.compassHeading,model.centroid,model.fixedHouseFacing,model.houseFacingWasExplicit,referenceDate,model.id)
                    val store=ShaSurveyStore.instance;val key=if(store.projectModels().first?.id==model.id)SpatialSurveyArchiveKeys.MEASURED else SpatialSurveyArchiveKeys.VIRTUAL
                    if(store.saveSurvey(revised,key,store.propertyID))showModel(revised)
                }.show()
            }.show()
        }
        button("native_manual_mark"){editSpatial(model)}
        button("native_site_facts"){siteFacts()}
        button("native_export_dxf") {NativeSharing.shareText(this,"survey.dxf",model.generateCAD_DXF(),"application/dxf")}
        button("native_export_json") {NativeSharing.shareText(this,"survey.json",ProjectCodec.gson.toJson(model),"application/json")}
        button("native_export_report") {NativeSharing.shareReport(this,model)}
    }
    private fun editSpatial(model:HouseSpatialSurvey){
        page(t("native_manual_mark"));label(t("native_manual_source"))
        val property=ShaSurveyStore.instance;val propertyID=property.propertyID
        val isMeasured=property.projectModels().first?.id==model.id
        fun commit(openings:List<SpatialOpening3D> = model.openings,objects:List<SpatialObject3D> = model.objects,beams:List<SpatialBeam3D> = model.beams){
            val updated=HouseSpatialSurveyEngine.analyzeSpatialHouse(model.scanMethod,model.walls,openings,beams,model.rooms,objects,model.compassHeading,
                model.centroid,model.fixedHouseFacing,model.houseFacingWasExplicit ?: false,referenceDate,model.id)
            if(property.saveSurvey(updated,if(isMeasured)SpatialSurveyArchiveKeys.MEASURED else SpatialSurveyArchiveKeys.VIRTUAL,propertyID))editSpatial(updated)
            else toast(t("native_workspace_conflict"))
        }
        model.openings.forEach {opening->label(opening.type.localizedName+" · ${opening.width} × ${opening.height} m");button("delete"){commit(openings=model.openings.filterNot {it.id==opening.id})}}
        model.objects.forEach {item->label(item.localizedCategoryName+" · ${item.sizeX} × ${item.sizeZ} m");button("delete"){commit(objects=model.objects.filterNot {it.id==item.id})}}
        model.beams.forEach {beam->label(t("native_beam")+" · ${beam.clearanceHeight} m");button("delete"){commit(beams=model.beams.filterNot {it.id==beam.id})}}
        val categories=listOf("bed","sofa","table","chair","storage","television","stove","sink","toilet","bathtub","refrigerator","washerdryer","oven","dishwasher","fireplace","stairs")
        val options=SpatialOpeningType.values().map {it.localizedName}+categories.map {key->SpatialObject3D(category=key,posX=0f,posY=0f,posZ=0f,sizeX=1f,sizeY=1f,sizeZ=1f).localizedCategoryName}+t("native_beam")
        button("native_add_marker") {
            AlertDialog.Builder(this).setItems(options.toTypedArray()){_,selected->
                page(options[selected]);label(t("native_marker_coordinate_note"))
                val x=input("X (m)",model.centroidX.toString(),true);val z=input("Z (m)",model.centroidZ.toString(),true)
                val w=input("floorplan_width_hint","1",true);val d=input("floorplan_depth_hint",".5",true);val h=input("native_ceiling_height","2",true)
                val angle=input("native_rotation","0",true)
                button("native_save") markerSave@{
                    val values=listOf(x,z,w,d,h,angle).map {it.text.toString().toFloatOrNull()}
                    if(values.any {it==null||!it.isFinite()}){toast(t("native_invalid_dimensions"));return@markerSave}
                    val px=values[0]!!;val pz=values[1]!!;val sw=values[2]!!;val sd=values[3]!!;val sh=values[4]!!;val rotation=(values[5]!!*Math.PI/180).toFloat()
                    if(sw !in .01f..50f||sd !in .01f..50f||sh !in .01f..10f||kotlin.math.abs(px)>500||kotlin.math.abs(pz)>500){toast(t("native_invalid_dimensions"));return@markerSave}
                    if(selected<SpatialOpeningType.values().size){val type=SpatialOpeningType.values()[selected]
                        commit(openings=model.openings+SpatialOpening3D(type=type,position=Vec3f(px,sh/2,pz),normal=Vec3f(kotlin.math.sin(rotation),0f,-kotlin.math.cos(rotation)),width=sw,height=sh))
                    }else if(selected==options.lastIndex)commit(beams=model.beams+SpatialBeam3D(startX=px,startY=sh,startZ=pz,endX=px+sw*kotlin.math.sin(rotation),endY=sh,endZ=pz-sw*kotlin.math.cos(rotation),clearanceHeight=sh,beamDepth=.35f,beamWidth=sd))
                    else commit(objects=model.objects+SpatialObject3D(category=categories[selected-SpatialOpeningType.values().size],posX=px,posY=sh/2,posZ=pz,sizeX=sw,sizeY=sh,sizeZ=sd,rotationY=rotation))
                }
            }.show()
        }
        button("native_model"){showModel(model)}
    }

    private fun siteFacts(){
        page(t("native_site_facts"));val store=ShaSurveyStore.instance
        PurpleWhiteEngine.instance.calculateChart(referenceDate).palaceItems.filter {it.palaceId!=5}.forEach {palace->
            label(palace.palaceName,19f)
            XuanKongSiteFactKind.values().forEach {kind->val toggle=CheckBox(this).apply {
                text=t(kind.titleKey);setTextColor(Color.WHITE);isChecked=store.siteFacts.any {it.palaceID==palace.palaceId-1&&it.kind==kind}
                setOnCheckedChangeListener {_,enabled->store.setSiteFact(kind,palace.palaceId-1,enabled,store.propertyID)}
            };frame?.addView(toggle)}
        }
    }
    private fun allocation() {
        editor=null
        val layout=workspace.snapshot.layout ?: return
        val people=FamilyRoomAllocationEngine.people();val rooms=layout.rooms
        page(t("fra_title"));label(t("fra_note"))
        if(!UserEntitlementsManager.instance.isVip) {button("settings_menu_vip") {paywall()};return}
        var assignments=FamilyRoomAllocationEngine.resolve(layout.familyRoomAssignments,rooms,people,layout.centroid,layout.compassRotation,layout.aspectRatio ?: 1f,true)
        val boxes=mutableListOf<Triple<CheckBox,String,String>>()
        var updating=false
        rooms.filter {FamilyRoomAllocationEngine.isAssignable(it)}.forEach {room->
            label(room.name,18f)
            FamilyRoomAllocationEngine.fits(room,rooms,people,layout.centroid,layout.compassRotation,layout.aspectRatio ?: 1f).forEach {fit->
                val checkbox=CheckBox(this).apply {text=fit.person.name+" · "+t(fit.reasonKey);setTextColor(Color.WHITE)
                    isChecked=assignments.any {it.personID==fit.person.id&&it.roomID==room.id}
                    setOnCheckedChangeListener {_,_->if(!updating){assignments=FamilyRoomAllocationEngine.toggling(fit.person.id,room,assignments,rooms,people);updating=true;boxes.forEach {(box,person,roomID)->box.isChecked=assignments.any {it.personID==person&&it.roomID==roomID}};updating=false}} }
                boxes.add(Triple(checkbox,fit.person.id,room.id));frame?.addView(checkbox)
            }
        }
        button("native_save") { workspace.save(layout.copy(familyRoomAssignments=assignments),workspace.snapshot.imageFileName,writer);render(2) }
        button("fra_clear"){workspace.save(layout.copy(familyRoomAssignments=emptyList()),workspace.snapshot.imageFileName,writer);allocation()}
        button("fra_automatic") { workspace.save(layout.copy(familyRoomAssignments=null),workspace.snapshot.imageFileName,writer);allocation() }
    }
    private fun analysisPage() {
        page(t("tab_analysis"))
        button("native_select_mountain"){AlertDialog.Builder(this).setItems(Mountain24Data.mountains.map {it.localizedName}.toTypedArray()){_,index->motion.lockAtFacingAngle(Mountain24Data.mountains[index].angleCenter);AlmanacWidget.refresh(this);analysisPage()}.show()}
        listOf("xuankong_stars" to {flyingStars()},"bazhai_tab_title" to {bazhai()},"sanhe_tab_title" to {sanhe()},
            "purple_white" to {purpleWhite()},"qimen_dunjia" to {qimen()},"bz_tool_owner" to {profile()},"bz_tool_dates" to {dates()}).forEach {(key,action)->button(key,action)}
        button("native_export_scroll") {exportScroll()}
    }
    private fun chooseDate(withTime:Boolean=false,after:()->Unit) {
        val previous=java.util.GregorianCalendar().apply {time=referenceDate}
        DatePickerDialogCompat.show(this,previous){date->
            fun apply(value:Date){referenceDate=value;customDate=true;after()}
            if(withTime)android.app.TimePickerDialog(this,{_,hour,minute->apply(java.util.GregorianCalendar().apply {time=date;set(Calendar.HOUR_OF_DAY,hour);set(Calendar.MINUTE,minute)}.time)},previous.get(Calendar.HOUR_OF_DAY),previous.get(Calendar.MINUTE),true).show()
            else apply(date)
        }
    }
    private fun dateTools(step:Int,field:Int,refresh:()->Unit){
        label(java.text.DateFormat.getDateTimeInstance().format(referenceDate),13f)
        button("native_previous"){referenceDate=java.util.GregorianCalendar().apply {time=referenceDate;add(field,-step)}.time;customDate=true;refresh()}
        button("native_next"){referenceDate=java.util.GregorianCalendar().apply {time=referenceDate;add(field,step)}.time;customDate=true;refresh()}
        button("native_clock_now"){customDate=false;referenceDate=Date();refresh()}
        liveRefresh=refresh
    }
    private fun palaceGrid(cells:List<Triple<Int,String,String>>,onClick:(Int)->Unit){
        val grid=TableLayout(this).apply {isStretchAllColumns=true}
        cells.chunked(3).forEach {row->val line=TableRow(this);row.forEach {cell->line.addView(Button(this).apply {text=cell.second+"\n"+cell.third;textSize=12f;isAllCaps=false;setOnClickListener {onClick(cell.first)}},TableRow.LayoutParams(0,-2,1f))};grid.addView(line)}
        frame?.addView(grid)
    }
    private fun flyingStars() {
        page(t("xuankong_stars"));if(!customDate)referenceDate=Date();button("native_choose_date") {chooseDate(true) {flyingStars()}}
        dateTools(1,Calendar.DAY_OF_YEAR){flyingStars()}
        val homeFacing=XuanKongHomeContextBuilder.facing(workspace.snapshot.layout,ShaSurveyStore.instance.latestInterior)
        choice("xkd_source",listOf(t("xkd_source_compass"),t("xkd_source_home")),if(analyzeHome)1 else 0){index->val next=index==1;if(next!=analyzeHome){if(next&&homeFacing==null){toast(t("native_house_facing"))}else {analyzeHome=next;useTiGua=null;flyingStars()}}}
        val state=if(analyzeHome&&homeFacing!=null)Mountain24Data.instance.resolveHeadingState(homeFacing) else motion.headingState
        if(selectedFlyingMountain!=state.facingMountain.id){selectedFlyingMountain=state.facingMountain.id;useTiGua=null}
        val chart=FlyingStarsEngine.instance.calculateChart(period,state.sittingMountain,state.facingMountain,useTiGua ?: state.isJianXiang,referenceDate)
        choice("native_period",(1..9).map {it.toString()},period-1) {if(period!=it+1){period=it+1;flyingStars()}}
        button("native_automatic_mode"){useTiGua=null;flyingStars()}
        val replacement=CheckBox(this).apply {text=chart.chartModeTitle;isChecked=chart.isTiGua;setTextColor(Color.WHITE);setOnCheckedChangeListener {_,checked->useTiGua=checked;flyingStars()}};frame?.addView(replacement)
        palaceGrid(listOf(3,8,1,2,4,6,7,0,5).map {id->val cell=chart.palaces.first {it.id==id};Triple(id,cell.localizedPalaceName,"${cell.mountainStar} / ${cell.facingStar} / ${cell.periodStar}")}){id->val cell=chart.palaces.first {it.id==id};AlertDialog.Builder(this).setTitle(cell.localizedPalaceName).setMessage(cell.localizedEvaluation+"\n"+TraditionalEvidenceCatalog.text(TraditionalEvidenceCatalog.pair(cell.mountainStar,cell.facingStar,cell.localizedPalaceName))).setPositiveButton(t("done"),null).show()}
        label(t(chart.pattern.titleKey),20f);label(t(chart.pattern.explanationKey));label(TraditionalEvidenceCatalog.text(chart.patternSourceReferences),12f)
        label(chart.summaryAnalysis,18f);label(chart.wealthAdvice)
        chart.palaces.forEach {cell->
            label("${cell.localizedPalaceName} · ${cell.mountainStar}/${cell.facingStar}/${cell.periodStar}",18f)
            label(cell.localizedEvaluation)
            label(TraditionalEvidenceCatalog.text(chart.sourceReferences(cell.id)),12f)
        }
        val context=if(analyzeHome&&homeFacing!=null)XuanKongHomeContextBuilder.build(workspace.snapshot.layout,ShaSurveyStore.instance.latestInterior,ShaSurveyStore.instance.records,ShaSurveyStore.instance.siteFacts) else null
        val deep=XuanKongDeepAnalyzer.analyze(chart,referenceDate,context)
        deep.warningKeys.forEach {label(t(it))};deep.missingKeys.forEach {label(t(it),12f)}
        deep.sectors.sortedBy {it.priority}.forEach {sector->
            label(chart.palaces.first {it.id==sector.palaceID}.localizedPalaceName+" · "+t(sector.use.titleKey),18f)
            sector.reasonKeys.forEach {label(t(it),13f)}
            sector.actions.forEach {action->label(t(action.textKey))
                button("native_task_toggle") {RemedyTaskStore(this).toggleRemedyTask("${sector.palaceID}-${action.name}",ShaSurveyStore.instance.propertyKey,
                    chart.palaces.first {it.id==sector.palaceID}.localizedPalaceName,t(sector.use.titleKey),t(action.textKey));toast(t("native_saved"))}
            }
        }
        deep.patternChecks.forEach {label(t(it.titleKey)+" · "+t(it.statusKey));label(t(it.actionKey))}
        button("tab_analysis") {analysisPage()}
    }
    private fun bazhai() {
        page(t("bazhai_tab_title"));val state=motion.headingState
        val chart=BaZhaiEngine.instance.analyze(state.sittingMountain.palace,state.facingMountain.palace)
        label(chart.localizedHouseGua+" · "+chart.localizedHouseType,20f)
        chart.items.forEach {label(it.localizedDirection+" · "+it.star.localizedName,18f);label(it.star.localizedSuggestion);label(t(it.star.suggestedHouseUse.actionKey));label(t(it.star.suggestedHouseUse.avoidKey));button("native_task_toggle"){RemedyTaskStore(this).toggleRemedyTask("bazhai-${it.guaName}-${it.star.name}",ShaSurveyStore.instance.propertyKey,it.localizedDirection,it.star.localizedName,t(it.star.suggestedHouseUse.actionKey));toast(t("native_saved"))}}
        button("bz_tool_owner") {profile()};button("tab_analysis") {analysisPage()}
    }
    private fun purpleWhite() {
        page(t("purple_white"));if(!customDate)referenceDate=Date();button("native_choose_date") {chooseDate {purpleWhite()}}
        dateTools(30,Calendar.DAY_OF_YEAR){purpleWhite()}
        val chart=PurpleWhiteEngine.instance.calculateChart(referenceDate,motion.heading)
        label("${chart.year} · ${chart.month} · ${chart.yearCentralStar}/${chart.monthCentralStar}",20f)
        palaceGrid(chart.palaceItems.map {Triple(it.palaceId,it.palaceName,"${it.yearGuestStar} / ${it.monthGuestStar}")}){id->val item=chart.palaceItems.first {it.palaceId==id};AlertDialog.Builder(this).setTitle(item.palaceName).setMessage(item.advice).setPositiveButton(t("done"),null).show()}
        chart.palaceItems.forEach {item->label(item.palaceName+" · ${item.yearGuestStar}/${item.monthGuestStar}",18f);label(item.advice)
            label(TraditionalEvidenceCatalog.text(TraditionalEvidenceCatalog.purpleWhite(item.yearGuestStar,item.monthGuestStar,item.palaceName)),12f)}
    }
    private fun qimen() {
        page(t("qimen_dunjia"));if(!customDate)referenceDate=Date();button("native_choose_date") {chooseDate(true) {qimen()}}
        dateTools(2,Calendar.HOUR_OF_DAY){qimen()}
        val chart=QimenEngine.instance.calculateChart(referenceDate,motion.heading)
        label(chart.title,20f);label(chart.bestDirection+" · "+chart.bestReason)
        QimenScenarioType.values().forEach {scenario->
            val result=QimenEngine.instance.evaluateScenario(scenario,chart,motion.heading)
            label(scenario.localizedTitle+" · "+result.directionTitle,17f);label(result.keyPattern);label(result.actionGuide,12f)
        }
        palaceGrid(chart.cells.map {Triple(it.id,it.localizedPalaceName,it.localizedDoorName+"\n"+it.localizedTianStem+" / "+it.localizedDiStem)}){id->val cell=chart.cells.first {it.id==id};AlertDialog.Builder(this).setTitle(cell.localizedPalaceName).setMessage(cell.localizedStarName+" · "+cell.localizedGodName).setPositiveButton(t("done"),null).show()}
        chart.cells.forEach {cell->label(cell.localizedPalaceName,18f);label(cell.localizedDoorName+" · "+cell.localizedStarName+" · "+cell.localizedGodName+"\n"+cell.localizedTianStem+" / "+cell.localizedDiStem)}
    }
    private fun sanhe() {
        page(t("sanhe_tab_title"));val state=motion.headingState
        val water=SanHeWaterEngine.instance.resolveHuangQuanWater(state.facingMountain)
        label(water.badgeText,19f);label(water.waterDesc);label(water.localizedQuote,13f);label(water.sourceReference.localizedText,12f)
        val sha=SanHeWaterEngine.instance.resolveBaSha(state.sittingMountain)
        label(sha.shaDir+" · "+sha.shaZhi,19f);label(sha.lore);label(sha.remedy);label(sha.localizedSong,13f);label(sha.sourceReference.localizedText,12f)
        SanHeWaterEngine.instance.resolveWaterMethod(state.sittingMountain,state.facingMountain).forEach {label(it.localizedMountainName+" · "+it.phase.localizedName,18f);label(it.phase.localizedWaterRule)}
    }
    private fun dates() {
        page(t("bz_tool_dates"));if(!customDate)referenceDate=Date();button("native_choose_date") {chooseDate {dates()}}
        dateTools(1,Calendar.DAY_OF_YEAR){dates()}
        val engine=ZeRiEngine.instance;val analysis=engine.analyze(referenceDate,motion.headingState.sittingMountain)
        button("native_share_calendar"){val image=DailyCardRenderer.renderPoster(referenceDate,motion.headingState);NativeSharing.openProof(this,image);image.recycle();NativeRetention.recordMilestone(this,"save_daily_card")}
        label(analysis.fourPillarsText,18f);label(analysis.overallStatus);label(analysis.detailsText)
        engine.calculateTwelveShichen(referenceDate,UserKuaProfileManager.instance.takeIf {it.isProfileEnabled}?.birthYear).forEach {item->
            label(item.timeRange+" · "+item.localizedPillar+" · "+item.localizedGodName+" · "+if(item.isAuspicious) "✓" else "—")
        }
        choice("native_day_category",ZeRiActivityCategory.values().map {it.localizedTitle},ZeRiActivityCategory.values().indexOf(dayCategory)) {val selected=ZeRiActivityCategory.values()[it];if(selected!=dayCategory){dayCategory=selected;dates()}}
        engine.findUpcomingAuspiciousDays(motion.headingState.sittingMountain,referenceDate,ownerBirthYear=UserKuaProfileManager.instance.takeIf {it.isProfileEnabled}?.birthYear,category=dayCategory).forEach {day->
            label(day.dateLabel+" · "+day.dayOfficerBadge+" · "+day.yiSummary)
            button("native_remind") {toast(t(if(NativeReminders.scheduleDay(this,day,AuspiciousReminderContext(ShaSurveyStore.instance.propertyKey,motion.headingState.sittingMountain.name,dayCategory)))"native_saved" else "native_reminder_past"))}
        }
    }
    private fun profile() {
        page(t("bz_tool_owner"));val profile=UserKuaProfileManager.instance
        label(t("profile_data_notice"));label(profile.localizedLifeKuaName()+" · "+profile.localizedZodiac(),25f)
        val enable=CheckBox(this).apply {text=t("native_enable_profile");setTextColor(Color.WHITE);isChecked=profile.isProfileEnabled;setOnCheckedChangeListener {_,enabled->profile.isProfileEnabled=enabled}};frame?.addView(enable)
        if(profile.isProfileEnabled&&UserEntitlementsManager.instance.isVip){
            val compatibility=profile.evaluateCompatibility(motion.headingState.sittingMountain.palace)
            label(compatibility.matchBadgeTitle,18f);label(compatibility.matchAdvice)
            compatibility.personalDirections.forEach {label(it.localizedDirection+" · "+it.star.localizedName);label(it.star.localizedSuggestion)}
        }
        val year=input("native_birth_year",profile.birthYear.toString(),true)
        val male=CheckBox(this).apply {text=t("native_male");isChecked=profile.isMale;setTextColor(Color.WHITE)};frame?.addView(male)
        button("native_save") {year.text.toString().toIntOrNull()?.let {profile.updateOwnerBirthYear(it,male.isChecked);profile()}}
        button("native_birth_date") {DatePickerDialogCompat.show(this,Calendar.getInstance()) {profile.updateOwnerBirth(it,male.isChecked);profile()}}
        profile.familyMembers.forEach {member->label(member.displayName+" · "+member.birthYear+" · "+member.guaKey);button("native_edit_family"){editFamily(member)};button("delete") {profile.removeFamilyMember(member.id);profile()}}
        button("native_add_family") {editFamily(null)}
        button("profile_data_delete_all") {AlertDialog.Builder(this).setMessage(t("profile_data_delete_note")).setPositiveButton(t("delete")) {_,_->profile.deleteAllPersonalProfiles();profile()}.setNegativeButton(t("cancel"),null).show()}
    }
    private fun editFamily(member: FamilyMemberProfile?) {
            val profile=UserKuaProfileManager.instance
            val box=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL}
            val name=EditText(this).apply {hint=t("native_name");setText(member?.customName ?: "")};box.addView(name)
            val birth=EditText(this).apply {hint=t("native_birth_year");inputType=2;setText((member?.birthYear ?: 1990).toString())};box.addView(birth)
            val gender=CheckBox(this).apply {text=t("native_male");isChecked=member?.isMale ?: true};box.addView(gender)
            val roles=FamilyRole.values();val role=Spinner(this).apply {adapter=ArrayAdapter(this@MainActivity,android.R.layout.simple_spinner_dropdown_item,roles.map {it.localizedTitle});setSelection(roles.indexOf(member?.role ?: FamilyRole.OTHER))};box.addView(role)
            var fullBirth=member?.birthDate
            val dateButton=Button(this).apply {text=fullBirth?.toString() ?: t("native_birth_date");setOnClickListener {DatePickerDialogCompat.show(this@MainActivity,Calendar.getInstance().apply {fullBirth?.let {time=it}}){fullBirth=it;birth.setText(Calendar.getInstance().apply {time=it}.get(Calendar.YEAR).toString());text=it.toString()}}};box.addView(dateButton)
            AlertDialog.Builder(this).setTitle(t(if(member==null)"native_add_family" else "native_edit_family")).setView(box).setPositiveButton(t("done")) {_,_->birth.text.toString().toIntOrNull()?.let {
                if(member==null)profile.addFamilyMember(roles[role.selectedItemPosition],name.text.toString(),birthDate=fullBirth,birthYear=it,isMale=gender.isChecked)
                else profile.updateFamilyMember(member.id,roles[role.selectedItemPosition],name.text.toString(),fullBirth,it,gender.isChecked)
                profile()
            }}.setNegativeButton(t("cancel"),null).show()
    }
    private fun onboarding(step:Int){
        page(t("native_intro_headerTitle"));label("${step+1}/3",13f)
        label(t("native_intro_step${step+1}Title"),22f);label(t("native_intro_step${step+1}Desc"));label(t("native_intro_step${step+1}Bullets"))
        val profile=UserKuaProfileManager.instance
        val birth=if(step==1)input("native_birth_year",profile.birthYear.toString(),true) else null
        val gender=if(step==1)CheckBox(this).apply {text=t("native_male");isChecked=profile.isMale;setTextColor(Color.WHITE);frame?.addView(this)} else null
        fun finish(){getSharedPreferences("native_onboarding",MODE_PRIVATE).edit().putBoolean("completed",true).apply();render(0)}
        button(if(step<2)"native_intro_nextButtonTitle" else "native_intro_startButtonTitle"){
            if(step==1){val year=birth?.text?.toString()?.toIntOrNull();if(year==null||year !in 1920..2035){toast(t("native_invalid_dimensions"));return@button};profile.updateOwnerBirthYear(year,gender!!.isChecked)}
            if(step<2)onboarding(step+1) else finish()
        }
        button("native_intro_skipTitle"){finish()}
    }
    private fun settingsPage() {
        page(t("tab_settings"));choice("settings_menu_language",AppLanguage.values().map {it.displayName},AppLanguage.values().indexOf(lang.currentSetting)) {
            val next=AppLanguage.values()[it];if(next!=lang.currentSetting){lang.setLanguage(this,next);AlmanacWidget.refresh(this);recreate()}
        }
        button("settings_menu_vip") {paywall()};button("settings_menu_kua_reminder") {profile()}
        button("native_solar_reminders") {NativeReminders.scheduleSolarTerms(this);toast(t("native_saved"))}
        button("native_scheduled_reminders"){reminders()}
        button("native_cancel_reminders") {NativeReminders.cancelAll(this);toast(t("native_saved"))}
        button("native_task_list") {tasks()}
        button("native_intro_headerTitle"){onboarding(0)}
        button("legal_compliance_title"){AlertDialog.Builder(this).setTitle(t("legal_compliance_title")).setMessage(t("legal_compliance_body")).setPositiveButton(t("done"),null).show()}
        button("native_rate_app"){runCatching {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("market://details?id=$packageName")))}.onFailure {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://play.google.com/store/apps/details?id=$packageName")))}}
        label(t("settings_safety_disclaimer"),13f)
        button("native_privacy") {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sdnlink.cn/i18n/${legalLocale()}/privacy.html")))}
        button("native_terms") {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sdnlink.cn/i18n/${legalLocale()}/subscription-terms.html")))}
        button("native_support") {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sdnlink.cn/i18n/${legalLocale()}/contact.html")))}
        button("paywall_restore_purchases") {GooglePlayBillingManager.instance.queryPurchases()}
        label(BuildConfig.VERSION_NAME,12f)
    }
    private fun reminders(){page(t("native_scheduled_reminders"));NativeReminders.entries(this).filter {it.time>System.currentTimeMillis()}.forEach {entry->label(entry.title,18f);label(Date(entry.time).toString()+" · "+entry.text);button("delete"){NativeReminders.cancel(this,entry.id);reminders()}}}
    private fun legalLocale()=when(lang.effectiveLanguage){AppLanguage.ZH_HANS,AppLanguage.AUTO->"zh-CN";AppLanguage.ZH_HANT->"zh-TW";else->lang.effectiveLanguage.rawValue}
    private fun paywall() {
        page(t("settings_menu_vip"));showingPaywall=true;label(t("native_billing_note"));label(t("native_credits")+" · "+UserEntitlementsManager.instance.exportCredits+" / "+UserEntitlementsManager.instance.floorplanCredits);if(!com.example.yiijingcompass.billing.PurchaseVerifier.configured)label(t("native_billing_configuration"));val billing=GooglePlayBillingManager.instance
        val products=org.json.JSONArray(billing.getProductDetailsJson())
        InAppProductId.values().forEach {product->
            val details=(0 until products.length()).map {products.getJSONObject(it)}.firstOrNull {it.optString("productId")==product.productId}
            details?.let {label(it.optString("title")+" · "+it.optString("price"));label(it.optString("description"),12f)}
            billing.subscriptionDisclosure(product.productId)?.let {label(it,14f)}
            button(product.localizedTitle) {billing.launchPurchaseFlow(this,product.productId) {launched,error->if(!launched)toast(error ?: t("native_purchase_failed"))}}
                .isEnabled=details!=null&&billing.canPurchase(product.productId)
        }
        button("paywall_restore_purchases") {billing.queryPurchases {runOnUiThread {paywall()}}}
        button("native_refresh_products"){billing.queryAllProductDetails();paywall()}
        button("native_privacy"){startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sdnlink.cn/i18n/${legalLocale()}/privacy.html")))}
        button("native_terms"){startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sdnlink.cn/i18n/${legalLocale()}/subscription-terms.html")))}
        button("native_manage_subscription") {startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://play.google.com/store/account/subscriptions")))}
    }
    private fun exportScroll(archiveOnly:Boolean=false) {
        if(!customDate)referenceDate=Date()
        val usesHome=archiveOnly||analyzeHome&&XuanKongHomeContextBuilder.facing(workspace.snapshot.layout,ShaSurveyStore.instance.latestInterior)!=null
        val layout=if(usesHome)workspace.snapshot.layout else null
        val report=layout?.takeIf {UserEntitlementsManager.instance.hasFloorplanAccess(ShaSurveyStore.instance.propertyKey)}?.let {
            val audit=FloorplanEngine.instance.auditFloorplan(it.rooms,it.centroid,it.compassRotation,aspectRatio=it.aspectRatio ?: 1f,date=referenceDate)
            audit.second+FamilyRoomExportSnapshot.capture(it.familyRoomAssignments,audit.first,FamilyRoomAllocationEngine.people(),it.centroid,it.compassRotation,it.aspectRatio ?: 1f,UserEntitlementsManager.instance.isVip,getSharedPreferences("family_export",MODE_PRIVATE).getBoolean("include",false)).report
        } ?: emptyList()
        val heading=if(usesHome)(XuanKongHomeContextBuilder.facing(layout,ShaSurveyStore.instance.latestInterior) ?: ShaSurveyStore.instance.archive?.compassHeading ?: motion.heading) else motion.heading
        val state=Mountain24Data.instance.resolveHeadingState(heading)
        val snapshot=TianJiAnalysisSnapshot(heading,period,useTiGua ?: state.isJianXiang,referenceDate).capturing(
            if(usesHome)XuanKongHomeContextBuilder.build(layout,ShaSurveyStore.instance.latestInterior,ShaSurveyStore.instance.records,ShaSurveyStore.instance.siteFacts) else null,
            if(usesHome)ShaSurveyStore.instance.propertyKey else null,report,if(usesHome)ShaSurveyStore.instance.archive else null)
        val coords=motion.coordsDesc;val solar=(if(motion.hasLocationFix)SolarTimeCalculator.instance.computeNow(motion.longitude).trueSolarTimeString else "--:--:--")
        val signature=ProjectCodec.decode(getSharedPreferences("report_signature",MODE_PRIVATE).getString("value",null),ReportSignature::class.java) ?: ReportSignature()
        val request=ReportPreviewActivity.Request(snapshot.copy(signature=signature),coords,solar,lang.effectiveLanguage)
        val file=File(cacheDir,"report-request-${UUID.randomUUID()}.json")
        file.writeText(ProjectCodec.gson.toJson(request))
        startActivity(Intent(this,ReportPreviewActivity::class.java).putExtra("request",file.name))
    }
    private fun tasks(){
        page(t("native_task_list"));val store=RemedyTaskStore(this);val property=ShaSurveyStore.instance.propertyKey
        store.tasks.filter {it.propertyKey==property}.forEach {task->
            val toggle=CheckBox(this).apply {text=task.palaceDirection+" · "+task.title;setTextColor(Color.WHITE);isChecked=task.completed
                setOnCheckedChangeListener {_,_->store.toggleRemedyCompletion(task.id,property)}};frame?.addView(toggle)
            label(task.remedyAction);label("${((System.currentTimeMillis()-task.createdAt.time)/86400000L+1).coerceIn(1,21)} / 21",12f);button("delete"){store.removeRemedyTask(task.id,property);tasks()}
        }
    }
    override fun onBillingServiceConnected() {}
    override fun onProductDetailsUpdated(products:Map<String,ProductDetails>){if(showingPaywall&&!isFinishing)paywall()}
    override fun onPurchaseSuccess(productId:String,orderId:String){if(showingPaywall&&!isFinishing)paywall()}
    override fun onPurchaseFailed(productId:String?,errorCode:Int,message:String){toast(message)}
    override fun onPurchasesRestored(restoredProductIds:List<String>){if(showingPaywall&&!isFinishing)paywall()}
    override fun onHeadingUpdate(heading: Double,trueHeading: Double,magneticHeading: Double,headingState: CompassHeadingState) {runOnUiThread {if(editorSync&&editor!=null)editorHeading=heading;updateCompass()}}
    override fun onTiltUpdate(pitch: Float,roll: Float,isLevel: Boolean) {runOnUiThread {updateCompass()}}
    override fun onLocationUpdate(lat: Double,lon: Double,alt: Double,speedKmH: Float,coordsDesc: String) {runOnUiThread {updateCompass()}}
    override fun onSolarTimeUpdate(solarTimeStr: String,solarTerm: String) {runOnUiThread {updateCompass()}}
    override fun onMagneticFieldUpdate(isDistorted: Boolean,strengthUT: Float) {runOnUiThread {updateCompass()}}
    override fun onAccuracyChange(accuracy: Int) {runOnUiThread {updateCompass()}}
}
