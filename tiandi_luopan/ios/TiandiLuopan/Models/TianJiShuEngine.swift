import UIKit
import Photos

public struct TianJiAnalysisSnapshot {
    public let heading: Double
    public let period: Int
    public let useTiGua: Bool
    public let reportDate: Date
    var homeContext: XuanKongHomeContext? = nil
    var propertyKey: String? = nil
    var capturedFloorplanReport: [FloorplanAuditItem] = []
    var capturedPanoramaArchive: PanoramaFengShuiArchive?
    var hasSpatialSnapshot = false

    public init(heading: Double, period: Int? = nil, useTiGua: Bool? = nil, reportDate: Date = Date()) {
        self.heading = heading
        self.period = min(9, max(1, period ?? FlyingStarsEngine.shared.currentPeriod(for: reportDate)))
        self.useTiGua = useTiGua ?? Mountain24Data.shared.resolveHeadingState(heading: heading).isJianXiang
        self.reportDate = reportDate
    }

    public func flyingStarsChart() -> XuanKongChart {
        FlyingStarsEngine.shared.calculateChart(
            period: period,
            sitting: Mountain24Data.shared.mountain(for: (heading + 180).truncatingRemainder(dividingBy: 360)),
            facing: Mountain24Data.shared.mountain(for: heading),
            useTiGua: useTiGua,
            date: reportDate
        )
    }

    func capturing(context: XuanKongHomeContext?, propertyKey: String?,
                   floorplanReport: [FloorplanAuditItem], panoramaArchive: PanoramaFengShuiArchive?) -> Self {
        var copy = self
        copy.homeContext = context
        copy.propertyKey = propertyKey
        copy.capturedFloorplanReport = floorplanReport
        copy.capturedPanoramaArchive = panoramaArchive
        copy.hasSpatialSnapshot = true
        return copy
    }

    func deepAnalysis(chart: XuanKongChart? = nil) -> XuanKongDeepAnalysis {
        XuanKongDeepAnalyzer.analyze(chart: chart ?? flyingStarsChart(), date: reportDate, context: homeContext)
    }

    func guidanceText(chart: XuanKongChart? = nil, analysis: XuanKongDeepAnalysis? = nil) -> String {
        let chart = chart ?? flyingStarsChart()
        let analysis = analysis ?? deepAnalysis(chart: chart)
        let lang = LocalizationManager.shared
        return ([lang.t(analysis.summaryKey)] + analysis.priorities.compactMap { sector -> String? in
            guard let cell = chart.palaces.first(where: { $0.id == sector.id }) else { return nil }
            let places = Array(Set(sector.places.map(\.name))).sorted().joined(separator: " / ")
            let heading = cell.plainDirectionName + " · " + lang.t(sector.use.titleKey)
                + (places.isEmpty ? "" : " · " + places)
            return ([heading] + sector.actions.map { "• " + lang.t($0.textKey) }).joined(separator: "\n")
        }).joined(separator: "\n\n")
    }

    public func ganzhiYear(timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.component(.year, from: reportDate)
            - (SolarTimeCalculator.shared.isBeforeLiChun(for: reportDate, timeZone: timeZone) ? 1 : 0)
        let offset = ((year - 4) % 60 + 60) % 60
        return "\(Array("甲乙丙丁戊己庚辛壬癸")[offset % 10])\(Array("子丑寅卯辰巳午未申酉戌亥")[offset % 12])"
    }
}

// MARK: - 福宅天机书 · 古典宣纸朱丝栏全案长卷导出引擎 (PRD 第14章)

public class TianJiShuEngine {
    public static let shared = TianJiShuEngine()
    
    private init() {}
    
    // 生成高清古典宣纸长卷勘测报告图
    public func generateScrollImage(
        heading inputHeading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        language: AppLanguage? = nil,
        isPro: Bool = true,
        floorplanReport: [FloorplanAuditItem] = [],
        panoramaArchive: PanoramaFengShuiArchive? = nil,
        reportDate inputDate: Date = Date(),
        analysis: TianJiAnalysisSnapshot? = nil
    ) -> UIImage {
        let snapshot = analysis ?? TianJiAnalysisSnapshot(heading: inputHeading, reportDate: inputDate)
        return renderScrollImage(heading: snapshot.heading, coordsDesc: coordsDesc, solarTimeDesc: solarTimeDesc,
            language: language, isPro: isPro,
            floorplanReport: snapshot.hasSpatialSnapshot ? snapshot.capturedFloorplanReport : floorplanReport,
            panoramaArchive: snapshot.hasSpatialSnapshot ? snapshot.capturedPanoramaArchive : panoramaArchive,
            reportDate: snapshot.reportDate, analysis: snapshot, canvasHeight: nil)
    }

    private func renderScrollImage(
        heading inputHeading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        language: AppLanguage? = nil,
        isPro: Bool = true,
        floorplanReport: [FloorplanAuditItem] = [],
        panoramaArchive: PanoramaFengShuiArchive? = nil,
        reportDate inputDate: Date = Date(),
        analysis: TianJiAnalysisSnapshot? = nil,
        canvasHeight: CGFloat?
    ) -> UIImage {
        let snapshot = analysis ?? TianJiAnalysisSnapshot(heading: inputHeading, reportDate: inputDate)
        let heading = snapshot.heading
        let reportDate = snapshot.reportDate
        // The canvas is extra tall because the scroll renders the full
        // harmonization suite: orientation, flying stars, water method,
        // qimen & eight mansions, purple-white guest stars, injurious
        // directions, exterior sha self-check, and the compliance notice.
        // A full survey can contain 24 water-method entries, all eight
        // mansions and current AR/interior findings.  The former 6000 px
        // canvas clipped those sections, so keep a larger upper bound and
        // measure variable text blocks before advancing the cursor.
        let archiveItemCount = (panoramaArchive?.exterior.count ?? 0)
            + (panoramaArchive?.interior?.shaItems.count ?? 0)
        let extraArchiveHeight = CGFloat(max(0, archiveItemCount - 12)) * 150.0
        let extraFloorplanHeight = CGFloat(max(0, floorplanReport.count - 12)) * 180.0
        // Reserve room for the complete nine-palace sections and date-selection
        // details below. The per-record additions cover unusually large
        // floorplan/AR archives without silently drawing past the bitmap.
        let minimumHeight: CGFloat = 15000 + extraArchiveHeight + extraFloorplanHeight
        let size = CGSize(width: 1080, height: canvasHeight ?? 1)
        var requiredHeight: CGFloat = minimumHeight
        // These dimensions describe the exported pixel size. The default
        // renderer scale follows the device's Retina factor and could turn
        // this into a 3240x18000 image, multiplying memory and render time.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        // Resolve the language before entering the renderer closure. The
        // image is generated off the main queue while the user can still
        // change the app language, so the report must use one stable locale.
        let renderLanguage = language ?? LocalizationManager.shared.effectiveLanguage
        
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            func tr8(
                _ hans: String,
                _ hant: String,
                _ en: String,
                _ ja: String,
                _ ko: String,
                _ vi: String,
                _ th: String,
                _ id: String
            ) -> String {
                switch renderLanguage {
                case .zhHant: return hant
                case .en: return en
                case .ja: return ja
                case .ko: return ko
                case .vi: return vi
                case .th: return th
                case .id: return id
                case .auto, .zhHans: return hans
                }
            }

            func drawMeasuredText(
                _ text: String,
                atY: CGFloat,
                font: UIFont,
                color: UIColor,
                x: CGFloat = 100,
                width: CGFloat = 880,
                minimumHeight: CGFloat = 0
            ) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let measured = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                let height = max(minimumHeight, ceil(measured.height) + 10)
                text.draw(in: CGRect(x: x, y: atY, width: width, height: height), withAttributes: attributes)
                return height
            }
            
            // 1. 宣纸底色 (温润米黄熟宣)
            let paperColor = UIColor(red: 247/255.0, green: 243/255.0, blue: 232/255.0, alpha: 1.0)
            cg.setFillColor(paperColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            
            // 宣纸暗纹网格
            cg.setStrokeColor(UIColor(red: 235/255.0, green: 228/255.0, blue: 212/255.0, alpha: 0.6).cgColor)
            cg.setLineWidth(1)
            for y in stride(from: 40, to: Int(size.height) - 40, by: 40) {
                cg.move(to: CGPoint(x: 40, y: CGFloat(y)))
                cg.addLine(to: CGPoint(x: 1040, y: CGFloat(y)))
            }
            cg.strokePath()
            
            // 2. 朱丝栏外框与双线边饰
            let vermilion = UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0) // 朱砂红
            cg.setStrokeColor(vermilion.cgColor)
            cg.setLineWidth(6)
            cg.stroke(CGRect(x: 45, y: 45, width: 990, height: size.height - 90))
            cg.setLineWidth(2)
            cg.stroke(CGRect(x: 55, y: 55, width: 970, height: size.height - 110))
            
            // 3. 卷首长卷标题
            let titleFont = UIFont.boldSystemFont(ofSize: 52)
            let subTitleFont = UIFont.systemFont(ofSize: 26, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 24)
            
            let titleText = tr8(
                "福 宅 天 机 勘 舆 全 案 书",
                "福 宅 天 機 勘 輿 全 案 書",
                "F O R T U N E  H O M E  C E L E S T I A L  S C R O L L",
                "福 宅 天 機 鑑 定 全 案 書",
                "복 택 천 기 감 여 전 안 서",
                "PHÚC TRẠCH THIÊN CƠ TOÀN THƯ",
                "คัมภีร์ตรวจฮวงจุ้ยเคหสถานสวรรค์",
                "KITAB FENG SHUI RUMAH BERKAH"
            )
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: vermilion,
                .kern: 10
            ]
            let tSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(at: CGPoint(x: (size.width - tSize.width) / 2, y: 90), withAttributes: titleAttr)
            
            let subTitle = tr8(
                "—— 天 机 演 象 · 天 地 时 空 全 息 罗 盘 钦 定 ——",
                "—— 天 機 演 象 · 天 地 時 空 全 息 羅 盤 欽 定 ——",
                "— TIANJI YANXIANG · CELESTIAL COMPASS —",
                "—— 天機演象・天地時空ホログラフィック羅盤欽定 ——",
                "—— 천기연상 · 천지시공 홀로그램 나경 흠정 ——",
                "—— THIÊN CƠ DIỄN TƯỢNG · THIÊN ĐỊA LA BÀN ĐỊNH BẢN ——",
                "— ปรากฏการณ์ฟ้าลิขิต · เข็มทิศกาลอวกาศฟ้าดิน —",
                "— TIANJI YANXIANG · KOMPAS HOLOGRAFIS ALAM SEMESTA —"
            )
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subTitleFont,
                .foregroundColor: UIColor(red: 110/255.0, green: 75/255.0, blue: 45/255.0, alpha: 1.0),
                .kern: 4
            ]
            let sSize = subTitle.size(withAttributes: subAttr)
            subTitle.draw(at: CGPoint(x: (size.width - sSize.width) / 2, y: 165), withAttributes: subAttr)
            
            // 防伪编号与福主尊称署名
            let snLabel = tr8("防伪鉴真号", "防偽鑒真號", "Verification No.", "識別真贋番号", "감정 진위 번호", "Mã xác thực", "หมายเลขตรวจสอบ", "No. Verifikasi")
            let sn = "\(snLabel): YX-\(Int(reportDate.timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
            sn.draw(at: CGPoint(x: 100, y: 220), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.gray
            ])

            let customClient = (UserDefaults.standard.string(forKey: "tianjishu_custom_client") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !customClient.isEmpty {
                let clientLine = tr8(
                    "委托福主：\(customClient) 雅鉴",
                    "委託福主：\(customClient) 雅鑒",
                    "Prepared for: \(customClient)",
                    "依頼施主：\(customClient) 様",
                    "의뢰 복주: \(customClient) 귀하",
                    "Thân chủ: \(customClient)",
                    "จัดทำเพื่อ: \(customClient)",
                    "Disiapkan untuk: \(customClient)"
                )
                let cAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: vermilion
                ]
                let cSize = clientLine.size(withAttributes: cAttr)
                clientLine.draw(at: CGPoint(x: max(540, 980 - cSize.width), y: 218), withAttributes: cAttr)
            }
            
            // 4. 第一部：坐向立极与分金格局
            var curY: CGFloat = 280
            let sec1Title = tr8(
                "第一卷 · 坐向立极与分金天心",
                "第一卷 · 坐向立極與分金天心",
                "I · ORIENTATION & FENJIN CENTER",
                "第一巻・座向立極と分金天心",
                "제1권 · 좌향입극 및 분금천심",
                "QUYỂN I · TỌA HƯỚNG LẬP CỰC VÀ PHÂN KIM",
                "บทที่ ๑ · ทิศตั้งประธานและองศาแบ่งทอง",
                "BAGIAN I · ORIENTASI & PUSAT FENJIN"
            )
            drawSectionHeader(ctx: cg, title: sec1Title, atY: curY, vermilion: vermilion)
            curY += 65
            
            let mFacing = Mountain24Data.shared.mountain(for: heading)
            let sitAngle = (heading + 180).truncatingRemainder(dividingBy: 360)
            let mSitting = Mountain24Data.shared.mountain(for: sitAngle)
            let fenjin = Fenjin120Data.shared.resolveFenjin(for: heading)
            let hex = Hexagram64Data.shared.hexagram(for: heading)
            
            let p1Text: String
            switch renderLanguage {
            case .en:
                p1Text = """
                • Facing orientation: \(mFacing.localizedName) mountain (measured \(String(format: "%.1f", heading))°) · \(mFacing.localizedPalace) Palace
                • Sitting mountain: \(mSitting.localizedName) (sitting \(String(format: "%.1f", sitAngle))°) · \(mSitting.localizedPalace)
                • 120 Fenjin: \(fenjin.jiaziName) (center \(String(format: "%.1f", fenjin.centerAngle))°) · [\(fenjin.localizedGrade)]
                • 64 Hexagrams: \(hex.localizedName) · upper \(hex.localizedUpperTrigram), lower \(hex.localizedLowerTrigram) · [\(hex.localizedLuckDegree)]
                • Survey coordinates: \(coordsDesc)
                • Solar-term true time: \(solarTimeDesc)
                """
            case .zhHant:
                p1Text = """
                • 物理向首方位：\(mFacing.localizedName)山向首（實測 \(String(format: "%.1f", heading))°）· \(mFacing.localizedPalace)宮
                • 住宅太極坐山：\(mSitting.localizedName)山立極（坐 \(String(format: "%.1f", sitAngle))°）· 屬\(mSitting.localizedPalace)
                • 一百二十分金：\(fenjin.jiaziName)分金（中心 \(String(format: "%.1f", fenjin.centerAngle))°）· 【\(fenjin.localizedGrade)】
                • 周易六十四卦：\(hex.localizedName) · 外卦\(hex.localizedUpperTrigram) 內卦\(hex.localizedLowerTrigram) · 爻度【\(hex.localizedLuckDegree)】
                • 堪輿定位座標：\(coordsDesc)
                • 節氣真太陽時：\(solarTimeDesc)
                """
            case .ja:
                p1Text = """
                • 向首方位：\(mFacing.localizedName)山（実測 \(String(format: "%.1f", heading))°）· \(mFacing.localizedPalace)宮
                • 坐山立極：\(mSitting.localizedName)山（坐 \(String(format: "%.1f", sitAngle))°）· \(mSitting.localizedPalace)宮所属
                • 百二十分金：\(fenjin.jiaziName)分金（中心 \(String(format: "%.1f", fenjin.centerAngle))°）· 【\(fenjin.localizedGrade)】
                • 周易六十四卦：\(hex.localizedName) · 上卦\(hex.localizedUpperTrigram) 下卦\(hex.localizedLowerTrigram) · 【\(hex.localizedLuckDegree)】
                • 観測座標：\(coordsDesc)
                • 真太陽時：\(solarTimeDesc)
                """
            case .ko:
                p1Text = """
                • 향수 방위: \(mFacing.localizedName)산 향수 (실측 \(String(format: "%.1f", heading))°) · \(mFacing.localizedPalace)궁
                • 주택 좌산: \(mSitting.localizedName)산 입극 (좌 \(String(format: "%.1f", sitAngle))°) · \(mSitting.localizedPalace)궁
                • 120 분금: \(fenjin.jiaziName)분금 (중심 \(String(format: "%.1f", fenjin.centerAngle))°) · 【\(fenjin.localizedGrade)】
                • 주역 64괘: \(hex.localizedName) · 외괘 \(hex.localizedUpperTrigram), 내괘 \(hex.localizedLowerTrigram) · 【\(hex.localizedLuckDegree)】
                • 관측 좌표: \(coordsDesc)
                • 절기 진태양시: \(solarTimeDesc)
                """
            case .vi:
                p1Text = """
                • Hướng hướng thủ: Sơn \(mFacing.localizedName) (đo đạc \(String(format: "%.1f", heading))°) · Cung \(mFacing.localizedPalace)
                • Tọa sơn lập cực: Sơn \(mSitting.localizedName) (tọa \(String(format: "%.1f", sitAngle))°) · Cung \(mSitting.localizedPalace)
                • 120 Phân kim: Phân kim \(fenjin.jiaziName) (tâm \(String(format: "%.1f", fenjin.centerAngle))°) · 【\(fenjin.localizedGrade)】
                • Chu Dịch 64 quẻ: \(hex.localizedName) · Ngoại quái \(hex.localizedUpperTrigram), Nội quái \(hex.localizedLowerTrigram) · 【\(hex.localizedLuckDegree)】
                • Tọa độ khảo sát: \(coordsDesc)
                • Chân thái dương thời: \(solarTimeDesc)
                """
            case .th:
                p1Text = """
                • ทิศหน้าบ้าน: เขา\(mFacing.localizedName) (วัดจริง \(String(format: "%.1f", heading))°) · วัง\(mFacing.localizedPalace)
                • ทิศหลังพิง: เขา\(mSitting.localizedName) (พิง \(String(format: "%.1f", sitAngle))°) · วัง\(mSitting.localizedPalace)
                • ๑๒๐ องศาแบ่งทอง: \(fenjin.jiaziName) (แกนกลาง \(String(format: "%.1f", fenjin.centerAngle))°) · 【\(fenjin.localizedGrade)】
                • ๖๔ กั้วอี้จิง: \(hex.localizedName) · กั้วบน \(hex.localizedUpperTrigram), กั้วล่าง \(hex.localizedLowerTrigram) · 【\(hex.localizedLuckDegree)】
                • พิกัดสำรวจ: \(coordsDesc)
                • เวลาสุริยคติแท้: \(solarTimeDesc)
                """
            case .id:
                p1Text = """
                • Orientasi Hadap: Gunung \(mFacing.localizedName) (terukur \(String(format: "%.1f", heading))°) · Istana \(mFacing.localizedPalace)
                • Gunung Sandaran: Gunung \(mSitting.localizedName) (duduk \(String(format: "%.1f", sitAngle))°) · Istana \(mSitting.localizedPalace)
                • 120 Fenjin: \(fenjin.jiaziName) (pusat \(String(format: "%.1f", fenjin.centerAngle))°) · [\(fenjin.localizedGrade)]
                • 64 Heksagram: \(hex.localizedName) · atas \(hex.localizedUpperTrigram), bawah \(hex.localizedLowerTrigram) · [\(hex.localizedLuckDegree)]
                • Koordinat Survei: \(coordsDesc)
                • Waktu Matahari Sejati: \(solarTimeDesc)
                """
            case .auto, .zhHans:
                p1Text = """
                • 物理向首方位：\(mFacing.localizedName)山向首（实测 \(String(format: "%.1f", heading))°）· \(mFacing.localizedPalace)宫
                • 住宅太极坐山：\(mSitting.localizedName)山立极（坐 \(String(format: "%.1f", sitAngle))°）· 属\(mSitting.localizedPalace)
                • 一百二十分金：\(fenjin.jiaziName)分金（中心 \(String(format: "%.1f", fenjin.centerAngle))°）· 【\(fenjin.localizedGrade)】
                • 周易六十四卦：\(hex.localizedName) · 外卦\(hex.localizedUpperTrigram) 内卦\(hex.localizedLowerTrigram) · 爻度【\(hex.localizedLuckDegree)】
                • 堪舆定位坐标：\(coordsDesc)
                • 节气真太阳时：\(solarTimeDesc)
                """
            }
            curY += drawMeasuredText(
                p1Text,
                atY: curY,
                font: bodyFont,
                color: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0),
                minimumHeight: 80
            ) + 12

            // 1.5 宅主本命卦人宅配卦与当日财神喜神吉位 (P1.1 & P2.1 全案长卷集成)
            let kuaMgr = UserKuaProfileManager.shared
            if kuaMgr.canUsePersonalAnalysis {
            let compat = kuaMgr.evaluateCompatibility(sittingPalace: mSitting.palace)
            let dailyGods = ZeRiEngine.shared.dailyCompassDirections(for: reportDate)
            let p1KuaText: String
            switch renderLanguage {
            case .en:
                p1KuaText = """
                • Owner Life Gua: \(kuaMgr.birthYear) (\(compat.localizedZodiacName)) · \(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup)) · [\(compat.matchBadgeTitle)]
                • Personal 4 Auspicious Sectors: Wealth \(compat.wealthDirection) · Health \(compat.healthDirection) · Harmony \(compat.harmonyDirection) · Study \(compat.studyDirection)
                • Daily Auspicious Bearings: God of Wealth \(dailyGods.wealthDirection) (\(Int(dailyGods.wealthAngle))°) · God of Joy \(dailyGods.joyDirection) (\(Int(dailyGods.joyAngle))°)
                """
            case .zhHant:
                p1KuaText = """
                • 宅主本命配卦：\(kuaMgr.birthYear)年（\(compat.localizedZodiacName)）· \(compat.localizedOwnerGuaName)（\(compat.localizedLifeGroup)）· 【\(compat.matchBadgeTitle)】
                • 宅主本命四吉方：生氣財位【\(compat.wealthDirection)】· 天醫祛病位【\(compat.healthDirection)】· 延年和合位【\(compat.harmonyDirection)】· 伏位文昌【\(compat.studyDirection)】
                • 當日出行納吉方：今日財神正位【\(dailyGods.wealthDirection)（\(Int(dailyGods.wealthAngle))°）】· 今日喜神吉位【\(dailyGods.joyDirection)（\(Int(dailyGods.joyAngle))°）】
                """
            case .ja:
                p1KuaText = """
                • 家主本命配卦：\(kuaMgr.birthYear)年（\(compat.localizedZodiacName)）· \(compat.localizedOwnerGuaName)（\(compat.localizedLifeGroup)）· 【\(compat.matchBadgeTitle)】
                • 本命四吉方位：生気財位【\(compat.wealthDirection)】· 天医健康位【\(compat.healthDirection)】· 延年和合位【\(compat.harmonyDirection)】· 伏位文昌【\(compat.studyDirection)】
                • 本日の吉方位：財神【\(dailyGods.wealthDirection)（\(Int(dailyGods.wealthAngle))°）】· 喜神【\(dailyGods.joyDirection)（\(Int(dailyGods.joyAngle))°）】
                """
            case .ko:
                p1KuaText = """
                • 건축주 본명배괘: \(kuaMgr.birthYear)년 (\(compat.localizedZodiacName)) · \(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup)) · 【\(compat.matchBadgeTitle)】
                • 본명 4길방: 생기재위【\(compat.wealthDirection)】· 천의건강위【\(compat.healthDirection)】· 연년화합위【\(compat.harmonyDirection)】· 복위문창【\(compat.studyDirection)】
                • 당일 출행 길방: 오늘의 재신방【\(dailyGods.wealthDirection) (\(Int(dailyGods.wealthAngle))°)】· 희신방【\(dailyGods.joyDirection) (\(Int(dailyGods.joyAngle))°)】
                """
            case .vi:
                p1KuaText = """
                • Bản mệnh Trạch chủ: Năm \(kuaMgr.birthYear) (\(compat.localizedZodiacName)) · \(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup)) · 【\(compat.matchBadgeTitle)】
                • Tứ cát phương bản mệnh: Sinh Khí 【\(compat.wealthDirection)】 · Thiên Y 【\(compat.healthDirection)】 · Diên Niên 【\(compat.harmonyDirection)】 · Phục Vị 【\(compat.studyDirection)】
                • Cát phương xuất hành: Thần Tài 【\(dailyGods.wealthDirection) (\(Int(dailyGods.wealthAngle))°)】 · Hỷ Thần 【\(dailyGods.joyDirection) (\(Int(dailyGods.joyAngle))°)】
                """
            case .th:
                p1KuaText = """
                • รหัสชีวิตเจ้าของบ้าน: ปี \(kuaMgr.birthYear) (\(compat.localizedZodiacName)) · \(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup)) · 【\(compat.matchBadgeTitle)】
                • ๔ ทิศมงคลประจำตัว: โชคลาภ【\(compat.wealthDirection)】· สุขภาพ【\(compat.healthDirection)】· ความปรองดอง【\(compat.harmonyDirection)】· การศึกษา【\(compat.studyDirection)】
                • ทิศมงคลประจำวัน: เทพโชคลาภ【\(dailyGods.wealthDirection) (\(Int(dailyGods.wealthAngle))°)】· เทพมงคล【\(dailyGods.joyDirection) (\(Int(dailyGods.joyAngle))°)】
                """
            case .id:
                p1KuaText = """
                • Gua Pemilik Rumah: \(kuaMgr.birthYear) (\(compat.localizedZodiacName)) · \(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup)) · [\(compat.matchBadgeTitle)]
                • 4 Sektor Keberuntungan: Rezeki \(compat.wealthDirection) · Kesehatan \(compat.healthDirection) · Harmoni \(compat.harmonyDirection) · Studi \(compat.studyDirection)
                • Arah Hoki Harian: Dewa Rezeki \(dailyGods.wealthDirection) (\(Int(dailyGods.wealthAngle))°) · Dewa Sukacita \(dailyGods.joyDirection) (\(Int(dailyGods.joyAngle))°)
                """
            case .auto, .zhHans:
                p1KuaText = """
                • 宅主本命配卦：\(kuaMgr.birthYear)年（\(compat.localizedZodiacName)）· \(compat.localizedOwnerGuaName)（\(compat.localizedLifeGroup)）· 【\(compat.matchBadgeTitle)】
                • 宅主本命四吉方：生气财位【\(compat.wealthDirection)】· 天医祛病位【\(compat.healthDirection)】· 延年和合位【\(compat.harmonyDirection)】· 伏位文昌【\(compat.studyDirection)】
                • 当日出行纳吉方：今日财神正位【\(dailyGods.wealthDirection)（\(Int(dailyGods.wealthAngle))°）】· 今日喜神吉位【\(dailyGods.joyDirection)（\(Int(dailyGods.joyAngle))°）】
                """
            }
            curY += drawMeasuredText(
                p1KuaText,
                atY: curY,
                font: bodyFont,
                color: vermilion,
                minimumHeight: 60
            ) + 20
            
            }

            // 5. 第二部：玄空飞星九宫方阵 (根据实时天文学历法动态排盘)
            let xkChart = snapshot.flyingStarsChart()
            let patternSummary = LocalizationManager.shared.t(xkChart.pattern.explanationKey) + "\n\n" + xkChart.analysisNote
            let meta = xkChart.periodMeta
            
            let sec2Title = tr8(
                "第二卷 · \(meta.yuan)\(meta.period)运玄空飞星气运方阵",
                "第二卷 · \(meta.yuan)\(meta.period)運玄空飛星氣運方陣",
                "II · FLYING STARS & PERIOD \(meta.period)",
                "第二巻・\(meta.yuan)\(meta.period)運 玄空飛星気運盤",
                "제2권 · \(meta.yuan)\(meta.period)운 현공비성 기운방진",
                "QUYỂN II · HUYỀN KHÔNG PHI TINH VẬN \(meta.period)",
                "บทที่ ๒ · ดาวเหินเสวียนคงยุค \(meta.period)",
                "BAGIAN II · BINTANG TERBANG & PERIODE \(meta.period)"
            )
            drawSectionHeader(ctx: cg, title: sec2Title, atY: curY, vermilion: vermilion)
            curY += 65
            
            let p2Text: String
            switch renderLanguage {
            case .en:
                p2Text = """
                • Current period: \(meta.label)
                • Flying-star pattern: [\(mSitting.localizedName) / \(mFacing.localizedName)] \(xkChart.patternType)
                • Ruling star qi: \(meta.starName) \(meta.element) star enters the center and illuminates the facing bright hall.
                • Overall analysis: \(patternSummary)
                """
            case .zhHant:
                p2Text = """
                • 當前地運：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 當令旺星氣場：\(meta.starName)\(meta.element)星入中當運，主星臨照向首明堂。
                • 綜合理氣研判：\(patternSummary)
                """
            case .ja:
                p2Text = """
                • 現在の地運：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 当令旺星の気：\(meta.starName)\(meta.element)星が中宮に入り、向首明堂を照らします。
                • 総合理気判断：\(patternSummary)
                """
            case .ko:
                p2Text = """
                • 현재 지운: \(meta.label)
                • 현공 격국 판정: 【\(mSitting.localizedName)산 \(mFacing.localizedName)향】\(xkChart.patternType)
                • 당령 왕성 기운: \(meta.starName)\(meta.element)성이 중궁에 입하여 향수 명당을 비춥니다.
                • 종합 이기 판단: \(patternSummary)
                """
            case .vi:
                p2Text = """
                • Địa vận hiện tại: \(meta.label)
                • Phán đoán cục diện: 【Sơn \(mSitting.localizedName) Hướng \(mFacing.localizedName)】\(xkChart.patternType)
                • Khí trường vượng tinh: Sao \(meta.starName) \(meta.element) nhập trung cung, chiếu sáng minh đường.
                • Phân tích tổng hợp: \(patternSummary)
                """
            case .th:
                p2Text = """
                • ยุคปัจจุบัน: \(meta.label)
                • รูปแบบผังเสวียนคง: 【พิง\(mSitting.localizedName) หัน\(mFacing.localizedName)】\(xkChart.patternType)
                • ชี่ดาวเจริญยุค: ดาว\(meta.starName) ธาตุ\(meta.element) เข้าสู่ศูนย์กลาง ส่องสว่างลานหน้าบ้าน
                • ผลวิเคราะห์ภาพรวม: \(patternSummary)
                """
            case .id:
                p2Text = """
                • Periode Saat Ini: \(meta.label)
                • Pola Bintang Terbang: [\(mSitting.localizedName) / \(mFacing.localizedName)] \(xkChart.patternType)
                • Qi Bintang Berkuasa: Bintang \(meta.starName) \(meta.element) masuk ke tengah menyinari ruang depan.
                • Analisis Keseluruhan: \(patternSummary)
                """
            case .auto, .zhHans:
                p2Text = """
                • 当前地运：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 当令旺星气场：\(meta.starName)\(meta.element)星入中当运，主星临照向首明堂。
                • 综合理气研判：\(patternSummary)
                """
            }
            curY += drawMeasuredText(
                p2Text,
                atY: curY,
                font: bodyFont,
                color: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0),
                minimumHeight: 80
            ) + 20
            
            // 6. 第三部：杨公八路黄泉与消砂纳水
            let sec3Title = tr8(
                "第三卷 · 杨公形气八路黄泉与水法宜忌",
                "第三卷 · 楊公形氣八路黃泉與水法宜忌",
                "III · YANG GONG WATER METHOD & HUANGQUAN",
                "第三巻・楊公八路黄泉と消砂納水法",
                "제3권 · 양공 팔로황천 및 소사납수법",
                "QUYỂN III · DƯƠNG CÔNG BÁT LỘ HOÀNG TUYỀN VÀ THỦY PHÁP",
                "บทที่ ๓ · วิชาสายน้ำหยางกงและน้ำฮวงเฉวียน",
                "BAGIAN III · METODE AIR YANG GONG & HUANGQUAN"
            )
            drawSectionHeader(ctx: cg, title: sec3Title, atY: curY, vermilion: vermilion)
            curY += 65
            
            let hq = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: mFacing)
            let basha = SanHeWaterEngine.shared.resolveBaSha(sitting: mSitting)
            let sanHeItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: mSitting, facing: mFacing)
            let lang = LocalizationManager.shared
            let hqLabel = tr8("向首八路黄泉判据", "向首八路黃泉判據", "Eight-Road Huangquan test", "向首八路黄泉判定", "향수 팔로황천 판별", "Phán định Bát Lộ Hoàng Tuyền", "เกณฑ์น้ำฮวงเฉวียนแปดทิศ", "Uji Huangquan Delapan Arah")
            let bashaLabel = tr8("坐山八煞曜位辨识", "坐山八煞曜位辨識", "Sitting-mountain Sha position", "坐山八煞曜位識別", "좌산 팔살요위 식별", "Nhận định Bát Sát Diệu vị", "ตำแหน่งดาวพิฆาตแปดทิศ", "Posisi Sha Delapan Arah")
            let waterLabel = tr8("十二长生纳水吉凶", "十二長生納水吉凶", "Twelve Changsheng water assessment", "十二長生納水吉凶", "십이장생 납수길흉", "Cát hung Thập Nhị Trường Sinh", "ประเมินน้ำสิบสองสภาวะฉางเซิง", "Penilaian Air Dua Belas Changsheng")
            
            var p3Text = "• \(hqLabel): \(hq.badgeText) · \(hq.waterDesc)\n"
            p3Text += "• \(bashaLabel): 【\(basha.localizedShaDir)】 · \(basha.remedy)\n"
            p3Text += "• \(waterLabel):\n"
            for item in sanHeItems {
                let verdict = item.isAuspicious
                    ? tr8("吉 · 宜来水纳气", "吉 · 宜來水納氣", "Auspicious · favorable inflow", "吉・来水歓迎", "길 · 내수 유입 권장", "Cát · nên đón nước vào tụ khí", "มงคล · ควรรับน้ำไหลเข้า", "Berkah · aliran masuk yang baik")
                    : tr8("忌 · 防破局流破", "忌 · 防破局流破", "Avoid · prevent draining the pattern", "忌・破局流出注意", "기 · 파국 유출 방지", "Kỵ · đề phòng nước chảy thoát phá cục", "อัปมงคล · ป้องกันน้ำไหลรั่วทำลายผัง", "Hindari · cegah aliran menguras energi")
                p3Text += "  - \(item.localizedMountainName)\(lang.t("mountain_suffix"))【\(item.stage)】: \(verdict), \(item.lore)\n"
            }
            curY += drawMeasuredText(
                p3Text,
                atY: curY,
                font: bodyFont,
                color: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0),
                minimumHeight: 80
            ) + 20
            
            // 7. 第四部：时家奇门与八宅命卦
            let sec4Title = tr8(
                "第四卷 · 时家奇门时空与八宅大游年",
                "第四卷 · 時家奇門時空與八宅大遊年",
                "IV · QIMEN TIME-SPACE & EIGHT MANSIONS",
                "第四巻・時家奇門時空と八宅大遊年",
                "제4권 · 시가기문 시공 및 팔택 대유년",
                "QUYỂN IV · THỜI GIA KỲ MÔN VÀ BÁT TRẠCH",
                "บทที่ ๔ · ขี่เหมินกาลอวกาศและแปดเรือน",
                "BAGIAN IV · RUANG-WAKTU QIMEN & DELAPAN RUMAH"
            )
            drawSectionHeader(ctx: cg, title: sec4Title, atY: curY, vermilion: vermilion)
            curY += 65
            
            let qm = QimenEngine.shared.calculateChart(date: reportDate, heading: heading)
            let bz = BaZhaiEngine.shared.analyze(sittingPalace: mSitting.palace, facingPalace: mFacing.palace)
            
            let p4Text: String
            switch renderLanguage {
            case .en:
                p4Text = """
                • QiMen time-space: \(qm.title)
                • Best direction to move now: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • House gua: [\(bz.localizedHouseGua)] · gate direction: \(bz.localizedGateDirection), receiving [\(bz.gateStar.localizedName)]
                • Sheng Qi direction: \(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "Sheng Qi"); suitable for the master bedroom or altar.
                """
            case .zhHant:
                p4Text = """
                • 時家奇門時空：\(qm.title)
                • 當前天時最優動身方：\(qm.bestNavDirection) (\(qm.bestNavReason))
                • 住宅宅卦歸屬：【\(bz.localizedHouseGua)】 · 向首開門方：\(bz.localizedGateDirection)方納【\(bz.gateStar.localizedName)】
                • 生氣大吉尊方：\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "生氣")方，宜作主臥或安奉神位。
                """
            case .ja:
                p4Text = """
                • 時家奇門盤：\(qm.title)
                • 現在の最適行動方位：\(qm.bestNavDirection)（\(qm.bestNavReason)）
                • 住宅本命卦：【\(bz.localizedHouseGua)】 · 開門方位：\(bz.localizedGateDirection) 方【\(bz.gateStar.localizedName)】
                • 生気大吉方位：\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "生気")方、主寝室や神仏のお祀りに最適。
                """
            case .ko:
                p4Text = """
                • 시가기문 시공: \(qm.title)
                • 현재 최적 출행 방위: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • 주택 택괘 귀속: 【\(bz.localizedHouseGua)】 · 대문 방향: \(bz.localizedGateDirection)방【\(bz.gateStar.localizedName)】
                • 생기 대길 존방: \(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "생기")방, 주침실 또는 제단 배치에 적합.
                """
            case .vi:
                p4Text = """
                • Thời không Kỳ Môn: \(qm.title)
                • Hướng xuất hành tốt nhất: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • Trạch quái nhà ở: 【\(bz.localizedHouseGua)】 · Hướng mở cửa: \(bz.localizedGateDirection) nạp 【\(bz.gateStar.localizedName)】
                • Phương vị Sinh Khí: Phương \(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "Sinh Khí"), thích hợp đặt phòng ngủ chính hoặc bàn thờ.
                """
            case .th:
                p4Text = """
                • กาลอวกาศขี่เหมิน: \(qm.title)
                • ทิศทางที่ดีที่สุดในขณะนี้: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • กั้วประจำตัวบ้าน: 【\(bz.localizedHouseGua)】 · ทิศเปิดประตู: \(bz.localizedGateDirection) รับดาว【\(bz.gateStar.localizedName)】
                • ทิศเซิงชี่มงคลยิ่ง: ทิศ\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "เซิงชี่") เหมาะเป็นห้องนอนใหญ่หรือตั้งหิ้งพระ
                """
            case .id:
                p4Text = """
                • Ruang-Waktu QiMen: \(qm.title)
                • Arah Terbaik Bergerak Sekarang: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • Gua Rumah: [\(bz.localizedHouseGua)] · Arah Pintu: \(bz.localizedGateDirection) menyerap [\(bz.gateStar.localizedName)]
                • Arah Sheng Qi: \(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "Sheng Qi"); sangat cocok untuk kamar utama atau altar.
                """
            case .auto, .zhHans:
                p4Text = """
                • 时家奇门时空：\(qm.title)
                • 当前天时最优动身方：\(qm.bestNavDirection) (\(qm.bestNavReason))
                • 住宅宅卦归属：【\(bz.localizedHouseGua)】 · 向首开门方：\(bz.localizedGateDirection)方纳【\(bz.gateStar.localizedName)】
                • 生气大吉尊方：\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "生气")方，宜作主卧或安奉神位。
                """
            }
            curY += drawMeasuredText(
                p4Text,
                atY: curY,
                font: bodyFont,
                color: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0),
                minimumHeight: 80
            ) + 20
            
            // 8. 第五部：全屋空间调理与开光化煞清单
            let sec5Title = tr8(
                "第五卷 · 全屋空间调理与镇煞秘诀",
                "第五卷 · 全屋空間調理與鎮煞秘訣",
                "V · WHOLE-HOME HARMONIZATION",
                "第五巻・全室空間調和と化煞の秘訣",
                "제5권 · 주택 공간 조율 및 비전 화살",
                "QUYỂN V · ĐIỀU HÒA KHÔNG GIAN VÀ HÓA SÁT",
                "บทที่ ๕ · การปรับสมดุลและเคล็ดลับสลายเคราะห์ทั่วบ้าน",
                "BAGIAN V · PENYELARASAN RUANG & PENANGKAL SHA"
            )
            drawSectionHeader(ctx: cg, title: sec5Title, atY: curY, vermilion: vermilion)
            curY += 65
            
            let pwChart = PurpleWhiteEngine.shared.calculateChart(date: reportDate, heading: heading)
            let deepAnalysis = snapshot.deepAnalysis(chart: xkChart)
            let zeri = ZeRiEngine.shared.analyze(date: reportDate, sitting: mSitting)
            let annualNote = tr8(
                "• 岁运太岁与择日：太岁在\(pwChart.taiSuiDescription)、岁破在\(pwChart.suiPoDescription)、三煞在\(pwChart.sanShaDescription)；当前四柱【\(zeri.fourPillarsText)】（\(zeri.overallStatus)）。",
                "• 歲運太歲與擇日：太歲在\(pwChart.taiSuiDescription)、歲破在\(pwChart.suiPoDescription)、三煞在\(pwChart.sanShaDescription)；當前四柱【\(zeri.fourPillarsText)】（\(zeri.overallStatus)）。",
                "• Annual Tai Sui & Date Selection: Tai Sui at \(pwChart.taiSuiDescription), Sui Po at \(pwChart.suiPoDescription), San Sha at \(pwChart.sanShaDescription); Four Pillars [\(zeri.fourPillarsText)] (\(zeri.overallStatus)).",
                "• 歳運太歳と択日：太歳\(pwChart.taiSuiDescription)・歳破\(pwChart.suiPoDescription)・三煞\(pwChart.sanShaDescription)；四柱【\(zeri.fourPillarsText)】（\(zeri.overallStatus)）。",
                "• 세운 태세 및 택일: 태세 \(pwChart.taiSuiDescription), 세파 \(pwChart.suiPoDescription), 삼살 \(pwChart.sanShaDescription); 사주 【\(zeri.fourPillarsText)】(\(zeri.overallStatus)).",
                "• Thái Tuế & Trạch Nhật: Thái Tuế \(pwChart.taiSuiDescription), Tuế Phá \(pwChart.suiPoDescription), Tam Sát \(pwChart.sanShaDescription); Tứ Trụ 【\(zeri.fourPillarsText)】 (\(zeri.overallStatus)).",
                "• ไท่ซุ่ยประจำปีและฤกษ์ยาม: ไท่ซุ่ย \(pwChart.taiSuiDescription), ซุ่ยพั่ว \(pwChart.suiPoDescription), ซานซ่า \(pwChart.sanShaDescription); สี่เสา 【\(zeri.fourPillarsText)】 (\(zeri.overallStatus))",
                "• Tai Sui Tahunan & Pemilihan Hari: Tai Sui di \(pwChart.taiSuiDescription), Sui Po di \(pwChart.suiPoDescription), San Sha di \(pwChart.sanShaDescription); Empat Pilar [\(zeri.fourPillarsText)] (\(zeri.overallStatus))."
            )
            let p5Text = """
            \(snapshot.guidanceText(chart: xkChart, analysis: deepAnalysis))
            \(annualNote)
            """
            curY += drawMeasuredText(
                p5Text,
                atY: curY,
                font: bodyFont,
                color: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0),
                minimumHeight: 80
            ) + 20

            // The summary above is intentionally short for the opening pages;
            // these sections carry every palace cell so the exported scroll is
            // a complete snapshot of the current engines rather than a list of
            // only the most notable directions.
            curY = drawFlyingStarsDetails(
                ctx: cg,
                curY: curY,
                vermilion: vermilion,
                renderLanguage: renderLanguage,
                chart: xkChart,
                analysis: deepAnalysis
            )
            curY = drawQimenDetails(
                ctx: cg,
                curY: curY,
                vermilion: vermilion,
                renderLanguage: renderLanguage,
                chart: qm
            )
            curY = drawZeRiDetails(
                ctx: cg,
                curY: curY,
                vermilion: vermilion,
                renderLanguage: renderLanguage,
                analysis: zeri
            )

            if !floorplanReport.isEmpty {
                curY = drawFloorplanAudit(
                    ctx: cg,
                    curY: curY,
                    vermilion: vermilion,
                    renderLanguage: renderLanguage,
                    report: floorplanReport
                )
            }
            
            // 8.2 流年紫白客星调理与催旺（含家人影响维度）
            curY = drawPurpleWhiteRemedies(ctx: cg, curY: curY, vermilion: vermilion, renderLanguage: renderLanguage, pwChart: pwChart, analysis: deepAnalysis)
            
            // 9. 八宅凶位化解与安镇（含家人影响维度）
            curY = drawBazhaiInjurious(ctx: cg, curY: curY, vermilion: vermilion, renderLanguage: renderLanguage, bz: bz)
            
            // 10. 形煞自查与化煞安宅（外部形煞通用化解清单）
            curY = drawShaSelfCheck(
                ctx: cg,
                curY: curY,
                vermilion: vermilion,
                renderLanguage: renderLanguage,
                archive: panoramaArchive
            )
            
            // 9. 卷尾朱砂印鉴与落款（支持自定义师门堂号与印文）
            let sealRect = CGRect(x: 780, y: curY + 20, width: 180, height: 180)
            cg.setStrokeColor(vermilion.cgColor)
            cg.setLineWidth(4)
            cg.stroke(sealRect)
            cg.stroke(sealRect.insetBy(dx: 6, dy: 6))

            let customSealRaw = (UserDefaults.standard.string(forKey: "tianjishu_custom_seal") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let sealText: String
            if !customSealRaw.isEmpty {
                if !customSealRaw.contains(" ") && !customSealRaw.contains("\n") && customSealRaw.count == 4 {
                    let mid = customSealRaw.index(customSealRaw.startIndex, offsetBy: 2)
                    sealText = "\(customSealRaw[..<mid])\n\(customSealRaw[mid...])"
                } else {
                    sealText = customSealRaw.replacingOccurrences(of: " ", with: "\n")
                }
            } else {
                sealText = tr8(
                    "天机演象\n罗盘\n御印",
                    "天機演象\n羅盤\n御印",
                    "TIANJI\nYANXIANG\nCELESTIAL\nSEAL",
                    "天機演象\n羅盤\n御印",
                    "천기연상\n나경\n어인",
                    "THIÊN CƠ\nLA BÀN\nNGỰ ẤN",
                    "สวรรค์ลิขิต\nเข็มทิศ\nตราประทับ",
                    "TIANJI\nKOMPAS\nSEGEL RESMI"
                )
            }
            let sealParagraph = NSMutableParagraphStyle()
            sealParagraph.alignment = .center
            sealParagraph.lineSpacing = 4
            let sealFontSize: CGFloat = customSealRaw.count > 8 ? 18 : (customSealRaw.count > 4 ? 22 : 28)
            let sealAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: sealFontSize),
                .foregroundColor: vermilion,
                .paragraphStyle: sealParagraph
            ]
            sealText.draw(in: sealRect.insetBy(dx: 14, dy: 24), withAttributes: sealAttr)
            
            // 岁次干支天文学立春动态推导
            let curGzYear = snapshot.ganzhiYear()
            
            let customMasterRaw = (UserDefaults.standard.string(forKey: "tianjishu_custom_master") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let signText: String
            if !customMasterRaw.isEmpty {
                switch renderLanguage {
                case .en:
                    signText = "CONSULTANT & STUDIO\n\(customMasterRaw)\nYEAR \(curGzYear)"
                case .zhHant:
                    signText = "堪 輿 親 訂 落 款\n\(customMasterRaw)\n歲 次 \(curGzYear) 謹 啟"
                case .ja:
                    signText = "風水鑑定親定\n\(customMasterRaw)\n歳 次 \(curGzYear) 謹 啓"
                case .ko:
                    signText = "풍수지리 감여 친정\n\(customMasterRaw)\n세 차 \(curGzYear) 삼가 올림"
                case .vi:
                    signText = "PHONG THỦY ĐỊNH BẢN\n\(customMasterRaw)\nTUẾ THỨ \(curGzYear) CẨN KHẢI"
                case .th:
                    signText = "ปรมาจารย์ฮวงจุ้ยลิขิต\n\(customMasterRaw)\nปี \(curGzYear)"
                case .id:
                    signText = "KONSULTAN FENG SHUI\n\(customMasterRaw)\nTAHUN \(curGzYear)"
                case .auto, .zhHans:
                    signText = "堪 舆 亲 订 落 款\n\(customMasterRaw)\n岁 次 \(curGzYear) 谨 启"
                }
            } else {
                switch renderLanguage {
                case .en:
                    signText = "MASTER FENG SHUI\nTIANJI YANXIANG\nYEAR \(curGzYear)"
                case .zhHant:
                    signText = "大 師 堪 輿 親 訂\n天 機 演 象 院\n歲 次 \(curGzYear) 謹 啟"
                case .ja:
                    signText = "監修 風水鑑定親定\n天 機 演 象 院\n歳 次 \(curGzYear) 謹 啓"
                case .ko:
                    signText = "풍수지리 감여 친정\n천 기 연 상 원\n세 차 \(curGzYear) 삼가 올림"
                case .vi:
                    signText = "PHONG THỦY ĐẠI SƯ ĐỊNH BẢN\nTHIÊN CƠ DIỄN TƯỢNG VIỆN\nTUẾ THỨ \(curGzYear) CẨN KHẢI"
                case .th:
                    signText = "ปรมาจารย์ฮวงจุ้ยลิขิต\nสถาบันเทียนจียั่นเซี่ยง\nปี \(curGzYear)"
                case .id:
                    signText = "MASTER FENG SHUI RESMI\nTIANJI YANXIANG ACADEMY\nTAHUN \(curGzYear)"
                case .auto, .zhHans:
                    signText = "大 师 堪 舆 亲 订\n天 机 演 象 院\n岁 次 \(curGzYear) 谨 启"
                }
            }
            let signParagraph = NSMutableParagraphStyle()
            signParagraph.alignment = .right
            signParagraph.lineSpacing = 4
            signText.draw(in: CGRect(x: 420, y: curY + 38, width: 340, height: 150), withAttributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 70/255.0, green: 50/255.0, blue: 35/255.0, alpha: 1.0),
                .paragraphStyle: signParagraph
            ])
            
            // 11. 卷尾合规免责声明 (Compliance & disclaimer)
            requiredHeight = max(minimumHeight, drawDisclaimer(ctx: cg, curY: curY, renderLanguage: renderLanguage))

            // Keep the access policy inside the renderer as well as in the
            // SwiftUI controls. A caller that receives the generated image
            // must never get an unmarked full report before an export credit
            // or VIP entitlement has been granted.
            if !isPro {
                let watermark = tr8(
                    "预览 · 解锁后导出无水印长卷",
                    "預覽 · 解鎖後匯出無水印長卷",
                    "PREVIEW · UNLOCK TO EXPORT WITHOUT WATERMARK",
                    "プレビュー・解放すると透かしなしで出力",
                    "미리보기 · 잠금 해제 후 워터마크 없이 내보내기",
                    "XEM TRƯỚC · MỞ KHÓA ĐỂ XUẤT KHÔNG DẤU",
                    "ตัวอย่าง · ปลดล็อกเพื่อส่งออกแบบไม่มีลายน้ำ",
                    "PRATINJAU · BUKA KUNCI UNTUK EKSPOR TANPA TANDA AIR"
                )
                cg.saveGState()
                cg.setAlpha(0.16)
                cg.translateBy(x: size.width * 0.5, y: size.height * 0.5)
                cg.rotate(by: -.pi / 8)
                let watermarkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 34),
                    .foregroundColor: vermilion
                ]
                let watermarkWidth = size.width * 1.25
                for y in stride(from: -size.height, through: size.height, by: 180) {
                    watermark.draw(in: CGRect(x: -watermarkWidth * 0.5, y: y, width: watermarkWidth, height: 60), withAttributes: watermarkAttributes)
                }
                cg.restoreGState()
            }
        }
        // First pass measures the entire report on a one-pixel canvas. Allocate
        // the full bitmap only once the content height (including footnotes) is known.
        if canvasHeight == nil {
            return renderScrollImage(heading: inputHeading, coordsDesc: coordsDesc, solarTimeDesc: solarTimeDesc,
                language: renderLanguage, isPro: isPro, floorplanReport: floorplanReport, panoramaArchive: panoramaArchive,
                reportDate: inputDate, analysis: snapshot, canvasHeight: ceil(requiredHeight))
        }
        return image
    }

    private func drawSectionHeader(ctx: CGContext, title: String, atY: CGFloat, vermilion: UIColor) {
        ctx.setStrokeColor(vermilion.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 90, y: atY + 38))
        ctx.addLine(to: CGPoint(x: 990, y: atY + 38))
        ctx.strokePath()
        
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: vermilion,
            .kern: 3
        ]
        title.draw(at: CGPoint(x: 95, y: atY), withAttributes: attr)
    }
    
    // 类级多语种文案选择（8 语种）
    private func tr8(_ hans: String, _ hant: String, _ en: String, _ ja: String, _ ko: String, _ vi: String, _ th: String, _ id: String, renderLanguage: AppLanguage) -> String {
        switch renderLanguage {
        case .zhHant: return hant
        case .en: return en
        case .ja: return ja
        case .ko: return ko
        case .vi: return vi
        case .th: return th
        case .id: return id
        case .auto, .zhHans: return hans
        }
    }

    // Current in-session floorplan findings.  The store is populated by the
    // floorplan page after each audit; an empty report means no floorplan was
    // provided and is intentionally omitted rather than replaced by a sample
    // layout.
    private func drawFloorplanAudit(
        ctx: CGContext,
        curY: CGFloat,
        vermilion: UIColor,
        renderLanguage: AppLanguage,
        report: [FloorplanAuditItem]
    ) -> CGFloat {
        let title = tr8(
            "户型现场审计 · 房间与缺角锦囊",
            "戶型現場審計 · 房間與缺角錦囊",
            "FLOORPLAN SURVEY · ROOM & CORNER REMEDIES",
            "間取り現場監査・部屋と欠角の化解",
            "평면 현장 감사 · 방과 결각 해법",
            "KIỂM TRA MẶT BẰNG · PHÒNG VÀ GÓC KHUYẾT",
            "ตรวจผังบ้าน · วิธีแก้ห้องและมุมเว้า",
            "AUDIT DENAH · SOLUSI RUANG & SUDUT HILANG",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: title, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        for item in report {
            let line = "【\(item.localizedSeverity)】\(item.title) · \(item.palace)\n\(item.lore)\n→ \(item.solution)"
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 14
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        return y
    }

    private func drawFlyingStarsDetails(
        ctx: CGContext,
        curY: CGFloat,
        vermilion: UIColor,
        renderLanguage: AppLanguage,
        chart: XuanKongChart,
        analysis: XuanKongDeepAnalysis
    ) -> CGFloat {
        let title = tr8(
            "玄空九宫全盘 · 山向星与逐宫锦囊",
            "玄空九宮全盤 · 山向星與逐宮錦囊",
            "XUAN KONG NINE PALACES · FULL STAR REMEDIES",
            "玄空九宮全盤・山向星と各宮の化解",
            "현공 구궁 전체 · 산향성 및 궁별 해법",
            "CỬU CUNG HUYỀN KHÔNG · SAO VÀ CẨM NANG TỪNG CUNG",
            "เก้าวังเสวียนคง · ดาวและเคล็ดลับทุกวัง",
            "SEMBILAN ISTANA XUAN KONG · BINTANG & SOLUSI TIAP ISTANA",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: title, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let mStarLabel = tr8("山星", "山星", "Mountain", "山星", "산성", "Sơn tinh", "ดาวภูเขา", "Bintang Gunung", renderLanguage: renderLanguage)
        let fStarLabel = tr8("向星", "向星", "Facing", "向星", "향성", "Hướng tinh", "ดาวทิศหัน", "Bintang Hadap", renderLanguage: renderLanguage)
        let wuHuangLabel = tr8("五黄", "五黃", "5-Yellow", "五黄", "오황", "Ngũ Hoàng", "5 เหลือง", "5-Kuning", renderLanguage: renderLanguage)
        let erHeiLabel = tr8("二黑", "二黑", "2-Black", "二黒", "이흑", "Nhị Hắc", "2 ดำ", "2-Hitam", renderLanguage: renderLanguage)
        for cell in chart.palaces {
            let sector = analysis.sectors.first { $0.id == cell.id }
            let use = sector?.use ?? cell.suggestedUse
            let sources = chart.sourceReferences(palaceID: cell.id, yearStar: sector?.yearStar, monthStar: sector?.monthStar)
                .filter { !$0.id.hasPrefix("pattern.") && $0.id != "classic.mountain_water" }
            let line = "【\(cell.localizedPalaceName)】 · \(mStarLabel) \(cell.mountainStar) · \(fStarLabel) \(cell.facingStar) · "
                + LocalizationManager.shared.t(use.titleKey) + "\n" + TraditionalEvidenceCatalog.text(sources)
            var displayLine = line
            if cell.isShaWuHuang || cell.isShaErHei {
                displayLine += " · \(cell.isShaWuHuang ? wuHuangLabel : erHeiLabel)"
            }
            let measured = (displayLine as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 12
            displayLine.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        return y + 18
    }

    private func drawQimenDetails(
        ctx: CGContext,
        curY: CGFloat,
        vermilion: UIColor,
        renderLanguage: AppLanguage,
        chart: QimenChart
    ) -> CGFloat {
        let title = tr8(
            "奇门九宫全盘 · 门星神干与趋避锦囊",
            "奇門九宮全盤 · 門星神干與趨避錦囊",
            "QIMEN NINE PALACES · DOOR, STAR, DEITY & GUIDANCE",
            "奇門九宮全盤・門星神干と吉凶",
            "기문 구궁 전체 · 문성신간 및 길흉",
            "CỬU CUNG KỲ MÔN · MÔN, TINH, THẦN, CAN VÀ CẨM NANG",
            "เก้าวังขี่เหมิน · ประตู ดาว เทพ ก้านฟ้า และคำแนะนำ",
            "SEMBILAN ISTANA QIMEN · GERBANG, BINTANG, DEWA & PETUNJUK",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: title, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let tianPrefix = tr8("天", "天", "Heaven ", "天", "천", "Thiên ", "ฟ้า ", "Langit ", renderLanguage: renderLanguage)
        let diPrefix = tr8("地", "地", "Earth ", "地", "지", "Địa ", "ดิน ", "Bumi ", renderLanguage: renderLanguage)
        for cell in chart.cells {
            let line = "【\(cell.localizedPalaceName)】\(cell.localizedDoorName) · \(cell.localizedStarName) · \(cell.localizedGodName) · \(tianPrefix)\(cell.localizedTianStem)/\(diPrefix)\(cell.localizedDiStem) · \(cell.doorLuck)"
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 12
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        let guidance = tr8(
            "趋吉：\(chart.bestNavDirection)；避忌：\(chart.tabooDirections)；\(chart.bestNavReason)",
            "趨吉：\(chart.bestNavDirection)；避忌：\(chart.tabooDirections)；\(chart.bestNavReason)",
            "Favorable: \(chart.bestNavDirection); avoid: \(chart.tabooDirections); \(chart.bestNavReason)",
            "吉方：\(chart.bestNavDirection)；忌方：\(chart.tabooDirections)；\(chart.bestNavReason)",
            "길방: \(chart.bestNavDirection); 금기: \(chart.tabooDirections); \(chart.bestNavReason)",
            "Cát: \(chart.bestNavDirection); tránh: \(chart.tabooDirections); \(chart.bestNavReason)",
            "มงคล: \(chart.bestNavDirection); หลีกเลี่ยง: \(chart.tabooDirections); \(chart.bestNavReason)",
            "Baik: \(chart.bestNavDirection); hindari: \(chart.tabooDirections); \(chart.bestNavReason)",
            renderLanguage: renderLanguage
        )
        let measured = (guidance as NSString).boundingRect(
            with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let height = ceil(measured.height) + 12
        guidance.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
        return y + height + 18
    }

    private func drawZeRiDetails(
        ctx: CGContext,
        curY: CGFloat,
        vermilion: UIColor,
        renderLanguage: AppLanguage,
        analysis: ZeRiAnalysis
    ) -> CGFloat {
        let title = tr8(
            "择日全案 · 神煞警告与宜忌锦囊",
            "擇日全案 · 神煞警告與宜忌錦囊",
            "DATE SELECTION · WARNINGS, DO & AVOID",
            "擇日全案・神煞警告と宜忌",
            "택일 전체 · 신살 경고 및 의기",
            "TRẠCH NHẬT · CẢNH BÁO VÀ VIỆC NÊN/KHÔNG NÊN",
            "ฤกษ์ยาม · คำเตือนและกิจกรรมควร/ห้าม",
            "PEMILIHAN HARI · PERINGATAN DAN KEGIATAN",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: title, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        var lines: [String] = [analysis.fourPillarsText, analysis.overallStatus]
        if let warning = analysis.suiPoWarning { lines.append(warning) }
        if let warning = analysis.yuePoWarning { lines.append(warning) }
        if let warning = analysis.sittingClashWarning { lines.append(warning) }
        if let warning = analysis.sanShaWarning { lines.append(warning) }
        if !analysis.detailsText.isEmpty { lines.append(analysis.detailsText) }
        let yiLabel = tr8("宜：", "宜：", "Do: ", "宜：", "권장: ", "Nên: ", "ควร: ", "Anjuran: ", renderLanguage: renderLanguage)
        let jiLabel = tr8("忌：", "忌：", "Avoid: ", "忌：", "금기: ", "Tránh: ", "ห้าม: ", "Hindari: ", renderLanguage: renderLanguage)
        let activitySeparator: String
        switch renderLanguage {
        case .en, .ko, .vi, .th, .id: activitySeparator = ", "
        case .auto, .zhHans, .zhHant, .ja: activitySeparator = "、"
        }
        if !analysis.yiActivities.isEmpty { lines.append(yiLabel + analysis.yiActivities.joined(separator: activitySeparator)) }
        if !analysis.jiActivities.isEmpty { lines.append(jiLabel + analysis.jiActivities.joined(separator: activitySeparator)) }
        for line in lines {
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 12
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        return y + 18
    }
    
    // 8.2 紫白流年客星调理与催旺（含家人影响维度）
    private func drawPurpleWhiteRemedies(ctx: CGContext, curY: CGFloat, vermilion: UIColor, renderLanguage: AppLanguage, pwChart: PurpleWhiteChart, analysis: XuanKongDeepAnalysis) -> CGFloat {
        let secTitle = tr8(
            "紫白流年 · 客星调理与催旺",
            "紫白流年 · 客星調理與催旺",
            "PURPLE-WHITE YEAR · GUEST STAR REMEDIES",
            "紫白流年・客星の調理と催旺",
            "자백 유년 · 객성 조리와 최왕",
            "TỬ BẠCH LƯU NIÊN · ĐIỀU LÝ KHÁCH TINH",
            "ดาวม่วงขาวประจำปี · ปรับดาวเยือนและเสริมพลัง",
            "BINTANG UNGU-PUTIH · PENYESUAIAN BINTANG TAMU",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: secTitle, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        for item in pwChart.palaceItems {
            let sector = analysis.sectors.first { $0.id == item.palaceId - 1 }
            let lang = LocalizationManager.shared
            let state = sector.map { lang.t($0.use.titleKey) } ?? ""
            let line = "「\(item.palaceName)」 " + lang.t("xkd_annual") + " \(item.yearGuestStar) · "
                + lang.t("xkd_monthly") + " \(item.monthGuestStar) · " + state + "\n"
                + TraditionalEvidenceCatalog.text(item.sourceReferences)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink
            ]
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 12
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        return y
    }
    
    // 9. 八宅凶位化解与安镇（含家人影响维度）
    private func drawBazhaiInjurious(ctx: CGContext, curY: CGFloat, vermilion: UIColor, renderLanguage: AppLanguage, bz: BaZhaiAnalysis) -> CGFloat {
        let secTitle = tr8(
            "八宅八宫 · 吉凶化解安镇",
            "八宅八宮 · 吉凶化解安鎮",
            "EIGHT MANSIONS · ALL PALACE REMEDIES",
            "八宅八宮・吉凶の化解と安鎮",
            "팔택 팔궁 · 길흉 화해와 안진",
            "BÁT TRẠCH BÁT CUNG · HÓA GIẢI TOÀN BỘ",
            "แปดเรือนแปดวัง · แก้เคล็ดครบถ้วน",
            "DELAPAN ISTANA · SEMUA PENANGKAL",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: secTitle, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        for item in bz.items {
            let line = "【\(item.star.localizedName) · \(item.localizedDirection)】\(item.star.localizedSuggestion)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink
            ]
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 12
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }
        return y
    }
    
    // 10. 形煞自查与化煞安宅（外部形煞通用化解清单）
    private func drawShaSelfCheck(
        ctx: CGContext,
        curY: CGFloat,
        vermilion: UIColor,
        renderLanguage: AppLanguage,
        archive: PanoramaFengShuiArchive?
    ) -> CGFloat {
        let secTitle = tr8(
            archive == nil ? "形煞自查 · 通用锦囊" : "形煞自查 · 当前现场记录",
            archive == nil ? "形煞自查 · 通用錦囊" : "形煞自查 · 當前現場記錄",
            archive == nil ? "EXTERNAL SHA · GENERAL REMEDIES" : "EXTERNAL SHA · CURRENT SURVEY",
            archive == nil ? "形煞セルフチェック・一般的な化解" : "形煞セルフチェック・現場記録",
            archive == nil ? "형살 자점 · 일반 화해" : "형살 자점 · 현장 기록",
            archive == nil ? "TỰ TRA HÌNH SÁT · CẨM NANG CHUNG" : "TỰ TRA HÌNH SÁT · GHI NHẬN HIỆN TRƯỜNG",
            archive == nil ? "ตรวจสอบเครื่องหมายพิฆาต · เคล็ดลับทั่วไป" : "ตรวจสอบเครื่องหมายพิฆาต · บันทึกภาคสนาม",
            archive == nil ? "PEMERIKSAAN SHA · PENANGKAL UMUM" : "PEMERIKSAAN SHA · SURVEI SAAT INI",
            renderLanguage: renderLanguage
        )
        drawSectionHeader(ctx: ctx, title: secTitle, atY: curY, vermilion: vermilion)
        var y = curY + 62
        let font = UIFont.systemFont(ofSize: 22)
        let ink = UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
        func drawLine(_ line: String) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink
            ]
            let measured = (line as NSString).boundingRect(
                with: CGSize(width: 880, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let height = ceil(measured.height) + 14
            line.draw(in: CGRect(x: 100, y: y, width: 880, height: height), withAttributes: attributes)
            y += height
        }

        if let archive {
            for record in archive.exterior {
                let sha = ExteriorShaEngine.shared.database.first(where: { $0.id == record.shaID })
                let name = sha?.localizedName ?? record.shaID
                let remedy = sha?.localizedRemedySolution ?? ""
                let elevLabel = tr8("仰角", "仰角", "Elev.", "仰角", "앙각", "Góc ngẩng", "มุมเงย", "Elevasi", renderLanguage: renderLanguage)
                let manualLabel = tr8("手动", "手動", "Manual", "手動", "수동", "Thủ công", "กำหนดเอง", "Manual", renderLanguage: renderLanguage)
                var metadata = String(format: "%.1f°", record.bearingDegrees)
                metadata += String(format: " · \(elevLabel) %.1f°", record.elevationDegrees)
                if let distance = record.distanceMeters {
                    metadata += String(format: " · %.1f m", distance)
                }
                if let confidence = record.confidence {
                    metadata += String(format: " · %.0f%%", confidence * 100)
                }
                metadata += record.source == .ai ? " · AI" : " · \(manualLabel)"
                if let note = record.note, !note.isEmpty {
                    metadata += " · " + note
                }
                drawLine("【\(name) · \(metadata)】\(remedy)")
            }
            if let interior = archive.interior {
                let interiorSummaryText = tr8(
                    "室内测绘：\(interior.scanMethod) · 房间 \(interior.rooms.count) · 墙体 \(interior.walls.count) · 门窗 \(interior.openings.count) · 风水评分 \(interior.fengshuiScore)",
                    "室內測繪：\(interior.scanMethod) · 房間 \(interior.rooms.count) · 牆體 \(interior.walls.count) · 門窗 \(interior.openings.count) · 風水評分 \(interior.fengshuiScore)",
                    "Interior survey: \(interior.scanMethod) · rooms \(interior.rooms.count) · walls \(interior.walls.count) · openings \(interior.openings.count) · score \(interior.fengshuiScore)",
                    "室内測量：\(interior.scanMethod)・部屋 \(interior.rooms.count)・壁 \(interior.walls.count)・開口部 \(interior.openings.count)・スコア \(interior.fengshuiScore)",
                    "실내 측량: \(interior.scanMethod) · 방 \(interior.rooms.count) · 벽 \(interior.walls.count) · 개구부 \(interior.openings.count) · 점수 \(interior.fengshuiScore)",
                    "Khảo sát nội thất: \(interior.scanMethod) · phòng \(interior.rooms.count) · tường \(interior.walls.count) · cửa mở \(interior.openings.count) · điểm \(interior.fengshuiScore)",
                    "สำรวจภายใน: \(interior.scanMethod) · ห้อง \(interior.rooms.count) · ผนัง \(interior.walls.count) · ช่องเปิด \(interior.openings.count) · คะแนน \(interior.fengshuiScore)",
                    "Survei interior: \(interior.scanMethod) · ruang \(interior.rooms.count) · dinding \(interior.walls.count) · bukaan \(interior.openings.count) · skor \(interior.fengshuiScore)",
                    renderLanguage: renderLanguage
                )
                let interiorSummary = interiorSummaryText + String(format: " · %.1f°", archive.compassHeading)
                drawLine(interiorSummary)
                for item in interior.shaItems {
                    drawLine("【\(item.title) · \(item.severity.localizedTitle)】\(item.solution)")
                }
            }
            if archive.exterior.isEmpty && archive.interior?.shaItems.isEmpty != false {
                drawLine(tr8(
                    "已建立现场档案，但当前没有可展示的形煞条目。",
                    "已建立現場檔案，但目前沒有可展示的形煞條目。",
                    "A survey archive exists, but it contains no sha findings.",
                    "現場記録はありますが、形煞の検出項目はありません。",
                    "현장 기록은 있지만 형살 항목이 없습니다.",
                    "Đã có hồ sơ khảo sát nhưng chưa có mục hình sát.",
                    "มีแฟ้มสำรวจแล้ว แต่ยังไม่มีรายการพิฆาต",
                    "Arsip survei ada, tetapi tidak ada temuan sha.",
                    renderLanguage: renderLanguage
                ))
            }
        } else {
            for sha in ExteriorShaEngine.shared.database {
                drawLine("【\(sha.localizedName)】\(sha.localizedRemedySolution)")
            }
        }
        return y
    }
    
    // 11. 卷尾合规免责声明（8 语种）
    private func drawDisclaimer(ctx: CGContext, curY: CGFloat, renderLanguage: AppLanguage) -> CGFloat {
        let disclaimer = tr8(
            "温馨提示：本长卷依据传统堪舆文化整理，仅供文化研究与娱乐参考，不构成医疗、法律、金融或投资建议，亦不承诺任何实际效果。请理性看待，涉及健康、财产等重大事项请咨询相关专业人士。",
            "溫馨提示：本長卷依據傳統堪輿文化整理，僅供文化研究與娛樂參考，不構成醫療、法律、金融或投資建議，亦不承諾任何實際效果。請理性看待，涉及健康、財產等重大事項請諮詢相關專業人士。",
            "Note: This scroll is compiled from traditional Feng Shui culture and is provided for cultural study and entertainment only. It does not constitute medical, legal, financial or investment advice, nor does it promise any actual outcome. Please view it rationally and consult qualified professionals on matters of health, property and other major decisions.",
            "ご案内：本書は伝統的な風水文化に基づき編纂され、文化的な研究・娯楽の参考のみを目的としています。医療・法律・金融・投資に関する助言ではなく、いかなる実際の効果も保証するものではありません。理性をもってご覧いただき、健康・財産など重要な事項は専門家にご相談ください。",
            "안내: 본 장권은 전통 풍수 문화를 바탕으로 정리되었으며 문화 연구 및 오락 참고용일 뿐, 의료·법률·금융·투자 자문을 제공하지 않으며 어떠한 실제 효과도 보장하지 않습니다. 합리적으로 판단하시고 건강·재산 등 중대한 사항은 전문가와 상담하시기 바랍니다.",
            "Lưu ý: Trường quyển này được biên soạn theo văn hóa Phong Thủy truyền thống, chỉ để tham khảo nghiên cứu văn hóa và giải trí, không phải lời khuyên y tế, pháp lý, tài chính hay đầu tư, cũng không hứa hẹn bất kỳ kết quả thực tế nào. Hãy nhìn nhận hợp lý; các vấn đề quan trọng như sức khỏe, tài sản vui lòng tham vấn chuyên gia.",
            "หมายเหตุ: ม้วนนี้จัดทำขึ้นตามวัฒนธรรมฮวงจุ้ยโบราณ เพื่อการศึกษาวัฒนธรรมและความบันเทิงเท่านั้น ไม่ใช่คำแนะนำทางการแพทย์ กฎหมาย การเงินหรือการลงทุน และไม่รับประกันผลลัพธ์จริงใด ๆ โปรดพิจารณาอย่างมีสติ เรื่องสำคัญด้านสุขภาพและทรัพย์สินควรปรึกษาผู้เชี่ยวชาญ",
            "Catatan: Gulungan ini disusun berdasarkan budaya Feng Shui tradisional, hanya untuk kajian budaya dan hiburan; bukan nasihat medis, hukum, keuangan atau investasi, dan tidak menjanjikan hasil nyata apa pun. Harap disikapi secara rasional; untuk hal penting seperti kesehatan dan properti, konsultasikan dengan ahli.",
            renderLanguage: renderLanguage
        )
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor(red: 120/255.0, green: 100/255.0, blue: 80/255.0, alpha: 1.0)
        ]
        let maxWidth: CGFloat = 880
        let neededHeight = ceil(disclaimer.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attr,
            context: nil
        ).height) + 8
        disclaimer.draw(in: CGRect(x: 100, y: curY + 260, width: maxWidth, height: neededHeight), withAttributes: attr)
        return curY + 260 + neededHeight + 80
    }
    
    // 保存至相册
    public func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        let message: String
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: message = "Celestial scroll saved to Photos successfully."
        case .zhHant: message = "天機宣紙勘測長卷已成功保存至系統相簿！"
        case .ja: message = "天機宣紙鑑定長巻がアルバムに保存されました！"
        case .ko: message = "천기 선지 감여 장권이 사진첩에 성공적으로 저장되었습니다!"
        case .vi: message = "Bản đồ phong thủy tuyên chỉ đã lưu vào album ảnh thành công!"
        case .th: message = "บันทึกคัมภีร์ตรวจฮวงจุ้ยลงในอัลบั้มรูปเรียบร้อยแล้ว!"
        case .id: message = "Gulungan Feng Shui berhasil disimpan ke galeri foto!"
        case .auto, .zhHans: message = "天机宣纸勘测长卷已成功保存至系统相册！"
        }
        let failure = LocalizationManager.shared.t("save_failed")

        let save: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if !success, let error = error {
                    NSLog("[TianJiShuEngine] Failed to save photo to album: %@", error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completion(success, success ? message : failure)
                }
            }
        }

        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            save()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized || status == .limited {
                    save()
                } else {
                    DispatchQueue.main.async { completion(false, failure) }
                }
            }
        default:
            DispatchQueue.main.async {
                completion(false, failure)
            }
        }
    }
}
