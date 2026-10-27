import SwiftUI

// MARK: - 户型空间立极与全屋风水体检视图 (Floorplan View - PRD 5.3)

public struct FloorplanView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    @State private var rooms: [FloorplanRoom] = FloorplanEngine.shared.generateSampleRooms()
    @State private var centroid: CGPoint = CGPoint(x: 0.5, y: 0.5) // 归一化重心
    @State private var compassRotation: Double = 0.0
    @State private var isSyncWithCompass: Bool = true
    @State private var selectedRoom: FloorplanRoom? = nil
    @State private var userFloorplanImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var showPaywall: Bool = false
    
    public init() {}
    
    private var effectiveHeading: Double {
        return isSyncWithCompass ? motion.headingState.facingAngle : compassRotation
    }
    
    public var body: some View {
        let auditResult = FloorplanEngine.shared.auditFloorplan(
            rooms: rooms,
            centroid: centroid,
            heading: effectiveHeading
        )
        
        return ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            
            VStack(spacing: 8) {
                // 1. 顶部控制栏
                topControlBar()
                
                // 2. 户型交互画布 (户型图 + 随动罗盘半透明扇区 + 立极中宫点)
                floorplanCanvasView(auditedRooms: auditResult.auditedRooms)
                    .frame(height: 340)
                    .padding(.horizontal, 16)
                
                // 3. 底部体检报告与房间列表
                auditListSection(report: auditResult.report)
            }
            .padding(.top, 8)
        }
        .sheet(item: $selectedRoom) { room in
            RoomAuditDetailSheet(room: room)
        }
        .sheet(isPresented: $showImagePicker) {
            FloorplanImagePicker(selectedImage: $userFloorplanImage)
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .floorplanSingle)
        }
    }
    
    // MARK: - 顶栏控制
    private func topControlBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("floorplan_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("当前立向: \(String(format: "%.1f", effectiveHeading))° (\(motion.headingState.sittingMountain.name)山\(motion.headingState.facingMountain.name)向)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // 导入真实户型图纸
            Button(action: {
                if !iap.canUseFloorplan {
                    showPaywall = true
                } else {
                    showImagePicker = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.badge.plus")
                    Text(userFloorplanImage == nil ? lang.t("import_plan") : lang.t("change_plan"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.yanCyan.opacity(0.2))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            
            if userFloorplanImage != nil {
                Button(action: {
                    userFloorplanImage = nil
                }) {
                    Text(lang.t("reset_sample"))
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            
            // 罗盘联动 / 手动微调
            Button(action: {
                isSyncWithCompass.toggle()
                if isSyncWithCompass {
                    compassRotation = motion.headingState.facingAngle
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isSyncWithCompass ? "location.fill" : "hand.draw.fill")
                    Text(isSyncWithCompass ? "联动" : "微调")
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isSyncWithCompass ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(isSyncWithCompass ? .green : .orange)
                .cornerRadius(6)
            }
            
            // 重置立极点
            Button(action: {
                centroid = CGPoint(x: 0.5, y: 0.5)
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .padding(5)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 户型交互画布
    private func floorplanCanvasView(auditedRooms: [FloorplanRoom]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerPt = CGPoint(x: centroid.x * w, y: centroid.y * h)
            
            ZStack {
                // 底色
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                // 真实导入图纸底图
                if let userImg = userFloorplanImage {
                    Image(uiImage: userImg)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.85)
                }
                
                // 户型外墙与房间隔断
                ForEach(auditedRooms) { room in
                    roomBlockView(room: room, w: w, h: h)
                }
                
                // 随动半透明罗盘八宫扇区与十字天心
                compassOverlayLayer(centerPt: centerPt, size: min(w, h))
                
                // 可拖拽的中宫立极点 (Centroid Handle)
                centroidHandle(centerPt: centerPt, w: w, h: h)
            }
            .clipped()
            .cornerRadius(12)
        }
    }
    
    private func roomBlockView(room: FloorplanRoom, w: CGFloat, h: CGFloat) -> some View {
        let rx = room.rect.origin.x * w
        let ry = room.rect.origin.y * h
        let rw = room.rect.size.width * w
        let rh = room.rect.size.height * h
        
        let isBad = room.inspectionLevel == "严重煞气" || room.inspectionLevel == "凶"
        let isGood = room.inspectionLevel == "吉"
        let strokeColor = isBad ? Color.red : (isGood ? Color.green : Color.white.opacity(0.25))
        let bgColor = isBad ? Color.red.opacity(0.15) : (isGood ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
        
        return Button(action: {
            if !iap.canUseFloorplan {
                showPaywall = true
            } else {
                selectedRoom = room
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(strokeColor, lineWidth: isBad ? 1.5 : 1)
                    )
                
                VStack(spacing: 2) {
                    Image(systemName: room.type.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(strokeColor)
                    Text(room.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text(room.palaceName)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(2)
            }
        }
        .frame(width: rw, height: rh)
        .position(x: rx + rw / 2, y: ry + rh / 2)
    }
    
    private func compassOverlayLayer(centerPt: CGPoint, size: CGFloat) -> some View {
        let r = size * 0.44
        
        return ZStack {
            // 八宫辐射线
            ForEach(0..<8) { i in
                let angle = Double(i) * 45.0 - effectiveHeading
                Path { p in
                    p.move(to: centerPt)
                    let rad = angle * .pi / 180.0
                    p.addLine(to: CGPoint(x: centerPt.x + CGFloat(sin(rad)) * r, y: centerPt.y - CGFloat(cos(rad)) * r))
                }
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.35), lineWidth: 1)
            }
            
            // 十字天心红线
            Path { p in
                p.move(to: CGPoint(x: centerPt.x - r, y: centerPt.y))
                p.addLine(to: CGPoint(x: centerPt.x + r, y: centerPt.y))
                p.move(to: CGPoint(x: centerPt.x, y: centerPt.y - r))
                p.addLine(to: CGPoint(x: centerPt.x, y: centerPt.y + r))
            }
            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
            
            // 外圈金环
            Circle()
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.4), lineWidth: 1)
                .frame(width: r * 2, height: r * 2)
                .position(centerPt)
        }
        .allowsHitTesting(false)
    }
    
    private func centroidHandle(centerPt: CGPoint, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.95, green: 0.85, blue: 0.45))
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.6), radius: 3)
            Circle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: 24, height: 24)
            Text("立极点")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.black)
        }
        .position(centerPt)
        .gesture(
            DragGesture()
                .onChanged { val in
                    let newX = max(0.1, min(0.9, val.location.x / w))
                    let newY = max(0.1, min(0.9, val.location.y / h))
                    centroid = CGPoint(x: newX, y: newY)
                }
        )
    }
    
    // MARK: - 底部体检报告
    private func auditListSection(report: [FloorplanAuditItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🏠 \(lang.t("audit_checklist")) (\(report.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text("拖动金圈微调中宫")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    if !iap.canUseFloorplan {
                        VIPLockCardView(
                            title: "空间立极全屋体检 · VIP 专享",
                            featureDesc: "全屋空间几何立极、大门/主卧/厨房/卫浴火烧天门、水浸中宫、鬼门水污深度诊断报告，需开通 VIP 或单套解锁。",
                            badge: "👑 VIP / 单套 ¥19.9",
                            targetProductId: .floorplanSingle,
                            onUnlockTap: { showPaywall = true }
                        )
                        
                        // 免费展示首条体检概览
                        if let firstItem = report.first {
                            auditItemRow(item: firstItem)
                        }
                    } else {
                        ForEach(report) { item in
                            auditItemRow(item: item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func auditItemRow(item: FloorplanAuditItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(item.severity == "严重煞气" ? Color.red : (item.severity == "吉" ? Color.green : Color.orange))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(item.severity)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(item.severity == "严重煞气" ? Color.red.opacity(0.2) : (item.severity == "吉" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                        .foregroundColor(item.severity == "严重煞气" ? .red : (item.severity == "吉" ? .green : .orange))
                        .cornerRadius(4)
                }
                Text(item.lore)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Text("💡 化解: \(item.solution)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(8)
    }
}

// MARK: - 房间风水体检详勘弹窗 (Room Audit Detail Sheet)
public struct RoomAuditDetailSheet: View {
    public let room: FloorplanRoom
    @Environment(\.presentationMode) var presentationMode
    
    public init(room: FloorplanRoom) {
        self.room = room
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.11).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 顶部房间名与方位徽章
                        HStack(spacing: 12) {
                            Image(systemName: room.type.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(room.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(room.palaceName.isEmpty ? "中宫立极分析中" : "立极方位：\(room.palaceName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.yanCyan)
                            }
                            
                            Spacer()
                            
                            Text(room.inspectionLevel)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeColor.opacity(0.2))
                                .foregroundColor(badgeColor)
                                .cornerRadius(6)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(12)
                        
                        // 2. 气场格局诊断
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Text("格局诊断：\(room.inspectionTitle)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(room.inspectionAdvice)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(12)
                        
                        // 3. 经典堪舆古籍与现代环境机理
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📜 古籍渊源与环境机理")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                            
                            Text("《阳宅三要》云：“大门、主卧、灶堂为阳宅三大核心纲领。”方位各司其职，相克则生浊滞，相生则聚福禄。")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(12)
                        
                        // 4. 生旺化煞秘笈
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 杨公秘传调理与生旺指南")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text(room.inspectionAdvice.isEmpty ? "保持室内光线明朗，适度开窗通风，摆放生机绿植以迎祥纳福。" : room.inspectionAdvice)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.12, blue: 0.11))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitle("空间立极详勘", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var badgeColor: Color {
        switch room.inspectionLevel {
        case "吉": return .green
        case "严重煞气": return .red
        case "预警": return .orange
        default: return Color.yanCyan
        }
    }
}
