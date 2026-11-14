package com.example.yiijingcompass

import android.content.Context
import android.graphics.*
import com.example.yiijingcompass.billing.SignedEntitlementPreferences
import com.example.yiijingcompass.model.*
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.time.Instant
import java.util.*
import javax.crypto.spec.SecretKeySpec
import kotlin.math.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28])
class DeepAnalysisParityTests {
    private val context get()=RuntimeEnvironment.getApplication() as Context
    private val date=Date.from(Instant.parse("2026-11-09T04:00:00Z"))
    @Before fun setup(){
        LocalizationManager.instance.init(context);LocalizationManager.instance.setLanguage(context,AppLanguage.EN)
        SignedEntitlementPreferences.keyProviderForTests={SecretKeySpec(ByteArray(32){5},"HmacSHA256")}
        context.getSharedPreferences("tianji_entitlements",0).edit().clear().commit();UserEntitlementsManager.instance.init(context)
        ShaSurveyStore.instance.init(context)
    }
    private fun cell(m:Int,f:Int)=PalaceCell(0,"Kan","坎","正北",9,9,m,f,false,m==9,f==9,m==5||f==5,m==2||f==2)
    private fun chart()=TianJiAnalysisSnapshot(345.0,9,false,date).flyingStarsChart()
    @Test fun reciprocalRelationsAndSourcesKeepOrderedPairMatches(){
        val reciprocal=mapOf(XuanKongStarPair.Relation.SAME to XuanKongStarPair.Relation.SAME,
            XuanKongStarPair.Relation.FIRST_GENERATES_SECOND to XuanKongStarPair.Relation.SECOND_GENERATES_FIRST,
            XuanKongStarPair.Relation.SECOND_GENERATES_FIRST to XuanKongStarPair.Relation.FIRST_GENERATES_SECOND,
            XuanKongStarPair.Relation.FIRST_CONTROLS_SECOND to XuanKongStarPair.Relation.SECOND_CONTROLS_FIRST,
            XuanKongStarPair.Relation.SECOND_CONTROLS_FIRST to XuanKongStarPair.Relation.FIRST_CONTROLS_SECOND)
        for(a in 1..9)for(b in 1..9){assertEquals(reciprocal[XuanKongStarPair(a,b).relation],XuanKongStarPair(b,a).relation)
            TraditionalEvidenceCatalog.pair(a,b,"room").forEach {assertTrue(it.matches.all {match->match.contains("$a/$b")})}}
    }
    @Test fun sourcesDoNotClaimDoubleFiveForASingleFive(){
        assertFalse(TraditionalEvidenceCatalog.pair(5,1,"N").any {it.id=="pair.five_five"})
        assertTrue(TraditionalEvidenceCatalog.pair(5,5,"N").any {it.id=="pair.five_five"})
        assertTrue(TraditionalEvidenceCatalog.pair(2,5,"N").any {it.id=="pair.two_five"})
        assertFalse(TraditionalEvidenceCatalog.purpleWhite(9,5,"N").any {it.titleKey=="ref_year_nine"})
    }
    @Test fun allStarsHaveSpecificEightMansionReferences(){
        assertEquals(8,StarLuckType.values().map {it.sourceReference.titleKey}.toSet().size)
        StarLuckType.values().forEach {assertEquals(listOf(it.localizedName),it.sourceReference.matches);assertTrue(it.sourceReference.quotes.isEmpty())}
    }
    @Test fun qimenGateReferencesOnlyDescribeTheSelectedGate(){
        for((names,key) in listOf(listOf("休门","生门","开门") to "ref_qimen_good",listOf("死门","惊门","伤门") to "ref_qimen_bad",listOf("杜门","景门") to "ref_qimen_neutral"))for(name in names){
            val door=QimenDoor(name,1,false,"","");assertEquals(key,door.sourceReference.titleKey);assertEquals(1,door.sourceReference.matches.size)}
    }
    @Test fun guestReferencesChangeWithoutChangingTheNatalChart(){
        val chart=chart()
        val a=chart.sourceReferences(0,1,4);val b=chart.sourceReferences(0,5,2)
        assertNotEquals(a,b);assertTrue(b.any {it.id=="pair.two_five"})
        assertEquals(chart.sourceReferences(0),chart.sourceReferences(0,0,10))
        assertTrue(chart.sourceReferences(99,1,4).isEmpty())
    }
    @Test fun sectorMappingCentersDirectionsAndWrapsNorth(){
        assertEquals(0,XuanKongDeepAnalyzer.palaceID(0.0));assertEquals(0,XuanKongDeepAnalyzer.palaceID(359.9))
        assertEquals(7,XuanKongDeepAnalyzer.palaceID(22.5));assertEquals(8,XuanKongDeepAnalyzer.palaceID(180.0))
        assertNull(XuanKongDeepAnalyzer.palaceID(Double.NaN))
    }
    @Test fun realNoiseAndBlockedAccessOverrideUnusedStarCautions(){
        val chart=chart().copy(palaces=chart().palaces.map {if(it.id==0)cell(1,9) else it})
        val facts=listOf(XuanKongSiteFact(XuanKongSiteFactKind.NOISE,0),XuanKongSiteFact(XuanKongSiteFactKind.BLOCKED_ACCESS,0))
        val result=XuanKongDeepAnalyzer.analyze(chart,date,XuanKongHomeContext(facts=facts))
        val north=result.sectors.first {it.palaceID==0};assertEquals(0,north.priority);assertEquals(XuanKongSectorUse.QUIET,north.use)
        assertTrue(XuanKongPracticalAction.CLEAR_ACCESS in north.actions);assertEquals(north.actions.size,north.actions.toSet().size)
    }
    @Test fun bathroomAndKitchenDoNotBecomeStudyOrSeatingAdvice(){
        val chart=chart().copy(palaces=chart().palaces.map {if(it.id==0)cell(1,4) else it})
        for(type in listOf(FloorplanRoomType.BATHROOM,FloorplanRoomType.KITCHEN,FloorplanRoomType.MISSING_CORNER)){
            val home=XuanKongHomeContext(places=listOf(XuanKongLocatedPlace("r",0,"Room",XuanKongPlaceKind.ROOM,type)))
            val north=XuanKongDeepAnalyzer.analyze(chart,date,home).sectors.first {it.palaceID==0}
            assertFalse(XuanKongPracticalAction.STUDY in north.actions);assertFalse(XuanKongPracticalAction.REST in north.actions)
        }
    }
    @Test fun coverageNeverInventsBedsAndConflictingModelCannotContaminatePlan(){
        val room=FloorplanRoom("large","Room",FloorplanRoomType.MASTER_BEDROOM,RectF(.05f,.05f,.95f,.95f))
        val layout=SavedFloorplanLayout(rooms=listOf(room),houseFacingDegrees=90.0)
        val model=HouseSpatialSurveyEngine.analyzeSpatialHouse("manual",emptyList(),emptyList(),emptyList(),
            listOf(SpatialRoom3D(name="Room",type=FloorplanRoomType.MASTER_BEDROOM,center=Vec3f(0f,1f,0f),size=Vec3f(6f,2f,4f))),
            listOf(SpatialObject3D(category="bed",posX=0f,posY=1f,posZ=-1f,sizeX=1f,sizeY=1f,sizeZ=2f)),0.0,houseFacingDegrees=180.0)
        val home=XuanKongHomeContextBuilder.build(layout,model,emptyList(),emptyList())
        assertTrue(home.places.map {it.palaceID}.toSet().size>=4);assertFalse(home.places.any {it.kind==XuanKongPlaceKind.BED})
        assertTrue("xkd_orientation_conflict" in home.warningKeys)
    }
    @Test fun polygonCentroidAndCentralRoomUseActualFootprint(){
        val concave=FloorplanRoom("L","L",FloorplanRoomType.STUDY,RectF(0f,0f,1f,1f),listOf(PointF(0f,0f),PointF(1f,0f),PointF(1f,.2f),PointF(.2f,.2f),PointF(.2f,1f),PointF(0f,1f)))
        val center=FloorplanRoom("center","Center",FloorplanRoomType.LIVING_ROOM,RectF(.4f,.4f,.6f,.6f))
        val result=FloorplanEngine.instance.auditFloorplan(listOf(concave,center),PointF(.5f,.5f),0.0).first
        assertTrue(result.first {it.id=="center"}.palaceName.contains("Center"));assertFalse(result.first {it.id=="L"}.palaceName.contains("Center"))
    }
    @Test fun entryDoorSelectionIsInvariantUnderArbitraryRotations(){
        val corners=listOf(Vec2f(0f,0f),Vec2f(10f,0f),Vec2f(10f,8f),Vec2f(0f,8f))
        for(degrees in 0..350 step 10){val r=degrees*PI/180
            fun rotate(p:Vec2f)=Vec2f((p.x*cos(r)-p.y*sin(r)).toFloat(),(p.x*sin(r)+p.y*cos(r)).toFloat())
            val doors=listOf(SpatialEntranceCandidate("main",rotate(Vec2f(5f,0f)),1f),SpatialEntranceCandidate("inside",rotate(Vec2f(4.5f,2f)),1.2f))
            assertEquals("main",GeometryUtils.entranceDoorID(corners.map(::rotate),doors))
        }
    }
    @Test fun changingAutomaticEntrancePreservesOnlyExplicitFacing(){
        fun door(x:Float,z:Float,nx:Float,nz:Float)=SpatialOpening3D(type=SpatialOpeningType.ENTRANCE_DOOR,position=Vec3f(x,1f,z),normal=Vec3f(nx,0f,nz),width=1f,height=2f)
        val first=HouseSpatialSurveyEngine.analyzeSpatialHouse("manual",emptyList(),listOf(door(0f,-2f,0f,-1f)),emptyList(),emptyList(),emptyList(),45.0,Vec3f(0f,0f,0f))
        assertNull(first.fixedHouseFacing)
        assertEquals(45.0,first.resolvedHouseFacing!!,.0001)
        val second=HouseSpatialSurveyEngine.analyzeSpatialHouse("manual",emptyList(),listOf(door(2f,0f,1f,0f)),emptyList(),emptyList(),emptyList(),45.0,Vec3f(0f,0f,0f),first.fixedHouseFacing)
        assertEquals(135.0,second.resolvedHouseFacing!!,.0001)
    }
    @Test fun virtualWritesDoNotReplaceAMeasuredOrExplicitProjection(){
        fun model(name:String)=HouseSpatialSurveyEngine.analyzeSpatialHouse(name,emptyList(),emptyList(),emptyList(),emptyList(),emptyList(),0.0)
        val store=ShaSurveyStore.instance;val measured=model("measured");val virtual=model("manual")
        store.replaceProperty(measured,null,emptyList());store.saveSurvey(virtual,SpatialSurveyArchiveKeys.VIRTUAL,store.propertyID)
        assertEquals(measured.id,store.latestInterior!!.id)
        store.replaceProperty(null,null,emptyList());val projected=model("projection");store.updateInterior(projected)
        store.saveSurvey(virtual,SpatialSurveyArchiveKeys.VIRTUAL,store.propertyID);assertEquals(projected.id,store.latestInterior!!.id)
    }
    @Test fun sourceFactsAndCaptureWritesCannotCrossProperties(){
        val store=ShaSurveyStore.instance;store.replaceProperty(null,null,emptyList());val old=store.propertyID
        store.setSiteFact(XuanKongSiteFactKind.NOISE,0,true,old);store.setSiteFact(XuanKongSiteFactKind.NOISE,0,true,old);assertEquals(1,store.siteFacts.size)
        store.replaceProperty(null,null,emptyList());store.setSiteFact(XuanKongSiteFactKind.NOISE,0,true,old);assertTrue(store.siteFacts.isEmpty())
    }
    @Test fun familyPrivacyAndClearedAllocationsStayCleared(){
        val people=listOf(FamilyRoomPerson("p","Private name","坎"))
        val rooms=listOf(FloorplanRoom("bed","Bedroom",FloorplanRoomType.MASTER_BEDROOM,RectF(.4f,.05f,.6f,.2f)))
        assertTrue(FamilyRoomExportSnapshot.capture(null,rooms,people,PointF(.5f,.5f),0.0,1f,true,false).labels.isEmpty())
        assertTrue(FamilyRoomAllocationEngine.resolve(emptyList(),rooms,people,PointF(.5f,.5f),0.0,1f,true).isEmpty())
        assertTrue(FamilyRoomAllocationEngine.resolve(null,rooms,people,PointF(.5f,.5f),0.0,1f,false).isEmpty())
    }
    @Test fun rotatedScansKeepGeographicHouseFindings(){
        val corners=listOf(Vec3f(-5f,0f,-3f),Vec3f(5f,0f,-3f),Vec3f(5f,0f,3f),Vec3f(-5f,0f,3f))
        fun analyze(rotated:Boolean):HouseSpatialSurvey {
            fun rotate(p:Vec3f)=if(rotated)Vec3f(p.z,p.y,-p.x) else p
            val points=corners.map(::rotate)
            val walls=points.indices.map {SpatialWall3D(start=points[it],end=points[(it+1)%points.size])}
            val rooms=listOf(SpatialRoom3D(name="Bedroom",type=FloorplanRoomType.MASTER_BEDROOM,center=rotate(Vec3f(2f,1.4f,-1f)),size=Vec3f(3f,2.8f,2f),rotationY=if(rotated)(-Math.PI/2).toFloat() else 0f),
                SpatialRoom3D(name="Bathroom",type=FloorplanRoomType.BATHROOM,center=rotate(Vec3f(-2f,1.4f,1f)),size=Vec3f(2f,2.8f,2f),rotationY=if(rotated)(-Math.PI/2).toFloat() else 0f))
            val door=SpatialOpening3D(type=SpatialOpeningType.ENTRANCE_DOOR,position=rotate(Vec3f(5f,1f,0f)),normal=rotate(Vec3f(1f,0f,0f)),width=1f,height=2f)
            return HouseSpatialSurveyEngine.analyzeSpatialHouse("test",walls,listOf(door),emptyList(),rooms,emptyList(),if(rotated)90.0 else 0.0,Vec3f(0f,0f,0f),analysisDate=date)
        }
        val first=analyze(false);val second=analyze(true)
        assertEquals(90.0,first.resolvedHouseFacing!!,.000001);assertEquals(first.resolvedHouseFacing!!,second.resolvedHouseFacing!!,.000001)
        fun findings(model:HouseSpatialSurvey)=model.shaItems.filter {it.title.contains("Xuan",true)||it.detail.contains("Ba Zhai",true)}.map {it.title+"|"+it.locationName+"|"+it.detail}.sorted()
        assertEquals(findings(first),findings(second))
    }
    @org.robolectric.annotation.GraphicsMode(org.robolectric.annotation.GraphicsMode.Mode.NATIVE)
    @Test fun exportKeepsLongGuidanceAndAllActions(){
        val place=XuanKongLocatedPlace("long",0,"Room ".repeat(12000),XuanKongPlaceKind.ROOM,FloorplanRoomType.STUDY)
        val snapshot=TianJiAnalysisSnapshot(345.0,9,false,date).capturing(XuanKongHomeContext(places=listOf(place)),"long",emptyList(),null)
        val image=TianJiShuEngine.instance.generateScrollImage(context,345.0,"","",isPro=true,analysis=snapshot)
        try {assertEquals(1080,image.width);assertTrue("Report must grow beyond its former fixed canvas: ${image.height}",image.height>15000)}finally {image.recycle()}
    }
}
