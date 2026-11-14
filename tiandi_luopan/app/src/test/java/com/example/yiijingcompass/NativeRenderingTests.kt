package com.example.yiijingcompass

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import com.example.yiijingcompass.billing.SignedEntitlementPreferences
import com.example.yiijingcompass.model.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import javax.crypto.spec.SecretKeySpec

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28],qualifiers="w411dp-h891dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class NativeRenderingTests {
    @Test fun nativePagesRenderWithRealFontsAndCanRecreate(){
        val context=RuntimeEnvironment.getApplication() as Context
        LocalizationManager.instance.init(context);LocalizationManager.instance.setLanguage(context,AppLanguage.EN)
        context.getSharedPreferences("native_onboarding",0).edit().putBoolean("completed",true).commit()
        SignedEntitlementPreferences.keyProviderForTests={SecretKeySpec(ByteArray(32){2},"HmacSHA256")}
        val folder=File("build/native-screenshots").apply {mkdirs()}
        for(tab in listOf(0,2,3)){
            val controller=Robolectric.buildActivity(MainActivity::class.java,Intent(context,MainActivity::class.java).putExtra("tab",tab)).setup().visible()
            val activity=controller.get();val view=activity.window.decorView
            view.measure(View.MeasureSpec.makeMeasureSpec(1080,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(1920,View.MeasureSpec.EXACTLY));view.layout(0,0,1080,1920)
            val bitmap=Bitmap.createBitmap(1080,1920,Bitmap.Config.ARGB_8888);view.draw(Canvas(bitmap))
            File(folder,"tab-$tab.png").outputStream().use {assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))};bitmap.recycle()
            controller.recreate();assertNotNull(controller.get().window.decorView)
            controller.pause().stop().destroy()
        }
    }
}
