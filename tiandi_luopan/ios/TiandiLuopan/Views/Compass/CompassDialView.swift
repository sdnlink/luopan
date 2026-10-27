import SwiftUI

// MARK: - 原生高性能矢量罗盘盘面视图 (Pure SwiftUI Compass Dial - 120Hz ProMotion)

public struct CompassDialView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var layers = CompassLayerManager.shared
    
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
                // 1. 随向旋转主盘 (绑定 continuousHeading 避免 360 度倒转 Bug)
                ZStack {
                    // 底盘渐变与同心金环
                    dialBackground(radius: radius)
                    
                    // 360 度外圈主刻度
                    if layers.showDegreeTicks {
                        degreeTicksLayer(radius: radius)
                    }
                    
                    // 二十四节气与十二消息卦环
                    if layers.showSolarTerms {
                        solarTermsLayer(radius: radius * 0.91)
                    }
                    
                    // 六十四卦分金环
                    if layers.showHexagrams64 {
                        hexagramsLayer(radius: radius * 0.83)
                    }
                    
                    // 一百二十分金环
                    if layers.showFenjin120 {
                        fenjinLayer(radius: radius * 0.75)
                    }
                    
                    // 二十四山正针环
                    if layers.showMountain24 {
                        mountain24Layer(radius: radius * 0.66)
                    }
                    
                    // 八卦八方环
                    if layers.showEightGua {
                        eightGuaLayer(radius: radius * 0.46)
                    }
                    
                    // 天池底盘与海底红线 (南北指向校准线)
                    tianChiLayer(radius: radius * 0.28)
                }
                .rotationEffect(.degrees(-motion.continuousHeading - motion.manualOffset - currentDragDelta))
                .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.88), value: motion.continuousHeading)
                
                // 2. 固定不动的十字天心线 (Crosshair)
                crosshairLayer(size: size)
                
                // 3. 地理真北金针 (根据当地磁偏角偏转，双指针系统)
                if layers.showTrueNorthNeedle {
                    trueNorthNeedleLayer(radius: radius * 0.28)
                }
                
                // 4. 天池中央红蓝双色红宝石磁针 (南朱雀红 / 北玄武青)
                magneticNeedleLayer(radius: radius * 0.26)
                
                // 5. 天池中央水平仪双轴气泡 (Level Bubble)
                if layers.showLevelBubble {
                    levelBubbleLayer(center: center, maxRadius: radius * 0.22)
                }
                
                // 6. 正北红三角顶针与正南对准刻度
                northSouthIndexLayer(radius: radius)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .gesture(
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
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.18),
                            Color(red: 0.08, green: 0.08, blue: 0.11),
                            Color(red: 0.03, green: 0.03, blue: 0.04)
                        ],
                        center: .center,
                        startRadius: radius * 0.2,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
            
            // 外圈金圈装饰
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.85, blue: 0.45),
                            Color(red: 0.65, green: 0.45, blue: 0.2),
                            Color(red: 0.95, green: 0.85, blue: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: radius * 2, height: radius * 2)
            
            Circle()
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.35), lineWidth: 1)
                .frame(width: radius * 1.82, height: radius * 1.82)
            
            Circle()
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.3), lineWidth: 1)
                .frame(width: radius * 1.5, height: radius * 1.5)
            
            Circle()
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.3), lineWidth: 1)
                .frame(width: radius * 0.92, height: radius * 0.92)
        }
    }
    
    // MARK: - 360 度外圈主刻度
    private func degreeTicksLayer(radius: CGFloat) -> some View {
        ForEach(0..<120) { i in
            let angle = Double(i) * 3.0
            let is10 = (i % 10 == 0)
            let is30 = (i % 30 == 0)
            
            Rectangle()
                .fill(is30 ? Color(red: 0.95, green: 0.85, blue: 0.45) : (is10 ? Color.white.opacity(0.8) : Color.white.opacity(0.35)))
                .frame(width: is30 ? 1.5 : (is10 ? 1.0 : 0.6), height: is30 ? 9 : (is10 ? 6 : 4))
                .offset(y: -radius + (is30 ? 4.5 : (is10 ? 3 : 2)))
                .rotationEffect(.degrees(angle))
        }
    }
    
    // MARK: - 二十四节气与十二消息卦环
    private func solarTermsLayer(radius: CGFloat) -> some View {
        ForEach(SolarTermsData.shared.terms) { term in
            VStack(spacing: 0) {
                Text(term.name)
                    .font(.system(size: 7, weight: term.isMajorTerm ? .bold : .regular))
                    .foregroundColor(term.isMajorTerm ? Color(red: 0.95, green: 0.45, blue: 0.3) : Color.white.opacity(0.65))
                if let hex = term.hexagramName {
                    Text(hex.prefix(1))
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
            }
            .offset(y: -radius + 6)
            .rotationEffect(.degrees(term.angleCenter))
        }
    }
    
    // MARK: - 六十四卦分金环
    private func hexagramsLayer(radius: CGFloat) -> some View {
        ForEach(hexagrams) { hex in
            Text(hex.name.prefix(2))
                .font(.system(size: 7, weight: .semibold, design: .serif))
                .foregroundColor(hex.luckDegree == "大吉" ? Color(red: 0.95, green: 0.75, blue: 0.3) : Color.white.opacity(0.65))
                .offset(y: -radius + 8)
                .rotationEffect(.degrees(hex.angleCenter))
        }
    }
    
    // MARK: - 一百二十分金环 (每山5分金, 旺相红金/孤虚白灰)
    private func fenjinLayer(radius: CGFloat) -> some View {
        ForEach(Fenjin120Data.shared.allFenjin) { f in
            Rectangle()
                .fill(f.isAuspicious ? Color(red: 0.95, green: 0.8, blue: 0.3) : Color.white.opacity(0.2))
                .frame(width: 1, height: f.isAuspicious ? 6 : 4)
                .offset(y: -radius)
                .rotationEffect(.degrees(f.centerAngle))
        }
    }
    
    // MARK: - 二十四山正针环
    private func mountain24Layer(radius: CGFloat) -> some View {
        ForEach(mountains) { m in
            let isMainBranch = ["子", "午", "卯", "酉", "乾", "坤", "艮", "巽"].contains(m.name)
            
            VStack(spacing: 1) {
                Text(m.name)
                    .font(.system(size: isMainBranch ? 15 : 12, weight: .bold, design: .serif))
                    .foregroundColor(isMainBranch ? Color(red: 0.96, green: 0.35, blue: 0.3) : Color(red: 0.95, green: 0.82, blue: 0.4))
                Text(m.element)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .offset(y: -radius + 14)
            .rotationEffect(.degrees(m.angleCenter))
        }
    }
    
    // MARK: - 先天八卦环
    private struct GuaItem: Identifiable {
        let id: String
        let angle: Double
    }
    
    private func eightGuaLayer(radius: CGFloat) -> some View {
        let guas: [GuaItem] = [
            GuaItem(id: "坎", angle: 0.0), GuaItem(id: "艮", angle: 45.0),
            GuaItem(id: "震", angle: 90.0), GuaItem(id: "巽", angle: 135.0),
            GuaItem(id: "离", angle: 180.0), GuaItem(id: "坤", angle: 225.0),
            GuaItem(id: "兑", angle: 270.0), GuaItem(id: "乾", angle: 315.0)
        ]
        return ForEach(guas) { item in
            Text(item.id)
                .font(.system(size: 14, weight: .black, design: .serif))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                .offset(y: -radius + 12)
                .rotationEffect(.degrees(item.angle))
        }
    }
    
    // MARK: - 天池海底红线
    private func tianChiLayer(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                .frame(width: radius * 2, height: radius * 2)
            
            Circle()
                .stroke(Color(red: 0.9, green: 0.75, blue: 0.35), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 1.5, height: radius * 1.85)
            
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
    
    // MARK: - 传统红蓝双色红宝石磁针 (Magnetic Needle)
    private func magneticNeedleLayer(radius: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -3.5, y: -radius * 0.8))
                path.addLine(to: CGPoint(x: 0, y: -radius * 0.92))
                path.addLine(to: CGPoint(x: 3.5, y: -radius * 0.8))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.7, green: 0.1, blue: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -3.5, y: radius * 0.8))
                path.addLine(to: CGPoint(x: 0, y: radius * 0.92))
                path.addLine(to: CGPoint(x: 3.5, y: radius * 0.8))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.25, blue: 0.6)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.95, green: 0.85, blue: 0.5), Color(red: 0.6, green: 0.45, blue: 0.2)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 5
                    )
                )
                .frame(width: 10, height: 10)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 地理真北金针 (根据当地磁偏角偏转，双指针系统)
    private func trueNorthNeedleLayer(radius: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -2.0, y: -radius * 0.85))
                path.addLine(to: CGPoint(x: 0, y: -radius * 1.05))
                path.addLine(to: CGPoint(x: 2.0, y: -radius * 0.85))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 0.8, green: 0.6, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color.yellow.opacity(0.4), radius: 2)
            
            Text("真")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(Color.black)
                .offset(y: -radius * 0.72)
        }
        .rotationEffect(.degrees(motion.currentDeclination))
        .allowsHitTesting(false)
    }
    
    // MARK: - 十字天心线
    private func crosshairLayer(size: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.75))
                .frame(width: 1, height: size * 0.96)
            Rectangle()
                .fill(Color.red.opacity(0.75))
                .frame(width: size * 0.96, height: 1)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 水平仪双轴水泡
    private func levelBubbleLayer(center: CGPoint, maxRadius: CGFloat) -> some View {
        let maxOffset: CGFloat = maxRadius * 0.75
        let offsetX = max(-maxOffset, min(maxOffset, CGFloat(motion.roll) * 3.5))
        let offsetY = max(-maxOffset, min(maxOffset, CGFloat(-motion.pitch) * 3.5))
        let isLevel = motion.isLevel
        
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: maxRadius * 1.2, height: maxRadius * 1.2)
            
            Circle()
                .fill(isLevel ? Color.green.opacity(0.65) : Color.orange.opacity(0.65))
                .frame(width: 14, height: 14)
                .offset(x: offsetX, y: offsetY)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: offsetX)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 正北与正南顶针
    private func northSouthIndexLayer(radius: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: -radius - 1))
                path.addLine(to: CGPoint(x: -7, y: -radius - 12))
                path.addLine(to: CGPoint(x: 7, y: -radius - 12))
                path.closeSubpath()
            }
            .fill(Color.red)
        }
        .allowsHitTesting(false)
    }
}
