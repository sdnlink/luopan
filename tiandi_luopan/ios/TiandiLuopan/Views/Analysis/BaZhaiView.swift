import SwiftUI

// MARK: - 八宅明镜与三合水法全景研判视图 (BaZhai & SanHe Water View)

public struct BaZhaiView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @State private var selectedSubTab: Int = 0 // 0: 八宅明镜, 1: 三合水法
    
    public init() {}
    
    public var body: some View {
        let state = motion.headingState
        let bz = BaZhaiEngine.shared.analyze(
            sittingPalace: state.sittingMountain.palace,
            facingPalace: state.facingMountain.palace
        )
        let shItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: state.sittingMountain)
        
        ScrollView {
            VStack(spacing: 16) {
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
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
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
        }
    }
    
    // MARK: - 三合水法内容
    private func sanHeContent(shItems: [SanHeWaterItem], state: CompassHeadingState) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("以【\(state.sittingMountain.name)山】立向考量十二长生水法")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text("生水旺水宜来流聚，死绝之气宜引出化煞")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
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
