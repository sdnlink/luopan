package com.example.yiijingcompass.model

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.graphics.RectF
import java.util.UUID
import kotlin.math.*

/** Wall/space geometry candidates, matching the iOS workflow's manual review.
 * No trained room-type model and no image upload. */
object FloorplanImageDetector {
    fun detect(bitmap:Bitmap):List<FloorplanRoom> {
        if(bitmap.width<24||bitmap.height<24)return emptyList()
        val scale=min(1.0,512.0/max(bitmap.width,bitmap.height))
        val w=max(1,(bitmap.width*scale).toInt());val h=max(1,(bitmap.height*scale).toInt())
        val image=Bitmap.createScaledBitmap(bitmap,w,h,false);val pixels=IntArray(w*h)
        image.getPixels(pixels,0,w,0,0,w,h)
        if(image!==bitmap)image.recycle()
        val walls=BooleanArray(w*h){i->val c=pixels[i];(Color.red(c)*299+Color.green(c)*587+Color.blue(c)*114)/1000<120}
        // Close single-pixel breaks so text labels do not merge adjacent rooms.
        val blocked=BooleanArray(w*h)
        for(y in 0 until h)for(x in 0 until w)blocked[y*w+x]=(-1..1).any {dy->(-1..1).any {dx->
            val xx=x+dx;val yy=y+dy;xx in 0 until w&&yy in 0 until h&&walls[yy*w+xx]}}
        val visited=BooleanArray(w*h);val queue=IntArray(w*h);val regions=mutableListOf<List<Int>>()
        for(seed in pixels.indices){
            if(blocked[seed]||visited[seed])continue
            var head=0;var tail=0;queue[tail++]=seed;visited[seed]=true;var border=false
            while(head<tail){val index=queue[head++];val x=index%w;val y=index/w
                if(x==0||y==0||x==w-1||y==h-1)border=true
                for(next in intArrayOf(if(x>0)index-1 else -1,if(x<w-1)index+1 else -1,if(y>0)index-w else -1,if(y<h-1)index+w else -1)){
                    if(next>=0&&!blocked[next]&&!visited[next]){visited[next]=true;queue[tail++]=next}
                }
            }
            val fraction=tail.toDouble()/(w*h)
            if(!border&&fraction in .008..0.85)regions.add(queue.take(tail))
        }
        val result=mutableListOf<FloorplanRoom>()
        for(region in regions.sortedByDescending {it.size}.take(40)){
            val xs=region.map {it%w};val ys=region.map {it/w}
            val rect=RectF(xs.min().toFloat()/w,ys.min().toFloat()/h,(xs.max()+1f)/w,(ys.max()+1f)/h)
            if(rect.width()<.03f||rect.height()<.03f)continue
            val type=FloorplanEngine.inferRoomType(region.size.toFloat()/(w*h),rect.width()/rect.height(),result) ?: FloorplanRoomType.UNKNOWN
            val polygon=outline(region,w,h)
            result.add(FloorplanRoom(UUID.randomUUID().toString(),type.localizedName,type,rect,polygon))
        }
        return result
    }
    private fun outline(region:List<Int>,w:Int,h:Int):List<PointF>? {
        val inside=region.toHashSet();val edges=mutableMapOf<Int,Int>()
        fun vertex(x:Int,y:Int)=y*(w+1)+x
        region.forEach {i->val x=i%w;val y=i/w
            if(y==0||i-w !in inside)edges[vertex(x,y)]=vertex(x+1,y)
            if(x==w-1||i+1 !in inside)edges[vertex(x+1,y)]=vertex(x+1,y+1)
            if(y==h-1||i+w !in inside)edges[vertex(x+1,y+1)]=vertex(x,y+1)
            if(x==0||i-1 !in inside)edges[vertex(x,y+1)]=vertex(x,y)
        }
        var best=emptyList<PointF>()
        while(edges.isNotEmpty()){
            val first=edges.keys.first();var current=first;val loop=mutableListOf<PointF>();var closed=false
            for(step in 0..edges.size){loop.add(PointF((current%(w+1)).toFloat()/w,(current/(w+1)).toFloat()/h))
                current=edges.remove(current) ?: break
                if(current==first){closed=true;break}
            }
            if(closed&&GeometryUtils.polygonArea(loop)>GeometryUtils.polygonArea(best))best=loop
        }
        if(best.size<3)return null
        val simplified=best.filterIndexed {i,b->val a=best[(i+best.size-1)%best.size];val c=best[(i+1)%best.size]
            abs((b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x))>1e-9}
        return simplified.takeIf {it.size in 3..512}
    }
}
