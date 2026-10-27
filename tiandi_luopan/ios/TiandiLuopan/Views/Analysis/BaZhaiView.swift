import SwiftUI

// MARK: - 八宅明镜与三合水法全景研判视图 (BaZhai & SanHe Water View)

public struct BaZhaiView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @State private var selectedSubTab: Int = 0 // 0: 八宅明镜, 1: 三合水法
    @State private var showPaywall: Bool = false
    public var isEmbedded: Bool = false
    
    public init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }
    
    public var body: some View {
        let state = motion.headingState
        let bz = BaZhaiEngine.shared.analyze(
            sittingPalace: state.sittingMountain.palace,
            facingPalace: state.facingMountain.palace
        )
        let shItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: state.sittingMountain)
        
        let content = VStack(spacing: 16) {
            // 1. 子 Tab 切换条
            subTabBar()
            
            if selectedSubTab == 0 {
                // 八宅明镜板块
                baZhaiContent(bz: bz, state: state)
            } else {
                // 三合水法板块
                sanHeContent(shItems: shItems, state: state)
            }
        }
        .padding(.top, isEmbedded ? 0 : 12)
        .padding(.bottom, isEmbedded ? 0 : 24)
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        
        if isEmbedded {
            content
        } else {
            ScrollView {
                content
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        }
    }
    
    // MARK: - 子 Tab 切换栏
    private func subTabBar() -> some View {
        HStack(spacing: 0) {
            Button(action: { selectedSubTab = 0 }) {
                Text("八宅大游年 · 门宅纳气")
                    .font(.system(size: 13, weight: selectedSubTab == 0 ? .bold : .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedSubTab == 0 ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                    .foregroundColor(selectedSubTab == 0 ? .black : .white.opacity(0.7))
            }
            
            Button(action: { selectedSubTab = 1 }) {
                Text("三合十二长生 · 黄泉水法")
                    .font(.system(size: 13, weight: selectedSubTab == 1 ? .bold : .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedSubTab == 1 ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                    .foregroundColor(selectedSubTab == 1 ? .black : .white.opacity(0.7))
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 八宅明镜内容
    private func baZhaiContent(bz: BaZhaiAnalysis, state: CompassHeadingState) -> some View {
        VStack(spacing: 12) {
            // 宅型概览卡
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(bz.houseGua)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text(bz.houseType)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(Color.orange)
                            .cornerRadius(4)
                    }
                    Text("向首开门方：\(bz.gateDirection)方 · 纳【\(bz.gateStar.rawValue)】")
                        .font(.system(size: 13))
                        .foregroundColor(bz.gateStar.isAuspicious ? Color.green : Color.red)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // 八方游年星列表
            VStack(spacing: 8) {
                ForEach(bz.items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.direction)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(item.star.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(item.star.isAuspicious ? Color(red: 0.4, green: 0.85, blue: 0.4) : Color(red: 0.95, green: 0.4, blue: 0.4))
                        }
                        .frame(width: 120, alignment: .leading)
                        
                        Text(item.star.actionSuggestion)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            
            // 天星择日 · 动土安门日课自检卡
            let zeri = ZeRiEngine.shared.analyze(sitting: state.sittingMountain)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text("天星择日 · 动土安门日课自检")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(zeri.overallStatus)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(zeri.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(zeri.isAuspicious ? Color.green : Color.red)
                        .cornerRadius(4)
                }
                
                Text("当前四柱：\(zeri.fourPillarsText)")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundColor(Color.yanCyan)
                
                Text(zeri.detailsText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("宜")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                        Text(zeri.yiActivities.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("忌")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                        Text(zeri.jiActivities.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 三合与杨公八煞黄泉消砂内容
    private func sanHeContent(shItems: [SanHeWaterItem], state: CompassHeadingState) -> some View {
        let hq = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: state.facingMountain)
        let basha = SanHeWaterEngine.shared.resolveBaSha(sitting: state.sittingMountain)
        
        return VStack(spacing: 12) {
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: "杨公八路黄泉与消砂 · VIP 专享",
                    featureDesc: "二十四山向首八路黄泉水法宜忌判定、救贫黄泉水法纳水秘诀与八煞曜位形峦消砂法则，需解锁 VIP 绝学特权。",
                    badge: "👑 VIP 绝学特权",
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
            } else {
                // 1. 八路黄泉水法判据卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "drop.triangle.fill")
                                .foregroundColor(Color.yanCyan)
                            Text("杨公形气 · 八路黄泉水法")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(hq.badgeText)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(hq.isJiuPin ? Color.green.opacity(0.2) : (hq.isDanger ? Color.red.opacity(0.2) : Color.blue.opacity(0.2)))
                            .foregroundColor(hq.isJiuPin ? Color.green : (hq.isDanger ? Color.red : Color.yanCyan))
                            .cornerRadius(4)
                    }
                    
                    Text(hq.waterDesc)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(3)
                    
                    Text("歌诀：“\(hq.quote)”")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                }
                .padding(12)
                .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // 2. 坐山曜煞消峰消砂卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "triangle.fill")
                                .foregroundColor(Color.orange)
                            Text("坐山曜煞 · 凶砂辨识与消纳")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("煞在【\(basha.shaDir)\(basha.shaZhi)位】")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    Text(basha.lore)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(2)
                    
                    Text(basha.remedy)
                        .font(.system(size: 11))
                        .foregroundColor(Color.yellow.opacity(0.9))
                        .lineSpacing(2)
                    
                    Text("口诀：“\(basha.song)”\n法则：\(basha.xiaoShaRule)")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color(red: 0.13, green: 0.11, blue: 0.11))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // 3. 三合十二长生水法总纲卡
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("以【\(state.sittingMountain.name)山】考量十二长生水法")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text("生水旺水宜来流聚，死绝之气宜引出化煞")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                
                // 4. 十二长生流派列表
                VStack(spacing: 8) {
                    ForEach(Array(shItems.prefix(12))) { item in
                        HStack {
                            Text(item.mountainName + "山")
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                                .frame(width: 50, alignment: .leading)
                            
                            Text("【\(item.phase.rawValue)】")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(item.phase == .changSheng || item.phase == .diWang ? Color.green : (item.phase == .mu || item.phase == .jue ? Color.orange : Color.white.opacity(0.8)))
                                .frame(width: 70, alignment: .leading)
                            
                            Text(item.phase.waterRule)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            if item.isHuangQuanSha {
                                Text("黄泉煞")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.3))
                                    .foregroundColor(.red)
                                    .cornerRadius(3)
                            }
                        }
                        .padding(10)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
