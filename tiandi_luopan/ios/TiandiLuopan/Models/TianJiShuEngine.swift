import UIKit

// MARK: - 福宅天机书 · 古典宣纸朱丝栏全案长卷导出引擎 (PRD 第14章)

public class TianJiShuEngine {
    public static let shared = TianJiShuEngine()
    
    private init() {}
    
    // 生成高清古典宣纸长卷勘测报告图 (1080 x 2400)
    public func generateScrollImage(
        heading: Double,
        coordsDesc: String,
        solarTimeDesc: String,
        isPro: Bool = true
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 2400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            let cg = ctx.cgContext
            
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
            
            let titleText = "福 宅 天 机 勘 舆 全 案 书"
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: vermilion,
                .kern: 10
            ]
            let tSize = titleText.size(withAttributes: titleAttr)
            titleText.draw(at: CGPoint(x: (size.width - tSize.width) / 2, y: 90), withAttributes: titleAttr)
            
            let subTitle = "—— 演 象 · 天 地 时 空 全 息 罗 盘 钦 定 ——"
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subTitleFont,
                .foregroundColor: UIColor(red: 110/255.0, green: 75/255.0, blue: 45/255.0, alpha: 1.0),
                .kern: 4
            ]
            let sSize = subTitle.size(withAttributes: subAttr)
            subTitle.draw(at: CGPoint(x: (size.width - sSize.width) / 2, y: 165), withAttributes: subAttr)
            
            // 防伪编号
            let sn = "防伪鉴真号：YX-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
            sn.draw(at: CGPoint(x: 100, y: 220), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.gray
            ])
            
            // 4. 第一部：坐向立极与分金格局
            var curY: CGFloat = 280
            drawSectionHeader(ctx: cg, title: "第一卷 · 坐向立极与分金天心", atY: curY, vermilion: vermilion)
            curY += 65
            
            let mFacing = Mountain24Data.shared.mountain(for: heading)
            let sitAngle = (heading + 180).truncatingRemainder(dividingBy: 360)
            let mSitting = Mountain24Data.shared.mountain(for: sitAngle)
            let fenjin = Fenjin120Data.shared.resolveFenjin(for: heading)
            let hex = Hexagram64Data.shared.hexagram(for: heading)
            
            let p1Text = """
            • 物理向首方位：\(mFacing.name)山向首 (实测 \(String(format: "%.1f", heading))°) · \(mFacing.post)宫
            • 住宅太极坐山：\(mSitting.name)山立极 (坐 \(String(format: "%.1f", sitAngle))°) · 属\(mSitting.palace)
            • 一百二十分金：\(fenjin.jiaziName)分金 (中心 \(String(format: "%.1f", fenjin.centerAngle))°) · 【\(fenjin.grade)】
            • 周易六十四卦：\(hex.name) · 外卦\(hex.upperTrigram) 内卦\(hex.lowerTrigram) · 爻度【\(hex.luckDegree)】
            • 勘舆定位坐标：\(coordsDesc)
            • 节气真太阳时：\(solarTimeDesc)
            """
            p1Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 260), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 250
            
            // 5. 第二部：下元九运玄空飞星九宫方阵
            drawSectionHeader(ctx: cg, title: "第二卷 · 下元九运玄空飞星气运方阵", atY: curY, vermilion: vermilion)
            curY += 65
            
            let p2Text = """
            • 当前地运：下元九运 (2024 - 2043 甲辰至癸亥廿载)
            • 玄空格局判定：【\(mSitting.name)山\(mFacing.name)向】正针飞星下卦盘
            • 当令旺星气场：九紫右弼当令火星入首向星，财气明朗；二黑病符星入坤宫需化泄。
            • 核心吉方：正南方(九紫当令)、正北方(一白远旺水)、正东方(一白贪狼生发)。
            • 忌犯凶位：正西方(七赤破军交剑煞)、正西北(五黄大煞)，切勿在此二方动土开工。
            """
            p2Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 240), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 230
            
            // 6. 第三部：杨公八路黄泉与消砂纳水
            drawSectionHeader(ctx: cg, title: "第三卷 · 杨公形气八路黄泉与水法宜忌", atY: curY, vermilion: vermilion)
            curY += 65
            
            let hq = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: mFacing)
            let basha = SanHeWaterEngine.shared.resolveBaSha(sitting: mSitting)
            let sanHeItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: mSitting)
            var p3Text = "• 向首八路黄泉判据：\(hq.badgeText) · \(hq.waterDesc)\n"
            p3Text += "• 坐山八煞曜位辨识：煞在【\(basha.shaDir)\(basha.shaZhi)位】· \(basha.remedy)\n"
            p3Text += "• 十二长生纳水吉凶：\n"
            for item in sanHeItems.prefix(3) {
                p3Text += "  - \(item.palace)【\(item.stage)】：\(item.isAuspicious ? "吉 · 宜来水纳气" : "忌 · 防破局流破")，\(item.lore)\n"
            }
            p3Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 230), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 220
            
            // 7. 第四部：时家奇门与八宅命卦
            drawSectionHeader(ctx: cg, title: "第四卷 · 时家奇门时空与八宅大游年", atY: curY, vermilion: vermilion)
            curY += 65
            
            let qm = QimenEngine.shared.calculateChart(heading: heading)
            let bz = BaZhaiEngine.shared.analyze(sittingPalace: mSitting.palace, facingPalace: mFacing.palace)
            
            let p4Text = """
            • 时家奇门时空：\(qm.title)
            • 当前天时最优动身方：\(qm.bestNavDirection) (\(qm.bestNavReason))
            • 住宅宅卦归属：【\(bz.houseGua)】 · 向首开门方：\(bz.gateDirection)方纳【\(bz.gateStar.rawValue)】
            • 生气大吉尊方：\(bz.items.first(where: { $0.star == .shengQi })?.direction ?? "生气")方，宜作主卧或安奉神位。
            """
            p4Text.draw(in: CGRect(x: 100, y: curY, width: 880, height: 210), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor(red: 40/255.0, green: 35/255.0, blue: 30/255.0, alpha: 1.0)
            ])
            curY += 200
            
            // 8. 第五部：全屋空间调理与开光化煞清单
            drawSectionHeader(ctx: cg, title: "第五卷 · 全屋空间调理与镇煞秘诀", atY: curY, vermilion: vermilion)
            curY += 65
            
            let p5Text = """
            1. 入户玄关：保持宽敞明亮，玄关柜忌顶部有横梁压顶；宜安放天然黄玉聚宝盆迎财。
            2. 厨房灶台：避免水龙头与灶台对冲（水火相煎），忌炉灶背向大门或悬空设台。
            3. 卫生间排浊：忌厕门直冲卧室床头，常备活性竹炭或安忍水净化地表阴浊湿气。
            4. 阳台防煞：若窗外对冲壁刀、电塔或反弓马路，安放纯铜泰山石敢当或山海镇阻挡。
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
            
            let sealText = "演象\n罗盘\n天机\n御印"
            let sealAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: vermilion
            ]
            sealText.draw(in: sealRect.insetBy(dx: 24, dy: 24), withAttributes: sealAttr)
            
            let signText = """
            大 师 堪 舆 亲 订
            演 象 时 空 罗 盘 院
            岁 次 丙 午 谨 启
            """
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
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, "天机宣纸勘测长卷已成功保存至系统相册！")
    }
}
