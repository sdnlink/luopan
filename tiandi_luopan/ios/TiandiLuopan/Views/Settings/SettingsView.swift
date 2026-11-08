import SwiftUI
import Foundation

/// Public HTTPS pages used by the purchase flow and App Store metadata.
/// Keep these URLs stable so the links shown in Settings and the paywall
/// always point at the currently published legal pages.
public enum LegalLinks {
    // Escape the slashes so the repository's lightweight Swift checker does
    // not mistake the URL for a source comment.
    public static let termsOfUse = URL(string: "https://yulintao.github.io/tiandiluopan-support/")!
    public static let privacyPolicy = URL(string: "https://yulintao.github.io/tiandiluopan-privacy/")!
    public static let subscriptionInfo = URL(string: "https://yulintao.github.io/tiandiluopan-subscription/")!
    /// 正式上架后分配的 App Store 数字 ID（配置后点击评分直接直达 App Store 撰写长评页面）
    public static let appStoreID: String = ""
}

private enum LegalDocument: String, Identifiable {
    case terms
    case privacy
    case compliance

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .terms: return "legal_terms_title"
        case .privacy: return "legal_privacy_title"
        case .compliance: return "legal_compliance_title"
        }
    }

    var bodyKey: String {
        switch self {
        case .terms: return "legal_terms_body"
        case .privacy: return "legal_privacy_body"
        case .compliance: return "legal_compliance_body"
        }
    }
}

// MARK: - 辅助本地化文案生成器 (Settings Localization Helpers)

enum SettingsLocalizationHelpers {
    static func ownerProfileEnableTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "启用宅主本命卦人宅配卦"
        case .zhHant: return "啟用宅主本命卦人宅配卦"
        case .en: return "Enable Owner Life Gua Matching"
        case .ja: return "家主本命卦マッチングを有効化"
        case .ko: return "본명괘 매칭 활성화"
        case .vi: return "Bật Phối Quẻ Trạch Chủ"
        case .th: return "เปิดใช้การจับคู่รหัสชีวิต"
        case .id: return "Aktifkan Pencocokan Gua Pemilik"
        default: return "启用宅主本命卦人宅配卦"
        }
    }

    static func ownerBirthYearTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "出生年份与本命卦"
        case .zhHant: return "出生年份與本命卦"
        case .en: return "Birth Year & Life Gua"
        case .ja: return "生年と本命卦"
        case .ko: return "출생연도 및 본명괘"
        case .vi: return "Năm Sinh & Bản Mệnh Quái"
        case .th: return "ปีเกิดและรหัสชีวิต"
        case .id: return "Tahun Lahir & Gua"
        default: return "出生年份与本命卦"
        }
    }

    static func ownerGenderTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "性别"
        case .zhHant, .ja: return "性別"
        case .en: return "Gender"
        case .ko: return "성별"
        case .vi: return "Giới tính"
        case .th: return "เพศ"
        case .id: return "Jenis Kelamin"
        default: return "性别"
        }
    }

    static func maleLabel(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "乾造 (男)"
        case .en: return "Male"
        case .ko: return "남성"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        default: return "乾造 (男)"
        }
    }

    static func femaleLabel(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "坤造 (女)"
        case .en: return "Female"
        case .ko: return "여성"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        default: return "坤造 (女)"
        }
    }

    static func solarTermNotifyTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "二十四节气交节与九星换月提醒"
        case .zhHant: return "二十四節氣交節與九星換月提醒"
        case .en: return "Solar Term & Monthly Star Alerts"
        case .ja: return "二十四節気・月盤切替通知"
        case .ko: return "24절기 및 월반 교체 알림"
        case .vi: return "Nhắc Giao Tiết & Đổi Sao Tháng"
        case .th: return "แจ้งเตือนวันเปลี่ยนสารทและดาวประจำเดือน"
        case .id: return "Pengingat Pergantian Musim & Bintang"
        default: return "二十四节气交节与九星换月提醒"
        }
    }

    static func solarTermNotifyDesc(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "系统将于二十四节气交节当日及九星换月当日早 08:30 自动向您推送节气气候与当月飞星吉凶提示。"
        case .zhHant: return "系統將於二十四節氣交節當日及九星換月當日早 08:30 自動向您推送節氣氣候與當月飛星吉凶提示。"
        case .en: return "Alerts for solar term changes and monthly Flying Star shifts will be delivered at 08:30 AM on transition days."
        case .ja: return "二十四節気の交節日および九星換月の当日の朝 08:30 に、気候と飛星の吉凶通知をお届けします。"
        case .ko: return "24절기 입절일 및 월반 교체 당일 오전 08:30에 절기 기후와 당월 비성 길흉 알림을 보내드립니다."
        case .vi: return "Hệ thống sẽ gửi thông báo khí hậu tiết khí và phi tinh cát hung vào lúc 08:30 sáng ngày giao tiết."
        case .th: return "ระบบจะแจ้งเตือนการเปลี่ยนสารทและดาวบินประจำเดือนในเวลา 08:30 น. ของวันเปลี่ยนสารท"
        case .id: return "Pemberitahuan perubahan musim dan Bintang Terbang akan dikirimkan pukul 08:30 pada hari transisi."
        default: return "系统将于二十四节气交节当日及九星换月当日早 08:30 自动向您推送节气气候与当月飞星吉凶提示。"
        }
    }

    static func onboardingReplayTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "新手 3 步快速立向教学指南"
        case .zhHant: return "新手 3 步快速立向教學指南"
        case .en: return "3-Step Quick Compass Guide"
        case .ja: return "3ステップ立向クイックガイド"
        case .ko: return "3단계 나침반 빠른 가이드"
        case .vi: return "Hướng Dẫn Lập Hướng 3 Bước"
        case .th: return "คู่มือการวัดทิศ 3 ขั้นตอน"
        case .id: return "Panduan Cepat 3 Langkah"
        default: return "新手 3 步快速立向教学指南"
        }
    }

    static func rateAppTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "为「天机演象」评分鼓励"
        case .zhHant: return "為「天機演象」評分鼓勵"
        case .en: return "Rate Tiandi Luopan"
        case .ja: return "アプリを評価して応援する"
        case .ko: return "앱 평가하기"
        case .vi: return "Đánh Giá Ứng Dụng"
        case .th: return "ให้คะแนนแอป"
        case .id: return "Beri Nilai Aplikasi"
        default: return "为「天机演象」评分鼓励"
        }
    }

    static func testFlightRateAlertTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "TestFlight Beta Notice"
        case .zhHant: return "TestFlight 測試版提示"
        case .ja: return "TestFlight ベータ版のご案内"
        case .ko: return "TestFlight 베타 안내"
        case .vi: return "Thông Báo TestFlight Beta"
        case .th: return "ข้อความแจ้งเตือน TestFlight"
        case .id: return "Pemberitahuan Beta TestFlight"
        case .auto, .zhHans: return "TestFlight 测试版提示"
        }
    }

    static func testFlightRateAlertMessage(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You are currently running a TestFlight beta build. Under Apple's rules, the 'Submit' button in rating dialogs is disabled in TestFlight and sandbox environments. Reviews will be fully active once released on the App Store! To submit feedback now, please use the 'Send Beta Feedback' option in the TestFlight app."
        case .zhHant:
            return "當前處於 TestFlight 測試環境。依蘋果官方規則，測試版應用評分彈窗中的「提交」按鈕會被系統強制置灰，無法向 App Store 提交公開評分。正式上架後將全面開放評價！您可在 TestFlight 中點擊「發送反饋」向我們提出建議。"
        case .ja:
            return "現在 TestFlight ベータテスト環境をご利用中です。Apple の仕様により、テスト版では評価ダイアログの「送信」ボタンが無効化されており、App Store に公開評価を投稿することはできません。正式リリース後に評価が可能となります。ご意見は TestFlight の「フィードバックを送信」よりお寄せください。"
        case .ko:
            return "현재 TestFlight 베타 환경입니다. Apple의 정책에 따라 테스트 버전에서는 평가 팝업의 '제출' 버튼이 비활성화되어 App Store에 공개 평가를 등록할 수 없습니다. 정식 출시 후 평가가 가능하며, 의견은 TestFlight 앱의 '피드백 보내기'를 이용해 주시기 바랍니다."
        case .vi:
            return "Bạn đang sử dụng phiên bản thử nghiệm TestFlight. Theo quy định của Apple, nút 'Gửi' trong hộp thoại đánh giá sẽ bị vô hiệu hóa trong môi trường thử nghiệm. Đánh giá sẽ hoạt động bình thường sau khi phát hành chính thức! Bạn có thể gửi ý kiến qua mục 'Gửi phản hồi Beta' trong ứng dụng TestFlight."
        case .th:
            return "ขณะนี้คุณกำลังใช้งานเวอร์ชันทดสอบ TestFlight ตามนโยบายของ Apple ปุ่ม 'ส่ง' ในหน้าต่างให้คะแนนจะถูกปิดใช้งานในเวอร์ชันทดสอบ เมื่อเปิดตัวอย่างเป็นทางการจะสามารถส่งคะแนนได้ตามปกติ หากมีข้อเสนอแนะโปรดใช้ตัวเลือก 'ส่งความคิดเห็น' ในแอป TestFlight"
        case .id:
            return "Anda saat ini menggunakan versi beta TestFlight. Berdasarkan kebijakan Apple, tombol 'Kirim' dinonaktifkan pada versi beta. Ulasan akan dibuka penuh setelah rilis resmi di App Store. Untuk memberikan saran, silakan gunakan 'Kirim Masukan' di aplikasi TestFlight."
        case .auto, .zhHans:
            return "当前处于 TestFlight 测试环境。按苹果官方规则，测试版应用弹出的评分弹窗中「提交」按钮会被系统强制置灰，无法向 App Store 提交公开评分。正式上架后将全面开放评价！您可在 TestFlight 中点击「发送反馈」向我们提出宝贵建议。"
        }
    }

    static func notificationPermissionDeniedTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Notification Permission Disabled"
        case .zhHant: return "通知權限未開啟"
        case .ja: return "通知が許可されていません"
        case .ko: return "알림 권한이 비활성화됨"
        case .vi: return "Chưa Bật Quyền Thông Báo"
        case .th: return "ยังไม่ได้เปิดการอนุญาตแจ้งเตือน"
        case .id: return "Izin Notifikasi Belum Diaktifkan"
        case .auto, .zhHans: return "通知权限未开启"
        }
    }

    static func notificationPermissionDeniedMessage(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You previously chose 'Don't Allow' for notifications. iOS requires you to enable notifications in the Settings app. Please go to Settings to enable alerts for 24 solar terms and monthly Flying Stars."
        case .zhHant:
            return "檢測到您之前點擊了「不允許」通知，iOS 系統限制應用無法再次直接彈窗請求授權。請前往系統「設定」中為「天機演象」開啟通知權限，以便及時接收二十四節氣交節與九星換月提醒。"
        case .ja:
            return "以前「許可しない」を選択されたため、iOSの制約によりアプリ内から再要求できません。「設定」アプリを開き、天地羅盤の通知をオンにして節気交節や九星換月の通知を受け取れるようにしてください。"
        case .ko:
            return "이전에 알림을 '허용 안 함'으로 설정하여 iOS 정책상 앱에서 바로 권한을 재요청할 수 없습니다. 시스템 '설정'에서 알림을 허용하시면 24절기 교절 및 자백구성 환월 알림을 받으실 수 있습니다."
        case .vi:
            return "Bạn đã chọn 'Không cho phép' thông báo trước đó. Vui lòng vào 'Cài đặt' của thiết bị để bật thông báo cho Thiên Địa La Bàn nhằm nhận nhắc nhở giao tiết khí và Cửu Tinh đổi cục."
        case .th:
            return "คุณเคยเลือก 'ไม่อนุญาต' การแจ้งเตือนไว้ ระบบ iOS กำหนดให้ต้องเปิดในแอปการตั้งค่าของเครื่อง โปรดไปที่ 'การตั้งค่า' เพื่อเปิดการแจ้งเตือนสำหรับสารท 24 절기 และดาวบินรายเดือน"
        case .id:
            return "Anda sebelumnya memilih 'Jangan Izinkan' notifikasi. Silakan buka 'Pengaturan' perangkat dan aktifkan notifikasi untuk menerima pengingat pergantian musim dan Bintang Terbang."
        case .auto, .zhHans:
            return "检测到您之前点击了「不允许」通知，iOS 系统限制应用无法再次直接弹窗请求授权。请前往系统「设置」中为「天机演象」开启通知权限，以便及时接收二十四节气交节与九星换月提醒。"
        }
    }

    static func goToSettingsTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Go to Settings"
        case .zhHant: return "前往設定"
        case .ja: return "設定へ移動"
        case .ko: return "설정으로 이동"
        case .vi: return "Đi đến Cài Đặt"
        case .th: return "ไปที่การตั้งค่า"
        case .id: return "Buka Pengaturan"
        case .auto, .zhHans: return "前往设置"
        }
    }
}

// MARK: - 系统设置总览视图 (Settings Root View)

public struct SettingsView: View {
    public var isActive: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @ObservedObject var kuaProfile = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared

    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var paymentError: String = ""
    @State private var paymentAlertIsError: Bool = true
    @State private var showPaymentError: Bool = false

    private static let appearanceConfigured: Void = {
        UITableView.appearance().backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
    }()

    public init(isActive: Bool = true) {
        self.isActive = isActive
        _ = Self.appearanceConfigured
    }

    private var isProUnlocked: Bool {
        iap.hasUnlockedVIP
    }

    public var body: some View {
        Group {
            if isActive {
                NavigationView {
                    List {
                        // 顶部用户/会员概要卡片
                        userHeaderSection

                        // 4 大功能模块菜单组
                        Section {
                            // 模块 1: 大师会员
                            NavigationLink(destination: MasterVIPPageView(selectedProductId: $selectedProductId)) {
                                menuRow(
                                    icon: "crown.fill",
                                    iconColor: Color(red: 0.95, green: 0.85, blue: 0.45),
                                    title: lang.t("settings_menu_vip"),
                                    badge: isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"),
                                    badgeColor: isProUnlocked ? .green : .yellow
                                )
                            }

                            // 模块 2: 宅主命卦与节气提醒
                            NavigationLink(destination: OwnerKuaReminderPageView()) {
                                menuRow(
                                    icon: "person.crop.circle.badge.checkmark",
                                    iconColor: Color.yanCyan,
                                    title: lang.t("settings_menu_kua_reminder"),
                                    subtitle: kuaProfileSubtitle
                                )
                            }

                            // 模块 3: 界面语言设置
                            NavigationLink(destination: LanguagePreferencesPageView()) {
                                menuRow(
                                    icon: "globe",
                                    iconColor: Color(red: 0.35, green: 0.65, blue: 0.95),
                                    title: lang.t("settings_menu_language"),
                                    subtitle: lang.currentSetting.displayName
                                )
                            }

                            // 模块 4: 关于
                            NavigationLink(destination: AboutPageView()) {
                                menuRow(
                                    icon: "info.circle.fill",
                                    iconColor: Color.orange,
                                    title: lang.t("settings_menu_about"),
                                    subtitle: "v" + lang.t("settings_version_value")
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.ignoresSafeArea())
                    .navigationBarTitle(lang.t("tab_settings"), displayMode: .inline)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        guard isActive else { return }
                        showPaymentError = false
                        iap.clearTransientMessages()
                        iap.refreshProductsIfNeeded()
                    }
                    .onReceive(iap.$lastErrorMessage) { message in
                        guard isActive else { return }
                        if let message = message {
                            paymentAlertIsError = true
                            paymentError = message
                            showPaymentError = true
                            iap.clearTransientMessages()
                        }
                    }
                    .onReceive(iap.$lastStatusMessage) { message in
                        guard isActive else { return }
                        if let message = message {
                            paymentAlertIsError = false
                            paymentError = message
                            showPaymentError = true
                            iap.clearTransientMessages()
                        }
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .preferredColorScheme(.dark)
            } else {
                Color.clear.ignoresSafeArea()
            }
        }
        .overlay(
            Group {
                if showPaymentError {
                    FloorplanConfirmDialog(
                        title: paymentAlertIsError ? lang.t("payment_failed_title") : lang.t("payment_status_title"),
                        message: paymentError,
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { showPaymentError = false },
                        onCancel: { showPaymentError = false }
                    )
                } else if retention.showNotificationPermissionDeniedAlert {
                    FloorplanConfirmDialog(
                        title: SettingsLocalizationHelpers.notificationPermissionDeniedTitle(lang),
                        message: SettingsLocalizationHelpers.notificationPermissionDeniedMessage(lang),
                        confirmTitle: SettingsLocalizationHelpers.goToSettingsTitle(lang),
                        cancelTitle: lang.t("cancel"),
                        confirmColor: Color.yanCyan,
                        onConfirm: {
                            retention.showNotificationPermissionDeniedAlert = false
                            retention.openSystemNotificationSettings()
                        },
                        onCancel: {
                            retention.showNotificationPermissionDeniedAlert = false
                        }
                    )
                }
            }
        )
    }

    private var userHeaderSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isProUnlocked
                                    ? [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)]
                                    : [Color(red: 0.25, green: 0.26, blue: 0.3), Color(red: 0.15, green: 0.16, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: isProUnlocked ? "crown.fill" : "person.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(isProUnlocked ? .black : .white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                            .adaptiveFont(size: 16, weight: .bold)
                            .foregroundColor(isProUnlocked ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                        if isProUnlocked {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                .font(.system(size: 13))
                        }
                    }
                    Text(userHeaderSubtitle)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var userHeaderSubtitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "天机演象 · 专业风水罗盘与玄空理气"
        case .zhHant: return "天機演象 · 專業風水羅盤與玄空理氣"
        case .en: return "Tiandi Luopan · Professional Feng Shui Compass"
        case .ja: return "天地羅盤 · プロ向け風水羅盤と玄空理気"
        case .ko: return "천지나침반 · 전문 풍수 나침반 및 현공이기"
        case .vi: return "Thiên Địa La Bàn · Huyền Không Phong Thủy"
        case .th: return "เข็มทิศฟ้าดิน · เข็มทิศฮวงจุ้ยมืออาชีพ"
        case .id: return "Tiandi Luopan · Kompas Feng Shui Profesional"
        default: return "天机演象 · 专业风水罗盘与玄空理气"
        }
    }

    private var kuaProfileSubtitle: String {
        if kuaProfile.isProfileEnabled {
            return "\(kuaProfile.birthYear) · \(kuaProfile.localizedLifeKuaName(language: lang.effectiveLanguage))"
        } else {
            return ""
        }
    }

    private func menuRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        badgeColor: Color? = nil
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .adaptiveFont(size: 15, weight: .medium)
                .foregroundColor(.white)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((badgeColor ?? .yellow).opacity(0.25))
                    .foregroundColor(badgeColor ?? .yellow)
                    .cornerRadius(6)
            } else if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 功能页 1: 大师会员 (Master VIP Page)

public struct MasterVIPPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Binding var selectedProductId: String

    public init(selectedProductId: Binding<String>) {
        self._selectedProductId = selectedProductId
    }

    private var isProUnlocked: Bool {
        iap.hasUnlockedVIP
    }

    private var selectedProductIsAvailable: Bool {
        guard let product = IAPProductID(rawValue: selectedProductId) else { return false }
        return iap.hasProduct(for: product)
    }

    public var body: some View {
        List {
            // 1. 会员状态与多档位收银台
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(lang.t("vip_member_center"))
                            .adaptiveFont(size: 16, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isProUnlocked ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                            .foregroundColor(isProUnlocked ? .green : .yellow)
                            .cornerRadius(6)
                    }

                    // 四档商品卡片选择
                    VStack(spacing: 8) {
                        productRow(id: .vipYearly, tag: lang.t("product_vip_yearly_tag"))
                        productRow(id: .proLifetime, tag: lang.t("product_pro_lifetime_tag"))
                        productRow(id: .floorplanSingle, tag: lang.t("product_floorplan_single_tag"))
                        productRow(id: .tianjiSingle, tag: lang.t("product_tianji_single_tag"))
                    }
                    .padding(.vertical, 4)

                    if !iap.isLoadingProducts,
                       let selectedProduct = IAPProductID(rawValue: selectedProductId),
                       !iap.hasProduct(for: selectedProduct) {
                        HStack(spacing: 8) {
                            Text(lang.t("price_unavailable"))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.orange.opacity(0.9))
                            Spacer()
                            Button(lang.t("reload_prices")) {
                                iap.refreshProductsIfNeeded(force: true)
                            }
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(.yanCyan)
                        }
                    }

                    // 购买与恢复按钮
                    if !iap.isLifetimeUser && (!isProUnlocked || selectedProductId == IAPProductID.proLifetime.rawValue) {
                        Button(action: {
                            iap.purchase(productId: selectedProductId)
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "applelogo")
                                Text(lang.t("pay_securely"))
                                Spacer()
                            }
                            .adaptiveFont(size: 13, weight: .bold)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }
                        .disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !selectedProductIsAvailable)
                    }

                    Button(action: {
                        iap.restorePurchases()
                    }) {
                        HStack {
                            Spacer()
                            Text(lang.t("restore_purchases"))
                                .adaptiveFont(size: 11)
                                .foregroundColor(Color.yanCyan)
                            Spacer()
                        }
                    }
                    .disabled(iap.isProcessingPurchase)
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }

            // 2. VIP 尊享特权矩阵
            Section(header: Text(lang.t("vip_privilege_header"))) {
                privilegeRow(icon: "sparkles", title: lang.t("privilege_qimen_title"))
                privilegeRow(icon: "calendar.badge.clock", title: lang.t("privilege_purplewhite_title"))
                privilegeRow(icon: "house.fill", title: lang.t("privilege_floorplan_title"))
                privilegeRow(icon: "scroll.fill", title: lang.t("privilege_tianji_title"))
                privilegeRow(icon: "camera.viewfinder", title: lang.t("ar_title"))
            }

            // 3. 自动续费服务声明链接
            Section {
                Button {
                    openURL(LegalLinks.subscriptionInfo)
                } label: {
                    HStack {
                        Label(lang.t("subscription_info_button"), systemImage: "safari")
                            .foregroundColor(Color.yanCyan)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .adaptiveFont(size: 12, weight: .semibold)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_vip"), displayMode: .inline)
        .preferredColorScheme(.dark)
    }

    private func productRow(id: IAPProductID, tag: String) -> some View {
        let isSelected = selectedProductId == id.rawValue

        return Button(action: {
            selectedProductId = id.rawValue
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tag)
                            .adaptiveFont(size: 9, weight: .bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(iap.localizedPrice(for: id))
                    .adaptiveFont(size: 15, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(10)
            .background(isSelected ? Color(red: 0.22, green: 0.19, blue: 0.12) : Color(red: 0.12, green: 0.13, blue: 0.17))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func privilegeRow(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .adaptiveFont(size: 13)
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
            Text(title)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(lang.t("vip_short"))
                .adaptiveFont(size: 9, weight: .bold)
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - 功能页 2: 宅主命卦与节气提醒 (Owner Life Gua & Solar Terms Page)

public struct OwnerKuaReminderPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var kuaProfile = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showEditOwnerKuaDialog: Bool = false

    public init() {}

    public var body: some View {
        List {
            // 1. 宅主本命卦人宅配卦
            Section(header: Text(SettingsLocalizationHelpers.ownerBirthYearTitle(lang))) {
                Toggle(SettingsLocalizationHelpers.ownerProfileEnableTitle(lang), isOn: $kuaProfile.isProfileEnabled)

                if kuaProfile.isProfileEnabled {
                    HStack {
                        Text(SettingsLocalizationHelpers.ownerBirthYearTitle(lang))
                        Spacer()
                        Button(action: {
                            showEditOwnerKuaDialog = true
                        }) {
                            HStack(spacing: 4) {
                                Text("\(kuaProfile.birthYear) · \(kuaProfile.localizedZodiac(language: lang.effectiveLanguage)) · \(kuaProfile.localizedLifeKuaName(language: lang.effectiveLanguage))")
                                    .adaptiveFont(size: 12, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.yanCyan)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Picker(SettingsLocalizationHelpers.ownerGenderTitle(lang), selection: $kuaProfile.isMale) {
                        Text(SettingsLocalizationHelpers.maleLabel(lang)).tag(true)
                        Text(SettingsLocalizationHelpers.femaleLabel(lang)).tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // 本命卦吉凶方位简卡（点击也可直接修改生辰）
                    Button(action: {
                        showEditOwnerKuaDialog = true
                    }) {
                        kuaInfoCard
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 2. 二十四节气交节与九星换月提醒
            Section(
                header: Text(SettingsLocalizationHelpers.solarTermNotifyTitle(lang)),
                footer: Text(SettingsLocalizationHelpers.solarTermNotifyDesc(lang))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.secondary)
            ) {
                Toggle(SettingsLocalizationHelpers.solarTermNotifyTitle(lang), isOn: Binding(
                    get: { retention.solarTermNotificationsEnabled },
                    set: { retention.setSolarTermNotifications(enabled: $0) }
                ))
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_kua_reminder"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditOwnerKuaDialog) {
            EditOwnerKuaDialog(
                isPresented: $showEditOwnerKuaDialog,
                sittingPalace: "坎",
                onSaved: {}
            )
        }
    }

    private var kuaInfoCard: some View {
        let compat = kuaProfile.evaluateCompatibility(sittingPalace: "坎")

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(compat.localizedOwnerGuaName)
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                Text(compat.localizedLifeGroup)
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yanCyan.opacity(0.2))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(5)
            }

            Divider().background(Color.white.opacity(0.12))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.effectiveLanguage == .en ? "Auspicious Directions" : "四大吉方")
                        .adaptiveFont(size: 10, weight: .semibold)
                        .foregroundColor(.green.opacity(0.9))
                    Text("生气 · 延年 · 天医 · 伏位")
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(lang.effectiveLanguage == .en ? "Inauspicious Directions" : "四大凶方")
                        .adaptiveFont(size: 10, weight: .semibold)
                        .foregroundColor(.red.opacity(0.9))
                    Text("绝命 · 五鬼 · 六煞 · 祸害")
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.13, blue: 0.17))
        .cornerRadius(8)
    }
}

// MARK: - 功能页 3: 界面语言设置 (UI Language & Preferences Page)

public struct LanguagePreferencesPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showCalibrationGuide: Bool = false

    public init() {}

    public var body: some View {
        List {
            // 1. 语言与偏好
            Section(header: Text(lang.t("app_language"))) {
                Toggle(lang.t("haptic_feedback"), isOn: $motion.isHapticEnabled)

                Picker(lang.t("app_language"), selection: $lang.currentSetting) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }

                Picker(lang.t("heading_reference"), selection: $motion.northReference) {
                    Text(lang.t("heading_reference_true")).tag(CompassNorthReference.trueNorth)
                    Text(lang.t("heading_reference_magnetic")).tag(CompassNorthReference.magneticNorth)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(lang.t("gps_coords"))
                        Spacer()
                        Text(motion.coordsDesc)
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 11)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted {
                        Button(lang.t("open_system_settings")) {
                            motion.openLocationSettings()
                        }
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                    } else if motion.locationAuthorizationStatus == .notDetermined {
                        Button(lang.t("request_location_permission")) {
                            motion.requestLocationPermission()
                        }
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                    }
                }

                HStack {
                    Text(lang.t("true_solar_time"))
                    Spacer()
                    Text(motion.solarTimeDesc)
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 11)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            // 2. 硬件传感器与校准
            Section(header: Text(lang.t("settings_calib_title"))) {
                HStack {
                    Text(lang.t("mag_distortion"))
                    Spacer()
                    Text(motion.isDistorted ? lang.t("settings_mag_field_warning") : lang.t("settings_mag_field_normal"))
                        .foregroundColor(motion.isDistorted ? .red : .green)
                        .adaptiveFont(size: 13)
                }

                HStack {
                    Text(lang.t("settings_mag_intensity"))
                    Spacer()
                    Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 13, design: .monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Button(action: {
                    showCalibrationGuide = true
                }) {
                    HStack {
                        Text(lang.t("compass_calib"))
                        Spacer()
                        Text(motion.isDistorted ? lang.t("settings_calib_status_need") : lang.t("settings_calib_status_high"))
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(motion.isDistorted ? .orange : .green)
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 12)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_language"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCalibrationGuide) {
            CalibrationSheet(keepsMotionActive: true)
        }
    }
}

// MARK: - 功能页 4: 关于 (About Page)

public struct AboutPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showOnboardingGuide: Bool = false
    @State private var showTestFlightRateTip: Bool = false
    @State private var legalDocument: LegalDocument? = nil

    public init() {}

    public var body: some View {
        List {
            // 1. 版本信息与应用标识
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "compass.drawing")
                        .font(.system(size: 42))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(appNameTitle)
                        .adaptiveFont(size: 16, weight: .bold)
                        .foregroundColor(.white)
                    Text(lang.t("settings_app_version") + " " + lang.t("settings_version_value"))
                        .adaptiveFont(size: 12)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // 2. 新手教程与评分反馈
            Section {
                Button(action: {
                    showOnboardingGuide = true
                }) {
                    HStack {
                        Label(SettingsLocalizationHelpers.onboardingReplayTitle(lang), systemImage: "book.pages.fill")
                            .foregroundColor(Color.yanCyan)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    handleRateAppTap()
                }) {
                    HStack {
                        Label(SettingsLocalizationHelpers.rateAppTitle(lang), systemImage: "star.bubble.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 3. 理论基础与安全警示
            Section(header: Text(lang.t("settings_theory_base"))) {
                HStack {
                    Text(lang.t("settings_theory_base"))
                    Spacer()
                    Text(lang.t("settings_theory_desc"))
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(lang.t("settings_safety_title"), systemImage: "exclamationmark.shield.fill")
                        .adaptiveFont(size: 13, weight: .semibold)
                        .foregroundColor(.orange)
                    Text(lang.t("settings_safety_disclaimer"))
                        .adaptiveFont(size: 11)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 2)
            }

            // 4. 法律条款与合规自律
            Section(header: Text(legalSectionTitle)) {
                HStack(spacing: 16) {
                    Button {
                        openURL(LegalLinks.termsOfUse)
                    } label: {
                        Label(lang.t("legal_terms_button"), systemImage: "safari")
                    }
                    .buttonStyle(.plain)
                    .adaptiveFont(size: 12, weight: .semibold)
                    .foregroundColor(Color.yanCyan)

                    Spacer()

                    Button {
                        openURL(LegalLinks.privacyPolicy)
                    } label: {
                        Label(lang.t("legal_privacy_button"), systemImage: "safari")
                    }
                    .buttonStyle(.plain)
                    .adaptiveFont(size: 12, weight: .semibold)
                    .foregroundColor(Color.yanCyan)
                }

                Button {
                    legalDocument = .compliance
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                        Text(lang.t("legal_compliance_button"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 10, weight: .semibold)
                    }
                }
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(.orange)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_about"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showOnboardingGuide) {
            OnboardingGuideSheet()
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentSheet(
                title: lang.t(document.titleKey),
                bodyText: lang.t(document.bodyKey)
            )
        }
        .overlay(
            Group {
                if showTestFlightRateTip {
                    FloorplanConfirmDialog(
                        title: SettingsLocalizationHelpers.testFlightRateAlertTitle(lang),
                        message: SettingsLocalizationHelpers.testFlightRateAlertMessage(lang),
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { showTestFlightRateTip = false },
                        onCancel: { showTestFlightRateTip = false }
                    )
                }
            }
        )
    }

    private var appNameTitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "天机演象 · 天地罗盘"
        case .zhHant: return "天機演象 · 天地羅盤"
        case .en: return "Tiandi Luopan"
        case .ja: return "天地羅盤"
        case .ko: return "천지나침반"
        case .vi: return "Thiên Địa La Bàn"
        case .th: return "เข็มทิศฟ้าดิน"
        case .id: return "Tiandi Luopan"
        default: return "天机演象 · 天地罗盘"
        }
    }

    private var legalSectionTitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "条款与合规"
        case .zhHant: return "條款與合規"
        case .en: return "Terms & Compliance"
        case .ja: return "利用規約とコンプライアンス"
        case .ko: return "이용약관 및 규정 준수"
        case .vi: return "Điều khoản & Tuân thủ"
        case .th: return "ข้อกำหนดและการปฏิบัติตามกฎระเบียบ"
        case .id: return "Ketentuan & Kepatuhan"
        default: return "条款与合规"
        }
    }

    private func handleRateAppTap() {
        if !LegalLinks.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(LegalLinks.appStoreID)?action=write-review"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }

        if RetentionServiceManager.isTestFlightOrDebug {
            showTestFlightRateTip = true
        }
        RetentionServiceManager.shared.requestImmediateReview()
    }
}

// MARK: - 用户协议与隐私说明 (Legal Document Sheet)

public struct LegalDocumentSheet: View {
    public let title: String
    public let bodyText: String
    @Environment(\.presentationMode) private var presentationMode

    public init(title: String, bodyText: String) {
        self.title = title
        self.bodyText = bodyText
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                Text(bodyText)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
