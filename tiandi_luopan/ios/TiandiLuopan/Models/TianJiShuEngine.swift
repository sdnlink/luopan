import UIKit
import Photos

// MARK: - 福宅天机书 · 古典宣纸朱丝栏全案长卷导出引擎 (PRD 第14章)

public class TianJiShuEngine {
    public static let shared = TianJiShuEngine()
    
    private init() {}
    
    // 生成高清古典宣纸长卷勘测报告图 (1080 x 2400)
    public func generateScrollImage(
        heading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        language: AppLanguage? = nil,
        isPro: Bool = true,
        reportDate: Date = Date()
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 2400)
        // These dimensions describe the exported pixel size. The default
        // renderer scale follows the device's Retina factor and could turn
        // this into a 3240x7200 image, multiplying memory and render time.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        // Resolve the language before entering the renderer closure. The
        // image is generated off the main queue while the user can still
        // change the app language, so the report must use one stable locale.
        let renderLanguage = language ?? LocalizationManager.shared.effectiveLanguage
        
        return renderer.image { ctx in
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
            
            // 1. 宣纸底色 (温润米黄熟宣)
            let paperColor = UIColor(red: 247/255.0, green: 243/255.0, blue: 232/255.0, alpha: 1.0)
            cg.setFillColor(paperColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            
            // 宣纸暗纹网格
            cg.setStrokeColor(UIColor(red: 235/255.0, green: 228/255.0, blue: 212/255.0, alpha: 0.6).cgColor)
            cg.setLineWidth(1)
            for y in stride(from: 40, to: 2360, by: 40) {
                cg.move(to: CGPoint(x: 40, y: CGFloat(y)))
                cg.addLine(to: CGPoint(x: 1040, y: CGFloat(y)))
            }
            cg.strokePath()
            
            // 2. 朱丝栏外框与双线边饰
            let vermilion = UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0) // 朱砂红
            cg.setStrokeColor(vermilion.cgColor)
            cg.setLineWidth(6)
            cg.stroke(CGRect(x: 45, y: 45, width: 990, height: 2310))
            cg.setLineWidth(2)
            cg.stroke(CGRect(x: 55, y: 55, width: 970, height: 2290))
            
            // 3. 卷首长卷标题
            let titleFont = UIFont.boldSystemFont(ofSize: 52)
            let subTitleFont = UIFont.systemFont(ofSize: 26, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 24)
            let sectionFont = UIFont.boldSystemFont(ofSize: 32)
            
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
            
            // 防伪编号
            let snLabel = tr8("防伪鉴真号", "防偽鑒真號", "Verification No.", "識別真贋番号", "감정 진위 번호", "Mã xác thực", "หมายเลขตรวจสอบ", "No. Verifikasi")
            let sn = "\(snLabel): YX-\(Int(reportDate.timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
            sn.draw(at: CGPoint(x: 100, y: 220), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.gray
            ])
            
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
            p1Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 260), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 250
            
            // 5. 第二部：玄空飞星九宫方阵 (根据实时天文学历法动态排盘)
            let xkChart = FlyingStarsEngine.shared.calculateChart(sitting: mSitting, facing: mFacing, date: reportDate)
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
                • Overall analysis: \(xkChart.summaryAnalysis)
                """
            case .zhHant:
                p2Text = """
                • 當前地運：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 當令旺星氣場：\(meta.starName)\(meta.element)星入中當運，主星臨照向首明堂。
                • 綜合理氣研判：\(xkChart.summaryAnalysis)
                """
            case .ja:
                p2Text = """
                • 現在の地運：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 当令旺星の気：\(meta.starName)\(meta.element)星が中宮に入り、向首明堂を照らします。
                • 総合理気判断：\(xkChart.summaryAnalysis)
                """
            case .ko:
                p2Text = """
                • 현재 지운: \(meta.label)
                • 현공 격국 판정: 【\(mSitting.localizedName)산 \(mFacing.localizedName)향】\(xkChart.patternType)
                • 당령 왕성 기운: \(meta.starName)\(meta.element)성이 중궁에 입하여 향수 명당을 비춥니다.
                • 종합 이기 판단: \(xkChart.summaryAnalysis)
                """
            case .vi:
                p2Text = """
                • Địa vận hiện tại: \(meta.label)
                • Phán đoán cục diện: 【Sơn \(mSitting.localizedName) Hướng \(mFacing.localizedName)】\(xkChart.patternType)
                • Khí trường vượng tinh: Sao \(meta.starName) \(meta.element) nhập trung cung, chiếu sáng minh đường.
                • Phân tích tổng hợp: \(xkChart.summaryAnalysis)
                """
            case .th:
                p2Text = """
                • ยุคปัจจุบัน: \(meta.label)
                • รูปแบบผังเสวียนคง: 【พิง\(mSitting.localizedName) หัน\(mFacing.localizedName)】\(xkChart.patternType)
                • ชี่ดาวเจริญยุค: ดาว\(meta.starName) ธาตุ\(meta.element) เข้าสู่ศูนย์กลาง ส่องสว่างลานหน้าบ้าน
                • ผลวิเคราะห์ภาพรวม: \(xkChart.summaryAnalysis)
                """
            case .id:
                p2Text = """
                • Periode Saat Ini: \(meta.label)
                • Pola Bintang Terbang: [\(mSitting.localizedName) / \(mFacing.localizedName)] \(xkChart.patternType)
                • Qi Bintang Berkuasa: Bintang \(meta.starName) \(meta.element) masuk ke tengah menyinari ruang depan.
                • Analisis Keseluruhan: \(xkChart.summaryAnalysis)
                """
            case .auto, .zhHans:
                p2Text = """
                • 当前地运：\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                • 当令旺星气场：\(meta.starName)\(meta.element)星入中当运，主星临照向首明堂。
                • 综合理气研判：\(xkChart.summaryAnalysis)
                """
            }
            p2Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 240), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 230
            
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
            let sanHeItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: mSitting)
            let lang = LocalizationManager.shared
            let hqLabel = tr8("向首八路黄泉判据", "向首八路黃泉判據", "Eight-Road Huangquan test", "向首八路黄泉判定", "향수 팔로황천 판별", "Phán định Bát Lộ Hoàng Tuyền", "เกณฑ์น้ำฮวงเฉวียนแปดทิศ", "Uji Huangquan Delapan Arah")
            let bashaLabel = tr8("坐山八煞曜位辨识", "坐山八煞曜位辨識", "Sitting-mountain Sha position", "坐山八煞曜位識別", "좌산 팔살요위 식별", "Nhận định Bát Sát Diệu vị", "ตำแหน่งดาวพิฆาตแปดทิศ", "Posisi Sha Delapan Arah")
            let waterLabel = tr8("十二长生纳水吉凶", "十二長生納水吉凶", "Twelve Changsheng water assessment", "十二長生納水吉凶", "십이장생 납수길흉", "Cát hung Thập Nhị Trường Sinh", "ประเมินน้ำสิบสองสภาวะฉางเซิง", "Penilaian Air Dua Belas Changsheng")
            
            var p3Text = "• \(hqLabel): \(hq.badgeText) · \(hq.waterDesc)\n"
            p3Text += "• \(bashaLabel): 【\(basha.localizedShaDir)】 · \(basha.remedy)\n"
            p3Text += "• \(waterLabel):\n"
            for item in sanHeItems.prefix(3) {
                let verdict = item.isAuspicious
                    ? tr8("吉 · 宜来水纳气", "吉 · 宜來水納氣", "Auspicious · favorable inflow", "吉・来水歓迎", "길 · 내수 유입 권장", "Cát · nên đón nước vào tụ khí", "มงคล · ควรรับน้ำไหลเข้า", "Berkah · aliran masuk yang baik")
                    : tr8("忌 · 防破局流破", "忌 · 防破局流破", "Avoid · prevent draining the pattern", "忌・破局流出注意", "기 · 파국 유출 방지", "Kỵ · đề phòng nước chảy thoát phá cục", "อัปมงคล · ป้องกันน้ำไหลรั่วทำลายผัง", "Hindari · cegah aliran menguras energi")
                p3Text += "  - \(item.localizedMountainName)\(lang.t("mountain_suffix"))【\(item.stage)】: \(verdict), \(item.lore)\n"
            }
            p3Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 230), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 220
            
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
            p4Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 210), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 200
            
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
            \(xkChart.wealthAdvice)
            \(xkChart.healthAdvice)
            \(xkChart.remedyAdvice)
            \(annualNote)
            """
            p5Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 210), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 200
            
            // 9. 卷尾朱砂印鉴与落款
            let sealRect = CGRect(x: 780, y: curY + 20, width: 180, height: 180)
            cg.setStrokeColor(vermilion.cgColor)
            cg.setLineWidth(4)
            cg.stroke(sealRect)
            cg.stroke(sealRect.insetBy(dx: 6, dy: 6))
            
            let sealText = tr8(
                "天机演象\n罗盘\n御印",
                "天機演象\n羅盤\n御印",
                "TIANJI\nYANXIANG\nCELESTIAL\nSEAL",
                "天機演象\n羅盤\n御印",
                "천기연상\n나경\n어인",
                "THIÊN CƠ\nLA BÀN\nNGỰ ẤN",
                "สวรรค์ลิขิต\nเข็มทิศ\nตราประทับ",
                "TIANJI\nKOMPAS\nSEGEL RESMI"
            )
            let sealAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: vermilion
            ]
            sealText.draw(in: sealRect.insetBy(dx: 16, dy: 24), withAttributes: sealAttr)
            
            // 岁次干支天文学立春动态推导
            let calendar = Calendar.current
            let now = reportDate
            let y = calendar.component(.year, from: now)
            let isBeforeLichun = SolarTimeCalculator.shared.isBeforeLiChun(for: now)
            let gzYear = isBeforeLichun ? (y - 1) : y
            let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
            let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
            let yOffset = ((gzYear - 4) % 60 + 60) % 60
            let curGzYear = "\(stems[yOffset % 10])\(branches[yOffset % 12])"
            
            let signText: String
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
            signText.draw(at: CGPoint(x: 500, y: curY + 45), withAttributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 70/255.0, green: 50/255.0, blue: 35/255.0, alpha: 1.0)
            ])
        }
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
                DispatchQueue.main.async {
                    completion(success, success ? message : (error?.localizedDescription ?? failure))
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
