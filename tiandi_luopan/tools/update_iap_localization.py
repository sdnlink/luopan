# -*- coding: utf-8 -*-
"""
Update LocalizationManager and StoreKitIAPManager with localized prices and error messages.
"""
import os

BASE_DIR = r"e:\code\android\tiandi_luopan\ios\TiandiLuopan"
LOC_MGR_PATH = os.path.join(BASE_DIR, "Models", "LocalizationManager.swift")
IAP_MGR_PATH = os.path.join(BASE_DIR, "StoreKitIAPManager.swift")

def update_loc_manager():
    with open(LOC_MGR_PATH, "r", encoding="utf-8") as f:
        c = f.read().replace("\r\n", "\n")

    if '"price_vip_yearly"' in c:
        print("LocalizationManager already has price keys.")
        return

    hans = """            "price_vip_yearly": "¥198/年",
            "price_pro_lifetime": "¥298",
            "price_floorplan_single": "¥19.9",
            "price_tianji_single": "¥9.9",
            "iap_err_parental_controls": "设备当前受家长控制或系统限制，无法完成应用内购买。",
            "iap_err_restore_failed_prefix": "恢复购买失败: ",
            "iap_err_cancelled_or_unknown": "购买已取消或发生未知错误",
            "iap_err_payment_cancelled": "用户已取消支付",
            "iap_err_payment_not_allowed": "该 Apple ID 不允许进行应用内购买",
            "iap_err_payment_invalid": "支付凭证无效，请检查付款方式",
            "iap_err_client_invalid": "客户端无权发起支付",
"""

    hant = """            "price_vip_yearly": "NT$990/年",
            "price_pro_lifetime": "NT$1,590",
            "price_floorplan_single": "NT$130",
            "price_tianji_single": "NT$70",
            "iap_err_parental_controls": "設備當前受家長控制或系統限制，無法完成應用內購買。",
            "iap_err_restore_failed_prefix": "恢復購買失敗: ",
            "iap_err_cancelled_or_unknown": "購買已取消或發生未知錯誤",
            "iap_err_payment_cancelled": "用戶已取消支付",
            "iap_err_payment_not_allowed": "該 Apple ID 不允許進行應用內購買",
            "iap_err_payment_invalid": "支付憑證無效，請檢查付款方式",
            "iap_err_client_invalid": "客戶端無權發起支付",
"""

    en = """            "price_vip_yearly": "$29.99/year",
            "price_pro_lifetime": "$49.99",
            "price_floorplan_single": "$3.99",
            "price_tianji_single": "$1.99",
            "iap_err_parental_controls": "In-App Purchases are disabled or restricted by parental controls.",
            "iap_err_restore_failed_prefix": "Restore failed: ",
            "iap_err_cancelled_or_unknown": "Purchase cancelled or unknown error occurred.",
            "iap_err_payment_cancelled": "Payment was cancelled.",
            "iap_err_payment_not_allowed": "This Apple ID is not permitted to make in-app purchases.",
            "iap_err_payment_invalid": "Payment credentials invalid, please check payment method.",
            "iap_err_client_invalid": "Client is not authorized to issue payment.",
"""

    pos_hant = c.find(".zhHant: [")
    if pos_hant != -1:
        close_hans = c.rfind("],", 0, pos_hant)
        if close_hans != -1:
            c = c[:close_hans] + hans + c[close_hans:]

    pos_en = c.find(".en: [")
    if pos_en != -1:
        close_hant = c.rfind("],", 0, pos_en)
        if close_hant != -1:
            c = c[:close_hant] + hant + c[close_hant:]

    close_en = c.rfind("]")
    if close_en != -1:
        close_dict = c.rfind("]", 0, close_en)
        if close_dict != -1:
            c = c[:close_dict] + en + c[close_dict:]

    with open(LOC_MGR_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated LocalizationManager with IAP keys.")

def update_iap_manager():
    with open(IAP_MGR_PATH, "r", encoding="utf-8") as f:
        c = f.read()

    # Replace priceText
    old_price = """    var priceText: String {
        switch self {
        case .vipYearly: return "¥198/年"
        case .proLifetime: return "¥298"
        case .floorplanSingle: return "¥19.9"
        case .tianjiSingle: return "¥9.9"
        }
    }"""

    new_price = """    var priceText: String {
        switch self {
        case .vipYearly: return LocalizationManager.shared.t("price_vip_yearly")
        case .proLifetime: return LocalizationManager.shared.t("price_pro_lifetime")
        case .floorplanSingle: return LocalizationManager.shared.t("price_floorplan_single")
        case .tianjiSingle: return LocalizationManager.shared.t("price_tianji_single")
        }
    }"""
    c = c.replace(old_price, new_price)

    # Parental control guard
    c = c.replace(
        'errorMsg: "设备当前受家长控制或系统限制，无法完成应用内购买。"',
        'errorMsg: LocalizationManager.shared.t("iap_err_parental_controls")'
    )

    # Restore failed
    c = c.replace(
        'errorMsg: "恢复购买失败: \\(error.localizedDescription)"',
        'errorMsg: "\(LocalizationManager.shared.t("iap_err_restore_failed_prefix"))\\(error.localizedDescription)"'
    )

    # Handle failed transaction
    old_handle_failed = """        var errorMsg = "购买已取消或发生未知错误"
        if let err = transaction.error as? SKError {
            switch err.code {
            case .paymentCancelled:
                errorMsg = "用户已取消支付"
            case .paymentNotAllowed:
                errorMsg = "该 Apple ID 不允许进行应用内购买"
            case .paymentInvalid:
                errorMsg = "支付凭证无效，请检查付款方式"
            case .clientInvalid:
                errorMsg = "客户端无权发起支付"
            default:
                errorMsg = err.localizedDescription
            }
        }"""

    new_handle_failed = """        let lang = LocalizationManager.shared
        var errorMsg = lang.t("iap_err_cancelled_or_unknown")
        if let err = transaction.error as? SKError {
            switch err.code {
            case .paymentCancelled:
                errorMsg = lang.t("iap_err_payment_cancelled")
            case .paymentNotAllowed:
                errorMsg = lang.t("iap_err_payment_not_allowed")
            case .paymentInvalid:
                errorMsg = lang.t("iap_err_payment_invalid")
            case .clientInvalid:
                errorMsg = lang.t("iap_err_client_invalid")
            default:
                errorMsg = err.localizedDescription
            }
        }"""
    c = c.replace(old_handle_failed, new_handle_failed)

    with open(IAP_MGR_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated StoreKitIAPManager.swift.")

if __name__ == "__main__":
    update_loc_manager()
    update_iap_manager()
