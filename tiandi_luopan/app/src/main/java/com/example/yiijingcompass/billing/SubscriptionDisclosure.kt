package com.example.yiijingcompass.billing

import com.android.billingclient.api.ProductDetails
import com.example.yiijingcompass.model.LocalizationManager

object SubscriptionDisclosure {
    fun period(raw:String):String? {
        val match=Regex("P([1-9][0-9]*)([DWMY])").matchEntire(raw) ?: return null
        val count=match.groupValues[1].toIntOrNull()?.takeIf {it<=1000} ?: return null
        val unit=mapOf("D" to "day","W" to "week","M" to "month","Y" to "year")[match.groupValues[2]] ?: return null
        return LocalizationManager.instance.t("subscription_period_${unit}_"+if(count==1)"one" else "many").replace("%ld",count.toString()).replace("%d",count.toString())
    }
    fun complete(details:ProductDetails):Boolean = details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.let {phases->
        phases.isNotEmpty()&&phases.all {it.formattedPrice.isNotBlank()&&it.priceCurrencyCode.isNotBlank()&&period(it.billingPeriod)!=null}
    }==true
    fun text(details:ProductDetails):String {
        val lang=LocalizationManager.instance
        val phases=details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList ?: return lang.t("subscription_details_unavailable")
        return phases.mapNotNull {phase->period(phase.billingPeriod)?.let {duration->
            val price=lang.t("subscription_price_per_period").replaceFirst("%@",phase.formattedPrice).replaceFirst("%@",duration)
            price+if(phase.billingCycleCount>0)" × ${phase.billingCycleCount}" else ""
        }}.joinToString(" → ")+"\n"+lang.t("native_subscription_renewal")
    }
}
