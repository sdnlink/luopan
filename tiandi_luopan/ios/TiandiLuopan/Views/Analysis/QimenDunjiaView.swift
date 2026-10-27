import SwiftUI

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航视图 (PRD 第11章)

public struct QimenDunjiaView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @State private var showPaywall: Bool = false
    
    public init() {}
    
    public var body: some View {
        let chart = QimenEngine.shared.calculateChart(heading: motion.headingState.facingAngle)
        
        let lang = LocalizationManager.shared
        return VStack(spacing: 12) {
            // 局数标题栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("qimen_header_title"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                Spacer()
                Text(chart.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("privilege_qimen_title"),
                    featureDesc: lang.t("privilege_qimen_desc"),
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
                .sheet(isPresented: $showPaywall) {
                    VIPPaywallSheet(defaultProductId: .vipYearly)
                }
            } else {
                // 3x3 奇门九宫方阵 (天地人神四盘)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(chart.cells) { cell in
                        qimenCellView(cell: cell)
                    }
                }
                .padding(.horizontal, 16)
                
                // 出行动身方位导航卡
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location.north.circle.fill")
                            .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                        Text(lang.t("qimen_travel_best"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(lang.t("qimen_pattern_best"))
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    
                    Text("\(lang.t("qimen_best_nav"))【\(chart.bestNavDirection)】！\(chart.bestNavReason)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.green)
                        .lineLimit(2)
                    
                    if !chart.tabooDirections.isEmpty {
                        Text("\(lang.t("qimen_taboo_nav"))【\(chart.tabooDirections)】\(lang.t("qimen_taboo_suffix"))")
                            .font(.system(size: 11))
                            .foregroundColor(Color.orange)
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func qimenCellView(cell: QimenPalaceCell) -> some View {
        let isJi = cell.isDoorAuspicious
        let isXiong = cell.isDoorInauspicious
        let borderColor = isJi ? Color.green.opacity(0.5) : (isXiong ? Color.red.opacity(0.4) : Color.white.opacity(0.12))
        let bgColor = isJi ? Color.green.opacity(0.08) : (isXiong ? Color.red.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))
        
        return VStack(spacing: 3) {
            // 顶行: 八神 / 九星
            HStack {
                Text(cell.localizedGodName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.yellow)
                Spacer()
                Text(cell.localizedStarName)
                    .font(.system(size: 9))
                    .foregroundColor(Color.yanCyan)
            }
            
            // 中行: 八门 (大字显影)
            Text(cell.localizedDoorName)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(isJi ? Color.green : (isXiong ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45)))
                .padding(.vertical, 2)
            
            // 底行: 宫名 / 天地三奇六仪
            HStack {
                Text(cell.localizedPalaceName)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(cell.tianStem)/\(cell.diStem)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
        }
        .padding(6)
        .frame(minHeight: 72)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
