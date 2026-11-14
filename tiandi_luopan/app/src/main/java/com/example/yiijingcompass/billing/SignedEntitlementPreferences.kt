package com.example.yiijingcompass.billing

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/** Android counterpart of the signed StoreKit consumable ledger. The HMAC key
 * remains in Android Keystore. A missing/inaccessible key never authorizes an
 * unsigned balance or generates a replacement for an existing signed ledger. */
internal class SignedEntitlementPreferences private constructor(private val raw:SharedPreferences,private val key:SecretKey):SharedPreferences {
    companion object {
        private const val SEAL="_ledger_signature"
        private const val ALIAS="yanxiang.entitlement.ledger.v1"
        internal var keyProviderForTests:(()->SecretKey)?=null
        fun open(context:Context):SignedEntitlementPreferences {
            val raw=context.getSharedPreferences("tianji_entitlements",Context.MODE_PRIVATE)
            val key=keyProviderForTests?.invoke() ?: run {
                val store=KeyStore.getInstance("AndroidKeyStore").apply {load(null)}
                (store.getKey(ALIAS,null) as? SecretKey) ?: run {
                    check(!raw.contains(SEAL)){"Existing paid ledger key unavailable"}
                    KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256,"AndroidKeyStore").apply {
                        init(KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY).setDigests(KeyProperties.DIGEST_SHA256).build())
                    }.generateKey()
                }
            }
            return SignedEntitlementPreferences(raw,key).apply {
                check(valid()||raw.all.isEmpty()||!raw.contains(SEAL)){"Paid ledger verification failed"}
                // Legacy JavaScript-driven flags were not signed purchases.
                if(raw.all.isNotEmpty()&&!raw.contains(SEAL))check(raw.edit().clear().commit())
            }
        }
    }
    private fun signature(values:Map<String,*>):String {
        val mac=Mac.getInstance("HmacSHA256");mac.init(key)
        val canonical=values.filterKeys {it!=SEAL}.toSortedMap().entries.joinToString("\n"){(k,v)->
            val value=if(v is Set<*>)v.map {it.toString()}.sorted().joinToString("\u0000") else v.toString()
            val type=when(v){is Set<*>->"set";is String->"string";is Int->"int";is Long->"long";is Float->"float";is Boolean->"bool";else->"invalid"}
            "${k.length}:$k:$type:${value.length}:$value"
        }
        return Base64.encodeToString(mac.doFinal(canonical.toByteArray()),Base64.NO_WRAP)
    }
    private fun valid():Boolean=raw.all.isEmpty()||raw.getString(SEAL,null)?.let {java.security.MessageDigest.isEqual(it.toByteArray(),signature(raw.all).toByteArray())}==true
    @Synchronized private fun values():Map<String,*> {check(valid()){ "Paid ledger verification failed" };return raw.all.filterKeys {it!=SEAL}}
    override fun getAll():MutableMap<String,*> = values().toMutableMap()
    override fun contains(key:String)=values().containsKey(key)
    override fun getString(key:String,defValue:String?)=values()[key] as? String ?: defValue
    override fun getStringSet(key:String,defValues:MutableSet<String>?):MutableSet<String>? = (values()[key] as? Set<*>)?.filterIsInstance<String>()?.toMutableSet() ?: defValues
    override fun getInt(key:String,defValue:Int)=values()[key] as? Int ?: defValue
    override fun getLong(key:String,defValue:Long)=values()[key] as? Long ?: defValue
    override fun getFloat(key:String,defValue:Float)=values()[key] as? Float ?: defValue
    override fun getBoolean(key:String,defValue:Boolean)=values()[key] as? Boolean ?: defValue
    override fun registerOnSharedPreferenceChangeListener(listener:SharedPreferences.OnSharedPreferenceChangeListener)=raw.registerOnSharedPreferenceChangeListener(listener)
    override fun unregisterOnSharedPreferenceChangeListener(listener:SharedPreferences.OnSharedPreferenceChangeListener)=raw.unregisterOnSharedPreferenceChangeListener(listener)
    override fun edit():SharedPreferences.Editor=Editor()
    private inner class Editor:SharedPreferences.Editor {
        private val changes=mutableMapOf<String,Any?>();private var clear=false
        override fun putString(key:String,value:String?)=apply {changes[key]=value}
        override fun putStringSet(key:String,values:MutableSet<String>?)=apply {changes[key]=values?.toSet()}
        override fun putInt(key:String,value:Int)=apply {changes[key]=value}
        override fun putLong(key:String,value:Long)=apply {changes[key]=value}
        override fun putFloat(key:String,value:Float)=apply {changes[key]=value}
        override fun putBoolean(key:String,value:Boolean)=apply {changes[key]=value}
        override fun remove(key:String)=apply {changes[key]=null}
        override fun clear()=apply {clear=true}
        override fun apply(){commit()}
        override fun commit():Boolean=synchronized(this@SignedEntitlementPreferences){runCatching {
            val data=if(clear)mutableMapOf<String,Any>() else values().mapValues {it.value as Any}.toMutableMap()
            changes.forEach {(key,value)->if(value==null)data.remove(key) else data[key]=value}
            data.remove(SEAL)
            val seal=signature(data);val editor=raw.edit().clear()
            data.forEach {(key,value)->when(value){is String->editor.putString(key,value);is Int->editor.putInt(key,value);is Long->editor.putLong(key,value);is Float->editor.putFloat(key,value);is Boolean->editor.putBoolean(key,value);is Set<*>->editor.putStringSet(key,value.filterIsInstance<String>().toSet());else->error("Invalid ledger value")}}
            editor.putString(SEAL,seal).commit()
        }.getOrDefault(false)}
    }
}
