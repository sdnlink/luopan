import SwiftUI

// MARK: - 主罗盘界面 (Compass Main View)

public struct CompassMainView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @State private var showHexagramDetail = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 背景渐变
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 4) {
                // 1. 顶部数据仪表
                CompassHeaderView()
                
                Spacer(minLength: 4)
                
                // 2. 核心随动罗盘盘面
                CompassDialView()
                    .padding(.horizontal, 8)
                
                Spacer(minLength: 4)
                
                // 3. 底部快捷周易分金与八宅提示卡
                bottomStatusCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }
    
    private func bottomStatusCard() -> some View {
        let hex = Hexagram64Data.shared.hexagram(for: motion.headingState.facingAngle)
        
        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(hex.name)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(hex.luckDegree)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(hex.luckDegree == "大吉" ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                        .foregroundColor(hex.luckDegree == "大吉" ? Color.green : Color.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(motion.coordsDesc)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            HStack {
                Text(hex.fenJinDetail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
                )
        )
    }
}
