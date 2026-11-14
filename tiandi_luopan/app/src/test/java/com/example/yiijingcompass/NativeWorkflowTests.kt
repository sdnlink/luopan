package com.example.yiijingcompass

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.util.Base64
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import com.example.yiijingcompass.billing.PurchaseVerifier
import com.example.yiijingcompass.model.*
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28])
class NativeWorkflowTests {
    private val context get()=RuntimeEnvironment.getApplication() as Context
    @Before fun setup(){
        LocalizationManager.instance.init(context)
        LocalizationManager.instance.setLanguage(context,AppLanguage.EN)
        context.getSharedPreferences("native_onboarding",0).edit().putBoolean("completed",true).commit()
        context.getSharedPreferences("tianji_entitlements",0).edit().clear().commit()
        com.example.yiijingcompass.billing.SignedEntitlementPreferences.keyProviderForTests={javax.crypto.spec.SecretKeySpec(ByteArray(32){7},"HmacSHA256")}
        UserEntitlementsManager.instance.init(context)
        ShaSurveyStore.instance.init(context)
    }
    private fun texts(view:View):List<TextView> = listOfNotNull(view as? TextView)+(if(view is ViewGroup)(0 until view.childCount).flatMap {texts(view.getChildAt(it))} else emptyList())
    private fun click(activity:MainActivity,key:String){
        val text=LocalizationManager.instance.t(key)
        val button=texts(activity.window.decorView).filterIsInstance<Button>().firstOrNull {it.text.toString()==text}
        assertNotNull("Missing native button: $key",button);button!!.performClick()
    }
    @Test fun allFiveTabsStartAsNativeViews(){
        for(tab in 0..4){
            val controller=Robolectric.buildActivity(MainActivity::class.java,Intent(context,MainActivity::class.java).putExtra("tab",tab)).setup()
            assertTrue(texts(controller.get().window.decorView).isNotEmpty())
            fun web(view:View):Boolean=view is android.webkit.WebView||(view is ViewGroup&&(0 until view.childCount).any {web(view.getChildAt(it))})
            assertFalse(web(controller.get().window.decorView));controller.pause().stop().destroy()
        }
    }
    @Test fun analysisMenusAndProfileEditorOpen(){
        val controller=Robolectric.buildActivity(MainActivity::class.java,Intent(context,MainActivity::class.java).putExtra("tab",3)).setup()
        val activity=controller.get()
        for(key in listOf("xuankong_stars","bazhai_tab_title","sanhe_tab_title","purple_white","qimen_dunjia","bz_tool_owner","bz_tool_dates")){
            click(activity,key)
            assertTrue(texts(activity.window.decorView).size>5)
            click(activity,"tab_analysis")
        }
        controller.pause().stop().destroy()
    }
    @Test fun signaturesRejectTamperingAndOtherPackages(){
        val pair=KeyPairGenerator.getInstance("RSA").apply {initialize(2048)}.generateKeyPair()
        val key=Base64.encodeToString(pair.public.encoded,Base64.NO_WRAP)
        val payload="""{"packageName":"com.example.yiijingcompass","purchaseToken":"unique-token"}"""
        val signer=Signature.getInstance("SHA1withRSA").apply {initSign(pair.private);update(payload.toByteArray())}
        val signed=Base64.encodeToString(signer.sign(),Base64.NO_WRAP)
        assertTrue(PurchaseVerifier.verifySignedPayload(payload,signed,key,"com.example.yiijingcompass"))
        assertFalse(PurchaseVerifier.verifySignedPayload(payload.replace("unique-token","forged"),signed,key,"com.example.yiijingcompass"))
        assertFalse(PurchaseVerifier.verifySignedPayload(payload,signed,key,"another.package"))
        assertFalse(PurchaseVerifier.verifySignedPayload(payload,signed,"","com.example.yiijingcompass"))
    }
    @Test fun creditsAreIdempotentAndRevokedMembershipCanRestore(){
        val store=UserEntitlementsManager.instance
        assertTrue(store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,"credit"))
        assertTrue(store.applyVerifiedPurchase(InAppProductId.TIANJI_SINGLE.productId,"credit"))
        assertEquals(1,store.exportCredits)
        store.applyVerifiedPurchase(InAppProductId.VIP_YEARLY.productId,"annual")
        assertTrue(store.isVip);store.reconcileMembership(emptySet());assertFalse(store.isVip)
        assertTrue(store.applyVerifiedPurchase(InAppProductId.VIP_YEARLY.productId,"annual"));assertTrue(store.isVip)
        store.reconcileMembership(emptySet());assertTrue(store.consumeCredit());assertEquals(0,store.exportCredits)
        store.refundExportCredit();assertEquals(1,store.exportCredits)
    }
    @Test fun floorplanPurchaseIsConsumedOnceAndGrantsOnlyOneProject(){
        val store=UserEntitlementsManager.instance
        assertFalse(store.acquireFloorplanAccess("A"))
        assertTrue(store.applyVerifiedPurchase(InAppProductId.FLOORPLAN_SINGLE.productId,"floorplan"))
        assertTrue(store.applyVerifiedPurchase(InAppProductId.FLOORPLAN_SINGLE.productId,"floorplan"))
        assertEquals(1,store.floorplanCredits)
        assertTrue(store.acquireFloorplanAccess("A"));assertEquals(0,store.floorplanCredits)
        assertTrue(store.acquireFloorplanAccess("A"));assertFalse(store.hasFloorplanAccess("B"))
        assertFalse(store.acquireFloorplanAccess("B"))
    }
    @Test fun invalidAndDuplicateImportedGeometryIsRejected(){
        val room=FloorplanRoom("id","room",FloorplanRoomType.STUDY,RectF(.1f,.1f,.5f,.5f))
        assertTrue(ProjectCodec.valid(SavedFloorplanLayout(rooms=listOf(room))))
        assertFalse(ProjectCodec.valid(SavedFloorplanLayout(rooms=listOf(room,room))))
        assertFalse(ProjectCodec.valid(SavedFloorplanLayout(rooms=listOf(room.copy(rect=RectF(0f,0f,Float.NaN,1f))))))
    }
    @Test fun plainImagesNeverBecomeDetectedRooms(){
        val bitmap=Bitmap.createBitmap(240,240,Bitmap.Config.ARGB_8888)
        for(color in listOf(Color.WHITE,Color.BLACK)) {bitmap.eraseColor(color);assertTrue(FloorplanImageDetector.detect(bitmap).isEmpty())}
        bitmap.eraseColor(Color.WHITE)
        val paint=Paint().apply {color=Color.BLACK;style=Paint.Style.STROKE;strokeWidth=6f}
        Canvas(bitmap).drawRect(25f,25f,210f,210f,paint)
        val rooms=FloorplanImageDetector.detect(bitmap)
        assertEquals(1,rooms.size);assertTrue(rooms.first().polygonPoints!!.size>=4);bitmap.recycle()
    }
    @Test fun frozenReportIsIndependentOfLaterPropertyChanges(){
        val places=mutableListOf(XuanKongLocatedPlace("r",0,"Bedroom",XuanKongPlaceKind.ROOM,FloorplanRoomType.MASTER_BEDROOM))
        val context=XuanKongHomeContext(places=places)
        val snapshot=TianJiAnalysisSnapshot(123.0,7,true,Date(1785000000000L)).capturing(context,"property-A",emptyList(),null)
        places.clear()
        assertEquals(1,snapshot.homeContext!!.places.size)
        val chart=snapshot.flyingStarsChart();assertEquals(7,chart.period);assertTrue(chart.isTiGua)
        assertEquals("property-A",snapshot.propertyKey)
    }
    @Test fun thaiLocaleDoesNotChangeAstronomicalYears(){
        val before=Locale.getDefault()
        try {
            val date=Date(1785000000000L)
            Locale.setDefault(Locale.US);val year=UserKuaProfileManager.fengShuiYear(date)
            Locale.setDefault(Locale("th","TH"));assertEquals(year,UserKuaProfileManager.fengShuiYear(date))
        }finally {Locale.setDefault(before)}
    }
}
