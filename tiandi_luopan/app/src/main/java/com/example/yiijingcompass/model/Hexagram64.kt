package com.example.yiijingcompass.model

/**
 * 六十四卦与易经三百八十四爻分金模型
 */
data class HexagramItem(
    val id: Int,
    val name: String,           // 卦名 (如: 乾为天、坤为地、水火既济)
    val upperTrigram: String,   // 上卦
    val lowerTrigram: String,   // 下卦
    val binaryCode: String,     // 6位二进制 (1阳0阴)
    val angleCenter: Double,    // 中心度数 (360 / 64 = 5.625°)
    val elementNumber: Int,     // 卦气五行生成数 (一水二火三木四金五土...)
    val luckDegree: String,     // 吉凶分级 (大吉、中吉、平、凶/慎用)
    val fenJinDetail: String    // 穿山透地七十二龙/易经分金描述
) {
    val isGreatAuspicious: Boolean get() = luckDegree == "大吉"

    val localizedName: String
        get() {
            val language = LocalizationManager.instance.effectiveLanguage
            return when (language) {
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> name
                AppLanguage.ZH_HANT -> name
                    .replace("剥", "剝")
                    .replace("风", "風")
                    .replace("观", "觀")
                    .replace("晋", "晉")
                    .replace("泽", "澤")
                    .replace("谦", "謙")
                    .replace("渐", "漸")
                    .replace("过", "過")
                    .replace("遁", "遯")
                    .replace("师", "師")
                    .replace("涣", "渙")
                    .replace("讼", "訟")
                    .replace("蛊", "蠱")
                    .replace("恒", "恆")
                    .replace("复", "復")
                    .replace("颐", "頤")
                    .replace("随", "隨")
                    .replace("无", "無")
                    .replace("贲", "賁")
                    .replace("既济", "既濟")
                    .replace("离", "離")
                    .replace("临", "臨")
                    .replace("损", "損")
                    .replace("节", "節")
                    .replace("归妹", "歸妹")
                    .replace("兑", "兌")
                    .replace("壮", "壯")

                AppLanguage.JA -> name
                    .replace("为", "為")
                    .replace("剥", "剥")
                    .replace("风", "風")
                    .replace("观", "観")
                    .replace("晋", "晋")
                    .replace("泽", "沢")
                    .replace("谦", "謙")
                    .replace("渐", "漸")
                    .replace("过", "過")
                    .replace("遁", "遯")
                    .replace("师", "師")
                    .replace("涣", "渙")
                    .replace("讼", "訟")
                    .replace("蛊", "蠱")
                    .replace("恒", "恒")
                    .replace("复", "復")
                    .replace("颐", "頤")
                    .replace("随", "随")
                    .replace("无", "無")
                    .replace("贲", "賁")
                    .replace("既济", "既済")
                    .replace("离", "離")
                    .replace("临", "臨")
                    .replace("损", "損")
                    .replace("节", "節")
                    .replace("归妹", "帰妹")
                    .replace("兑", "兌")
                    .replace("壮", "壮")

                AppLanguage.KO -> {
                    val koMap = mapOf(
                        "坤为地" to "곤위지 (坤為地)", "山地剥" to "산지박 (山地剝)", "水地比" to "수지비 (水地比)", "风地观" to "풍지관 (風地觀)",
                        "雷地豫" to "뇌지예 (雷地豫)", "火地晋" to "화지진 (火地晉)", "泽地萃" to "택지췌 (澤地萃)", "天地否" to "천지비 (天地否)",
                        "地山谦" to "지산겸 (地山謙)", "艮为山" to "간위산 (艮為山)", "水山蹇" to "수산건 (水山蹇)", "风山渐" to "풍산점 (風山漸)",
                        "雷山小过" to "뇌산소과 (雷山小過)", "火山旅" to "화산려 (火山旅)", "泽山咸" to "택산함 (澤山咸)", "天山遁" to "천산둔 (天山遯)",
                        "地水师" to "지수사 (地水師)", "山水蒙" to "산수몽 (山水蒙)", "坎为水" to "감위수 (坎為水)", "风水涣" to "풍수환 (風水渙)",
                        "雷水解" to "뇌수해 (雷水解)", "火水未济" to "화수미제 (火水未濟)", "泽水困" to "택수곤 (澤水困)", "天水讼" to "천수송 (天水訟)",
                        "地风升" to "지풍승 (地風升)", "山风蛊" to "산풍고 (山風蠱)", "水风井" to "수풍정 (水風井)", "巽为风" to "손위풍 (巽為風)",
                        "雷风恒" to "뇌풍항 (雷風恆)", "火风鼎" to "화풍정 (火風鼎)", "泽风大过" to "택풍대과 (澤風大過)", "天风姤" to "천풍구 (天風姤)",
                        "地雷复" to "지뢰복 (地雷復)", "山雷颐" to "산뢰이 (山雷頤)", "水雷屯" to "수뢰둔 (水雷屯)", "风雷益" to "풍뢰익 (風雷益)",
                        "震为雷" to "진위뢰 (震為雷)", "火雷噬嗑" to "화뢰서합 (火雷噬嗑)", "泽雷随" to "택뢰수 (澤雷隨)", "天雷无妄" to "천뢰무망 (天雷無妄)",
                        "地火明夷" to "지화명이 (地火明夷)", "山火贲" to "산화비 (山火賁)", "水火既济" to "수화기제 (水火既濟)", "风火家人" to "풍화가인 (風火家人)",
                        "雷火丰" to "뇌화풍 (雷火豐)", "离为火" to "이위화 (離為火)", "泽火革" to "택화혁 (澤火革)", "天火同人" to "천화동인 (天火同人)",
                        "地泽临" to "지택림 (地澤臨)", "山泽损" to "산택손 (山澤損)", "水泽节" to "수택절 (水澤節)", "风泽中孚" to "풍택중부 (風澤中孚)",
                        "雷泽归妹" to "뇌택귀매 (雷澤歸妹)", "火泽睽" to "화택규 (火澤睽)", "兑为泽" to "태위택 (兌為澤)", "天泽履" to "천택리 (天澤履)",
                        "地天泰" to "지천태 (地天泰)", "山天大畜" to "산천대축 (山天大畜)", "水天需" to "수천수 (水天需)", "风天小畜" to "풍천소축 (風天小畜)",
                        "雷天大壮" to "뇌천대장 (雷天大壯)", "火天大有" to "화천대유 (火天大有)", "泽天夬" to "택천쾌 (澤天夬)", "乾为天" to "건위천 (乾為天)"
                    )
                    koMap[name] ?: name
                }

                AppLanguage.VI -> {
                    val viMap = mapOf(
                        "坤为地" to "Thuần Khôn", "山地剥" to "Sơn Địa Bác", "水地比" to "Thủy Địa Tỷ", "风地观" to "Phong Địa Quán",
                        "雷地豫" to "Lôi Địa Dự", "火地晋" to "Hỏa Địa Tấn", "泽地萃" to "Trạch Địa Tụy", "天地否" to "Thiên Địa Bĩ",
                        "地山谦" to "Địa Sơn Khiêm", "艮为山" to "Thuần Cấn", "水山蹇" to "Thủy Sơn Kiển", "风山渐" to "Phong Sơn Tiệm",
                        "雷山小过" to "Lôi Sơn Tiểu Quá", "火山旅" to "Hỏa Sơn Lữ", "泽山咸" to "Trạch Sơn Hàm", "天山遁" to "Thiên Sơn Độn",
                        "地水师" to "Địa Thủy Sư", "山水蒙" to "Sơn Thủy Mông", "坎为水" to "Thuần Khảm", "风水涣" to "Phong Thủy Hoán",
                        "雷水解" to "Lôi Thủy Giải", "火水未济" to "Hỏa Thủy Vị Tế", "泽水困" to "Trạch Thủy Khốn", "天水讼" to "Thiên Thủy Tụng",
                        "地风升" to "Địa Phong Thăng", "山风蛊" to "Sơn Phong Cổ", "水风井" to "Thủy Phong Tỉnh", "巽为风" to "Thuần Tốn",
                        "雷风恒" to "Lôi Phong Hằng", "火风鼎" to "Hỏa Phong Đỉnh", "泽风大过" to "Trạch Phong Đại Quá", "天风姤" to "Thiên Phong Cấu",
                        "地雷复" to "Địa Lôi Phục", "山雷颐" to "Sơn Lôi Di", "水雷屯" to "Thủy Lôi Truân", "风雷益" to "Phong Lôi Ích",
                        "震为雷" to "Thuần Chấn", "火雷噬嗑" to "Hỏa Lôi Phệ Hạp", "泽雷随" to "Trạch Lôi Tùy", "天雷无妄" to "Thiên Lôi Vô Vọng",
                        "地火明夷" to "Địa Hỏa Minh Di", "山火贲" to "Sơn Hỏa Bí", "水火既济" to "Thủy Hỏa Ký Tế", "风火家人" to "Phong Hỏa Gia Nhân",
                        "雷火丰" to "Lôi Hỏa Phong", "离为火" to "Thuần Ly", "泽火革" to "Trạch Hỏa Cách", "天火同人" to "Thiên Hỏa Đồng Nhân",
                        "地泽临" to "Địa Trạch Lâm", "山泽损" to "Sơn Trạch Tổn", "水泽节" to "Thủy Trạch Tiết", "风泽中孚" to "Phong Trạch Trung Phu",
                        "雷泽归妹" to "Lôi Trạch Quy Muội", "火泽睽" to "Hỏa Trạch Khuê", "兑为泽" to "Thuần Đoài", "天泽履" to "Thiên Trạch Lý",
                        "地天泰" to "Địa Thiên Thái", "山天大畜" to "Sơn Thiên Đại Súc", "水天需" to "Thủy Thiên Nhu", "风天小畜" to "Phong Thiên Tiểu Súc",
                        "雷天大壮" to "Lôi Thiên Đại Tráng", "火天大有" to "Hỏa Thiên Đại Hữu", "泽天夬" to "Trạch Thiên Quái", "乾为天" to "Thuần Càn"
                    )
                    viMap[name] ?: name
                }

                AppLanguage.EN -> {
                    val enMap = mapOf(
                        "坤为地" to "Kun · Earth", "山地剥" to "Bo · Splitting Apart", "水地比" to "Bi · Union", "风地观" to "Guan · Viewing",
                        "雷地豫" to "Yu · Enthusiasm", "火地晋" to "Jin · Progress", "泽地萃" to "Cui · Gathering", "天地否" to "Pi · Standstill",
                        "地山谦" to "Qian · Modesty", "艮为山" to "Gen · Mountain", "水山蹇" to "Jian · Difficulty", "风山渐" to "Jian · Development",
                        "雷山小过" to "Xiao Guo · Small Excess", "火山旅" to "Lv · The Wanderer", "泽山咸" to "Xian · Mutual Influence", "天山遁" to "Dun · Retreat",
                        "地水师" to "Shi · The Army", "山水蒙" to "Meng · Youthful Folly", "坎为水" to "Kan · Water", "风水涣" to "Huan · Dispersion",
                        "雷水解" to "Xie · Deliverance", "火水未济" to "Wei Ji · Before Completion", "泽水困" to "Kun · Oppression", "天水讼" to "Song · Conflict",
                        "地风升" to "Sheng · Pushing Upward", "山风蛊" to "Gu · Decay", "水风井" to "Jing · The Well", "巽为风" to "Xun · Wind",
                        "雷风恒" to "Heng · Constancy", "火风鼎" to "Ding · The Caldron", "泽风大过" to "Da Guo · Great Excess", "天风姤" to "Gou · Coming to Meet",
                        "地雷复" to "Fu · Return", "山雷颐" to "Yi · Nourishment", "水雷屯" to "Zhun · Initial Difficulty", "风雷益" to "Yi · Increase",
                        "震为雷" to "Zhen · Thunder", "火雷噬嗑" to "Shi He · Biting Through", "泽雷随" to "Sui · Following", "天雷无妄" to "Wu Wang · Innocence",
                        "地火明夷" to "Ming Yi · Darkening of Light", "山火贲" to "Bi · Grace", "水火既济" to "Ji Ji · After Completion", "风火家人" to "Jia Ren · The Family",
                        "雷火丰" to "Feng · Abundance", "离为火" to "Li · Fire", "泽火革" to "Ge · Revolution", "天火同人" to "Tong Ren · Fellowship",
                        "地泽临" to "Lin · Approach", "山泽损" to "Sun · Decrease", "水泽节" to "Jie · Limitation", "风泽中孚" to "Zhong Fu · Inner Truth",
                        "雷泽归妹" to "Gui Mei · Marrying Maiden", "火泽睽" to "Kui · Opposition", "兑为泽" to "Dui · Lake", "天泽履" to "Lv · Treading",
                        "地天泰" to "Tai · Peace", "山天大畜" to "Da Chu · Great Accumulation", "水天需" to "Xu · Waiting", "风天小畜" to "Xiao Chu · Small Taming",
                        "雷天大壮" to "Da Zhuang · Great Power", "火天大有" to "Da You · Great Possession", "泽天夬" to "Guai · Breakthrough", "乾为天" to "Qian · Heaven"
                    )
                    enMap[name] ?: "Hexagram ${id + 1}"
                }

                AppLanguage.TH -> {
                    val thMap = mapOf(
                        "坤为地" to "คุน (ดินล้วน)", "山地剥" to "ซานตี้โป (การแตกร้าว)", "水地比" to "สุ่ยตี้ปี่ (การรวมพลัง)", "风地观" to "เฟิงตี้กวาน (การเพ่งพินิจ)",
                        "雷地豫" to "เหลยตี้ยวี่ (ความเบิกบาน)", "火地晋" to "หั่วตี้จิ้น (ความก้าวหน้า)", "泽地萃" to "เจ๋อตี้ชุ่ย (การชุมนุม)", "天地否" to "เทียนตี้พี (การติดขัด)",
                        "地山谦" to "ตี้ซานเชียน (ความถ่อมตน)", "艮为山" to "เกิ้น (ภูเขาล้วน)", "水山蹇" to "สุ่ยซานเจี่ยน (อุปสรรค)", "风山渐" to "เฟิงซานเจี้ยน (ก้าวหน้าช้าๆ)",
                        "雷山小过" to "เหลยซานเสี่ยวกั้ว (เกินพอดีเล็กน้อย)", "火山旅" to "หั่วซานลวี่ (ผู้เดินทาง)", "泽山咸" to "เจ๋อซานเสียน (แรงดึงดูดใจ)", "天山遁" to "เทียนซานตุ้น (การถอยร่น)",
                        "地水师" to "ตี้สุ่ยซือ (กองทัพ)", "山水蒙" to "ซานสุ่ยเหมิง (ความเยาว์วัย)", "坎为水" to "ข่าน (น้ำล้วน)", "风水涣" to "เฟิงสุ่ยฮ่วน (การกระจายตัว)",
                        "雷水解" to "เหลยสุ่ยเซี่ย (การคลี่คลาย)", "火水未济" to "หั่วสุ่ยเว่ยจี้ (ยังไม่บรรลุ)", "泽水困" to "เจ๋อสุ่ยคุ่น (ความยากลำบาก)", "天水讼" to "เทียนสุ่ยซ่ง (การฟ้องร้อง)",
                        "地风升" to "ตี้เฟิงเซิง (การเลื่อนขั้น)", "山风蛊" to "ซานเฟิงกู่ (ความผุพัง)", "水风井" to "สุ่ยเฟิงจิ่ง (บ่อน้ำ)", "巽为风" to "ซวิ่น (ลมล้วน)",
                        "雷风恒" to "เหลยเฟิงเหิง (ความมั่นคง)", "火风鼎" to "หั่วเฟิงติ่ง (กระถางศักดิ์สิทธิ์)", "泽风大过" to "เจ๋อเฟิงต้ากั้ว (เกินพอดีอย่างยิ่ง)", "天风姤" to "เทียนเฟิงโก้ว (การพานพบ)",
                        "地雷复" to "ตี้เหลยฟู่ (การหวนกลับ)", "山雷颐" to "ซานเหลยอี๋ (การบำรุง)", "水雷屯" to "สุ่ยเหลยถุน (ความลำบากเริ่มต้น)", "风雷益" to "เฟิงเหลยอี้ (การเพิ่มพูน)",
                        "震为雷" to "เจิ้น (ฟ้าร้องล้วน)", "火雷噬嗑" to "หั่วเหลยซื่อเค่อ (การขบเคี้ยว)", "泽雷随" to "เจ๋อเหลยสุย (การคล้อยตาม)", "天雷无妄" to "เทียนเหลยอู๋ว่าง (ความไร้เดียงสา)",
                        "地火明夷" to "ตี้หั่วหมิงอี๋ (แสงสว่างดับลง)", "山火贲" to "ซานหั่วปี้ (ความสง่างาม)", "水火既济" to "สุ่ยหั่วจี้จี้ (สำเร็จสมบูรณ์)", "风火家人" to "เฟิงหั่วเจียเหริน (ครอบครัว)",
                        "雷火丰" to "เหลยหั่วเฟิง (ความอุดมสมบูรณ์)", "离为火" to "หลี (ไฟล้วน)", "泽火革" to "เจ๋อหั่วเก๋อ (การปฏิรูป)", "天火同人" to "เทียนหั่วถงเหริน (ภราดรภาพ)",
                        "地泽临" to "ตี้เจ๋อหลิน (การเข้าใกล้)", "山泽损" to "ซานเจ๋อสุ่น (การสูญเสีย)", "水泽节" to "สุ่ยเจ๋อเจี๋ย (การควบคุมจำกัด)", "风泽中孚" to "เฟิงเจ๋อจงฝู (ความจริงใจภายใน)",
                        "雷泽归妹" to "เหลยเจ๋อกุยเม่ย (หญิงสาวแต่งงาน)", "火泽睽" to "หั่วเจ๋อขุย (ความขัดแย้ง)", "兑为泽" to "ตุ้ย (หนองน้ำล้วน)", "天泽履" to "เทียนเจ๋อลวี่ (การปฏิบัติตาม)",
                        "地天泰" to "ตี้เทียนไท่ (ความสงบสุข)", "山天大畜" to "ซานเทียนต้าซู่ (การสะสมใหญ่)", "水天需" to "สุ่ยเทียนซวี (การรอคอย)", "风天小畜" to "เฟิงเทียนเสี่ยวซู่ (การสะสมเล็ก)",
                        "雷天大壮" to "เหลยเทียนต้าจ้วง (พลังอำนาจยิ่งใหญ่)", "火天大有" to "หั่วเทียนต้าโหย่ว (ความมั่งคั่งอันยิ่งใหญ่)", "泽天夬" to "เจ๋อเทียนไกว้ (การตัดสินใจเฉียบขาด)", "乾为天" to "เฉียน (ฟ้าล้วน)"
                    )
                    thMap[name] ?: name
                }

                AppLanguage.ID -> {
                    val idMap = mapOf(
                        "坤为地" to "Kun · Bumi", "山地剥" to "Bo · Pengupasan", "水地比" to "Bi · Persatuan", "风地观" to "Guan · Memandang",
                        "雷地豫" to "Yu · Kegembiraan", "火地晋" to "Jin · Kemajuan", "泽地萃" to "Cui · Berkumpul", "天地否" to "Pi · Kemandekan",
                        "地山谦" to "Qian · Kerendahan Hati", "艮为山" to "Gen · Gunung", "水山蹇" to "Jian · Rintangan", "风山渐" to "Jian · Kemajuan Bertahap",
                        "雷山小过" to "Xiao Guo · Kelebihan Kecil", "火山旅" to "Lv · Pengelana", "泽山咸" to "Xian · Daya Tarik", "天山遁" to "Dun · Menarik Diri",
                        "地水师" to "Shi · Pasukan Tentara", "山水蒙" to "Meng · Kebodohan Muda", "坎为水" to "Kan · Air", "风水涣" to "Huan · Pembubaran",
                        "雷水解" to "Xie · Pembebasan", "火水未济" to "Wei Ji · Sebelum Selesai", "泽水困" to "Kun · Kesulitan", "天水讼" to "Song · Perselisihan",
                        "地风升" to "Sheng · Naik ke Atas", "山风蛊" to "Gu · Pembusukan", "水风井" to "Jing · Sumur Air", "巽为风" to "Xun · Angin",
                        "雷风恒" to "Heng · Keteguhan", "火风鼎" to "Ding · Kuali Keramat", "泽风大过" to "Da Guo · Kelebihan Besar", "天风姤" to "Gou · Pertemuan",
                        "地雷复" to "Fu · Kembali", "山雷颐" to "Yi · Menjaga Diri", "水雷屯" to "Zhun · Kesulitan Awal", "风雷益" to "Yi · Keuntungan",
                        "震为雷" to "Zhen · Petir", "火雷噬嗑" to "Shi He · Menggigit Tuntas", "泽雷随" to "Sui · Mengikuti", "天雷无妄" to "Wu Wang · Ketulusan",
                        "地火明夷" to "Ming Yi · Redupnya Cahaya", "山火贲" to "Bi · Keanggunan", "水火既济" to "Ji Ji · Sesudah Selesai", "风火家人" to "Jia Ren · Keluarga",
                        "雷火丰" to "Feng · Kelimpahan", "离为火" to "Li · Api", "泽火革" to "Ge · Revolusi", "天火同人" to "Tong Ren · Persaudaraan",
                        "地泽临" to "Lin · Pendekatan", "山泽损" to "Sun · Pengurangan", "水泽节" to "Jie · Pengendalian", "风泽中孚" to "Zhong Fu · Kejujuran Hati",
                        "雷泽归妹" to "Gui Mei · Menikahkan Gadis", "火泽睽" to "Kui · Pertentangan", "兑为泽" to "Dui · Danau", "天泽履" to "Lv · Melangkah",
                        "地天泰" to "Tai · Kedamaian", "山天大畜" to "Da Chu · Pengumpulan Besar", "水天需" to "Xu · Menunggu", "风天小畜" to "Xiao Chu · Pengumpulan Kecil",
                        "雷天大壮" to "Da Zhuang · Kekuatan Besar", "火天大有" to "Da You · Kepemilikan Besar", "泽天夬" to "Guai · Ketegasan", "乾为天" to "Qian · Langit"
                    )
                    idMap[name] ?: name
                }
            }
        }
}

class Hexagram64Data private constructor() {
    companion object {
        val instance: Hexagram64Data by lazy { Hexagram64Data() }
    }

    val hexagrams: List<HexagramItem>

    init {
        val names = listOf(
            "坤为地", "山地剥", "水地比", "风地观", "雷地豫", "火地晋", "泽地萃", "天地否",
            "地山谦", "艮为山", "水山蹇", "风山渐", "雷山小过", "火山旅", "泽山咸", "天山遁",
            "地水师", "山水蒙", "坎为水", "风水涣", "雷水解", "火水未济", "泽水困", "天水讼",
            "地风升", "山风蛊", "水风井", "巽为风", "雷风恒", "火风鼎", "泽风大过", "天风姤",
            "地雷复", "山雷颐", "水雷屯", "风雷益", "震为雷", "火雷噬嗑", "泽雷随", "天雷无妄",
            "地火明夷", "山火贲", "水火既济", "风火家人", "雷火丰", "离为火", "泽火革", "天火同人",
            "地泽临", "山泽损", "水泽节", "风泽中孚", "雷泽归妹", "火泽睽", "兑为泽", "天泽履",
            "地天泰", "山天大畜", "水天需", "风天小畜", "雷天大壮", "火天大有", "泽天夬", "乾为天"
        )
        val trigrams = listOf("坤", "艮", "坎", "巽", "震", "离", "兑", "乾")
        val step = 360.0 / 64.0
        val list = mutableListOf<HexagramItem>()

        for (i in 0 until 64) {
            val angle = i.toDouble() * step
            val name = names[i % names.size]
            val luck: String
            val detail: String

            when (i % 8) {
                0, 7 -> {
                    luck = "大吉"
                    detail = "旺相得令 · 丁财两旺 · 纳气纯清"
                }
                1, 3, 5 -> {
                    luck = "中吉"
                    detail = "合十通关 · 文昌显贵 · 催官生贵"
                }
                2 -> {
                    luck = "平"
                    detail = "平常平和 · 宜静不宜动 · 平稳发展"
                }
                else -> {
                    luck = "慎用"
                    detail = "孤虚出煞 · 空亡差错 · 需抽爻换象化解"
                }
            }

            val binary = i.toString(2).padStart(6, '0')
            list.add(
                HexagramItem(
                    id = i,
                    name = name,
                    upperTrigram = trigrams[i % 8],
                    lowerTrigram = trigrams[i / 8],
                    binaryCode = binary,
                    angleCenter = angle,
                    elementNumber = (i % 9) + 1,
                    luckDegree = luck,
                    fenJinDetail = detail
                )
            )
        }
        hexagrams = list
    }

    fun hexagram(angle: Double): HexagramItem {
        val norm = (angle % 360.0 + 360.0) % 360.0
        val step = 360.0 / 64.0
        val idx = ((norm + step / 2.0) / step).toInt() % 64
        return hexagrams[idx]
    }
}

