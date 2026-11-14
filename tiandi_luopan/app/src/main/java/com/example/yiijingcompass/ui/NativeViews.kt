package com.example.yiijingcompass.ui

import android.app.DatePickerDialog
import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.CompassMotionManager
import kotlin.math.*
import java.util.*

object DatePickerDialogCompat {
    fun show(context: Context,calendar: Calendar,onDate: (Date)->Unit) {
        DatePickerDialog(context,{_,year,month,day->
            onDate(Calendar.getInstance().apply {clear();set(year,month,day,12,0,0)}.time)
        },calendar.get(Calendar.YEAR),calendar.get(Calendar.MONTH),calendar.get(Calendar.DAY_OF_MONTH)).show()
    }
}

class NativeCompassView(context: Context): View(context) {
    var heading=0.0
    var layers=CompassLayerManager.instance
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val gold=Color.rgb(235,205,110)
    override fun onDraw(canvas: Canvas) {
        val centerX=width/2f;val centerY=height/2f;val radius=min(width,height)*.47f
        canvas.save();canvas.translate(centerX,centerY);canvas.rotate(-heading.toFloat())
        paint.color=gold;paint.style=Paint.Style.STROKE;paint.strokeWidth=2f
        listOf(1f,.88f,.73f,.58f,.4f).forEach {canvas.drawCircle(0f,0f,radius*it,paint)}
        if(layers.showDegreeTicks) for(degree in 0 until 360 step 3) {
            canvas.save();canvas.rotate(degree.toFloat());val length=if(degree%30==0) 18 else 7
            canvas.drawLine(0f,-radius,0f,-radius+length,paint);canvas.restore()
        }
        paint.style=Paint.Style.FILL;paint.textAlign=Paint.Align.CENTER
        fun radial(text: String,degrees: Double,r: Float,size: Float) {
            canvas.save();canvas.rotate(degrees.toFloat());canvas.translate(0f,-radius*r)
            canvas.rotate(heading.toFloat()-degrees.toFloat());paint.textSize=size;canvas.drawText(text,0f,size*.3f,paint);canvas.restore()
        }
        if(layers.showMountain24) Mountain24Data.mountains.forEach {radial(it.localizedName,it.angleCenter,.79f,radius*.063f)}
        if(layers.showFenjin120) Fenjin120Data.instance.allFenjin.forEach {radial(it.jiaziName,it.centerAngle,.94f,radius*.025f)}
        if(layers.showEightGua) listOf(0.0,45.0,90.0,135.0,180.0,225.0,270.0,315.0).forEach {angle->radial(Mountain24Data.find(angle).localizedPalace,angle,.49f,radius*.07f)}
        if(layers.showSolarTerms) SolarTermsData.instance.terms.forEach {item->
            val words=item.localizedName.split(" ")
            val lines=if(words.size>1)listOf(words.take((words.size+1)/2).joinToString(" "),words.drop((words.size+1)/2).joinToString(" ")) else listOf(item.localizedName)
            lines.forEachIndexed {index,line->radial(line,item.angleCenter,.64f+(index-(lines.size-1)/2f)*.035f,radius*.028f)}
        }
        if(layers.showHexagrams64) for(item in Hexagram64Data.instance.hexagrams) {
            canvas.save();canvas.rotate(item.angleCenter.toFloat());paint.strokeWidth=1f
            for(line in 0..5) {val y=-radius*.7f+line*3
                if(item.binaryCode[line]=='1') canvas.drawLine(-4f,y,4f,y,paint)
                else {canvas.drawLine(-4f,y,-1f,y,paint);canvas.drawLine(1f,y,4f,y,paint)}
            }
            canvas.restore()
        }
        if(layers.showDailyGodMarkers){val directions=ZeRiEngine.instance.dailyCompassDirections(Date());paint.color=Color.GREEN
            radial("$",directions.wealthAngle,.35f,20f);radial("♡",directions.joyAngle,.35f,20f);paint.color=gold}
        canvas.restore()
        paint.color=Color.RED;paint.strokeWidth=3f;canvas.drawLine(centerX,centerY-radius,centerX,centerY+radius,paint)
        paint.color=gold;paint.textSize=22f;canvas.drawText("▲",centerX,centerY-radius+25,paint)
        val motion=CompassMotionManager.instance
        if(layers.showTrueNorthNeedle) {canvas.save();canvas.rotate((motion.trueHeading-heading).toFloat(),centerX,centerY)
            paint.color=Color.GREEN;canvas.drawLine(centerX,centerY,centerX,centerY-radius*.9f,paint);canvas.restore()}
        if(layers.showLevelBubble) {paint.color=if(motion.isLevel) Color.GREEN else Color.RED
            canvas.drawCircle(centerX+motion.roll.coerceIn(-20f,20f)*2,centerY+motion.pitch.coerceIn(-20f,20f)*2,12f,paint)}
    }
}

class NativeFloorplanView(context: Context): View(context) {
    var rooms=mutableListOf<FloorplanRoom>()
    var centroid=PointF(.5f,.5f)
    var aspectRatio=1f
    var backgroundImage: Bitmap?=null
    var familyLabels:Map<String,String> = emptyMap()
    var backgroundPath: String?=null
    var selectCenter=false
    var onChanged:(()->Unit)?=null
    var onSelected:((FloorplanRoom)->Unit)?=null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    private var selected: FloorplanRoom?=null
    private var startRect: RectF?=null
    private var start=PointF()
    private var moved=false
    private var resizing=false
    private fun bounds()=GeometryUtils.aspectFitRect(aspectRatio,RectF(12f,12f,width-12f,height-12f))
    private fun screen(p: PointF): PointF {val b=bounds();return PointF(b.left+p.x*b.width(),b.top+p.y*b.height())}
    private fun normalized(x: Float,y: Float): PointF {val b=bounds();return PointF((x-b.left)/b.width(),(y-b.top)/b.height())}
    override fun onDraw(canvas: Canvas) {
        val b=bounds();paint.color=Color.rgb(40,48,54);canvas.drawRect(b,paint)
        backgroundImage?.let {paint.alpha=150;canvas.drawBitmap(it,null,b,paint);paint.alpha=255}
        rooms.forEach {room->
            val points=room.polygonPoints ?: listOf(PointF(room.rect.left,room.rect.top),PointF(room.rect.right,room.rect.top),PointF(room.rect.right,room.rect.bottom),PointF(room.rect.left,room.rect.bottom))
            val path=Path();points.map(::screen).forEachIndexed {i,p->if(i==0)path.moveTo(p.x,p.y) else path.lineTo(p.x,p.y)};path.close()
            paint.color=Color.argb(90,40,180,200);paint.style=Paint.Style.FILL;canvas.drawPath(path,paint)
            paint.color=if(selected?.id==room.id) Color.YELLOW else Color.CYAN;paint.style=Paint.Style.STROKE;paint.strokeWidth=2f;canvas.drawPath(path,paint)
            paint.style=Paint.Style.FILL;paint.color=Color.WHITE;paint.textAlign=Paint.Align.CENTER;paint.textSize=24f
            val c=screen(room.center);canvas.drawText(room.name,c.x,c.y,paint)
            if(selected?.id==room.id){val handle=screen(PointF(room.rect.right,room.rect.bottom));canvas.drawCircle(handle.x,handle.y,14f,paint)}
        }
        familyLabels.forEach {(id,name)->rooms.firstOrNull {it.id==id}?.let {room->val p=screen(room.center);paint.color=Color.YELLOW;paint.style=Paint.Style.FILL;paint.textSize=20f;paint.textAlign=Paint.Align.CENTER;canvas.drawText(name,p.x,p.y+24,paint)}}
        val c=screen(centroid);paint.color=Color.RED;paint.strokeWidth=3f
        canvas.drawLine(c.x-14,c.y,c.x+14,c.y,paint);canvas.drawLine(c.x,c.y-14,c.x,c.y+14,paint)
    }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val p=normalized(event.x,event.y)
        when(event.actionMasked){
            MotionEvent.ACTION_DOWN->{
                parent?.requestDisallowInterceptTouchEvent(true)
                if(selectCenter){centroid=PointF(p.x.coerceIn(0f,1f),p.y.coerceIn(0f,1f));selectCenter=false;onChanged?.invoke();invalidate();return true}
                selected=rooms.asReversed().firstOrNull {FloorplanEngine.roomContains(it,p)}
                start=PointF(event.x,event.y);startRect=selected?.let {RectF(it.rect)};moved=false
                val corner=selected?.let {screen(PointF(it.rect.right,it.rect.bottom))}
                resizing=corner!=null && hypot(event.x-corner.x,event.y-corner.y)<40
                invalidate();return true
            }
            MotionEvent.ACTION_MOVE->{
                val room=selected ?: return true;val r=startRect ?: return true
                val b=bounds();val dx=(event.x-start.x)/b.width();val dy=(event.y-start.y)/b.height()
                if(hypot(event.x-start.x,event.y-start.y)>8)moved=true
                if(moved){val next=if(resizing)RectF(r.left,r.top,(r.right+dx).coerceIn(r.left+.02f,1f),(r.bottom+dy).coerceIn(r.top+.02f,1f)) else {
                    val x=(r.left+dx).coerceIn(0f,max(0f,1-r.width()));val y=(r.top+dy).coerceIn(0f,max(0f,1-r.height()))
                    RectF(x,y,x+r.width(),y+r.height())}
                    val changed=room.transformed(next);room.rect=changed.rect;room.polygonPoints=changed.polygonPoints;invalidate()
                };return true
            }
            MotionEvent.ACTION_UP->{parent?.requestDisallowInterceptTouchEvent(false);if(moved)onChanged?.invoke() else selected?.let {onSelected?.invoke(it)};performClick();return true}
            MotionEvent.ACTION_CANCEL->{parent?.requestDisallowInterceptTouchEvent(false);if(moved)onChanged?.invoke();return true}
        };return true
    }
    override fun performClick(): Boolean {super.performClick();return true}
}

/** Orthographic/isometric software renderer; gestures rotate the real geometry. */
class NativeHouse3DView(context: Context): View(context) {
    var survey: HouseSpatialSurvey?=null
    var viewMode=0
    var topDown:Boolean
        get()=viewMode==1
        set(value){viewMode=if(value)1 else 0}
    var gridMode=0
    var showDimensions=true
    var showShaAlerts=true
    var selectedSha:HouseSpatialShaItem?=null
    var onInspect:((String)->Unit)?=null
    private val inspectPoints=mutableListOf<Pair<PointF,String>>()
    var yaw=.5f
    private var lastX=0f
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(canvas: Canvas) {
        val model=survey ?: return
        canvas.drawColor(Color.rgb(12,18,28))
        inspectPoints.clear()
        val span=max(max(model.dimensions.totalWidth,model.dimensions.totalDepth),model.dimensions.ceilingHeight).coerceAtLeast(1f)
        val entrance=model.openings.firstOrNull {it.type==SpatialOpeningType.ENTRANCE_DOOR}
        val camera=entrance?.position ?: Vec3f(model.centroidX,0f,model.centroidZ+span/2)
        val look=Vec2f(model.centroidX-camera.x,model.centroidZ-camera.z).normalized()
        val frontYaw=atan2(look.x, -look.y)+(yaw-.5f)
        val scale=min(width,height)*.72f/span
        fun project(x: Float,y: Float,z: Float): PointF {
            val dx=x-model.centroidX;val dz=z-model.centroidZ
            if(viewMode==2){
                val rx=x-camera.x;val rz=z-camera.z
                val depth=rx*sin(frontYaw)-rz*cos(frontYaw)
                if(depth<.08f)return PointF(Float.NaN,Float.NaN)
                return PointF(width/2f+(rx*cos(frontYaw)+rz*sin(frontYaw))*width*.7f/depth,height/2f-(y-1.6f)*width*.7f/depth)
            }
            val xx=dx*cos(yaw)-dz*sin(yaw);val zz=dx*sin(yaw)+dz*cos(yaw)
            val perspective=if(topDown)1f else 1f/(1f+zz/(span*2))
            return PointF(width/2+xx*scale*perspective,height*.65f+(if(topDown)zz else zz*.45f-y*.8f)*scale*perspective)
        }
        fun line(a: Vec3f,b: Vec3f,color: Int){val p=project(a.x,a.y,a.z);val q=project(b.x,b.y,b.z);paint.color=color;paint.strokeWidth=2f;if(p.x.isFinite()&&q.x.isFinite())canvas.drawLine(p.x,p.y,q.x,q.y,paint)}
        model.walls.forEach {w->
            val a=w.start;val b=w.end;val c=Vec3f(b.x,b.y+w.height,b.z);val d=Vec3f(a.x,a.y+w.height,a.z)
            listOf(a to b,b to c,c to d,d to a).forEach {line(it.first,it.second,Color.CYAN)}
            if(showDimensions){val p=project((a.x+b.x)/2,0f,(a.z+b.z)/2);paint.textSize=18f;paint.color=Color.CYAN;canvas.drawText(String.format(Locale.getDefault(),"%.2f m",(b-a).length()),p.x,p.y,paint)}
        }
        fun box(center: Vec3f,size: Vec3f,color: Int,rotation:Float=0f) {
            val points=(0..7).map {i->Vec3f(center.x+(if(i and 1==0)-.5f else .5f)*size.x,center.y+(if(i and 2==0)-.5f else .5f)*size.y,center.z+(if(i and 4==0)-.5f else .5f)*size.z)}
            val rotated=points.map {p->val x=p.x-center.x;val z=p.z-center.z;Vec3f(center.x+x*cos(rotation)-z*sin(rotation),p.y,center.z+x*sin(rotation)+z*cos(rotation))}
            for(i in 0..7)for(bit in listOf(1,2,4))if(i and bit==0)line(rotated[i],rotated[i or bit],color)
        }
        model.rooms.forEach {r->box(r.center,r.size,Color.argb(170,220,190,90),r.rotationY ?: 0f);val p=project(r.centerX,0f,r.centerZ);paint.color=Color.WHITE;paint.textSize=22f;paint.textAlign=Paint.Align.CENTER;canvas.drawText(r.name,p.x,p.y,paint);inspectPoints.add(p to (r.name+" · ${r.sizeX} × ${r.sizeZ} m"))}
        model.objects.forEach {box(it.position,it.size,Color.GREEN,it.rotationY ?: 0f);inspectPoints.add(project(it.posX,it.posY,it.posZ) to (it.localizedCategoryName+" · ${it.sizeX} × ${it.sizeY} × ${it.sizeZ} m"))}
        model.openings.forEach {o->box(o.position,Vec3f(o.width,o.height,.05f),if(o.type==SpatialOpeningType.WINDOW)Color.BLUE else Color.MAGENTA,atan2(o.normalX,o.normalZ));inspectPoints.add(project(o.posX,o.posY,o.posZ) to (o.type.localizedName+" · ${o.width} × ${o.height} m"))}
        model.beams.forEach {beam->line(beam.start,beam.end,Color.RED)}
        if(showShaAlerts)model.shaItems.forEach {item->item.coordinate?.let {at->val p=project(at.x,at.y,at.z);paint.color=if(item.id==selectedSha?.id)Color.YELLOW else Color.RED;canvas.drawCircle(p.x,p.y,if(item.id==selectedSha?.id)13f else 7f,paint);item.vectorEnd?.let {line(at,it,paint.color)}}}
        val facing=model.resolvedHouseFacing
        if(gridMode!=2&&facing!=null){
            val state=Mountain24Data.instance.resolveHeadingState(facing)
            val stars=FlyingStarsEngine.instance.calculateChart(sitting=state.sittingMountain,facing=state.facingMountain)
            val bazhai=BaZhaiEngine.instance.analyze(state.sittingMountain.palace,state.facingMountain.palace)
            val w=model.dimensions.totalWidth;val d=model.dimensions.totalDepth
            for(i in 1..2){val x=model.centroidX-w/2+w*i/3;val z=model.centroidZ-d/2+d*i/3
                line(Vec3f(x,0f,model.centroidZ-d/2),Vec3f(x,0f,model.centroidZ+d/2),Color.DKGRAY)
                line(Vec3f(model.centroidX-w/2,0f,z),Vec3f(model.centroidX+w/2,0f,z),Color.DKGRAY)
            }
            for(row in 0..2)for(col in 0..2){
                val x=model.centroidX+(col-1)*w/3;val z=model.centroidZ+(row-1)*d/3
                val point=project(x,.02f,z);val id=if(row==1&&col==1)4 else XuanKongDeepAnalyzer.palaceID(atan2((x-model.centroidX).toDouble(),-(z-model.centroidZ).toDouble())*180/PI+model.compassHeading) ?: 4
                val cell=stars.palaces.first {it.id==id}
                val text=if(gridMode==1)"${cell.mountainStar}/${cell.facingStar}" else bazhai.items.firstOrNull {it.guaName==cell.guaName}?.star?.localizedName ?: cell.localizedPalaceName
                paint.color=Color.rgb(230,200,110);paint.textSize=20f;canvas.drawText(text,point.x,point.y,paint)
            }
        }
    }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if(event.action==MotionEvent.ACTION_DOWN){lastX=event.x;parent?.requestDisallowInterceptTouchEvent(true)}
        if(event.action==MotionEvent.ACTION_MOVE){yaw+=(event.x-lastX)/150;lastX=event.x;invalidate()}
        if(event.action==MotionEvent.ACTION_UP){parent?.requestDisallowInterceptTouchEvent(false)
            inspectPoints.minByOrNull {hypot((it.first.x-event.x).toDouble(),(it.first.y-event.y).toDouble())}?.takeIf {hypot((it.first.x-event.x).toDouble(),(it.first.y-event.y).toDouble())<60}?.let {onInspect?.invoke(it.second)}
            performClick()}
        return true
    }
    override fun performClick(): Boolean {super.performClick();return true}
}
