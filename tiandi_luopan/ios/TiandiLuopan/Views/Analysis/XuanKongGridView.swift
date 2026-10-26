import SwiftUI

// MARK: - 原生玄空九宫飞星排盘与三元九运视图 (XuanKong Flying Stars View)

public struct XuanKongGridView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @State private var selectedPeriod: Int = 9
    
    // 九宫格九个方位的标准九宫排布对应 (从左到右，从上到下：东南4、正南9、西南2；正东3、中宫5、正西7；东北8、正北1、西北6)
    // 洛书标准顺序索引：[3, 8, 1, 2, 4, 6, 7, 0, 5]
    private let gridDisplayOrder = [3, 8, 1, 2, 4, 6, 7, 0, 5]
    
    public init() {}
    
    public var body: some View {
        let chart = FlyingStarsEngine.shared.calculateChart(
            period: selectedPeriod,
            sitting: motion.headingState.sittingMountain,
            facing: motion.headingState.facingMountain
        )
        
        ScrollView {
            VStack(spacing: 16) {
                // 1. 元运选择器 (一运 ~ 九运)
                periodPickerBar()
                
                // 2. 当前坐向格局徽章
                patternBadgeView(chart: chart)
                
                // 3. 经典玄空九宫格 (3x3 矩阵)
                ninePalacesGrid(chart: chart)
                    .padding(.horizontal, 16)
                
                // 4. 深度格局断语卡
                analysisCard(chart: chart)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
    }
    
    // MARK: - 元运切换栏
    private func periodPickerBar() -> some View {
        VStack(spacing: 6) {
            Text("元运选择 (当前下元九运 2024-2043)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...9, id: \.self) { p in
                        Button(action: {
                            selectedPeriod = p
                        }) {
                            Text("\(p)运")
                                .font(.system(size: 13, weight: p == selectedPeriod ? .bold : .medium))
                                .frame(width: 44, height: 32)
                                .background(p == selectedPeriod ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.white.opacity(0.1))
                                .foregroundColor(p == selectedPeriod ? .black : .white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 格局徽章
    private func patternBadgeView(chart: XuanKongChart) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("\(chart.sittingMountain)山\(chart.facingMountain)向")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text(chart.patternType)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(Color.orange)
                    .cornerRadius(6)
            }
        }
    }
    
    // MARK: - 3x3 九宫飞星网格
    private func ninePalacesGrid(chart: XuanKongChart) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(gridDisplayOrder, id: \.self) { idx in
                let cell = chart.palaces[idx]
                palaceCellView(cell: cell)
            }
        }
    }
    
    private func palaceCellView(cell: PalaceCell) -> some View {
        VStack(spacing: 4) {
            // 方位与宫位名
            HStack {
                Text(cell.direction)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(cell.trigram)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // 核心飞星：山星 (左上) · 向星 (右上) · 运星 (下中)
            HStack(alignment: .center) {
                // 山星 (丁星)
                Text("\(cell.mountainStar)")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundColor(cell.isWangMountain ? Color.green : (cell.mountainStar == 5 ? Color.red : .white))
                
                Spacer()
                
                // 向星 (财星)
                Text("\(cell.facingStar)")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundColor(cell.isWangFacing ? Color(red: 0.95, green: 0.85, blue: 0.45) : (cell.facingStar == 5 ? Color.red : .white))
            }
            .padding(.horizontal, 4)
            
            Spacer()
            
            // 底栏运星与当位评价
            HStack {
                Text("运\(cell.periodStar)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.yanCyan)
                Spacer()
                if cell.isShaWuHuang || cell.isShaErHei {
                    Text("煞")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.red)
                } else if cell.isWangFacing {
                    Text("旺财")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(8)
        .frame(height: 105)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cell.isCenter ? Color(red: 0.16, green: 0.15, blue: 0.18) : Color(red: 0.11, green: 0.11, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cell.isWangFacing ? Color.yellow.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 深度格局断语卡
    private func analysisCard(chart: XuanKongChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("三元玄空深度堪舆研判")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            
            Text(chart.summaryAnalysis)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.25), lineWidth: 1)
                )
        )
    }
}
