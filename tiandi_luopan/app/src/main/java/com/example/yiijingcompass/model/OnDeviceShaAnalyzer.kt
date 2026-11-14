package com.example.yiijingcompass.model

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.*

data class ShaAnalysisResult(val shaID:String,val confidence:Double,val targetX:Double,val targetY:Double,
    val detectedRegions:Int,val summary:String,val horizontalFOVDegrees:Double?=null)

/** ARCore planes/depth provide optional geometric evidence; absence never means
 * a depth measurement was obtained. Confidence is a heuristic geometry score. */
data class ARSceneEvidence(val trackingIsNormal:Boolean,val mappingIsUsable:Boolean,val depthAvailable:Boolean=false,
    val depthStreamAvailable:Boolean=false,val depthCoverage:Double=0.0,val depthSampleMeters:Double?=null,
    val leftDepthMeters:Double?=null,val rightDepthMeters:Double?=null,val topDepthMeters:Double?=null,
    val bottomDepthMeters:Double?=null,val verticalPlaneCount:Int=0,val wallFaceCount:Int=0,val horizontalFOVDegrees:Double?=null)

data class ImageGeometryRegion(val points:List<PointF>,val confidence:Double){
    val box=GeometryUtils.polygonBounds(points) ?: RectF()
    val topLeft=points.minByOrNull {it.x-it.y} ?: PointF()
    val topRight=points.maxByOrNull {it.x+it.y} ?: PointF()
    val bottomLeft=points.minByOrNull {it.x+it.y} ?: PointF()
    val bottomRight=points.maxByOrNull {it.x-it.y} ?: PointF()
    val verticality:Double get(){fun score(a:PointF,b:PointF)=abs((b.y-a.y).toDouble())/hypot((b.x-a.x).toDouble(),(b.y-a.y).toDouble()).coerceAtLeast(.00001)
        return (score(bottomLeft,topLeft)+score(bottomRight,topRight))/2}
}

/** Native local geometry detector with two threshold passes and the same scene
 * classification rules as main iOS. Every candidate requires manual review. */
class OnDeviceShaAnalyzer private constructor(){
    companion object {val instance by lazy {OnDeviceShaAnalyzer()}}
    fun analyze(bitmap:Bitmap,onResult:(ShaAnalysisResult?)->Unit)=analyze(bitmap,null,onResult)
    fun analyze(bitmap:Bitmap,evidence:ARSceneEvidence?,onResult:(ShaAnalysisResult?)->Unit){
        if(bitmap.isRecycled||bitmap.width<24||bitmap.height<24||evidence?.let {(!it.trackingIsNormal&&!it.mappingIsUsable)||(it.depthAvailable&&it.depthStreamAvailable&&it.depthCoverage<.08)}==true){onResult(null);return}
        val relaxed=regions(bitmap,106);val strict=regions(bitmap,142)
        val a=classify(relaxed,evidence);val b=classify(strict,evidence)
        val ca=contourCandidate(relaxed,evidence);val cb=contourCandidate(strict,evidence)
        val pair=if(a!=null&&b!=null&&isConsistent(a,b))a to b else if(ca!=null&&cb!=null&&isConsistent(ca,cb))ca to cb else null
        onResult(pair?.let {(one,two)->one.copy(confidence=min(.95,(one.confidence+two.confidence)/2+
            (if(evidence?.verticalPlaneCount ?: 0>0).03 else 0.0)+(if(evidence?.depthCoverage ?: 0.0>=.4).03 else 0.0)),
            targetX=(one.targetX+two.targetX)/2,targetY=(one.targetY+two.targetY)/2,
            detectedRegions=min(one.detectedRegions,two.detectedRegions),summary=LocalizationManager.instance.t("native_candidate_note"))})
    }
    fun isConsistent(a:ShaAnalysisResult,b:ShaAnalysisResult)=a.shaID==b.shaID&&hypot(a.targetX-b.targetX,a.targetY-b.targetY)<=.10&&abs(a.confidence-b.confidence)<=.18
    private fun regions(bitmap:Bitmap,threshold:Int):List<ImageGeometryRegion>{
        val factor=min(1.0,512.0/max(bitmap.width,bitmap.height));val w=max(1,(bitmap.width*factor).toInt());val h=max(1,(bitmap.height*factor).toInt())
        val sampled=Bitmap.createScaledBitmap(bitmap,w,h,false);val pixels=IntArray(w*h);sampled.getPixels(pixels,0,w,0,0,w,h)
        if(sampled!==bitmap)sampled.recycle()
        val dark=BooleanArray(w*h){i->val p=pixels[i];(Color.red(p)*299+Color.green(p)*587+Color.blue(p)*114)/1000<threshold}
        val visited=BooleanArray(w*h);val queue=IntArray(w*h);val results=mutableListOf<ImageGeometryRegion>()
        for(seed in dark.indices){if(!dark[seed]||visited[seed])continue
            var head=0;var tail=0;queue[tail++]=seed;visited[seed]=true
            var minX=w;var maxX=0;var minY=h;var maxY=0;val boundary=mutableListOf<PointF>()
            while(head<tail){val i=queue[head++];val x=i%w;val y=i/w;minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
                var edge=false
                for(dy in -1..1)for(dx in -1..1){if(dx==0&&dy==0)continue;val xx=x+dx;val yy=y+dy
                    if(xx !in 0 until w||yy !in 0 until h){edge=true;continue};val next=yy*w+xx
                    if(!dark[next])edge=true else if(!visited[next]){visited[next]=true;queue[tail++]=next}
                }
                if(edge)boundary.add(PointF(x.toFloat()/w,1-y.toFloat()/h))
            }
            val area=(maxX-minX).toDouble()*(maxY-minY)/(w*h)
            if(area !in .02.. .65||boundary.size<8||minX<=1&&minY<=1&&maxX>=w-2&&maxY>=h-2)continue
            val hull=GeometryUtils.convexHull(boundary)
            if(hull.size<3)continue
            val fill=GeometryUtils.polygonArea(hull)/(area.toFloat().coerceAtLeast(.0001f))
            results.add(ImageGeometryRegion(hull,.70+.22*fill.coerceIn(0f,1f)))
        }
        return results.sortedByDescending {it.box.width()*it.box.height()}.take(24)
    }
    fun classify(regions:List<ImageGeometryRegion>,evidence:ARSceneEvidence?=null):ShaAnalysisResult? {
        val usable=regions.filter {it.confidence>=.60&&it.box.width()*it.box.height() in .020f.. .65f}
        val candidates=mutableListOf<ShaAnalysisResult>()
        fun add(id:String,score:Double,x:Float,y:Float,minimum:Double=.72){if(score>=minimum)candidates.add(ShaAnalysisResult(id,min(.95,score),x.toDouble(),1-y.toDouble(),usable.size,LocalizationManager.instance.t("native_candidate_note"),evidence?.horizontalFOVDegrees))}
        val tall=usable.filter {val b=it.box;max(b.width(),b.height())/min(b.width(),b.height()).coerceAtLeast(.001f)>=2.2&&b.width()<=.36&&b.height()>=.24&&it.verticality>=.85&&b.centerX()>.05&&b.centerX()<.95}
        for(i in tall.indices)for(j in i+1 until tall.size){
            val sorted=listOf(tall[i],tall[j]).sortedBy {it.box.centerX()};val left=sorted[0];val right=sorted[1];val l=left.box;val r=right.box
            if(l.centerX()>=.52||r.centerX()<=.48)continue
            val separation=r.centerX()-l.centerX();val gap=r.left-l.right;val overlap=min(l.bottom,r.bottom)-max(l.top,r.top)
            val baseline=abs(l.top-r.top);val ratio=min(l.height(),r.height())/max(l.height(),r.height())
            if(separation in .24f.. .78f&&gap in .06f.. .45f&&overlap>=.26&&baseline<=.18&&ratio>=.55&&l.width()<=.24&&r.width()<=.24){
                val center=evidence?.depthSampleMeters;val ld=evidence?.leftDepthMeters;val rd=evidence?.rightDepthMeters
                val flank=if(ld!=null&&rd!=null)(ld+rd)/2 else null
                if(!(center!=null&&flank!=null&&center<1.8&&flank<1.8&&abs(center-flank)<.12)){
                    val bonus=if(center!=null&&flank!=null&&(center>flank+.35||center>=3.5)).05 else 0.0
                    val score=(left.confidence+right.confidence)/2*.45+min(1.0,min(l.height(),r.height())/.55)*.25+(left.verticality+right.verticality)/2*.20+((gap-.06)/.22).coerceIn(0.0,1.0)*.10+bonus
                    add("tianzhan",score,(l.centerX()+r.centerX())/2,(l.centerY()+r.centerY())/2)
                }
            }
            if(r.height()>=l.height()*1.28&&r.bottom>l.bottom+.08&&baseline<=.22){
                val bonus=if(evidence?.rightDepthMeters!=null&&evidence.leftDepthMeters!=null&&evidence.rightDepthMeters<=evidence.leftDepthMeters+.5).04 else 0.0
                add("baihu",(left.confidence+right.confidence)/2*.55+min(1.0,((r.height()-l.height())/max(.1f,l.height())).toDouble())*.30+right.verticality*.15+bonus,r.centerX(),r.centerY())
            }
        }
        for(base in usable){val b=base.box;if(b.width()<.26||b.height()<.20||b.bottom>.78)continue
            for(upper in usable){if(upper===base)continue;val u=upper.box
                if(u.width()>=.06&&u.width()<=b.width()*.55&&u.height()>=.06&&u.height()<=b.height()*.65&&u.top>=b.bottom-.06&&u.top<=b.bottom+.12&&u.centerX()>=b.left+.04&&u.centerX()<=b.right-.04){
                    val bonus=if(evidence?.topDepthMeters!=null&&evidence.depthSampleMeters!=null&&evidence.topDepthMeters>evidence.depthSampleMeters+.25).05 else 0.0
                    add("tantou",(base.confidence+upper.confidence)/2*.65+upper.verticality*.25+.08+bonus,u.centerX(),u.centerY())
                }
            }
        }
        for(region in usable){val b=region.box
            fun distance(a:PointF,c:PointF)=hypot((a.x-c.x).toDouble(),(a.y-c.y).toDouble())
            val top=distance(region.topRight,region.topLeft);val bottom=distance(region.bottomRight,region.bottomLeft)
            val taper=min(top,bottom)/max(.001,max(top,bottom))
            if(taper<=.68&&region.verticality<.92&&b.height()>=.18&&b.centerY()>=.35)add("huoxing",region.confidence*.60+min(1.0,(.72-taper)/.40)*.30+.10,b.centerX(),b.bottom)
            if(b.top<=.22&&b.bottom>=.45&&abs(b.centerX()-.5)<=.22&&top<bottom*.82){
                val bonus=if(evidence?.bottomDepthMeters!=null&&evidence.depthSampleMeters!=null&&evidence.depthSampleMeters>evidence.bottomDepthMeters+.4).06 else 0.0
                val overhead=usable.any {it!==region&&it.box.top>=b.bottom-.08&&it.box.width()>=b.width()*.85}
                add(if(overhead)"chuanxin" else "luchong",region.confidence*.60+min(1.0,(1-top/max(.001,bottom))/.45)*.28+.08+bonus,b.centerX(),b.centerY())
            }
            if(b.width()>=.48&&b.height()<=.26&&b.centerY()<=.38){
                val slope=abs(region.topRight.y-region.topLeft.y)/max(.001f,b.width());val curved=slope>=.12||taper<=.82
                val bonus=if(evidence?.bottomDepthMeters!=null&&evidence.bottomDepthMeters<=3.2).05 else 0.0
                add(if(curved)"fangong" else "gejiao",region.confidence*.65+min(1.0,b.width()/.65)*.25+bonus,b.centerX(),b.centerY(),.73)
            }
        }
        return candidates.maxByOrNull {it.confidence}
    }
    private fun contourCandidate(regions:List<ImageGeometryRegion>,evidence:ARSceneEvidence?):ShaAnalysisResult? {
        val candidates=mutableListOf<ShaAnalysisResult>()
        for(region in regions.take(18)){val b=region.box;val points=simplify(region.points,.025f);if(points.size !in 3..5||b.height()<.18||b.centerY()<.35)continue
            var best=180.0;var apex=points[0]
            for(i in points.indices){val a=points[(i+points.size-1)%points.size];val p=points[i];val c=points[(i+1)%points.size]
                val ax=(a.x-p.x).toDouble();val ay=(a.y-p.y).toDouble();val bx=(c.x-p.x).toDouble();val by=(c.y-p.y).toDouble();val la=hypot(ax,ay);val lb=hypot(bx,by)
                if(la<=.04||lb<=.04)continue;val angle=acos(((ax*bx+ay*by)/(la*lb)).coerceIn(-1.0,1.0))*180/PI
                if(angle<best){best=angle;apex=p}
            }
            if(best<=56)candidates.add(ShaAnalysisResult("huoxing",min(.91,.72+min(1.0,(60-best)/35)*.16),apex.x.toDouble(),1-apex.y.toDouble(),regions.size,LocalizationManager.instance.t("native_candidate_note"),evidence?.horizontalFOVDegrees))
        }
        return candidates.maxByOrNull {it.confidence}
    }
    private fun simplify(points:List<PointF>,epsilon:Float):List<PointF>{
        val output=points.toMutableList();var changed=true
        while(changed&&output.size>3){changed=false
            for(i in output.indices){val a=output[(i+output.size-1)%output.size];val b=output[i];val c=output[(i+1)%output.size]
                val distance=abs((c.x-a.x)*(a.y-b.y)-(a.x-b.x)*(c.y-a.y))/hypot((c.x-a.x).toDouble(),(c.y-a.y).toDouble()).coerceAtLeast(.00001)
                if(distance<epsilon){output.removeAt(i);changed=true;break}
            }
        };return output
    }
}
