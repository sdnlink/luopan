import SwiftUI
import Darwin

// MARK: - 原生高性能矢量罗盘盘面视图 (Pure SwiftUI Compass Dial - 120Hz ProMotion)

public struct CompassDialView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var layers = CompassLayerManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // 手势与缩放状态
    @State private var lastDragAngle: Double = 0.0
    @State private var hasDragStart: Bool = false
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
            // Keep a real safe margin for the outer stroke, radial labels and
            // the north index. The previous 94% diameter left only a few
            // points of breathing room on compact devices.
            let radius = max(0, size * 0.5 - 18)
            let dialCanvasSize = radius * 2 + 32
            // 盘径自适应：以 iPhone 参考半径 175pt 为 1.0x。
            // 分栏左栏 / Duo 内屏的盘径明显小于整屏，各环的径向间距也随之变窄；
            // 文字若放大或保持不变，24 山 / 64 卦 / 节气环必然互相压叠。
            // iPad 12.9 竖屏盘径 ~500pt，文字必须同比放大才可读：上限放到 1.7x。
            let dialGrow = min(max(radius / 175.0, 0.55), 1.7)
            
            ZStack {
                // 1. 随向旋转主盘 (绑定 continuousHeading 避免 360 度倒转 Bug)
                ZStack {
                    // 底盘渐变与同心金环
                    dialBackground(radius: radius)
                    
                    // 360 度外圈主刻度
                    if layers.showDegreeTicks {
                        degreeTicksLayer(radius: radius, grow: dialGrow)
                    }

                    // 二十四节气与十二消息卦环
                    if layers.showSolarTerms {
                        solarTermsLayer(radius: radius * 0.91, grow: dialGrow)
                    }

                    // 六十四卦分金环
                    if layers.showHexagrams64 {
                        hexagramsLayer(radius: radius * 0.83, grow: dialGrow)
                    }

                    // 一百二十分金环
                    if layers.showFenjin120 {
                        fenjinLayer(radius: radius * 0.75, grow: dialGrow)
                    }

                    // 二十四山正针环
                    if layers.showMountain24 {
                        mountain24Layer(radius: radius * 0.66, grow: dialGrow)
                    }

                    // 八卦八方环
                    if layers.showEightGua {
                        eightGuaLayer(radius: radius * 0.46, grow: dialGrow)
                    }

                    // 天池底盘与海底红线 (南北指向校准线)
                    tianChiLayer(radius: radius * 0.28)
                }
                .frame(width: dialCanvasSize, height: dialCanvasSize)
                .drawingGroup() // 启用 Metal GPU 纹理光栅化，彻底消除旋转时几百个图层的 CPU 测量与重绘负荷
                .rotationEffect(.degrees(-motion.continuousHeading - motion.manualOffset - currentDragDelta))
                
                // 2. 固定不动的十字天心线 (Crosshair)
                crosshairLayer(size: size)
                
                // 3. 地理真北金针 (根据当地磁偏角偏转，双指针系统)
                if layers.showTrueNorthNeedle && motion.hasDeclination {
                    trueNorthNeedleLayer(radius: radius * 0.28, grow: dialGrow)
                }
                
                // 4. 天池中央红蓝双色红宝石磁针 (南朱雀红 / 北玄武青)
                magneticNeedleLayer(radius: radius * 0.26)
                    .rotationEffect(.degrees(-motion.continuousMagneticHeading - motion.manualOffset))
                
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
                        if !hasDragStart {
                            hasDragStart = true
                            lastDragAngle = angle
                        } else {
                            var stepDelta = angle - lastDragAngle
                            if stepDelta > 180 { stepDelta -= 360 }
                            if stepDelta < -180 { stepDelta += 360 }
                            currentDragDelta += stepDelta
                            lastDragAngle = angle
                        }
                    }
                    .onEnded { _ in
                        if hasDragStart {
                            motion.applyManualDragDelta(degrees: currentDragDelta)
                        }
                        lastDragAngle = 0
                        hasDragStart = false
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
    private func degreeTicksLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        ForEach(0..<120) { i in
            let angle = Double(i) * 3.0
            let is10 = (i % 10 == 0)
            let is30 = (i % 30 == 0)

            Rectangle()
                .fill(is30 ? Color(red: 0.95, green: 0.85, blue: 0.45) : (is10 ? Color.white.opacity(0.8) : Color.white.opacity(0.35)))
                .frame(width: (is30 ? 1.5 : (is10 ? 1.0 : 0.6)) * grow,
                       height: (is30 ? 9.0 : (is10 ? 6.0 : 4.0)) * grow)
                .offset(y: -radius + (is30 ? 4.5 : (is10 ? 3.0 : 2.0)) * grow)
                .rotationEffect(.degrees(angle))
        }
    }
    
    // MARK: - 二十四节气与十二消息卦环
    private func solarTermsLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        let activeTerm = SolarTermsData.shared.terms.first {
            $0.name == motion.currentSolarTermName
        }

        return ZStack {
            if let activeTerm = activeTerm {
                solarTermHighlightLayer(radius: radius, term: activeTerm)
            }

            ForEach(SolarTermsData.shared.terms) { term in
                VStack(spacing: 0) {
                    Text(term.localizedDialName)
                        .adaptiveFont(size: 7 * grow, weight: term.isMajorTerm ? .bold : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundColor(term.name == motion.currentSolarTermName
                            ? Color.black
                            : (term.isMajorTerm ? Color(red: 0.95, green: 0.45, blue: 0.3) : Color.white.opacity(0.65)))
                    if let hex = term.localizedHexagramLabel {
                        Text(hex)
                            .adaptiveFont(size: 6 * grow, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundColor(term.name == motion.currentSolarTermName ? Color.black.opacity(0.85) : Color(red: 0.95, green: 0.85, blue: 0.45))
                    }
                }
                .frame(width: radius * 0.24)
                .offset(y: -radius + 6 * grow)
                .rotationEffect(.degrees(term.angleCenter))
            }
        }
    }

    /// Highlights the complete 15° solar-term sector in the same north-based
    /// coordinate system as the labels. A polygon is used instead of a shape
    /// arc so the sector remains stable inside the fixed dial canvas.
    private func solarTermHighlightLayer(radius: CGFloat, term: SolarTermItem) -> some View {
        let center = CGPoint(x: radius, y: radius)
        let innerRadius = max(0, radius - 18)
        let outerRadius = radius + 5
        let startAngle = term.angleCenter - 7.5
        let endAngle = term.angleCenter + 7.5
        let steps = 12

        return Path { path in
            func point(angle: Double, radius: CGFloat) -> CGPoint {
                let radians = angle * .pi / 180.0
                return CGPoint(
                    x: center.x + CGFloat(Darwin.sin(radians)) * radius,
                    y: center.y - CGFloat(Darwin.cos(radians)) * radius
                )
            }

            path.move(to: point(angle: startAngle, radius: outerRadius))
            for step in 1...steps {
                let fraction = Double(step) / Double(steps)
                path.addLine(to: point(angle: startAngle + (endAngle - startAngle) * fraction, radius: outerRadius))
            }
            for step in stride(from: steps, through: 0, by: -1) {
                let fraction = Double(step) / Double(steps)
                path.addLine(to: point(angle: startAngle + (endAngle - startAngle) * fraction, radius: innerRadius))
            }
            path.closeSubpath()
        }
        .fill(Color(red: 1.0, green: 0.78, blue: 0.18).opacity(0.72))
        .overlay(
            Path { path in
                func point(angle: Double, radius: CGFloat) -> CGPoint {
                    let radians = angle * .pi / 180.0
                    return CGPoint(
                        x: center.x + CGFloat(Darwin.sin(radians)) * radius,
                        y: center.y - CGFloat(Darwin.cos(radians)) * radius
                    )
                }
                path.move(to: point(angle: startAngle, radius: outerRadius))
                for step in 1...steps {
                    let fraction = Double(step) / Double(steps)
                    path.addLine(to: point(angle: startAngle + (endAngle - startAngle) * fraction, radius: outerRadius))
                }
            }
            .stroke(Color.yellow, lineWidth: 1.5)
        )
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
    }
    
    // MARK: - 六十四卦分金环
    private func hexagramsLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        ForEach(hexagrams) { hex in
            Text(hex.localizedDialLabel)
                .adaptiveFont(size: 7 * grow, weight: .semibold, design: .serif)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(hex.isGreatAuspicious ? Color(red: 0.95, green: 0.75, blue: 0.3) : Color.white.opacity(0.65))
                .frame(width: radius * 0.092)
                .offset(y: -radius + 8 * grow)
                .rotationEffect(.degrees(hex.angleCenter))
        }
    }
    
    // MARK: - 一百二十分金环 (每山5分金, 旺相红金/孤虚白灰)
    private func fenjinLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        ForEach(Fenjin120Data.shared.allFenjin) { f in
            Rectangle()
                .fill(f.isAuspicious ? Color(red: 0.95, green: 0.8, blue: 0.3) : Color.white.opacity(0.2))
                .frame(width: 1.0 * grow, height: (f.isAuspicious ? 6.0 : 4.0) * grow)
                .offset(y: -radius)
                .rotationEffect(.degrees(f.centerAngle))
        }
    }
    
    // MARK: - 二十四山正针环
    private func mountain24Layer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        return ZStack {
            ForEach(mountains) { m in
                let isMainBranch = m.isCardinalOrCorner
                // 标签高度跟随系统字号（1.0 ... 1.3x）与盘径放大（grow），
                // 取自当前窗口的 Environment，多窗口下各窗口各取各的。
                let baseLabelHeight: CGFloat = horizontalSizeClass == .regular ? 36.0 : 30.0
                // 基准高度也要随盘径缩放：否则 grow < 1 时
                // (labelHeight - baseLabelHeight) 为负，会把标签推到盘外。
                let scaledBaseHeight = baseLabelHeight * grow
                let labelHeight = scaledBaseHeight
                    * AdaptiveFontMetrics.dynamicTypeScale(for: dynamicTypeSize)

                VStack(spacing: 1) {
                    Text(m.localizedName)
                        .adaptiveFont(size: (isMainBranch ? 15 : 12) * grow, weight: .bold, design: .serif)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundColor(isMainBranch ? Color(red: 0.96, green: 0.35, blue: 0.3) : Color(red: 0.95, green: 0.82, blue: 0.4))
                    Text(m.localizedElement)
                        .adaptiveFont(size: 7 * grow, weight: .medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                // 24 山标签是"山名 + 五行"两行：高度随系统字号与盘径放大。
                // 外沿固定：标签变高时中心向盘心方向补偿一半增量，
                // 避免放大后外沿压到度数环、内沿继续挤 64 卦环。
                // 标签宽度必须小于圆周上每个标签的节距：
                // 24 个标签均分 2π·radius，节距 ≈ 0.262·radius，留 15% 间隙取 0.222。
                // 旧值 radius*0.25 叠加旋转后相邻标签必然互相压叠。
                .frame(width: min(max(24 * grow, radius * 0.25), radius * 0.222),
                       height: labelHeight)
                .offset(y: -radius + 14 * grow + (labelHeight - scaledBaseHeight) / 2)
                .rotationEffect(.degrees(m.angleCenter))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }
    
    // MARK: - 后天八卦环 (坎北/离南/震东/兑西，洛书后天方位)
    private struct GuaItem: Identifiable {
        let id: String
        let key: String
        let angle: Double
    }
    
    private func eightGuaLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        let lang = LocalizationManager.shared
        let guas: [GuaItem] = [
            GuaItem(id: "kan", key: "gua_kan", angle: 0.0),
            GuaItem(id: "gen", key: "gua_gen", angle: 45.0),
            GuaItem(id: "zhen", key: "gua_zhen", angle: 90.0),
            GuaItem(id: "xun", key: "gua_xun", angle: 135.0),
            GuaItem(id: "li", key: "gua_li", angle: 180.0),
            GuaItem(id: "kun", key: "gua_kun", angle: 225.0),
            GuaItem(id: "dui", key: "gua_dui", angle: 270.0),
            GuaItem(id: "qian", key: "gua_qian", angle: 315.0)
        ]
        return ForEach(guas) { item in
            Text(lang.t(item.key))
                .adaptiveFont(size: 14 * grow, weight: .black, design: .serif)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                .frame(width: radius * 0.42)
                .offset(y: -radius + 12 * grow)
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
        let center = radius

        return ZStack {
            // 北端：传统罗盘以青/蓝色端指向地磁北。
            Path { path in
                path.move(to: CGPoint(x: center, y: center))
                path.addLine(to: CGPoint(x: center - 3.5, y: center - radius * 0.8))
                path.addLine(to: CGPoint(x: center, y: center - radius * 0.92))
                path.addLine(to: CGPoint(x: center + 3.5, y: center - radius * 0.8))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.25, blue: 0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            
            // 南端：红色端与北端相反，避免把磁针读成反向。
            Path { path in
                path.move(to: CGPoint(x: center, y: center))
                path.addLine(to: CGPoint(x: center - 3.5, y: center + radius * 0.8))
                path.addLine(to: CGPoint(x: center, y: center + radius * 0.92))
                path.addLine(to: CGPoint(x: center + 3.5, y: center + radius * 0.8))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.7, green: 0.1, blue: 0.1)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            
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
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
    }
    
    // MARK: - 地理真北金针 (根据当地磁偏角偏转，双指针系统)
    private func trueNorthNeedleLayer(radius: CGFloat, grow: CGFloat = 1.0) -> some View {
        let center = radius
        let rotationAngle: Double
        if motion.northReference == .trueNorth {
            rotationAngle = -motion.continuousHeading - motion.manualOffset
        } else {
            rotationAngle = -(motion.continuousMagneticHeading + motion.currentDeclination) - motion.manualOffset
        }

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: center, y: center))
                path.addLine(to: CGPoint(x: center - 2.0, y: center - radius * 0.85))
                path.addLine(to: CGPoint(x: center, y: center - radius * 1.05))
                path.addLine(to: CGPoint(x: center + 2.0, y: center - radius * 0.85))
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
            .frame(width: radius * 2, height: radius * 2)
            
            Text(lang.t("true_north_short"))
                .adaptiveFont(size: 7 * grow, weight: .bold)
                .foregroundColor(Color.black)
                .offset(y: -radius * 0.72)
        }
        .frame(width: radius * 2, height: radius * 2)
        .rotationEffect(.degrees(rotationAngle))
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
        let canvasSize = radius * 2 + 32
        let center = canvasSize / 2

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: center, y: center - radius - 1))
                path.addLine(to: CGPoint(x: center - 7, y: center - radius - 12))
                path.addLine(to: CGPoint(x: center + 7, y: center - radius - 12))
                path.closeSubpath()
            }
            .fill(Color.red)
        }
        .frame(width: canvasSize, height: canvasSize)
        .allowsHitTesting(false)
    }
}
