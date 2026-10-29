import Foundation

// MARK: - 六十四卦与易经三百八十四爻分金模型

public struct HexagramItem: Identifiable, Codable {
    public let id: Int
    public let name: String           // 卦名 (如: 乾为天、坤为地、水火既济)
    public let upperTrigram: String   // 上卦
    public let lowerTrigram: String   // 下卦
    public let binaryCode: String     // 6位二进制 (1阳0阴)
    public let angleCenter: Double    // 中心度数 (360 / 64 = 5.625°)
    public let elementNumber: Int     // 卦气五行生成数 (一水二火三木四金五土...)
    public let luckDegree: String     // 吉凶分级 (大吉、中吉、平、凶)
    public let fenJinDetail: String   // 穿山透地七十二龙/易经分金描述
    
    public init(id: Int, name: String, upperTrigram: String, lowerTrigram: String, binaryCode: String, angleCenter: Double, elementNumber: Int, luckDegree: String, fenJinDetail: String) {
        self.id = id
        self.name = name
        self.upperTrigram = upperTrigram
        self.lowerTrigram = lowerTrigram
        self.binaryCode = binaryCode
        self.angleCenter = angleCenter
        self.elementNumber = elementNumber
        self.luckDegree = luckDegree
        self.fenJinDetail = fenJinDetail
    }
    public var isGreatAuspicious: Bool { luckDegree == "大吉" }

    public var localizedName: String {
        let language = LocalizationManager.shared.effectiveLanguage
        switch language {
        case .auto, .zhHans:
            return name
        case .zhHant:
            return name
                .replacingOccurrences(of: "剥", with: "剝")
                .replacingOccurrences(of: "风", with: "風")
                .replacingOccurrences(of: "观", with: "觀")
                .replacingOccurrences(of: "晋", with: "晉")
                .replacingOccurrences(of: "泽", with: "澤")
                .replacingOccurrences(of: "谦", with: "謙")
                .replacingOccurrences(of: "渐", with: "漸")
                .replacingOccurrences(of: "过", with: "過")
                .replacingOccurrences(of: "遁", with: "遯")
                .replacingOccurrences(of: "师", with: "師")
                .replacingOccurrences(of: "涣", with: "渙")
                .replacingOccurrences(of: "讼", with: "訟")
                .replacingOccurrences(of: "蛊", with: "蠱")
                .replacingOccurrences(of: "恒", with: "恆")
                .replacingOccurrences(of: "复", with: "復")
                .replacingOccurrences(of: "颐", with: "頤")
                .replacingOccurrences(of: "随", with: "隨")
                .replacingOccurrences(of: "无", with: "無")
                .replacingOccurrences(of: "贲", with: "賁")
                .replacingOccurrences(of: "既济", with: "既濟")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "临", with: "臨")
                .replacingOccurrences(of: "损", with: "損")
                .replacingOccurrences(of: "节", with: "節")
                .replacingOccurrences(of: "归妹", with: "歸妹")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "壮", with: "壯")
        case .ja:
            return name
                .replacingOccurrences(of: "为", with: "為")
                .replacingOccurrences(of: "剥", with: "剥")
                .replacingOccurrences(of: "风", with: "風")
                .replacingOccurrences(of: "观", with: "観")
                .replacingOccurrences(of: "晋", with: "晋")
                .replacingOccurrences(of: "泽", with: "沢")
                .replacingOccurrences(of: "谦", with: "謙")
                .replacingOccurrences(of: "渐", with: "漸")
                .replacingOccurrences(of: "过", with: "過")
                .replacingOccurrences(of: "遁", with: "遯")
                .replacingOccurrences(of: "师", with: "師")
                .replacingOccurrences(of: "涣", with: "渙")
                .replacingOccurrences(of: "讼", with: "訟")
                .replacingOccurrences(of: "蛊", with: "蠱")
                .replacingOccurrences(of: "恒", with: "恒")
                .replacingOccurrences(of: "复", with: "復")
                .replacingOccurrences(of: "颐", with: "頤")
                .replacingOccurrences(of: "随", with: "随")
                .replacingOccurrences(of: "无", with: "無")
                .replacingOccurrences(of: "贲", with: "賁")
                .replacingOccurrences(of: "既济", with: "既済")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "临", with: "臨")
                .replacingOccurrences(of: "损", with: "損")
                .replacingOccurrences(of: "节", with: "節")
                .replacingOccurrences(of: "归妹", with: "帰妹")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "壮", with: "壮")
        case .ko:
            let koMap: [String: String] = [
                "坤为地": "곤위지 (坤為地)", "山地剥": "산지박 (山地剝)", "水地比": "수지비 (水地比)", "风地观": "풍지관 (風地觀)",
                "雷地豫": "뇌지예 (雷地豫)", "火地晋": "화지진 (火地晉)", "泽地萃": "택지췌 (澤地萃)", "天地否": "천지비 (天地否)",
                "地山谦": "지산겸 (地山謙)", "艮为山": "간위산 (艮為山)", "水山蹇": "수산건 (水山蹇)", "风山渐": "풍산점 (風山漸)",
                "雷山小过": "뇌산소과 (雷山小過)", "火山旅": "화산려 (火山旅)", "泽山咸": "택산함 (澤山咸)", "天山遁": "천산둔 (天山遯)",
                "地水师": "지수사 (地水師)", "山水蒙": "산수몽 (山水蒙)", "坎为水": "감위수 (坎為水)", "风水涣": "풍수환 (風水渙)",
                "雷水解": "뇌수해 (雷水解)", "火水未济": "화수미제 (火水未濟)", "泽水困": "택수곤 (澤水困)", "天水讼": "천수송 (天水訟)",
                "地风升": "지풍승 (地風升)", "山风蛊": "산풍고 (山風蠱)", "水风井": "수풍정 (水風井)", "巽为风": "손위풍 (巽為風)",
                "雷风恒": "뇌풍항 (雷風恆)", "火风鼎": "화풍정 (火風鼎)", "泽风大过": "택풍대과 (澤風大過)", "天风姤": "천풍구 (天風姤)",
                "地雷复": "지뢰복 (地雷復)", "山雷颐": "산뢰이 (山雷頤)", "水雷屯": "수뢰둔 (水雷屯)", "风雷益": "풍뢰익 (風雷益)",
                "震为雷": "진위뢰 (震為雷)", "火雷噬嗑": "화뢰서합 (火雷噬嗑)", "泽雷随": "택뢰수 (澤雷隨)", "天雷无妄": "천뢰무망 (天雷無妄)",
                "地火明夷": "지화명이 (地火明夷)", "山火贲": "산화비 (山火賁)", "水火既济": "수화기제 (水火既濟)", "风火家人": "풍화가인 (風火家人)",
                "雷火丰": "뇌화풍 (雷火豐)", "离为火": "이위화 (離為火)", "泽火革": "택화혁 (澤火革)", "天火同人": "천화동인 (天火同人)",
                "地泽临": "지택림 (地澤臨)", "山泽损": "산택손 (山澤損)", "水泽节": "수택절 (水澤節)", "风泽中孚": "풍택중부 (風澤中孚)",
                "雷泽归妹": "뇌택귀매 (雷澤歸妹)", "火泽睽": "화택규 (火澤睽)", "兑为泽": "태위택 (兌為澤)", "天泽履": "천택리 (天澤履)",
                "地天泰": "지천태 (地天泰)", "山天大畜": "산천대축 (山天大畜)", "水天需": "수천수 (水天需)", "风天小畜": "풍천소축 (風天小畜)",
                "雷天大壮": "뇌천대장 (雷天大壯)", "火天大有": "화천대유 (火天大有)", "泽天夬": "택천쾌 (澤天夬)", "乾为天": "건위천 (乾為天)"
            ]
            return koMap[name] ?? name
        case .vi:
            let viMap: [String: String] = [
                "坤为地": "Thuần Khôn", "山地剥": "Sơn Địa Bác", "水地比": "Thủy Địa Tỷ", "风地观": "Phong Địa Quán",
                "雷地豫": "Lôi Địa Dự", "火地晋": "Hỏa Địa Tấn", "泽地萃": "Trạch Địa Tụy", "天地否": "Thiên Địa Bĩ",
                "地山谦": "Địa Sơn Khiêm", "艮为山": "Thuần Cấn", "水山蹇": "Thủy Sơn Kiển", "风山渐": "Phong Sơn Tiệm",
                "雷山小过": "Lôi Sơn Tiểu Quá", "火山旅": "Hỏa Sơn Lữ", "泽山咸": "Trạch Sơn Hàm", "天山遁": "Thiên Sơn Độn",
                "地水师": "Địa Thủy Sư", "山水蒙": "Sơn Thủy Mông", "坎为水": "Thuần Khảm", "风水涣": "Phong Thủy Hoán",
                "雷水解": "Lôi Thủy Giải", "火水未济": "Hỏa Thủy Vị Tế", "泽水困": "Trạch Thủy Khốn", "天水讼": "Thiên Thủy Tụng",
                "地风升": "Địa Phong Thăng", "山风蛊": "Sơn Phong Cổ", "水风井": "Thủy Phong Tỉnh", "巽为风": "Thuần Tốn",
                "雷风恒": "Lôi Phong Hằng", "火风鼎": "Hỏa Phong Đỉnh", "泽风大过": "Trạch Phong Đại Quá", "天风姤": "Thiên Phong Cấu",
                "地雷复": "Địa Lôi Phục", "山雷颐": "Sơn Lôi Di", "水雷屯": "Thủy Lôi Truân", "风雷益": "Phong Lôi Ích",
                "震为雷": "Thuần Chấn", "火雷噬嗑": "Hỏa Lôi Phệ Hạp", "泽雷随": "Trạch Lôi Tùy", "天雷无妄": "Thiên Lôi Vô Vọng",
                "地火明夷": "Địa Hỏa Minh Di", "山火贲": "Sơn Hỏa Bí", "水火既济": "Thủy Hỏa Ký Tế", "风火家人": "Phong Hỏa Gia Nhân",
                "雷火丰": "Lôi Hỏa Phong", "离为火": "Thuần Ly", "泽火革": "Trạch Hỏa Cách", "天火同人": "Thiên Hỏa Đồng Nhân",
                "地泽临": "Địa Trạch Lâm", "山泽损": "Sơn Trạch Tổn", "水泽节": "Thủy Trạch Tiết", "风泽中孚": "Phong Trạch Trung Phu",
                "雷泽归妹": "Lôi Trạch Quy Muội", "火泽睽": "Hỏa Trạch Khuê", "兑为泽": "Thuần Đoài", "天泽履": "Thiên Trạch Lý",
                "地天泰": "Địa Thiên Thái", "山天大畜": "Sơn Thiên Đại Súc", "水天需": "Thủy Thiên Nhu", "风天小畜": "Phong Thiên Tiểu Súc",
                "雷天大壮": "Lôi Thiên Đại Tráng", "火天大有": "Hỏa Thiên Đại Hữu", "泽天夬": "Trạch Thiên Quái", "乾为天": "Thuần Càn"
            ]
            return viMap[name] ?? name
        case .en:
            let enMap: [String: String] = [
                "坤为地": "Kun · Earth", "山地剥": "Bo · Splitting Apart", "水地比": "Bi · Union", "风地观": "Guan · Viewing",
                "雷地豫": "Yu · Enthusiasm", "火地晋": "Jin · Progress", "泽地萃": "Cui · Gathering", "天地否": "Pi · Standstill",
                "地山谦": "Qian · Modesty", "艮为山": "Gen · Mountain", "水山蹇": "Jian · Difficulty", "风山渐": "Jian · Development",
                "雷山小过": "Xiao Guo · Small Excess", "火山旅": "Lv · The Wanderer", "泽山咸": "Xian · Mutual Influence", "天山遁": "Dun · Retreat",
                "地水师": "Shi · The Army", "山水蒙": "Meng · Youthful Folly", "坎为水": "Kan · Water", "风水涣": "Huan · Dispersion",
                "雷水解": "Xie · Deliverance", "火水未济": "Wei Ji · Before Completion", "泽水困": "Kun · Oppression", "天水讼": "Song · Conflict",
                "地风升": "Sheng · Pushing Upward", "山风蛊": "Gu · Decay", "水风井": "Jing · The Well", "巽为风": "Xun · Wind",
                "雷风恒": "Heng · Constancy", "火风鼎": "Ding · The Caldron", "泽风大过": "Da Guo · Great Excess", "天风姤": "Gou · Coming to Meet",
                "地雷复": "Fu · Return", "山雷颐": "Yi · Nourishment", "水雷屯": "Zhun · Initial Difficulty", "风雷益": "Yi · Increase",
                "震为雷": "Zhen · Thunder", "火雷噬嗑": "Shi He · Biting Through", "泽雷随": "Sui · Following", "天雷无妄": "Wu Wang · Innocence",
                "地火明夷": "Ming Yi · Darkening of Light", "山火贲": "Bi · Grace", "水火既济": "Ji Ji · After Completion", "风火家人": "Jia Ren · The Family",
                "雷火丰": "Feng · Abundance", "离为火": "Li · Fire", "泽火革": "Ge · Revolution", "天火同人": "Tong Ren · Fellowship",
                "地泽临": "Lin · Approach", "山泽损": "Sun · Decrease", "水泽节": "Jie · Limitation", "风泽中孚": "Zhong Fu · Inner Truth",
                "雷泽归妹": "Gui Mei · Marrying Maiden", "火泽睽": "Kui · Opposition", "兑为泽": "Dui · Lake", "天泽履": "Lv · Treading",
                "地天泰": "Tai · Peace", "山天大畜": "Da Chu · Great Accumulation", "水天需": "Xu · Waiting", "风天小畜": "Xiao Chu · Small Taming",
                "雷天大壮": "Da Zhuang · Great Power", "火天大有": "Da You · Great Possession", "泽天夬": "Guai · Breakthrough", "乾为天": "Qian · Heaven"
            ]
            return enMap[name] ?? "Hexagram \(id + 1)"
        case .th:
            let thMap: [String: String] = [
                "坤为地": "คุน (ดินล้วน)", "山地剥": "ซานตี้โป (การแตกร้าว)", "水地比": "สุ่ยตี้ปี่ (การรวมพลัง)", "风地观": "เฟิงตี้กวาน (การเพ่งพินิจ)",
                "雷地豫": "เหลยตี้ยวี่ (ความเบิกบาน)", "火地晋": "หั่วตี้จิ้น (ความก้าวหน้า)", "泽地萃": "เจ๋อตี้ชุ่ย (การชุมนุม)", "天地否": "เทียนตี้พี (การติดขัด)",
                "地山谦": "ตี้ซานเชียน (ความถ่อมตน)", "艮为山": "เกิ้น (ภูเขาล้วน)", "水山蹇": "สุ่ยซานเจี่ยน (อุปสรรค)", "风山渐": "เฟิงซานเจี้ยน (ก้าวหน้าช้าๆ)",
                "雷山小过": "เหลยซานเสี่ยวกั้ว (เกินพอดีเล็กน้อย)", "火山旅": "หั่วซานลวี่ (ผู้เดินทาง)", "泽山咸": "เจ๋อซานเสียน (แรงดึงดูดใจ)", "天山遁": "เทียนซานตุ้น (การถอยร่น)",
                "地水师": "ตี้สุ่ยซือ (กองทัพ)", "山水蒙": "ซานสุ่ยเหมิง (ความเยาว์วัย)", "坎为水": "ข่าน (น้ำล้วน)", "风水涣": "เฟิงสุ่ยฮ่วน (การกระจายตัว)",
                "雷水解": "เหลยสุ่ยเซี่ย (การคลี่คลาย)", "火水未济": "หั่วสุ่ยเว่ยจี้ (ยังไม่บรรลุ)", "泽水困": "เจ๋อสุ่ยคุ่น (ความยากลำบาก)", "天水讼": "เทียนสุ่ยซ่ง (การฟ้องร้อง)",
                "地风升": "ตี้เฟิงเซิง (การเลื่อนขั้น)", "山风蛊": "ซานเฟิงกู่ (ความผุพัง)", "水风井": "สุ่ยเฟิงจิ่ง (บ่อน้ำ)", "巽为风": "ซวิ่น (ลมล้วน)",
                "雷风恒": "เหลยเฟิงเหิง (ความมั่นคง)", "火风鼎": "หั่วเฟิงติ่ง (กระถางศักดิ์สิทธิ์)", "泽风大过": "เจ๋อเฟิงต้ากั้ว (เกินพอดีอย่างยิ่ง)", "天风姤": "เทียนเฟิงโก้ว (การพานพบ)",
                "地雷复": "ตี้เหลยฟู่ (การหวนกลับ)", "山雷颐": "ซานเหลยอี๋ (การบำรุง)", "水雷屯": "สุ่ยเหลยถุน (ความลำบากเริ่มต้น)", "风雷益": "เฟิงเหลยอี้ (การเพิ่มพูน)",
                "震为雷": "เจิ้น (ฟ้าร้องล้วน)", "火雷噬嗑": "หั่วเหลยซื่อเค่อ (การขบเคี้ยว)", "泽雷随": "เจ๋อเหลยสุย (การคล้อยตาม)", "天雷无妄": "เทียนเหลยอู๋ว่าง (ความไร้เดียงสา)",
                "地火明夷": "ตี้หั่วหมิงอี๋ (แสงสว่างดับลง)", "山火贲": "ซานหั่วปี้ (ความสง่างาม)", "水火既济": "สุ่ยหั่วจี้จี้ (สำเร็จสมบูรณ์)", "风火家人": "เฟิงหั่วเจียเหริน (ครอบครัว)",
                "雷火丰": "เหลยหั่วเฟิง (ความอุดมสมบูรณ์)", "离为火": "หลี (ไฟล้วน)", "泽火革": "เจ๋อหั่วเก๋อ (การปฏิรูป)", "天火同人": "เทียนหั่วถงเหริน (ภราดรภาพ)",
                "地泽临": "ตี้เจ๋อหลิน (การเข้าใกล้)", "山泽损": "ซานเจ๋อสุ่น (การสูญเสีย)", "水泽节": "สุ่ยเจ๋อเจี๋ย (การควบคุมจำกัด)", "风泽中孚": "เฟิงเจ๋อจงฝู (ความจริงใจภายใน)",
                "雷泽归妹": "เหลยเจ๋อกุยเม่ย (หญิงสาวแต่งงาน)", "火泽睽": "หั่วเจ๋อขุย (ความขัดแย้ง)", "兑为泽": "ตุ้ย (หนองน้ำล้วน)", "天泽履": "เทียนเจ๋อลวี่ (การปฏิบัติตาม)",
                "地天泰": "ตี้เทียนไท่ (ความสงบสุข)", "山天大畜": "ซานเทียนต้าซู่ (การสะสมใหญ่)", "水天需": "สุ่ยเทียนซวี (การรอคอย)", "风天小畜": "เฟิงเทียนเสี่ยวซู่ (การสะสมเล็ก)",
                "雷天大壮": "เหลยเทียนต้าจ้วง (พลังอำนาจยิ่งใหญ่)", "火天大有": "หั่วเทียนต้าโหย่ว (ความมั่งคั่งอันยิ่งใหญ่)", "泽天夬": "เจ๋อเทียนไกว้ (การตัดสินใจเฉียบขาด)", "乾为天": "เฉียน (ฟ้าล้วน)"
            ]
            return thMap[name] ?? name
        case .id:
            let idMap: [String: String] = [
                "坤为地": "Kun · Bumi", "山地剥": "Bo · Pengupasan", "水地比": "Bi · Persatuan", "风地观": "Guan · Memandang",
                "雷地豫": "Yu · Kegembiraan", "火地晋": "Jin · Kemajuan", "泽地萃": "Cui · Berkumpul", "天地否": "Pi · Kemandekan",
                "地山谦": "Qian · Kerendahan Hati", "艮为山": "Gen · Gunung", "水山蹇": "Jian · Rintangan", "风山渐": "Jian · Kemajuan Bertahap",
                "雷山小过": "Xiao Guo · Kelebihan Kecil", "火山旅": "Lv · Pengelana", "泽山咸": "Xian · Daya Tarik", "天山遁": "Dun · Menarik Diri",
                "地水师": "Shi · Pasukan Tentara", "山水蒙": "Meng · Kebodohan Muda", "坎为水": "Kan · Air", "风水涣": "Huan · Pembubaran",
                "雷水解": "Xie · Pembebasan", "火水未济": "Wei Ji · Sebelum Selesai", "泽水困": "Kun · Kesulitan", "天水讼": "Song · Perselisihan",
                "地风升": "Sheng · Naik ke Atas", "山风蛊": "Gu · Pembusukan", "水风井": "Jing · Sumur Air", "巽为风": "Xun · Angin",
                "雷风恒": "Heng · Keteguhan", "火风鼎": "Ding · Kuali Keramat", "泽风大过": "Da Guo · Kelebihan Besar", "天风姤": "Gou · Pertemuan",
                "地雷复": "Fu · Kembali", "山雷颐": "Yi · Menjaga Diri", "水雷屯": "Zhun · Kesulitan Awal", "风雷益": "Yi · Keuntungan",
                "震为雷": "Zhen · Petir", "火雷噬嗑": "Shi He · Menggigit Tuntas", "泽雷随": "Sui · Mengikuti", "天雷无妄": "Wu Wang · Ketulusan",
                "地火明夷": "Ming Yi · Redupnya Cahaya", "山火贲": "Bi · Keanggunan", "水火既济": "Ji Ji · Sesudah Selesai", "风火家人": "Jia Ren · Keluarga",
                "雷火丰": "Feng · Kelimpahan", "离为火": "Li · Api", "泽火革": "Ge · Revolusi", "天火同人": "Tong Ren · Persaudaraan",
                "地泽临": "Lin · Pendekatan", "山泽损": "Sun · Pengurangan", "水泽节": "Jie · Pengendalian", "风泽中孚": "Zhong Fu · Kejujuran Hati",
                "雷泽归妹": "Gui Mei · Menikahkan Gadis", "火泽睽": "Kui · Pertentangan", "兑为泽": "Dui · Danau", "天泽履": "Lv · Melangkah",
                "地天泰": "Tai · Kedamaian", "山天大畜": "Da Chu · Pengumpulan Besar", "水天需": "Xu · Menunggu", "风天小畜": "Xiao Chu · Pengumpulan Kecil",
                "雷天大壮": "Da Zhuang · Kekuatan Besar", "火天大有": "Da You · Kepemilikan Besar", "泽天夬": "Guai · Ketegasan", "乾为天": "Qian · Langit"
            ]
            return idMap[name] ?? name
        default:
            return name
        }
    }

    public var localizedLuckDegree: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .auto, .zhHans:
            return luckDegree
        case .zhHant:
            return luckDegree
        case .en:
            switch luckDegree {
            case "大吉": return "Great Auspicious"
            case "中吉": return "Auspicious"
            case "慎用": return "Use with Care"
            default: return "Neutral"
            }
        case .ja:
            switch luckDegree {
            case "大吉": return "大吉"
            case "中吉": return "中吉"
            case "慎用": return "慎用"
            default: return "平"
            }
        case .ko:
            switch luckDegree {
            case "大吉": return "대길 (大吉)"
            case "中吉": return "중길 (中吉)"
            case "慎用": return "신용 (慎用)"
            default: return "평 (平)"
            }
        case .vi:
            switch luckDegree {
            case "大吉": return "Đại Cát"
            case "中吉": return "Trung Cát"
            case "慎用": return "Thận Dụng"
            default: return "Bình"
            }
        case .th:
            switch luckDegree {
            case "大吉": return "มหามงคล"
            case "中吉": return "มงคลปานกลาง"
            case "慎用": return "ควรระวัง"
            default: return "ปานกลาง"
            }
        case .id:
            switch luckDegree {
            case "大吉": return "Sangat Baik"
            case "中吉": return "Cukup Baik"
            case "慎用": return "Hati-hati"
            default: return "Netral"
            }
        default:
            return luckDegree
        }
    }

    public var localizedUpperTrigram: String {
        localizeTrigram(upperTrigram)
    }

    public var localizedLowerTrigram: String {
        localizeTrigram(lowerTrigram)
    }

    private func localizeTrigram(_ tri: String) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .auto, .zhHans:
            return tri
        case .zhHant:
            return tri.replacingOccurrences(of: "离", with: "離").replacingOccurrences(of: "兑", with: "兌")
        case .ja:
            return ["坤": "坤 (天)", "艮": "艮 (山)", "坎": "坎 (水)", "巽": "巽 (風)", "震": "震 (雷)", "离": "離 (火)", "兑": "兌 (沢)", "乾": "乾 (天)"][tri] ?? tri
        case .ko:
            return ["坤": "곤 (坤)", "艮": "간 (艮)", "坎": "감 (坎)", "巽": "손 (巽)", "震": "진 (震)", "离": "이 (離)", "兑": "태 (兌)", "乾": "건 (乾)"][tri] ?? tri
        case .vi:
            return ["坤": "Khôn", "艮": "Cấn", "坎": "Khảm", "巽": "Tốn", "震": "Chấn", "离": "Ly", "兑": "Đoài", "乾": "Càn"][tri] ?? tri
        case .en:
            return ["坤": "Kun (Earth)", "艮": "Gen (Mountain)", "坎": "Kan (Water)", "巽": "Xun (Wind)", "震": "Zhen (Thunder)", "离": "Li (Fire)", "兑": "Dui (Lake)", "乾": "Qian (Heaven)"][tri] ?? tri
        case .th:
            return ["坤": "คุน (ดิน)", "艮": "เกิ้น (ภูเขา)", "坎": "ข่าน (น้ำ)", "巽": "ซวิ่น (ลม)", "震": "เจิ้น (ฟ้าร้อง)", "离": "หลี (ไฟ)", "兑": "ตุ้ย (หนองน้ำ)", "乾": "เฉียน (ฟ้า)"][tri] ?? tri
        case .id:
            return ["坤": "Kun (Bumi)", "艮": "Gen (Gunung)", "坎": "Kan (Air)", "巽": "Xun (Angin)", "震": "Zhen (Petir)", "离": "Li (Api)", "兑": "Dui (Danau)", "乾": "Qian (Langit)"][tri] ?? tri
        default:
            return tri
        }
    }

    public var localizedFenJinDetail: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .zhHans {
            return fenJinDetail
        }
        if lang == .zhHant {
            return fenJinDetail
                .replacingOccurrences(of: "财", with: "財")
                .replacingOccurrences(of: "两", with: "兩")
                .replacingOccurrences(of: "关", with: "關")
                .replacingOccurrences(of: "显", with: "顯")
                .replacingOccurrences(of: "贵", with: "貴")
                .replacingOccurrences(of: "动", with: "動")
                .replacingOccurrences(of: "稳", with: "穩")
                .replacingOccurrences(of: "展", with: "展")
                .replacingOccurrences(of: "虚", with: "虛")
                .replacingOccurrences(of: "煞", with: "煞")
                .replacingOccurrences(of: "差错", with: "差錯")
                .replacingOccurrences(of: "换", with: "換")
                .replacingOccurrences(of: "解", with: "解")
        }
        switch lang {
        case .en:
            if fenJinDetail.contains("旺相得令") {
                return "Prosperous and in season · Flourishing health and wealth · Pure intake of qi"
            } else if fenJinDetail.contains("合十通关") {
                return "Harmonious combination · Academic and career nobility · Promoting official rank"
            } else if fenJinDetail.contains("平常平和") {
                return "Balanced and calm · Best kept quiet · Steady development"
            } else {
                return "Lone-void sha energy · Void and error line · Requires line transformation remedy"
            }
        case .ja:
            if fenJinDetail.contains("旺相得令") {
                return "旺相得令・人財両旺・純清の気を納める"
            } else if fenJinDetail.contains("合十通关") {
                return "合十通関・文昌顕貴・官位昇進と高貴を促す"
            } else if fenJinDetail.contains("平常平和") {
                return "平常平穏・静を尊び動を避ける・安定した発展"
            } else {
                return "孤虚出煞・空亡差錯・爻変による化解を要す"
            }
        case .ko:
            if fenJinDetail.contains("旺相得令") {
                return "왕상득령 · 인재양왕 · 순청한 기운을 수용함"
            } else if fenJinDetail.contains("合十通关") {
                return "합십통관 · 문창현귀 · 관록과 귀함을 촉진함"
            } else if fenJinDetail.contains("平常平和") {
                return "평상평화 · 정적인 것이 유리 · 안정적인 발전"
            } else {
                return "고허출살 · 공망착오 · 효변을 통한 화해 필요"
            }
        case .vi:
            if fenJinDetail.contains("旺相得令") {
                return "Vượng tướng đắc lệnh · Đinh tài lưỡng vượng · Nạp khí thuần thanh"
            } else if fenJinDetail.contains("合十通关") {
                return "Hợp thập thông quan · Văn xương hiển quý · Thôi quan sinh quý"
            } else if fenJinDetail.contains("平常平和") {
                return "Bình thường bình hòa · Nghi tĩnh bất nghi động · Phát triển ổn định"
            } else {
                return "Cô hư xuất sát · Không vong sai thất · Cần trừu hào hoán tượng hóa giải"
            }
        case .th:
            if fenJinDetail.contains("旺相得令") {
                return "รุ่งเรืองตามฤดูกาล · ทรัพย์และครอบครัวรุ่งเรือง · รับพลังงานบริสุทธิ์"
            } else if fenJinDetail.contains("合十通关") {
                return "รวมสิบประสานพลัง · เจริญก้าวหน้าทางวิชาการและยศศักดิ์"
            } else if fenJinDetail.contains("平常平和") {
                return "ราบเรียบสงบสุข · ควรสงบมากกว่าเคลื่อนไหว · พัฒนาอย่างมั่นคง"
            } else {
                return "พลังโดดเดี่ยวว่างเปล่าปะทะ · ข้อผิดพลาดความว่างเปล่า · ต้องปรับเปลี่ยนเส้นพลังแก้ไข"
            }
        case .id:
            if fenJinDetail.contains("旺相得令") {
                return "Makmur dan beruntung · Keturunan & rezeki melimpah · Energi murni seimbang"
            } else if fenJinDetail.contains("合十通关") {
                return "Harmonis selaras sepuluh · Kejayaan akademis & karir meningkat"
            } else if fenJinDetail.contains("平常平和") {
                return "Biasa dan tenang · Lebih baik diam daripada bergerak · Berkembang stabil"
            } else {
                return "Energi sha terasing · Garis kekosongan keliru · Perlu perbaikan transformasi garis"
            }
        default:
            return fenJinDetail
        }
    }
}

public final class Hexagram64Data {
    public static let shared = Hexagram64Data()
    
    public let hexagrams: [HexagramItem]
    
    private init() {
        // 圆周64卦按先天圆图顺布生成
        let names = [
            "坤为地", "山地剥", "水地比", "风地观", "雷地豫", "火地晋", "泽地萃", "天地否",
            "地山谦", "艮为山", "水山蹇", "风山渐", "雷山小过", "火山旅", "泽山咸", "天山遁",
            "地水师", "山水蒙", "坎为水", "风水涣", "雷水解", "火水未济", "泽水困", "天水讼",
            "地风升", "山风蛊", "水风井", "巽为风", "雷风恒", "火风鼎", "泽风大过", "天风姤",
            "地雷复", "山雷颐", "水雷屯", "风雷益", "震为雷", "火雷噬嗑", "泽雷随", "天雷无妄",
            "地火明夷", "山火贲", "水火既济", "风火家人", "雷火丰", "离为火", "泽火革", "天火同人",
            "地泽临", "山泽损", "水泽节", "风泽中孚", "雷泽归妹", "火泽睽", "兑为泽", "天泽履",
            "地天泰", "山天大畜", "水天需", "风天小畜", "雷天大壮", "火天大有", "泽天夬", "乾为天"
        ]
        
        var list: [HexagramItem] = []
        let step = 360.0 / 64.0 // 5.625°
        
        let trigrams = ["坤", "艮", "坎", "巽", "震", "离", "兑", "乾"]
        for i in 0..<64 {
            let angle = Double(i) * step
            let name = names[i % names.count]
            let luck: String
            let detail: String
            
            // 易经分金吉凶判定：旺相孤虚煞曜
            switch i % 8 {
            case 0, 7:
                luck = "大吉"
                detail = "旺相得令 · 丁财两旺 · 纳气纯清"
            case 1, 3, 5:
                luck = "中吉"
                detail = "合十通关 · 文昌显贵 · 催官生贵"
            case 2:
                luck = "平"
                detail = "平常平和 · 宜静不宜动 · 平稳发展"
            default:
                luck = "慎用"
                detail = "孤虚出煞 · 空亡差错 · 需抽爻换象化解"
            }
            
            let item = HexagramItem(
                id: i,
                name: name,
                upperTrigram: trigrams[i % 8],
                lowerTrigram: trigrams[i / 8],
                binaryCode: String(repeating: "0", count: max(0, 6 - String(i, radix: 2).count)) + String(i, radix: 2),
                angleCenter: angle,
                elementNumber: (i % 9) + 1,
                luckDegree: luck,
                fenJinDetail: detail
            )
            list.append(item)
        }
        self.hexagrams = list
    }
    
    public func hexagram(for angle: Double) -> HexagramItem {
        let norm = (angle.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let step = 360.0 / 64.0
        let idx = Int((norm + step / 2.0) / step) % 64
        return hexagrams[idx]
    }
}
