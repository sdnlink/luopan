import SwiftUI

// MARK: - 户型空间立极与全屋风水体检视图 (Floorplan View - PRD 5.3)

public struct FloorplanView: View {
    public var isActive: Bool = true
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
    @State private var isEditingRooms: Bool = false
    @State private var activeRoomDragID: String? = nil
    @State private var activeRoomStartRect: CGRect? = nil
    @State private var centroidDragStart: CGPoint? = nil
    @State private var didConsumeFloorplanCredit: Bool = false
    @State private var auditedRooms: [FloorplanRoom] = []
    @State private var auditReport: [FloorplanAuditItem] = []
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    private var effectiveHeading: Double {
        if !isSyncWithCompass {
            return compassRotation
        }
        // 增加 0.25° 死区与防抖阻尼
        let raw = motion.headingState.facingAngle
        return (round(raw * 2.0) / 2.0) // 0.5度一级阶梯消抖
    }
    
    public var body: some View {
        // CompassMotionManager publishes tilt and magnetic-field samples more
        // often than the floorplan audit inputs change. Reuse the last audit
        // result so those unrelated samples only redraw the visible overlay.
        let auditResult: (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) = isActive
            ? (auditedRooms, auditReport)
            : (rooms, [])
        
        return ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            
            if isActive {
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
        }
        .sheet(item: $selectedRoom) { room in
            RoomAuditDetailSheet(room: room)
        }
        .sheet(isPresented: $showImagePicker) {
            FloorplanImagePicker(selectedImage: $userFloorplanImage) {
                if !iap.hasUnlockedVIP && !didConsumeFloorplanCredit {
                    if iap.consumeFloorplanCredit() {
                        didConsumeFloorplanCredit = true
                    } else {
                        userFloorplanImage = nil
                        showPaywall = true
                    }
                }
                }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .floorplanSingle)
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            // Keep the user's room geometry while refreshing language-dependent
            // sample labels and diagnostics.
            let previousRooms = rooms
            let rects = rooms.map(\.rect)
            let refreshed = FloorplanEngine.shared.generateSampleRooms()
            rooms = refreshed.enumerated().map { index, room in
                var updated = room
                if index < previousRooms.count {
                    // Preserve identity so an open detail sheet and report
                    // rows update their text instead of being replaced.
                    updated.id = previousRooms[index].id
                    updated.rect = rects[index]
                }
                return updated
            }
            if let selectedID = selectedRoom?.id,
               let refreshedRoom = rooms.first(where: { $0.id == selectedID }) {
                selectedRoom = refreshedRoom
            }
            refreshAudit()
        }
        .onAppear {
            refreshAudit()
        }
        .onChange(of: isActive) { active in
            if active {
                refreshAudit()
            }
        }
        .onChange(of: effectiveHeading) { _ in
            refreshAudit()
        }
        .onChange(of: centroid) { _ in
            refreshAudit()
        }
    }

    /// Keep an already-presented room sheet aligned with the same audit input
    /// used by the canvas and report list. Without this, rotating the compass
    /// or dragging the Tai Ji point updated the page behind the sheet while
    /// the detail card continued to show stale palace/severity text.
    private func refreshAudit() {
        guard isActive else { return }
        let result = FloorplanEngine.shared.auditFloorplan(
            rooms: rooms,
            centroid: centroid,
            heading: effectiveHeading
        )
        auditedRooms = result.auditedRooms
        auditReport = result.report
        if let selectedID = selectedRoom?.id {
            selectedRoom = result.auditedRooms.first(where: { $0.id == selectedID })
        }
    }

    private var hasFloorplanAccess: Bool {
        iap.hasUnlockedVIP || didConsumeFloorplanCredit
    }

    private func acquireFloorplanAccess() -> Bool {
        if iap.hasUnlockedVIP || didConsumeFloorplanCredit { return true }
        guard iap.consumeFloorplanCredit() else {
            showPaywall = true
            return false
        }
        didConsumeFloorplanCredit = true
        return true
    }
    
    // MARK: - 顶栏控制
    private func topControlBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("floorplan_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(lang.t("floorplan_current_facing"))\(String(format: "%.1f", effectiveHeading))° (\(motion.headingState.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(motion.headingState.facingMountain.localizedName)\(lang.t("facing_suffix")))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // 导入真实户型图纸
            Button(action: {
                if iap.hasUnlockedVIP || didConsumeFloorplanCredit || iap.floorplanCreditsCount > 0 {
                    showImagePicker = true
                } else {
                    showPaywall = true
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
                    // "Reset sample" must also restore the editable demo
                    // layout. Previously it removed only the background image,
                    // leaving dragged room rectangles and the centroid in the
                    // imported plan's state.
                    rooms = FloorplanEngine.shared.generateSampleRooms()
                    centroid = CGPoint(x: 0.5, y: 0.5)
                    isEditingRooms = false
                    activeRoomDragID = nil
                    activeRoomStartRect = nil
                    refreshAudit()
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
                    Text(isSyncWithCompass ? lang.t("floorplan_sync_compass") : lang.t("floorplan_manual_tune"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isSyncWithCompass ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(isSyncWithCompass ? .green : .orange)
                .cornerRadius(6)
            }

            // 导入户型图后，可手动把示例房间框调整到真实房间位置。
            Button(action: {
                isEditingRooms.toggle()
                activeRoomDragID = nil
                activeRoomStartRect = nil
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isEditingRooms ? "checkmark.circle.fill" : "rectangle.3.group")
                    Text(lang.t(isEditingRooms ? "floorplan_finish_rooms" : "floorplan_edit_rooms"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isEditingRooms ? Color.green.opacity(0.25) : Color.white.opacity(0.1))
                .foregroundColor(isEditingRooms ? .green : .white)
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
        
        let isBad = room.isBad
        let isGood = room.isGood
        let strokeColor = isBad ? Color.red : (isGood ? Color.green : Color.white.opacity(0.25))
        let bgColor = isBad ? Color.red.opacity(0.15) : (isGood ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
        
        return Button(action: {
            if isEditingRooms { return }
            if acquireFloorplanAccess() {
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
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard isEditingRooms else { return }

                    if activeRoomDragID != room.id {
                        activeRoomDragID = room.id
                        activeRoomStartRect = room.rect
                    }
                    guard let startRect = activeRoomStartRect,
                          let index = rooms.firstIndex(where: { $0.id == room.id }) else { return }

                    let dx = value.translation.width / max(w, 1)
                    let dy = value.translation.height / max(h, 1)
                    let maxX = max(0.0, 1.0 - startRect.width)
                    let maxY = max(0.0, 1.0 - startRect.height)
                    var updated = rooms[index]
                    updated.rect.origin.x = max(0.0, min(maxX, startRect.origin.x + dx))
                    updated.rect.origin.y = max(0.0, min(maxY, startRect.origin.y + dy))
                    rooms[index] = updated

                    // Keep the dragged rectangle responsive without rerunning
                    // palace/severity evaluation for every drag sample. The
                    // full audit is refreshed once the gesture ends.
                    if let auditedIndex = auditedRooms.firstIndex(where: { $0.id == room.id }) {
                        var audited = auditedRooms[auditedIndex]
                        audited.rect = updated.rect
                        auditedRooms[auditedIndex] = audited
                    }
                }
                .onEnded { _ in
                    activeRoomDragID = nil
                    activeRoomStartRect = nil
                    refreshAudit()
                }
        )
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
            Text(lang.t("floorplan_center_point"))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.black)
        }
        .position(centerPt)
        .gesture(
            DragGesture()
                .onChanged { val in
                    if centroidDragStart == nil {
                        centroidDragStart = centroid
                    }
                    guard let start = centroidDragStart else { return }
                    let newX = max(0.1, min(0.9, start.x + val.translation.width / max(w, 1)))
                    let newY = max(0.1, min(0.9, start.y + val.translation.height / max(h, 1)))
                    centroid = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in
                    centroidDragStart = nil
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
                Text(lang.t("drag_center_hint"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    if !hasFloorplanAccess {
                        VIPLockCardView(
                            title: lang.t("privilege_floorplan_title"),
                            featureDesc: lang.t("privilege_floorplan_desc"),
                            badge: lang.t("vip_badge_title"),
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
                .fill(item.isSevere ? Color.red : (item.isGood ? Color.green : Color.orange))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(item.isSevere ? lang.t("floorplan_severe_sha") : (item.isGood ? lang.t("grade_auspicious") : lang.t("floorplan_warn_sha")))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(item.isSevere ? Color.red.opacity(0.2) : (item.isGood ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                        .foregroundColor(item.isSevere ? .red : (item.isGood ? .green : .orange))
                        .cornerRadius(4)
                }
                Text(item.lore)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Text("\(lang.t("floorplan_solution_prefix")) \(item.solution)")
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
    @ObservedObject var lang = LocalizationManager.shared
    
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
                                
                                Text(room.palaceName.isEmpty ? lang.t("floorplan_analyzing_center") : "\(lang.t("floorplan_palace_prefix"))\(room.palaceName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.yanCyan)
                            }
                            
                            Spacer()
                            
                            Text(localizedLevel)
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
                                Text("\(lang.t("floorplan_diag_prefix"))\(room.inspectionTitle)")
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
                            Text(lang.t("floorplan_classic_origin"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                            
                            Text(lang.t("floorplan_yangzhai_quote"))
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(12)
                        
                        // 4. 生旺化煞秘笈
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_master_remedy"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text(room.inspectionAdvice.isEmpty ? lang.t("floorplan_room_advice") : room.inspectionAdvice)
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
            .navigationBarTitle(lang.t("floorplan_detail_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var badgeColor: Color {
        if room.isGood { return .green }
        if room.isSevere { return .red }
        if room.isWarning { return .orange }
        return Color.yanCyan
    }
    
    private var localizedLevel: String {
        let lang = LocalizationManager.shared
        if room.isGood { return lang.t("floorplan_level_auspicious") }
        if room.isSevere { return lang.t("floorplan_level_severe") }
        if room.isWarning { return lang.t("floorplan_level_warning") }
        return lang.t("floorplan_level_neutral")
    }
}
