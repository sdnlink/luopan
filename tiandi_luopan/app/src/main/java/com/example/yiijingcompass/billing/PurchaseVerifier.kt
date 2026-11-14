package com.example.yiijingcompass.billing

import android.util.Base64
import com.android.billingclient.api.Purchase
import com.example.yiijingcompass.BuildConfig
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

object PurchaseVerifier {
    val configured get()=BuildConfig.GOOGLE_PLAY_LICENSE_KEY.isNotBlank()
    fun verify(purchase:Purchase):Boolean {
        if(!configured||purchase.purchaseState!=Purchase.PurchaseState.PURCHASED)return false
        return verifySignedPayload(purchase.originalJson,purchase.signature,BuildConfig.GOOGLE_PLAY_LICENSE_KEY,BuildConfig.APPLICATION_ID)
    }
    internal fun verifySignedPayload(json:String,encodedSignature:String,encodedKey:String,packageName:String):Boolean {
        if(encodedKey.isBlank())return false
        return runCatching {
            val payload=JSONObject(json)
            if(payload.optString("packageName")!=packageName||payload.optString("purchaseToken",payload.optString("token")).isBlank())return false
            val key=KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.decode(encodedKey,Base64.DEFAULT)))
            val signature=Signature.getInstance("SHA1withRSA")
            signature.initVerify(key);signature.update(json.toByteArray(Charsets.UTF_8))
            signature.verify(Base64.decode(encodedSignature,Base64.DEFAULT))
        }.getOrDefault(false)
    }
}
