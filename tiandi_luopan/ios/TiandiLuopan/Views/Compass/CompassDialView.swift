import SwiftUI

// MARK: - 原生高性能矢量罗盘盘面视图 (Pure SwiftUI Compass Dial)

public struct CompassDialView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    
    // 手势与缩放状态
    @State private var dragStartAngle: Double = 0.0
    @State private var currentDragDelta: Double = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    private let mountains = Mountain24Data.shared.mountains
    private let hexagrams = Hexagram64Data.shared.hexagrams
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.47
            
            ZStack {
                // 1. 随向旋转主盘 (支持陀螺仪自动随向 + 单指触控手动拨盘)
                ZStack {
                    // 底盘渐变与同心金环
                    dialBackground(radius: radius)
                    
                    // 360 度外圈主刻度
                    degreeTicksLayer(radius: radius)
                    
                    // 六十四卦分金环
                    hexagramsLayer(radius: radius * 0.86)
                    
                    // 二十四山正针环
                    mountain24Layer(radius: radius * 0.68)
                    
                    // 八卦八方环
                    eightGuaLayer(radius: radius * 0.46)
                    
                    // 天池底盘与海底红线 (南北指向校准线)
                    tianChiLayer(radius: radius * 0.28)
                }
                .rotationEffect(.degrees(-motion.heading - motion.manualOffset - currentDragDelta))
                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.86), value: motion.heading)
                
                // 2. 固定不动的十字天心线 (Crosshair)
                crosshairLayer(size: size)
                
                // 3. 天池中央水平仪双轴气泡 (Level Bubble)
                levelBubbleLayer(center: center, maxRadius: radius * 0.22)
                
                // 4. 正北红线与正南指示针
                northSouthIndexLayer(radius: radius)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .gesture(
                // 单指拖拽旋转手势
                DragGesture()
                    .onChanged { value in
                        let location = value.location
                        let angle = atan2(location.y - center.y, location.x - center.x) * 180 / .pi
                        if dragStartAngle == 0 {
                            dragStartAngle = angle
                        } else {
                            currentDragDelta = (angle - dragStartAngle)
                        }
                    }
                    .onEnded { _ in
                        motion.applyManualDragDelta(degrees: currentDragDelta)
                        dragStartAngle = 0
                        currentDragDelta = 0
                    }
            )
            .simultaneousGesture(
                // 双指捏合缩放手势
                MagnificationGesture()
                    .onChanged { val in
                        scale = min(max(lastScale * val, 0.85), 2.2)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
        }
    }
    
    // MARK: - 盘面背景
    private func dialBackground(radius: CGFloat) -> some View {
        ZStack {
            // 黑金玄武岩多阶渐变底
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.14, green: 0.13, blue: 0.11), Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.04, green: 0.04, blue: 0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Color.black.opacity(0.8), radius: 15, x: 0, y: 8)
            
            // 外圈金边
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.75, blue: 0.35), Color(red: 0.6, green: 0.45, blue: 0.15), Color(red: 0.95, green: 0.85, blue: 0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.5
                )
                .frame(width: radius * 2, height: radius * 2)
            
            // 同心分隔金线
            ForEach([0.86, 0.68, 0.46, 0.28], id: \.self) { rRatio in
                Circle()
                    .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.4), lineWidth: 1)
                    .frame(width: radius * CGFloat(rRatio) * 2, height: radius * CGFloat(rRatio) * 2)
            }
        }
    }
    
    // MARK: - 360 度圆周刻度
    private func degreeTicksLayer(radius: CGFloat) -> some View {
        ForEach(0..<120) { i in
            let deg = Double(i) * 3.0
            let isMajor = (i % 10 == 0) // 30°
            let isMid = (i % 5 == 0)   // 15°
            let tickLen: CGFloat = isMajor ? 11 : (isMid ? 7 : 4)
            let color = isMajor ? Color(red: 0.95, green: 0.8, blue: 0.3) : Color.white.opacity(0.45)
            
            Rectangle()
                .fill(color)
                .frame(width: isMajor ? 1.8 : 1.0, height: tickLen)
                .offset(y: -radius + tickLen / 2 + 3)
                .rotationEffect(.degrees(deg))
        }
    }
    
    // MARK: - 六十四卦分金环
    private func hexagramsLayer(radius: CGFloat) -> some View {
        ForEach(hexagrams) { hex in
            Text(hex.name.prefix(2))
                .font(.system(size: 8, weight: .semibold, design: .serif))
                .foregroundColor(hex.luckDegree == "大吉" ? Color(red: 0.95, green: 0.75, blue: 0.3) : Color.white.opacity(0.7))
                .offset(y: -radius + 12)
                .rotationEffect(.degrees(hex.angleCenter))
        }
    }
    
    // MARK: - 二十四山正针环
    private func mountain24Layer(radius: CGFloat) -> some View {
        ForEach(mountains) { m in
            let isMainBranch = ["子", "午", "卯", "酉", "乾", "坤", "艮", "巽"].contains(m.name)
            
            VStack(spacing: 2) {
                Text(m.name)
                    .font(.system(size: isMainBranch ? 16 : 13, weight: .bold, design: .serif))
                    .foregroundColor(isMainBranch ? Color(red: 0.96, green: 0.35, blue: 0.3) : Color(red: 0.95, green: 0.82, blue: 0.4))
                Text(m.element)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .offset(y: -radius + 18)
            .rotationEffect(.degrees(m.angleCenter))
        }
    }
    
    // MARK: - 先天八卦环
    private func eightGuaLayer(radius: CGFloat) -> some View {
        let guas = [
            ("坎", 0.0), ("艮", 45.0), ("震", 90.0), ("巽", 135.0),
            ("离", 180.0), ("坤", 225.0), ("兑", 270.0), ("乾", 315.0)
        ]
        return ForEach(guas, id: \.0) { item in
            Text(item.0)
                .font(.system(size: 15, weight: .black, design: .serif))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                .offset(y: -radius + 14)
                .rotationEffect(.degrees(item.1))
        }
    }
    
    // MARK: - 天池海底红线
    private func tianChiLayer(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.06))
                .frame(width: radius * 2, height: radius * 2)
            
            // 天池外金环
            Circle()
                .stroke(Color(red: 0.9, green: 0.75, blue: 0.35), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            
            // 海底红线 (子午红线)
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 1.5, height: radius * 1.8)
            
            // 南北红点
            Circle()
                .fill(Color.red)
                .frame(width: 5, height: 5)
                .offset(y: -radius * 0.75)
            Circle()
                .fill(Color.red)
                .frame(width: 5, height: 5)
                .offset(y: radius * 0.75)
        }
    }
    
    // MARK: - 固定十字天心红线 (Crosshair)
    private func crosshairLayer(size: CGFloat) -> some View {
        ZStack {
            // 垂直天心线
            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(width: 1.2, height: size * 0.96)
            
            // 水平天心线
            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(width: size * 0.96, height: 1.2)
            
            // 中心准星微圆环
            Circle()
                .stroke(Color.red.opacity(0.8), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 真实双轴水平仪气泡
    private func levelBubbleLayer(center: CGPoint, maxRadius: CGFloat) -> some View {
        let maxOffset: CGFloat = maxRadius * 0.65
        let xOffset = CGFloat(-motion.roll / 15.0) * maxOffset
        let yOffset = CGFloat(motion.pitch / 15.0) * maxOffset
        
        let clampedX = min(max(xOffset, -maxOffset), maxOffset)
        let clampedY = min(max(yOffset, -maxOffset), maxOffset)
        
        return ZStack {
            // 水平基准绿圈
            Circle()
                .stroke(motion.isLevel ? Color.green.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            
            // 游动水平气泡
            Circle()
                .fill(motion.isLevel ? Color.green.opacity(0.85) : Color.yellow.opacity(0.8))
                .frame(width: 10, height: 10)
                .offset(x: clampedX, y: clampedY)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.7), value: motion.pitch)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 顶部正北与坐向标记
    private func northSouthIndexLayer(radius: CGFloat) -> some View {
        VStack {
            Image(systemName: "triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.red)
                .rotationEffect(.degrees(180))
                .offset(y: -radius - 12)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
