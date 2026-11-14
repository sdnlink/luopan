package com.example.yiijingcompass

import android.graphics.PointF
import android.graphics.RectF
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28])
class IOSParityTests {
    private fun date(value:String)=Date.from(Instant.parse(value))
    @Before fun setup(){LocalizationManager.instance.init(RuntimeEnvironment.getApplication())}
    @Test fun rectangularPlanRestoresAspectBeforeBearing(){
        val from=PointF(.5f,.5f);val to=PointF(.7f,.3f)
        assertEquals(71.565051177,GeometryUtils.bearing(from,to,3f),.0001)
        for(ratio in listOf(1f/3,1f,3f)){
            val rect=GeometryUtils.aspectFitRect(ratio,RectF(40f,20f,1040f,760f))
            assertEquals(ratio,rect.width()/rect.height(),.00001f)
            val a=PointF(rect.left+from.x*rect.width(),rect.top+from.y*rect.height())
            val b=PointF(rect.left+to.x*rect.width(),rect.top+to.y*rect.height())
            assertEquals(GeometryUtils.bearing(from,to,ratio),GeometryUtils.bearing(a,b),.0001)
        }
    }
    @Test fun polygonSharedEdgesAndVerticesCountAsInside(){
        val points=listOf(PointF(0f,0f),PointF(1f,0f),PointF(1f,1f),PointF(0f,1f))
        assertTrue(GeometryUtils.polygonContains(PointF(1f,.5f),points))
        assertTrue(GeometryUtils.polygonContains(PointF(0f,0f),points))
        assertFalse(GeometryUtils.polygonContains(PointF(1.1f,.5f),points))
        assertFalse(GeometryUtils.polygonContains(PointF(.1f,.1f),emptyList()))
    }
    @Test fun affineRoomEditTransformsPolygonWithBounds(){
        val room=FloorplanRoom("room","Room",FloorplanRoomType.STUDY,RectF(0f,0f,.5f,.5f),listOf(PointF(0f,0f),PointF(.5f,0f),PointF(0f,.5f)))
        val changed=room.transformed(RectF(.25f,.25f,.5f,.75f))
        assertEquals(.25f,changed.polygonPoints!![0].x,.00001f)
        assertEquals(.75f,changed.polygonPoints!![2].y,.00001f)
    }
    @Test fun trueSolarClockDoesNotIncludeSummerTime(){
        val d=date("2026-07-01T16:00:00Z");val engine=SolarTimeCalculator.instance
        val ny=engine.calculate(d,-74.006,TimeZone.getTimeZone("America/New_York"))
        val utc=engine.calculate(d,-74.006,TimeZone.getTimeZone("UTC"))
        assertTrue(ny.trueSolarTimeString.startsWith("11:00:"))
        assertEquals(ny.trueSolarTimeString,utc.trueSolarTimeString)
        assertEquals(ny.dayPillar,utc.dayPillar)
        assertEquals(240.0,ny.timeOffsetMinutes-utc.timeOffsetMinutes,.000001)
    }
    @Test fun solarClockIsContinuousAcrossDST(){
        val engine=SolarTimeCalculator.instance;val zone=TimeZone.getTimeZone("America/New_York")
        val before=engine.calculate(date("2026-03-08T06:59:59Z"),-74.006,zone)
        val after=engine.calculate(date("2026-03-08T07:00:00Z"),-74.006,zone)
        fun seconds(value:String)=value.split(":").map(String::toInt).let {it[0]*3600+it[1]*60+it[2]}
        assertEquals(1,seconds(after.trueSolarTimeString)-seconds(before.trueSolarTimeString))
    }
    @Test fun civilYearMonthDoNotDependOnSolarLongitude(){
        val engine=SolarTimeCalculator.instance
        for(instant in listOf("2026-02-03T12:00:00Z","2026-02-05T12:00:00Z")){
            val a=engine.calculate(date(instant),-170.0).baziGanzhi.split(" ").take(2)
            val b=engine.calculate(date(instant),170.0).baziGanzhi.split(" ").take(2)
            assertEquals(a,b)
        }
    }
    @Test fun oneZiHourUsesOneQimenBureauAcrossMidnight(){
        val engine=QimenEngine.instance;val zone=TimeZone.getTimeZone("Asia/Shanghai")
        val a=engine.calculateChart(date("2026-08-19T15:30:00Z"),timeZone=zone)
        val b=engine.calculateChart(date("2026-08-19T16:30:00Z"),timeZone=zone)
        assertEquals(a.juNumber,b.juNumber);assertEquals(a.cells.map {it.tianStem},b.cells.map {it.tianStem})
        assertEquals(a.shichen,b.shichen)
    }
    @Test fun qimenTimeKeyDistinguishesDSTRepeatedHour(){
        val zone=TimeZone.getTimeZone("America/New_York")
        val a=QimenEngine.instance.chartTimeKey(date("2026-11-01T05:30:00Z"),zone)
        val b=QimenEngine.instance.chartTimeKey(date("2026-11-01T06:30:00Z"),zone)
        assertEquals(a.hour,b.hour);assertNotEquals(a.utcOffset,b.utcOffset)
    }
    @Test fun birthGuaFiveFollowsGenderSubstitution(){
        for(year in 1900..2099){
            assertTrue(UserKuaProfileManager.calcGuaNumber(year,true) in listOf(1,2,3,4,6,7,8,9))
            assertTrue(UserKuaProfileManager.calcGuaNumber(year,false) in listOf(1,2,3,4,6,7,8,9))
        }
        assertEquals(9,UserKuaProfileManager.calcGuaNumber(1991,true))
        assertEquals(6,UserKuaProfileManager.calcGuaNumber(1991,false))
    }
    @Test fun familyMigrationRepairsIDsAndDoesNotChangeThemAgain(){
        val json=org.json.JSONArray("""[{"id":"same","role":"son","birthYear":2000,"isMale":true},{"id":"same","role":"son","birthYear":2002,"isMale":true},{"role":"daughter","birthYear":2003,"isMale":false}]""")
        val people=UserKuaProfileManager.restoringFamilyMembers(json)
        assertEquals(3,people.map {it.id}.toSet().size)
        val restored=UserKuaProfileManager.restoringFamilyMembers(org.json.JSONArray(people.map {it.toJson()}))
        assertEquals(people.map {it.id},restored.map {it.id})
    }
    @Test fun familyAllocationDoesNotAssignKitchensAndRequiresAccess(){
        val rooms=listOf(FloorplanRoom("k","Kitchen",FloorplanRoomType.KITCHEN,RectF(.6f,.1f,.9f,.4f)))
        val people=listOf(FamilyRoomPerson("owner","Owner","坎"))
        assertTrue(FamilyRoomAllocationEngine.recommend(rooms,people,PointF(.5f,.5f),0.0,1f,true).isEmpty())
        assertTrue(FamilyRoomAllocationEngine.resolve(null,rooms,people,PointF(.5f,.5f),0.0,1f,false).isEmpty())
    }
    @Test fun changingBedroomToStudyRemovesItsOldAssignments(){
        val a=listOf(FamilyRoomAssignment("p","room"))
        assertTrue(FamilyRoomAllocationEngine.afterChangingRoomUse(a,"room",FloorplanRoomType.MASTER_BEDROOM,FloorplanRoomType.STUDY)!!.isEmpty())
        assertEquals(a,FamilyRoomAllocationEngine.afterChangingRoomUse(a,"room",FloorplanRoomType.MASTER_BEDROOM,FloorplanRoomType.SECOND_BEDROOM))
    }
    @Test fun allStarPairsHaveOneOfFiveRelations(){
        val counts=mutableMapOf<XuanKongStarPair.Relation,Int>()
        for(a in 1..9)for(b in 1..9){val pair=XuanKongStarPair(a,b);counts[pair.relation]=(counts[pair.relation] ?: 0)+1
            assertTrue(TraditionalEvidenceCatalog.pair(a,b,"test").isNotEmpty())}
        assertEquals(81,counts.values.sum());assertEquals(5,counts.size)
    }
    @Test fun cautionHasPriorityEvenInPeriodsTwoAndFive(){
        val state=Mountain24Data.instance.resolveHeadingState(0.0)
        for(period in listOf(2,5)){
            val chart=FlyingStarsEngine.instance.calculateChart(period,state.sittingMountain,state.facingMountain)
            chart.palaces.filter {it.isShaWuHuang||it.isShaErHei}.forEach {assertEquals(XuanKongSectorUse.QUIET,it.suggestedUse)}
        }
    }
    @Test fun projectionRespectsRollAndCandidateEdges(){
        val projection=ARTargetProjection(60.0,1.5)
        val pose=ARCapturePose(90.0,0.0,projection)
        assertEquals(90.0,pose.bearing(PointF(.5f,.5f)),.0001)
        assertEquals(0.0,pose.elevation(PointF(.5f,.5f)),.0001)
        assertTrue(pose.isCompatible(ARCapturePose(92.0,0.0,projection)))
        assertFalse(pose.isCompatible(ARCapturePose(98.0,0.0,projection)))
        val p=ARTargetProjection.targetPoint(PointF(0f,1f),PointF(-2f,2f),PointF(100f,100f),PointF(20f,20f))
        assertEquals(.1f,p.x,.0001f);assertEquals(.9f,p.y,.0001f)
    }
    @Test fun houseFacingRequiresEntranceOrExplicitInput(){
        assertNull(HouseSpatialSurveyEngine.resolveHouseFacing(emptyList(),Vec3f(0f,0f,0f),120.0))
        assertEquals(30.0,HouseSpatialSurveyEngine.resolveHouseFacing(emptyList(),Vec3f(0f,0f,0f),120.0,390.0)!!,.000001)
        val door=SpatialOpening3D(type=SpatialOpeningType.ENTRANCE_DOOR,position=Vec3f(0f,1f,-2f),normal=Vec3f(0f,0f,-1f),width=.9f,height=2f)
        assertEquals(45.0,HouseSpatialSurveyEngine.resolveHouseFacing(listOf(door),Vec3f(0f,0f,0f),45.0)!!,.0001)
    }
    @Test fun mappingRejectsAnotherSurveyAndRestoresPaddedCoordinates(){
        val mapping=FloorplanSurveyMapping("A",0.0,0.0,10.0,20.0,.1)
        assertNull(mapping.point(0f,0f,"B"))
        assertEquals(.5f,mapping.point(5f,10f,"A")!!.x,.000001f)
        assertEquals(.9f,mapping.point(10f,20f,"A")!!.y,.000001f)
    }
    @Test fun generalDayNeverClaimsSittingMountainAnalysis(){
        val d=date("2026-11-10T12:00:00Z")
        assertNull(ZeRiEngine.instance.analyzeGeneralDay(d).sittingClashWarning)
        val hours=ZeRiEngine.instance.calculateTwelveShichen(d)
        assertEquals(12,hours.size);assertEquals(6,hours.count {it.isAuspicious})
        assertTrue(WidgetAlmanacBuilder.make(d).isGeneralDay)
    }
    @Test fun propertySwitchInvalidatesStaleMeasurementWrites(){
        val store=ShaSurveyStore.instance;store.init(RuntimeEnvironment.getApplication())
        val old=store.propertyID
        assertTrue(store.replaceProperty(null,null,emptyList()))
        assertNotEquals(old,store.propertyID)
        assertFalse(store.replaceProperty(null,null,emptyList(),expectedPropertyID=old))
        assertTrue(store.records.isEmpty());assertNull(store.latestInterior)
    }
    @Test fun exactSolarTermBoundariesAreSortedAndWithinOneYear(){
        val start=date("2026-01-01T00:00:00Z")
        val terms=SolarTimeCalculator.instance.upcomingSolarTerms(start,24)
        assertEquals(24,terms.size)
        assertTrue(terms.first().date.after(start));assertTrue(terms.last().date.before(Date(start.time+366*86400000L)))
        assertEquals(terms.map {it.date.time}.sorted(),terms.map {it.date.time})
    }
}
