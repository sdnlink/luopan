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
            func tr(_ hans: String, _ hant: String, _ en: String) -> String {
                switch renderLanguage {
                case .en: return en
                case .zhHant: return hant
                default: return hans
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
            
            let titleText = tr("福 宅 天 机 勘 舆 全 案 书", "福 宅 天 機 勘 輿 全 案 書", "F O R T U N E  H O M E  C E L E S T I A L  S C R O L L")
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: vermilion,
                .kern: 10
            ]
            let tSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(at: CGPoint(x: (size.width - tSize.width) / 2, y: 90), withAttributes: titleAttr)
            
            let subTitle = tr("—— 天 机 演 象 · 天 地 时 空 全 息 罗 盘 钦 定 ——", "—— 天 機 演 象 · 天 地 時 空 全 息 羅 盤 欽 定 ——", "— TIANJI YANXIANG · CELESTIAL COMPASS —")
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subTitleFont,
                .foregroundColor: UIColor(red: 110/255.0, green: 75/255.0, blue: 45/255.0, alpha: 1.0),
                .kern: 4
            ]
            let sSize = subTitle.size(withAttributes: subAttr)
            subTitle.draw(at: CGPoint(x: (size.width - sSize.width) / 2, y: 165), withAttributes: subAttr)
            
            // 防伪编号
            let sn = "\(tr("防伪鉴真号", "防偽鑒真號", "Verification No.")): YX-\(Int(reportDate.timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
            sn.draw(at: CGPoint(x: 100, y: 220), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.gray
            ])
            
            // 4. 第一部：坐向立极与分金格局
            var curY: CGFloat = 280
            drawSectionHeader(ctx: cg, title: tr("第一卷 · 坐向立极与分金天心", "第一卷 · 坐向立極與分金天心", "I · ORIENTATION & FENJIN CENTER"), atY: curY, vermilion: vermilion)
            curY += 65
            
            let mFacing = Mountain24Data.shared.mountain(for: heading)
            let sitAngle = (heading + 180).truncatingRemainder(dividingBy: 360)
            let mSitting = Mountain24Data.shared.mountain(for: sitAngle)
            let fenjin = Fenjin120Data.shared.resolveFenjin(for: heading)
            let hex = Hexagram64Data.shared.hexagram(for: heading)
            
            let p1Text: String
            if renderLanguage == .en {
                p1Text = """
                • Facing orientation: \(mFacing.localizedName) mountain (measured \(String(format: "%.1f", heading))°) · \(mFacing.localizedPalace) Palace
                • Sitting mountain: \(mSitting.localizedName) (sitting \(String(format: "%.1f", sitAngle))°) · \(mSitting.localizedPalace)
                • 120 Fenjin: \(fenjin.jiaziName) (center \(String(format: "%.1f", fenjin.centerAngle))°) · [\(fenjin.localizedGrade)]
                • 64 Hexagrams: \(hex.localizedName) · upper \(hex.localizedUpperTrigram), lower \(hex.localizedLowerTrigram) · [\(hex.localizedLuckDegree)]
                • Survey coordinates: \(coordsDesc)
                • Solar-term true time: \(solarTimeDesc)
                """
            } else if renderLanguage == .zhHant {
                p1Text = """
                • 物理向首方位：\(mFacing.localizedName)山向首（實測 \(String(format: "%.1f", heading))°）· \(mFacing.localizedPalace)宮
                • 住宅太極坐山：\(mSitting.localizedName)山立極（坐 \(String(format: "%.1f", sitAngle))°）· 屬\(mSitting.localizedPalace)
                • 一百二十分金：\(fenjin.jiaziName)分金（中心 \(String(format: "%.1f", fenjin.centerAngle))°）· 【\(fenjin.localizedGrade)】
                • 周易六十四卦：\(hex.localizedName) · 外卦\(hex.localizedUpperTrigram) 內卦\(hex.localizedLowerTrigram) · 爻度【\(hex.localizedLuckDegree)】
                • 堪輿定位座標：\(coordsDesc)
                • 節氣真太陽時：\(solarTimeDesc)
                """
            } else {
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
            
            drawSectionHeader(ctx: cg, title: renderLanguage == .en ? "II · FLYING STARS & PERIOD \(meta.period)" : (renderLanguage == .zhHant ? "第二卷 · \(meta.yuan)\(meta.period)運玄空飛星氣運方陣" : "第二卷 · \(meta.yuan)\(meta.period)运玄空飞星气运方阵"), atY: curY, vermilion: vermilion)
            curY += 65
            
            let p2Text: String
            if renderLanguage == .en {
                p2Text = """
                • Current period: \(meta.label)
                • Flying-star pattern: [\(mSitting.localizedName) / \(mFacing.localizedName)] \(xkChart.patternType)
                • Ruling star qi: \(meta.starName) \(meta.element) star enters the center and illuminates the facing bright hall.
                • Overall analysis: \(xkChart.summaryAnalysis)
                """
            } else {
                p2Text = """
                \(renderLanguage == .zhHant ? "• 當前地運：" : "• 当前地运：")\(meta.label)
                • 玄空格局判定：【\(mSitting.localizedName)山\(mFacing.localizedName)向】\(xkChart.patternType)
                \(renderLanguage == .zhHant ? "• 當令旺星氣場：\(meta.starName)\(meta.element)星入中當運，主星臨照向首明堂。" : "• 当令旺星气场：\(meta.starName)\(meta.element)星入中当运，主星临照向首明堂。")
                \(renderLanguage == .zhHant ? "• 綜合理氣研判：\(xkChart.summaryAnalysis)" : "• 综合理气研判：\(xkChart.summaryAnalysis)")
                """
            }
            p2Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 240), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 230
            
            // 6. 第三部：杨公八路黄泉与消砂纳水
            drawSectionHeader(ctx: cg, title: tr("第三卷 · 杨公形气八路黄泉与水法宜忌", "第三卷 · 楊公形氣八路黃泉與水法宜忌", "III · YANG GONG WATER METHOD & HUANGQUAN"), atY: curY, vermilion: vermilion)
            curY += 65
            
            let hq = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: mFacing)
            let basha = SanHeWaterEngine.shared.resolveBaSha(sitting: mSitting)
            let sanHeItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: mSitting)
            let lang = LocalizationManager.shared
            var p3Text = "• \(tr("向首八路黄泉判据", "向首八路黃泉判據", "Eight-Road Huangquan test")): \(hq.badgeText) · \(hq.waterDesc)\n"
            p3Text += "• \(tr("坐山八煞曜位辨识", "坐山八煞曜位辨識", "Sitting-mountain Sha position")): 【\(basha.localizedShaDir)】 · \(basha.remedy)\n"
            p3Text += "• \(tr("十二长生纳水吉凶", "十二長生納水吉凶", "Twelve Changsheng water assessment")):\n"
            for item in sanHeItems.prefix(3) {
                let verdict = item.isAuspicious ? tr("吉 · 宜来水纳气", "吉 · 宜來水納氣", "Auspicious · favorable inflow") : tr("忌 · 防破局流破", "忌 · 防破局流破", "Avoid · prevent draining the pattern")
                p3Text += "  - \(item.localizedMountainName)\(lang.t("mountain_suffix"))【\(item.stage)】: \(verdict), \(item.lore)\n"
            }
            p3Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 230), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 220
            
            // 7. 第四部：时家奇门与八宅命卦
            drawSectionHeader(ctx: cg, title: tr("第四卷 · 时家奇门时空与八宅大游年", "第四卷 · 時家奇門時空與八宅大遊年", "IV · QIMEN TIME-SPACE & EIGHT MANSIONS"), atY: curY, vermilion: vermilion)
            curY += 65
            
            let qm = QimenEngine.shared.calculateChart(date: reportDate, heading: heading)
            let bz = BaZhaiEngine.shared.analyze(sittingPalace: mSitting.palace, facingPalace: mFacing.palace)
            
            let p4Text: String
            if renderLanguage == .en {
                p4Text = """
                • QiMen time-space: \(qm.title)
                • Best direction to move now: \(qm.bestNavDirection) (\(qm.bestNavReason))
                • House gua: [\(bz.localizedHouseGua)] · gate direction: \(bz.localizedGateDirection), receiving [\(bz.gateStar.localizedName)]
                • Sheng Qi direction: \(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "Sheng Qi"); suitable for the master bedroom or altar.
                """
            } else {
                p4Text = """
                \(renderLanguage == .zhHant ? "• 時家奇門時空：" : "• 时家奇门时空：")\(qm.title)
                \(renderLanguage == .zhHant ? "• 當前天時最優動身方：" : "• 当前天时最优动身方：")\(qm.bestNavDirection) (\(qm.bestNavReason))
                \(renderLanguage == .zhHant ? "• 住宅宅卦歸屬：【\(bz.localizedHouseGua)】 · 向首開門方：\(bz.localizedGateDirection)方納【\(bz.gateStar.localizedName)】" : "• 住宅宅卦归属：【\(bz.localizedHouseGua)】 · 向首开门方：\(bz.localizedGateDirection)方纳【\(bz.gateStar.localizedName)】")
                \(renderLanguage == .zhHant ? "• 生氣大吉尊方：\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "生氣")方，宜作主臥或安奉神位。" : "• 生气大吉尊方：\(bz.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "生气")方，宜作主卧或安奉神位。")
                """
            }
            p4Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 210), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 200
            
            // 8. 第五部：全屋空间调理与开光化煞清单
            drawSectionHeader(ctx: cg, title: tr("第五卷 · 全屋空间调理与镇煞秘诀", "第五卷 · 全屋空間調理與鎮煞秘訣", "V · WHOLE-HOME HARMONIZATION"), atY: curY, vermilion: vermilion)
            curY += 65
            
            let p5Text: String
            if renderLanguage == .en {
                p5Text = """
                1. Entry: keep it bright and spacious; avoid beams over the console and add a natural jade wealth vessel.
                2. Kitchen: keep the faucet and stove apart; avoid a stove facing the door or suspended without support.
                3. Bathroom: prevent the door facing the bed; use bamboo charcoal or cleansing water to reduce damp qi.
                4. Balcony: if facing a wall blade, tower or reverse-bow road, use a brass Taishan stone or Mountain-Sea Shield.
                """
            } else {
                p5Text = """
                \(renderLanguage == .zhHant ? "1. 入戶玄關：保持寬敞明亮，玄關櫃忌頂部有橫梁壓頂；宜安放天然黃玉聚寶盆迎財。" : "1. 入户玄关：保持宽敞明亮，玄关柜忌顶部有横梁压顶；宜安放天然黄玉聚宝盆迎财。")
                \(renderLanguage == .zhHant ? "2. 廚房灶台：避免水龍頭與灶台對衝（水火相煎），忌爐灶背向大門或懸空設台。" : "2. 厨房灶台：避免水龙头与灶台对冲（水火相煎），忌炉灶背向大门或悬空设台。")
                \(renderLanguage == .zhHant ? "3. 衛生間排濁：忌廁門直衝臥室床頭，常備活性竹炭或安忍水淨化地表陰濁濕氣。" : "3. 卫生间排浊：忌厕门直冲卧室床头，常备活性竹炭或安忍水净化地表阴浊湿气。")
                \(renderLanguage == .zhHant ? "4. 陽台防煞：若窗外對衝壁刀、電塔或反弓馬路，安放純銅泰山石敢當或山海鎮阻擋。" : "4. 阳台防煞：若窗外对冲壁刀、电塔或反弓马路，安放纯铜泰山石敢当或山海镇阻挡。")
                """
            }
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
            
            let sealText = tr("天机演象\n罗盘\n御印", "天機演象\n羅盤\n御印", "TIANJI\nYANXIANG\nCELESTIAL\nSEAL")
            let sealAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: vermilion
            ]
            sealText.draw(in: sealRect.insetBy(dx: 24, dy: 24), withAttributes: sealAttr)
            
            // 岁次干支天文学立春动态推导
            let calendar = Calendar.current
            let now = reportDate
            let y = calendar.component(.year, from: now)
            let m = calendar.component(.month, from: now)
            let solarTermIndex = SolarTimeCalculator.shared.solarTermIndex(for: now)
            let isBeforeLichun = m < 2 || (m == 2 && solarTermIndex < 2)
            let gzYear = isBeforeLichun ? (y - 1) : y
            let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
            let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
            let yOffset = ((gzYear - 4) % 60 + 60) % 60
            let curGzYear = "\(stems[yOffset % 10])\(branches[yOffset % 12])"
            
            let signText = renderLanguage == .en ? "MASTER FENG SHUI\nTIANJI YANXIANG\nYEAR \(curGzYear)" : (renderLanguage == .zhHant ? "大 師 堪 輿 親 訂\n天 機 演 象 院\n歲 次 \(curGzYear) 謹 啟" : "大 师 堪 舆 亲 订\n天 机 演 象 院\n岁 次 \(curGzYear) 谨 启")
            signText.draw(at: CGPoint(x: 540, y: curY + 45), withAttributes: [
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
        default: message = "天机宣纸勘测长卷已成功保存至系统相册！"
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
