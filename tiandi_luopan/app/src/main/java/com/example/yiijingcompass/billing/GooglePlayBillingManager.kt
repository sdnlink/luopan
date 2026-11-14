package com.example.yiijingcompass.billing

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.android.billingclient.api.*
import com.example.yiijingcompass.model.InAppProductId
import com.example.yiijingcompass.model.UserEntitlementsManager
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * 演象·天机排盘 Google Play 官方计费核心管理器 (BillingClient 6.2+)
 *
 * 遵循 Google Play 最新政策：
 * 1. 严格使用 Google Play In-App Billing 处理所有数字商品交易
 * 2. 支持一次性商品买断、单次算力点数消耗与周期性连续包年订阅
 * 3. 交易状态安全落盘、自动完成确认 (Acknowledge) 与消耗 (Consume)
 * 4. 具备冷启动离线重连机制与订单自动恢复能力 (Restore Purchases)
 */
class GooglePlayBillingManager private constructor() : PurchasesUpdatedListener, BillingClientStateListener {

    companion object {
        private const val TAG = "GooglePlayBilling"
        val instance: GooglePlayBillingManager by lazy { GooglePlayBillingManager() }

        // 一次性商品与消耗品
        val INAPP_PRODUCTS = listOf(
            InAppProductId.PRO_LIFETIME.productId,
            InAppProductId.FLOORPLAN_SINGLE.productId,
            InAppProductId.TIANJI_SINGLE.productId
        )

        val CONSUMABLE_PRODUCTS=setOf(InAppProductId.TIANJI_SINGLE.productId,InAppProductId.FLOORPLAN_SINGLE.productId)

        // 周期性订阅商品
        val SUBS_PRODUCTS = listOf(
            InAppProductId.VIP_YEARLY.productId
        )
    }

    interface BillingEventListener {
        fun onBillingServiceConnected()
        fun onProductDetailsUpdated(products: Map<String, ProductDetails>)
        fun onPurchaseSuccess(productId: String, orderId: String)
        fun onPurchaseFailed(productId: String?, errorCode: Int, message: String)
        fun onPurchasesRestored(restoredProductIds: List<String>)
    }

    private val purchaseGeneration=AtomicLong()
    private var billingClient: BillingClient? = null
    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val isConnecting = AtomicBoolean(false)
    private var isConnected = false

    // 缓存 Google Play 返回的最新商品本地化定价与详情
    private val productDetailsCache = ConcurrentHashMap<String, ProductDetails>()

    // 监听器集合
    private val listeners = mutableListOf<BillingEventListener>()

    fun init(context: Context) {
        if (billingClient != null) return
        appContext = context.applicationContext
        billingClient = BillingClient.newBuilder(context)
            .setListener(this)
            .enablePendingPurchases()
            .build()
        startConnection()
    }

    fun addListener(listener: BillingEventListener) {
        synchronized(listeners) {
            if (!listeners.contains(listener)) {
                listeners.add(listener)
            }
        }
    }

    fun removeListener(listener: BillingEventListener) {
        synchronized(listeners) {
            listeners.remove(listener)
        }
    }

    /**
     * 连接 Google Play 服务
     */
    fun startConnection() {
        val client = billingClient ?: return
        if (isConnected || isConnecting.getAndSet(true)) return

        Log.i(TAG, "Starting Google Play BillingClient connection...")
        try {
            client.startConnection(this)
        } catch (e: Exception) {
            isConnecting.set(false)
            Log.e(TAG, "Failed to initiate Billing connection", e)
        }
    }

    override fun onBillingSetupFinished(billingResult: BillingResult) {
        isConnecting.set(false)
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            isConnected = true
            Log.i(TAG, "Google Play BillingClient setup successful.")
            notifyListeners { it.onBillingServiceConnected() }
            // 1. 查询商品最新定价与元数据
            queryAllProductDetails()
            // 2. 检查与恢复用户历史已购项目
            queryPurchases()
        } else {
            isConnected = false
            Log.w(TAG, "Billing setup failed with code: ${billingResult.responseCode}, msg: ${billingResult.debugMessage}")
            scheduleReconnect()
        }
    }

    override fun onBillingServiceDisconnected() {
        isConnected = false
        isConnecting.set(false)
        Log.w(TAG, "Google Play Billing disconnected. Scheduling reconnect...")
        scheduleReconnect()
    }

    private fun scheduleReconnect() {
        mainHandler.postDelayed({
            if (!isConnected) {
                startConnection()
            }
        }, 3000)
    }

    /**
     * 批量查询 In-App 与 Subscription 商品信息
     */
    fun queryAllProductDetails() {
        val client = billingClient
        if (client == null || !client.isReady) {
            startConnection()
            return
        }

        // 1. 一次性内购商品列表
        val inAppList = INAPP_PRODUCTS.map { pid ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(pid)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }

        val inAppParams = QueryProductDetailsParams.newBuilder()
            .setProductList(inAppList)
            .build()

        client.queryProductDetailsAsync(inAppParams) { result, productDetailsList ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                for (details in productDetailsList) {
                    productDetailsCache[details.productId] = details
                    Log.i(TAG, "Loaded INAPP product: ${details.productId}, price: ${details.oneTimePurchaseOfferDetails?.formattedPrice}")
                }
                notifyListeners { it.onProductDetailsUpdated(productDetailsCache) }
            } else {
                Log.w(TAG, "Failed to query INAPP products: ${result.debugMessage}")
            }
        }

        // 2. 连续包年订阅商品列表
        val subsList = SUBS_PRODUCTS.map { pid ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(pid)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }

        val subsParams = QueryProductDetailsParams.newBuilder()
            .setProductList(subsList)
            .build()

        client.queryProductDetailsAsync(subsParams) { result, productDetailsList ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                for (details in productDetailsList) {
                    productDetailsCache[details.productId] = details
                    val offer = details.subscriptionOfferDetails?.firstOrNull()
                    Log.i(TAG, "Loaded SUBS product: ${details.productId}, price: ${offer?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice}")
                }
                notifyListeners { it.onProductDetailsUpdated(productDetailsCache) }
            } else {
                Log.w(TAG, "Failed to query SUBS products: ${result.debugMessage}")
            }
        }
    }

    /**
     * 发起 Google Play 安全支付
     */
    fun launchPurchaseFlow(activity: Activity, productId: String, onLaunched: ((Boolean, String?) -> Unit)? = null) {
        if(appContext!=null&&!UserEntitlementsManager.instance.storageReady())UserEntitlementsManager.instance.init(appContext!!)
        if(!UserEntitlementsManager.instance.storageReady()){onLaunched?.invoke(false,com.example.yiijingcompass.model.LocalizationManager.instance.t("iap_storage_unavailable"));return}
        if(!PurchaseVerifier.configured){onLaunched?.invoke(false,com.example.yiijingcompass.model.LocalizationManager.instance.t("native_billing_configuration"));return}
        val lang = com.example.yiijingcompass.model.LocalizationManager.instance.effectiveLanguage
        val client = billingClient
        if (client == null || !client.isReady) {
            startConnection()
            val msg = when (lang) {
                com.example.yiijingcompass.model.AppLanguage.EN -> "Connecting to Google Play Store, please try again shortly"
                com.example.yiijingcompass.model.AppLanguage.ZH_HANT -> "Google Play 商店連線中，請稍候重試"
                com.example.yiijingcompass.model.AppLanguage.JA -> "Google Play ストアに接続中です。しばらくしてから再試行してください"
                com.example.yiijingcompass.model.AppLanguage.KO -> "Google Play 스토어에 연결 중입니다. 잠시 후 다시 시도해 주세요"
                com.example.yiijingcompass.model.AppLanguage.VI -> "Đang kết nối Google Play Store, vui lòng thử lại sau"
                com.example.yiijingcompass.model.AppLanguage.TH -> "กำลังเชื่อมต่อ Google Play Store โปรดลองอีกครั้งในภายหลัง"
                com.example.yiijingcompass.model.AppLanguage.ID -> "Menghubungkan ke Google Play Store, silakan coba lagi"
                else -> "Google Play 商店连接中，请稍候重试"
            }
            onLaunched?.invoke(false, msg)
            return
        }

        val details = productDetailsCache[productId]
        if (details == null) {
            queryAllProductDetails()
            val msg = com.example.yiijingcompass.model.LocalizationManager.instance.t("iap_product_loading")
            onLaunched?.invoke(false, msg)
            return
        }

        val productDetailsParamsList = mutableListOf<BillingFlowParams.ProductDetailsParams>()

        if (details.productType == BillingClient.ProductType.SUBS) {
            if(!SubscriptionDisclosure.complete(details)){onLaunched?.invoke(false,com.example.yiijingcompass.model.LocalizationManager.instance.t("subscription_details_unavailable"));return}
            val offerDetails = details.subscriptionOfferDetails?.firstOrNull()
            if (offerDetails == null) {
                val msg = when (lang) {
                    com.example.yiijingcompass.model.AppLanguage.EN -> "Subscription pricing details not found"
                    com.example.yiijingcompass.model.AppLanguage.ZH_HANT -> "未找到該訂閱方案的定價資訊"
                    com.example.yiijingcompass.model.AppLanguage.JA -> "このサブスクリプションの価格情報が見つかりません"
                    com.example.yiijingcompass.model.AppLanguage.KO -> "구독 요금제 가격 정보를 찾을 수 없습니다"
                    com.example.yiijingcompass.model.AppLanguage.VI -> "Không tìm thấy thông tin giá gói đăng ký"
                    com.example.yiijingcompass.model.AppLanguage.TH -> "ไม่พบข้อมูลราคาของแผนการสมัครสมาชิกนี้"
                    com.example.yiijingcompass.model.AppLanguage.ID -> "Informasi harga langganan tidak ditemukan"
                    else -> "未找到该订阅方案的定价信息"
                }
                onLaunched?.invoke(false, msg)
                return
            }
            productDetailsParamsList.add(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(details)
                    .setOfferToken(offerDetails.offerToken)
                    .build()
            )
        } else {
            productDetailsParamsList.add(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(details)
                    .build()
            )
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(productDetailsParamsList)
            .build()

        val billingResult = client.launchBillingFlow(activity, flowParams)
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            onLaunched?.invoke(true, null)
        } else {
            val msg = "调起 Google Play 支付失败 (${billingResult.responseCode}): ${billingResult.debugMessage}"
            Log.e(TAG, msg)
            onLaunched?.invoke(false, msg)
        }
    }

    /**
     * 支付结果接收监听 (PurchasesUpdatedListener)
     */
    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        purchaseGeneration.incrementAndGet()
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                if (purchases != null) {
                    for (purchase in purchases) {
                        handlePurchase(purchase)
                    }
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                Log.i(TAG, "User canceled purchase flow.")
                notifyListeners { it.onPurchaseFailed(null, billingResult.responseCode, "用户已取消支付") }
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                Log.i(TAG, "Item already owned, refreshing entitlements.")
                queryPurchases()
            }
            else -> {
                val err = "Purchase failed: code ${billingResult.responseCode}, ${billingResult.debugMessage}"
                Log.e(TAG, err)
                notifyListeners { it.onPurchaseFailed(null, billingResult.responseCode, billingResult.debugMessage) }
            }
        }
    }

    /**
     * 处理单笔交易：确认 (Acknowledge) 或消耗 (Consume)
     */
    private fun handlePurchase(purchase: Purchase) {
        if(!PurchaseVerifier.verify(purchase))return
        for(productId in purchase.products.filter {it in INAPP_PRODUCTS||it in SUBS_PRODUCTS}){
            if(!UserEntitlementsManager.instance.applyVerifiedPurchase(productId,purchase.purchaseToken)){
                notifyListeners {it.onPurchaseFailed(productId,BillingClient.BillingResponseCode.ERROR,com.example.yiijingcompass.model.LocalizationManager.instance.t("iap_storage_unavailable"))};continue
            }
            if(productId in CONSUMABLE_PRODUCTS){
                billingClient?.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()){result,_->
                    if(result.responseCode==BillingClient.BillingResponseCode.OK)notifyListeners {it.onPurchaseSuccess(productId,purchase.orderId ?: purchase.purchaseToken)}
                }
            }else if(!purchase.isAcknowledged){
                billingClient?.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()){result->
                    if(result.responseCode==BillingClient.BillingResponseCode.OK)notifyListeners {it.onPurchaseSuccess(productId,purchase.orderId ?: purchase.purchaseToken)}
                }
            }else notifyListeners {it.onPurchaseSuccess(productId,purchase.orderId ?: purchase.purchaseToken)}
        }
    }

    /**
     * 查询与恢复购买
     */
    fun queryPurchases(onComplete: ((List<String>) -> Unit)? = null) {
        val client = billingClient
        if (client == null || !client.isReady) {
            startConnection()
            onComplete?.invoke(emptyList())
            return
        }

        val generation=purchaseGeneration.incrementAndGet()
        val restoredIds = mutableListOf<String>()

        // 查询 INAPP 已购
        val inAppParams = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()

        client.queryPurchasesAsync(inAppParams) { result, purchases ->
            if(purchaseGeneration.get()!=generation)return@queryPurchasesAsync
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                for (p in purchases) {
                    if (PurchaseVerifier.verify(p)) {
                        if(p.products.any {it in CONSUMABLE_PRODUCTS})handlePurchase(p)
                        for (pid in p.products.filter {it !in CONSUMABLE_PRODUCTS}) {
                            UserEntitlementsManager.instance.applyVerifiedPurchase(pid,p.purchaseToken)
                            restoredIds.add(pid)
                        }
                        if (!p.isAcknowledged && p.products.none {it in CONSUMABLE_PRODUCTS}) {
                            client.acknowledgePurchase(
                                AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()
                            ) {}
                        }
                    }
                }
            }

            // 查询 SUBS 已购
            val subsParams = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()

            client.queryPurchasesAsync(subsParams) subscriptionQuery@{ subResult, subPurchases ->
                if(purchaseGeneration.get()!=generation)return@subscriptionQuery
                if (subResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    for (p in subPurchases) {
                        if (PurchaseVerifier.verify(p)) {
                            for (pid in p.products.filter {it !in CONSUMABLE_PRODUCTS}) {
                                UserEntitlementsManager.instance.applyVerifiedPurchase(pid,p.purchaseToken)
                                restoredIds.add(pid)
                            }
                            if (!p.isAcknowledged) {
                                client.acknowledgePurchase(
                                    AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()
                                ) {}
                            }
                        }
                    }
                }

                if(result.responseCode==BillingClient.BillingResponseCode.OK&&subResult.responseCode==BillingClient.BillingResponseCode.OK&&PurchaseVerifier.configured)
                    UserEntitlementsManager.instance.reconcileMembership(restoredIds.toSet())
                if(result.responseCode!=BillingClient.BillingResponseCode.OK||subResult.responseCode!=BillingClient.BillingResponseCode.OK){
                    val failure=if(result.responseCode!=BillingClient.BillingResponseCode.OK)result else subResult
                    notifyListeners {it.onPurchaseFailed(null,failure.responseCode,failure.debugMessage)}
                }else if(!PurchaseVerifier.configured)notifyListeners {it.onPurchaseFailed(null,BillingClient.BillingResponseCode.ERROR,com.example.yiijingcompass.model.LocalizationManager.instance.t("native_billing_configuration"))}
                Log.i(TAG, "Active purchase restoration complete")
                notifyListeners { it.onPurchasesRestored(restoredIds) }
                onComplete?.invoke(restoredIds)
            }
        }
    }

    /**
     * 获取商品本地格式化价格（如 "$29.99" 或 "¥198.00"）
     */
    fun getFormattedPrice(productId: String): String? {
        val details = productDetailsCache[productId] ?: return null
        return if (details.productType == BillingClient.ProductType.SUBS) {
            details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice
        } else {
            details.oneTimePurchaseOfferDetails?.formattedPrice
        }
    }

    /**
     * 将所有 Google Play 商品本地化详情转为 JSON
     */
    fun subscriptionDisclosure(productId:String):String?=productDetailsCache[productId]?.takeIf {it.productType==BillingClient.ProductType.SUBS}?.let(SubscriptionDisclosure::text)
    fun canPurchase(productId:String):Boolean=PurchaseVerifier.configured&&productDetailsCache[productId]?.let {it.productType!=BillingClient.ProductType.SUBS||SubscriptionDisclosure.complete(it)}==true
    fun getProductDetailsJson(): String {
        val arr = JSONArray()
        for ((pid, details) in productDetailsCache) {
            val obj = JSONObject().apply {
                put("productId", pid)
                put("title", details.title)
                put("description", details.description)
                put("type", details.productType)
                if (details.productType == BillingClient.ProductType.SUBS) {
                    val phase = details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.firstOrNull()
                    put("price", phase?.formattedPrice ?: "")
                    put("priceAmountMicros", phase?.priceAmountMicros ?: 0)
                    put("currencyCode", phase?.priceCurrencyCode ?: "")
                } else {
                    val offer = details.oneTimePurchaseOfferDetails
                    put("price", offer?.formattedPrice ?: "")
                    put("priceAmountMicros", offer?.priceAmountMicros ?: 0)
                    put("currencyCode", offer?.priceCurrencyCode ?: "")
                }
            }
            arr.put(obj)
        }
        return arr.toString()
    }

    private fun notifyListeners(action: (BillingEventListener) -> Unit) {
        val listCopy = synchronized(listeners) { listeners.toList() }
        mainHandler.post {
            for (listener in listCopy) {
                try {
                    action(listener)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in listener callback", e)
                }
            }
        }
    }
}

