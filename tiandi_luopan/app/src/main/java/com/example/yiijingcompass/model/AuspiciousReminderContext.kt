package com.example.yiijingcompass.model

import java.security.MessageDigest
import java.util.*

data class AuspiciousReminderContext(val propertyKey:String,val sittingMountain:String,val category:ZeRiActivityCategory=ZeRiActivityCategory.ALL){
    fun key(date:Date,timeZone:TimeZone=TimeZone.getDefault()):String {
        val calendar=GregorianCalendar(timeZone).apply {time=date}
        val identity="$propertyKey\u0000$sittingMountain\u0000${category.name}"
        val digest=MessageDigest.getInstance("SHA-256").digest(identity.toByteArray()).take(12).joinToString(""){"%02x".format(it)}
        return String.format(Locale.ROOT,"%04d-%02d-%02d-",calendar.get(Calendar.YEAR),calendar.get(Calendar.MONTH)+1,calendar.get(Calendar.DAY_OF_MONTH))+digest
    }
}
