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
        val client = billingClient
        if (client == null || !client.isReady) {
            startConnection()
            onLaunched?.invoke(false, "Google Play 商店连接中，请稍候重试")
            return
        }

        val details = productDetailsCache[productId]
        if (details == null) {
            queryAllProductDetails()
            onLaunched?.invoke(false, "商品信息载入中，请稍候点击重试")
            return
        }

        val productDetailsParamsList = mutableListOf<BillingFlowParams.ProductDetailsParams>()

        if (details.productType == BillingClient.ProductType.SUBS) {
            val offerDetails = details.subscriptionOfferDetails?.firstOrNull()
            if (offerDetails == null) {
                onLaunched?.invoke(false, "未找到该订阅方案的定价信息")
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
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) {
            Log.w(TAG, "Purchase ${purchase.orderId} is not in PURCHASED state (${purchase.purchaseState})")
            return
        }

        for (productId in purchase.products) {
            // 1. 若为单次消耗品（如长卷单次导出）-> 执行消耗并补足点数
            if (productId == InAppProductId.TIANJI_SINGLE.productId) {
                val consumeParams = ConsumeParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()

                billingClient?.consumeAsync(consumeParams) { result, _ ->
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                        Log.i(TAG, "Successfully consumed $productId")
                        UserEntitlementsManager.instance.applyPurchase(productId)
                        notifyListeners { it.onPurchaseSuccess(productId, purchase.orderId ?: purchase.purchaseToken) }
                    } else {
                        Log.e(TAG, "Failed to consume $productId: ${result.debugMessage}")
                    }
                }
            } else {
                // 2. 若为非消耗品或连续订阅 -> 确保已完成确认 Acknowledge
                if (!purchase.isAcknowledged) {
                    val ackParams = AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()

                    billingClient?.acknowledgePurchase(ackParams) { result ->
                        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                            Log.i(TAG, "Successfully acknowledged $productId")
                            UserEntitlementsManager.instance.applyPurchase(productId)
                            notifyListeners { it.onPurchaseSuccess(productId, purchase.orderId ?: purchase.purchaseToken) }
                        } else {
                            Log.e(TAG, "Failed to acknowledge $productId: ${result.debugMessage}")
                        }
                    }
                } else {
                    // 已确认过，同步本地特权状态
                    UserEntitlementsManager.instance.applyPurchase(productId)
                    notifyListeners { it.onPurchaseSuccess(productId, purchase.orderId ?: purchase.purchaseToken) }
                }
            }
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

        val restoredIds = mutableListOf<String>()

        // 查询 INAPP 已购
        val inAppParams = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()

        client.queryPurchasesAsync(inAppParams) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                for (p in purchases) {
                    if (p.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        for (pid in p.products) {
                            UserEntitlementsManager.instance.applyPurchase(pid)
                            restoredIds.add(pid)
                        }
                        if (!p.isAcknowledged && !p.products.contains(InAppProductId.TIANJI_SINGLE.productId)) {
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

            client.queryPurchasesAsync(subsParams) { subResult, subPurchases ->
                if (subResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    for (p in subPurchases) {
                        if (p.purchaseState == Purchase.PurchaseState.PURCHASED) {
                            for (pid in p.products) {
                                UserEntitlementsManager.instance.applyPurchase(pid)
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

                Log.i(TAG, "Restored active purchases: $restoredIds")
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

