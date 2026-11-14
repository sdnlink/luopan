package com.example.yiijingcompass

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import android.os.Looper
import android.util.Base64
import com.example.yiijingcompass.billing.*
import com.example.yiijingcompass.model.*
import com.example.yiijingcompass.sensor.CompassMotionManager
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.Shadows.shadowOf
import java.time.Instant
import java.util.*
import javax.crypto.spec.SecretKeySpec
import kotlin.math.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28])
class SpatialAndStateParityTests {
    private val context get()=RuntimeEnvironment.getApplication() as Context
    @Before fun setup(){
        LocalizationManager.instance.init(context);LocalizationManager.instance.setLanguage(context,AppLanguage.EN)
        context.getSharedPreferences("tianji_entitlements",0).edit().clear().commit()
        SignedEntitlementPreferences.keyProviderForTests={SecretKeySpec(ByteArray(32){9},"HmacSHA256")}
        UserEntitlementsManager.instance.init(context)
        ShaSurveyStore.instance.init(context)
    }
    @Test fun cancelledReservationDoesNotReleaseAnotherAndCommitIsIdempotent(){
        val store=UserEntitlementsManager.instance
        for(token in listOf("one","two"))assertTrue(store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,token))
        val a=store.reserveTianjiCredit()!!;val b=store.reserveTianjiCredit()!!
        repeat(10){assertNull(store.reserveTianjiCredit())}
        store.refundTianjiCreditReservation(a);store.refundTianjiCreditReservation(a);assertEquals(1,store.exportCredits)
        store.commitTianjiCreditReservation(b);store.refundTianjiCreditReservation(b);assertEquals(1,store.exportCredits)
        store.init(context);assertEquals(1,store.exportCredits)
    }
    @Test fun floorplanFailedSaveNeverSpendsItsCredit(){
        val store=UserEntitlementsManager.instance;store.applyVerifiedPurchase(InAppProductId.FLOORPLAN_SINGLE.productId,"credit")
        assertFalse(store.acquireFloorplanAccess("A"){false});assertEquals(1,store.floorplanCredits);assertFalse(store.hasFloorplanAccess("A"))
        assertTrue(store.acquireFloorplanAccess("A"){true});assertEquals(0,store.floorplanCredits)
    }
    @Test fun unsignedOrTamperedEntitlementsDoNotUnlock(){
        val store=UserEntitlementsManager.instance;store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,"credit")
        context.getSharedPreferences("tianji_entitlements",0).edit().putInt("export_credits",9999).commit()
        assertFalse(store.storageReady());store.init(context);assertEquals(0,store.exportCredits);assertFalse(store.isVip)
    }
    @Test fun missingPaidLedgerKeyIsNotReplaced(){
        val store=UserEntitlementsManager.instance;store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,"credit")
        SignedEntitlementPreferences.keyProviderForTests={throw IllegalStateException("temporarily locked")}
        store.init(context);assertFalse(store.storageReady());assertEquals(0,store.exportCredits)
        SignedEntitlementPreferences.keyProviderForTests={SecretKeySpec(ByteArray(32){9},"HmacSHA256")}
        store.init(context);assertEquals(1,store.exportCredits)
    }
    @Test fun activeReservationSurvivesRepeatedStorageRefresh(){
        val store=UserEntitlementsManager.instance;store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,"credit")
        val token=store.reserveTianjiCredit()!!;repeat(3){store.init(context);assertEquals(0,store.exportCredits)}
        store.refundTianjiCreditReservation(token);assertEquals(1,store.exportCredits)
    }
    @Test fun portableIOSBackupPreservesGeometryImageAndAppleDate(){
        val payload="""{"id":"old","title":"iOS home","createdAt":0,"layout":{"rooms":[{"id":"r","name":"Study","type":"书房","rect":[[0.1,0.2],[0.4,0.3]],"polygonPoints":[[0.1,0.2],[0.5,0.2],[0.1,0.5]],"palaceName":"","inspectionTitle":"","inspectionLevel":"平","inspectionLore":"","inspectionAdvice":""}],"centroidX":0.5,"centroidY":0.5,"compassRotation":30,"isSyncWithCompass":false,"hasFloorplanAccess":true},"backupImageData":"aW1hZ2U="}"""
        val record=PortableCaseCodec.decode(payload)
        assertEquals(978307200000L,record.createdAt.time);assertEquals(FloorplanRoomType.STUDY,record.layout.rooms.first().type)
        assertEquals(.5f,record.layout.rooms.first().rect.right,.00001f);assertEquals(3,record.layout.rooms.first().polygonPoints!!.size)
        assertEquals("image",String(Base64.decode(record.backupImageBase64,Base64.DEFAULT)));assertFalse(record.layout.hasFloorplanAccess)
        assertTrue(ProjectCodec.valid(PortableCaseCodec.decode(PortableCaseCodec.encode(record)).layout))
    }
    @Test fun directLayoutBackupCanRoundTrip(){
        val layout=SavedFloorplanLayout(rooms=listOf(FloorplanRoom("r","Study",FloorplanRoomType.STUDY,RectF(.1f,.1f,.5f,.5f))),compassRotation=45.0)
        val record=PortableCaseCodec.decode(ProjectCodec.gson.toJson(layout));assertEquals(45.0,record.layout.compassRotation,.000001)
    }
    @Test fun concurrentCaseStoresNeverResurrectDeletedCases(){
        context.getSharedPreferences("floorplan_cases",0).edit().clear().commit()
        val a=FloorplanCaseStore(context);val b=FloorplanCaseStore(context)
        a.insert(FloorplanCaseRecord(id="A",title="A",layout=SavedFloorplanLayout()))
        b.insert(FloorplanCaseRecord(id="B",title="B",layout=SavedFloorplanLayout()))
        assertEquals(setOf("A","B"),a.records.map {it.id}.toSet())
        a.remove("A");b.rename("B","new");assertEquals(listOf("B"),a.records.map {it.id})
    }
    @Test fun threeLandmarksRecoverRotationTranslationAndRejectWrongPoints(){
        val original=listOf(Vec3f(0f,0f,0f),Vec3f(4f,0f,0f),Vec3f(4f,0f,3f))
        fun transform(p:Vec3f)=Vec3f(10-p.z,1+p.y,7+p.x)
        val current=original.map(::transform);val fit=SpatialMapRegistration.fit(original,current)!!
        assertEquals(0.0,fit.errorMeters,.000001)
        assertEquals(transform(Vec3f(2f,0f,1f)),fit.point(Vec3f(2f,0f,1f)))
        assertEquals(0.0,fit.heading(90.0),.000001)
        assertNull(SpatialMapRegistration.fit(original,listOf(Vec3f(0f,0f,0f),Vec3f(10f,0f,0f),Vec3f(0f,0f,2f))))
    }
    @Test fun copiedDepthUsesViewportMappingAndRejectsUnavailableSamples(){
        val depth=ARCapturedDepth(3,3,floatArrayOf(0f,2f,0f,2f,3f,2f,0f,2f,0f),floatArrayOf(1f,0f,0f,0f,1f,0f))
        assertEquals(2f,depth.sample(PointF(.5f,.5f))!!,.00001f)
        assertNull(depth.sample(PointF(-1f,.5f)))
        assertNull(depth.copy(meters=FloatArray(9)).sample(PointF(.5f,.5f)))
    }
    @Test fun captureMatrixMatchesHeadingAndRollConstructor(){
        val identity=floatArrayOf(1f,0f,0f,0f,0f,1f,0f,0f,0f,0f,1f,0f,0f,0f,0f,1f)
        val projection=ARTargetProjection(65.0,.75)
        val pose=ARCapturePose(identity,17.0,projection)
        assertTrue(pose.isCompatible(ARCapturePose(17.0,0.0,projection)))
        assertEquals(17.0,pose.bearing(PointF(.5f,.5f)),.00001)
    }
    @Test fun chartLockNeverFreezesPhysicalCameraOrTilt(){
        val motion=CompassMotionManager.instance;motion.start(context);motion.lockAtFacingAngle(123.0)
        val matrix=floatArrayOf(1f,0f,0f,0f,0f,-1f,0f,1f,0f)
        motion.processRotationMatrix(matrix)
        assertEquals(123.0,motion.heading,.000001)
        assertNotNull(motion.physicalCameraHeading());assertNotNull(motion.physicalCameraElevation())
        assertEquals(0.0,motion.physicalCameraHeading()!!,.00001)
        assertNull(motion.physicalCameraHeading(System.currentTimeMillis()+4000))
        motion.isLocked=false;motion.stop()
    }
    @Test fun depthRejectsFlatDoorFrameAndConfirmsPairedMasses(){
        fun region(left:Float,right:Float)=ImageGeometryRegion(listOf(PointF(left,.1f),PointF(right,.1f),PointF(right,.9f),PointF(left,.9f)),.95)
        val regions=listOf(region(.15f,.35f),region(.65f,.85f))
        val base=ARSceneEvidence(true,true,true,true,.9,5.0,2.0,2.0)
        assertEquals("tianzhan",OnDeviceShaAnalyzer.instance.classify(regions,base)!!.shaID)
        val flat=base.copy(depthSampleMeters=1.0,leftDepthMeters=1.0,rightDepthMeters=1.0)
        assertNull(OnDeviceShaAnalyzer.instance.classify(regions,flat))
    }
    @Test fun repeatedDetectorPassesRejectInconsistentTarget(){
        val a=ShaAnalysisResult("luchong",.8,.5,.5,1,"")
        assertTrue(OnDeviceShaAnalyzer.instance.isConsistent(a,a.copy(targetX=.55)))
        assertFalse(OnDeviceShaAnalyzer.instance.isConsistent(a,a.copy(targetX=.8)))
        assertFalse(OnDeviceShaAnalyzer.instance.isConsistent(a,a.copy(shaID="baihu")))
    }
    @Test fun subscriptionPeriodsPreserveActualValuesAcrossEightLanguages(){
        for(lang in AppLanguage.values().filter {it!=AppLanguage.AUTO}){
            LocalizationManager.instance.setLanguage(context,lang)
            assertTrue(SubscriptionDisclosure.period("P3M")!!.contains("3"))
            assertNotEquals(SubscriptionDisclosure.period("P1M"),SubscriptionDisclosure.period("P3M"))
        }
        assertNull(SubscriptionDisclosure.period("P0Y"));assertNull(SubscriptionDisclosure.period("unknown"))
    }
    @Test fun calendarKeysDistinguishHomesAndYears(){
        assertNotEquals(AuspiciousReminderContext("A","子",ZeRiActivityCategory.ALL).key(Date.from(Instant.parse("2026-05-01T00:00:00Z"))),AuspiciousReminderContext("B","子",ZeRiActivityCategory.ALL).key(Date.from(Instant.parse("2026-05-01T00:00:00Z"))))
    }
    @Test fun deepLinksPreserveIOSRoutesWithoutAcceptingUnknownSchemes(){
        fun route(value:String)=AppNavigationRoute.resolve(Intent(Intent.ACTION_VIEW,Uri.parse(value)))
        assertEquals(AppNavigationRoute(3,"qimen"),route("tiandiluopan://tab?index=2&sub=qimen"))
        assertEquals(AppNavigationRoute(2),route("tiandiluopan://floorplan"))
        assertNull(route("https://evil.test/analysis?feature=qimen"));assertNull(route("tiandiluopan://analysis?feature=unknown"))
    }
    @Test fun renderLanguageIsCapturedWithoutChangingUserPreference(){
        val manager=LocalizationManager.instance;manager.setLanguage(context,AppLanguage.EN)
        val english=manager.t("tab_floorplan")
        assertNotEquals(english,manager.withLanguage(AppLanguage.ZH_HANS){manager.t("tab_floorplan")})
        assertEquals(english,manager.t("tab_floorplan"))
        runCatching {manager.withLanguage(AppLanguage.JA){throw IllegalStateException("render failed")}}
        assertEquals(AppLanguage.EN,manager.effectiveLanguage)
    }
    @Test fun metricDXFUsesTruePolygonAndDimensions(){
        val room=FloorplanRoom("r","Triangle",FloorplanRoomType.STUDY,RectF(0f,0f,1f,1f),listOf(PointF(0f,0f),PointF(1f,0f),PointF(0f,1f)))
        val dxf=FloorplanEngine.instance.exportMetricDXF(listOf(room),PointF(.5f,.5f),12.0,8.0)
        assertEquals(3,Regex("0\nLINE\n").findAll(dxf).count());assertTrue(dxf.contains("12.000000"));assertTrue(dxf.contains("-8.000000"))
    }
    @Test fun cameraLeaseCannotBeStolenAcrossWindows(){
        val lease=com.example.yiijingcompass.ui.CameraLease
        assertTrue(lease.acquire("A"));assertTrue(lease.acquire("A"));assertFalse(lease.acquire("B"))
        lease.release("B");assertTrue(lease.owns("A"));lease.release("A");assertTrue(lease.acquire("B"));lease.release("B")
    }
    @Test fun sourceSelectionPreventsOtherHouseDataFromLeakingIntoCompassReport(){
        val snapshot=TianJiAnalysisSnapshot(30.0,8,false).capturing(null,null,emptyList(),null)
        assertTrue(snapshot.hasSpatialSnapshot);assertNull(snapshot.homeContext);assertNull(snapshot.capturedPanoramaArchive);assertTrue(snapshot.capturedFloorplanReport.isEmpty())
    }
}
