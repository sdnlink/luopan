import SwiftUI

// MARK: - 紫白飞星流年流月客星动态气运与太岁三煞视图 (PRD 第12章)

public struct PurpleWhiteView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showPaywall: Bool = false
    
    public init() {}
    
    public var body: some View {
        let chart = PurpleWhiteEngine.shared.calculateChart(heading: motion.headingState.facingAngle)
        
        let lang = LocalizationManager.shared
        return VStack(spacing: 12) {
            // 标题与太岁/三煞摘要栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("purplewhite_header_title"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                Spacer()
                Text("\(chart.year) · \(chart.month)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("privilege_purplewhite_title"),
                    featureDesc: lang.t("privilege_purplewhite_desc"),
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
                .sheet(isPresented: $showPaywall) {
                    VIPPaywallSheet(defaultProductId: .vipYearly)
                }
            } else {
                // 太岁、岁破、三煞警戒条
                HStack(spacing: 8) {
                    tagPill(title: lang.t("tai_sui_label"), value: chart.taiSuiDescription, color: Color.red)
                    tagPill(title: lang.t("sui_po_label"), value: chart.suiPoDescription, color: Color.orange)
                    tagPill(title: lang.t("san_sha_label"), value: chart.sanShaDescription, color: Color.purple)
                }
                .padding(.horizontal, 16)
                
                // 3x3 九宫飞星网格 (流年客星与二五交加报警)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(chart.palaceItems) { item in
                        palaceCellView(item: item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func tagPill(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
    
    private func palaceCellView(item: PurpleWhitePalaceItem) -> some View {
        let isDanger = item.isDanger25 || item.yearGuestStar == 5
        let isJi = [1, 4, 6, 8, 9].contains(item.yearGuestStar)
        let strokeColor = isDanger ? Color.red : (isJi ? Color.green.opacity(0.5) : Color.white.opacity(0.12))
        let bgColor = isDanger ? Color.red.opacity(0.12) : (isJi ? Color.green.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))
        
        return VStack(spacing: 2) {
            // 顶行: 宫位名 + 冲犯标签
            HStack {
                Text(item.direction)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if item.isTaiSui {
                    Text(lang.t("tag_taisui"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                } else if item.isSanSha {
                    Text(lang.t("tag_sansha"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple)
                }
            }
            
            // 中行: 年飞星数字 (大字显影)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(item.yearGuestStar)")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(isDanger ? Color.red : (isJi ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.7)))
                
                Text("\(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 1)
            
            // 底行: 星名与化解提示
            Text(item.starName)
                .font(.system(size: 8))
                .foregroundColor(isDanger ? Color.red : Color.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(6)
        .frame(minHeight: 68)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: isDanger ? 1.5 : 1)
        )
    }
}
