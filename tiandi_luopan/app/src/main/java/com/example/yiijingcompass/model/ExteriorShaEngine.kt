package com.example.yiijingcompass.model

enum class ShaSeverity(val rawValue: String, val badgeColorHex: String) {
    CRITICAL("极凶 (大煞破局)", "#ef4444"),
    WARNING("中凶 (损丁耗财)", "#f59e0b"),
    MINOR("轻微 (气场受扰)", "#eab308"),
    NOTICE("吉象 (明堂清秀)", "#10b981");

    val localizedTitle: String
        get() = when (this) {
            CRITICAL -> when (LocalizationManager.shared.effectiveLanguage) {
                AppLanguage.EN -> "Critical (Major Harm)"
                AppLanguage.ZH_HANT, AppLanguage.JA -> "極凶 (大煞破局)"
                AppLanguage.KO -> "극흉 (대살파국)"
                AppLanguage.VI -> "Cực Hung (Đại Sát Phá Cục)"
                AppLanguage.TH -> "ร้ายแรงมาก (เคราะห์ใหญ่ทำลายล้าง)"
                AppLanguage.ID -> "Kritis (Kerusakan Besar)"
                else -> rawValue
            }
            WARNING -> when (LocalizationManager.shared.effectiveLanguage) {
                AppLanguage.EN -> "Warning (Severe Harm)"
                AppLanguage.ZH_HANT, AppLanguage.JA -> "中凶 (損丁耗財)"
                AppLanguage.KO -> "중흉 (손정모재)"
                AppLanguage.VI -> "Trung Hung (Tổn Đinh Hao Tài)"
                AppLanguage.TH -> "ปานกลาง (สูญเสียทรัพย์สินและคน)"
                AppLanguage.ID -> "Peringatan (Kerugian Parah)"
                else -> rawValue
            }
            MINOR -> when (LocalizationManager.shared.effectiveLanguage) {
                AppLanguage.EN -> "Minor (Qi Disturbance)"
                AppLanguage.ZH_HANT, AppLanguage.JA -> "輕微 (氣場受擾)"
                AppLanguage.KO -> "경미 (기장방해)"
                AppLanguage.VI -> "Nhẹ (Khí Trường Bị Nhiễu)"
                AppLanguage.TH -> "เล็กน้อย (รบกวนพลังงานชี่)"
                AppLanguage.ID -> "Ringan (Gangguan Qi)"
                else -> rawValue
            }
            NOTICE -> when (LocalizationManager.shared.effectiveLanguage) {
                AppLanguage.EN -> "Auspicious (Bright Hall Clear)"
                AppLanguage.ZH_HANT, AppLanguage.JA -> "吉象 (明堂清秀)"
                AppLanguage.KO -> "길상 (명당청수)"
                AppLanguage.VI -> "Cát Tượng (Minh Đường Thanh Tú)"
                AppLanguage.TH -> "มงคล (ลานหมิงถังบริสุทธิ์)"
                AppLanguage.ID -> "Menguntungkan (Ming Tang Bersih)"
                else -> rawValue
            }
        }
}

data class ExteriorShaItem(
    val id: String,
    val name: String,              // 形煞名称 (天斩煞、路冲煞、反弓水...)
    val aliases: String,           // 别名/古名
    val visualFeature: String,     // 视觉特征
    val metaphysicsHarm: String,   // 风水危害原理
    val severity: ShaSeverity,     // 严重等级
    val classicalText: String,     // 古籍赋文
    val remedySolution: String     // 大师化解方案与开光法器建议
) {
    val localizedName: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> when (id) {
                "tianzhan" -> "Sky Severing Sha"
                "luchong"  -> "Road Rush Sha"
                "fangong"  -> "Reverse Bow Water"
                "tantou"   -> "Peeking Sha"
                "chuanxin" -> "Heart Piercing Sha"
                "huoxing"  -> "Fire Shape Sha"
                "baihu"    -> "White Tiger Sha"
                "gejiao"   -> "Feet Cutting Sha"
                else -> name
            }
            AppLanguage.ZH_HANT, AppLanguage.JA -> when (id) {
                "tianzhan" -> "天斬煞"
                "luchong"  -> "路衝煞"
                "fangong"  -> "反弓水"
                "tantou"   -> "探頭煞"
                "chuanxin" -> "穿心煞"
                "huoxing"  -> "火形煞"
                "baihu"    -> "白虎煞"
                "gejiao"   -> if (LocalizationManager.shared.effectiveLanguage == AppLanguage.JA) "割脚煞" else "割腳煞"
                else -> name
            }
            AppLanguage.KO -> when (id) {
                "tianzhan" -> "천참살"
                "luchong"  -> "노충살"
                "fangong"  -> "반궁수"
                "tantou"   -> "탐두살"
                "chuanxin" -> "천심살"
                "huoxing"  -> "화형살"
                "baihu"    -> "백호살"
                "gejiao"   -> "할각살"
                else -> name
            }
            AppLanguage.VI -> when (id) {
                "tianzhan" -> "Thiên Trảm Sát"
                "luchong"  -> "Lộ Xung Sát"
                "fangong"  -> "Phản Cung Thủy"
                "tantou"   -> "Thám Đầu Sát"
                "chuanxin" -> "Xuyên Tâm Sát"
                "huoxing"  -> "Hỏa Hình Sát"
                "baihu"    -> "Bạch Hổ Sát"
                "gejiao"   -> "Cát Cước Sát"
                else -> name
            }
            AppLanguage.TH -> when (id) {
                "tianzhan" -> "เคราะห์ผ่าสวรรค์ (เทียนจั่นซา)"
                "luchong"  -> "เคราะห์ทางพุ่งชน (ลู่ชงซา)"
                "fangong"  -> "เคราะห์คันศรย้อนกลับ (ฝ่านกงซา)"
                "tantou"   -> "เคราะห์แอบมอง (ท่านโถวซา)"
                "chuanxin" -> "เคราะห์ทะลวงหัวใจ (ชวนซินซา)"
                "huoxing"  -> "เคราะห์รูปไฟ (หั่วสิงซา)"
                "baihu"    -> "เคราะห์เสือขาว (ไป๋หู่ซา)"
                "gejiao"   -> "เคราะห์ตัดข้อเท้า (เกอเจี่ยวซา)"
                else -> name
            }
            AppLanguage.ID -> when (id) {
                "tianzhan" -> "Sha Pemotong Langit"
                "luchong"  -> "Sha Jalan Menusuk"
                "fangong"  -> "Sha Busur Terbalik"
                "tantou"   -> "Sha Mengintip"
                "chuanxin" -> "Sha Menembus Jantung"
                "huoxing"  -> "Sha Bentuk Api"
                "baihu"    -> "Sha Harimau Putih"
                "gejiao"   -> "Sha Pemotong Kaki"
                else -> name
            }
            else -> name
        }

    val localizedAliases: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> when (id) {
                "tianzhan" -> "Wind Blade Gap · Split House"
                "luchong"  -> "Spear Sha · Arrow Sha"
                "fangong"  -> "Sickle Sha · Curved Knife"
                "tantou"   -> "Peeping Tom Sha · Hidden Observer"
                "chuanxin" -> "Hanging Needle · Hollow Qi"
                "huoxing"  -> "Sharp Angle · Transformer Sha"
                "baihu"    -> "Dominant Right · Tiger Head"
                "gejiao"   -> "Foot Scraper · Rapid Stream"
                else -> aliases
            }
            AppLanguage.ZH_HANT -> when (id) {
                "tianzhan" -> "天塹煞 · 穿心風"
                "luchong"  -> "槍煞 · 箭煞"
                "fangong"  -> "割腳鐮 · 彎刀煞"
                "tantou"   -> "窺視煞 · 偷窺小人"
                "chuanxin" -> "懸針煞 · 地底貫通"
                "huoxing"  -> "尖角煞 · 尖峰衝煞"
                "baihu"    -> "虎強龍弱 · 白虎抬頭"
                "gejiao"   -> "割腳水 · 貼足急流"
                else -> aliases
            }
            AppLanguage.JA -> when (id) {
                "tianzhan" -> "天塹殺・穿心風"
                "luchong"  -> "槍殺・矢殺"
                "fangong"  -> "反弓殺・鎌刀殺"
                "tantou"   -> "覗き見殺・小人殺"
                "chuanxin" -> "懸針殺・貫通風"
                "huoxing"  -> "尖角殺・鋭角衝煞"
                "baihu"    -> "白虎台頭・虎強龍弱"
                "gejiao"   -> "割脚水・貼足急流"
                else -> aliases
            }
            AppLanguage.KO -> when (id) {
                "tianzhan" -> "천참살 · 관심풍"
                "luchong"  -> "창살 · 전살"
                "fangong"  -> "반궁살 · 낫살"
                "tantou"   -> "엿보기살 · 규시살"
                "chuanxin" -> "현침살 · 지하관통살"
                "huoxing"  -> "첨각살 · 화형충살"
                "baihu"    -> "백호대두 · 호강용약"
                "gejiao"   -> "할각수 · 첩족급류"
                else -> aliases
            }
            AppLanguage.VI -> when (id) {
                "tianzhan" -> "Thiên Tiệm Sát · Xuyên Tâm Phong"
                "luchong"  -> "Thương Sát · Tiễn Sát"
                "fangong"  -> "Phản Cung Thủy · Đoản Đao Sát"
                "tantou"   -> "Khuy Thị Sát · Tiểu Nhân Dòm Ngó"
                "chuanxin" -> "Huyền Châm Sát · Địa Đạo Xuyên Tâm"
                "huoxing"  -> "Tiêm Giác Sát · Tiêm Phong Xung"
                "baihu"    -> "Bạch Hổ Ngẩng Đầu · Hổ Vượng Long Suy"
                "gejiao"   -> "Cát Cước Thủy · Cấp Lưu Sát Chân"
                else -> aliases
            }
            AppLanguage.TH -> when (id) {
                "tianzhan" -> "เคราะห์ลมกรีดแทง · อาคารผ่าซีก"
                "luchong"  -> "เคราะห์หอกทิ่มแทง · ศรพิฆาต"
                "fangong"  -> "เคราะห์เคียวกรีด · ธนูตัดโชค"
                "tantou"   -> "เคราะห์แอบมอง · เหลี่ยมเร้นลับ"
                "chuanxin" -> "เคราะห์เข็มเสียบทะลุ · ลมกลวงใต้ดิน"
                "huoxing"  -> "เคราะห์มุมแหลม · สามเหลี่ยมทิ่มแทง"
                "baihu"    -> "เคราะห์ข่มมังกรเขียว · เสือขาวผงาด"
                "gejiao"   -> "เคราะห์น้ำตัดเท้า · กระแสน้ำประชิด"
                else -> aliases
            }
            AppLanguage.ID -> when (id) {
                "tianzhan" -> "Celah Pisau Angin · Rumah Terbelah"
                "luchong"  -> "Sha Tombak · Sha Panah Lurus"
                "fangong"  -> "Sha Sabit · Sha Belati Lengkung"
                "tantou"   -> "Sha Mengintip Tersembunyi"
                "chuanxin" -> "Sha Jarum Menembus Tanah"
                "huoxing"  -> "Sha Sudut Tajam · Sha Menara Segitiga"
                "baihu"    -> "Harimau Putih Menindih Naga Hijau"
                "gejiao"   -> "Air Pemotong Pondasi"
                else -> aliases
            }
            else -> aliases
        }

    val localizedVisualFeature: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> when (id) {
                "tianzhan" -> "Extremely narrow gap between two high-rise buildings directly facing the property."
                "luchong"  -> "A straight road, alley, or corridor pointing directly at the main entrance or window."
                "fangong"  -> "An elevated bridge, highway, or curved road bending outward like an arched bow."
                "tantou"   -> "A roof corner, dome, or structure peering from behind a frontal building."
                "chuanxin" -> "Subway, tunnel, or busy roadway passing directly underneath the building."
                "huoxing"  -> "Sharp roof corners, triangular towers, gas stations, or electrical substations."
                "baihu"    -> "Right-side building is noticeably taller than the left (Azure Dragon) side."
                "gejiao"   -> "High-speed road or turbulent waterway running directly against building foundations."
                else -> visualFeature
            }
            AppLanguage.ZH_HANT -> when (id) {
                "tianzhan" -> "兩棟高樓間隙極度狹窄，如巨斧凌空劈裂，正對向首或坐山。"
                "luchong"  -> "筆直道路或長廊直刺明堂大門、陽台或主臥窗戶，車流直逼。"
                "fangong"  -> "高架橋、河流或弧形道路如拉滿之弓箭，弧頂凸面正對房屋。"
                "tantou"   -> "前方建築物後方隱隱露出一角或圓頂，如有人探首窺視宅內。"
                "chuanxin" -> "樓宇下方有地鐵、隧道、車道貫穿，或正門正對直通後窗。"
                "huoxing"  -> "對面大廈屋角、三角形頂棚、加油站、變電站或紅色尖塔直刺。"
                "baihu"    -> "住宅右側建築物明顯高過左側青龍方，或右側有大型動土施工。"
                "gejiao"   -> "高架橋、貼身快速車道或洶湧急流緊挨樓腳，沒有明堂緩衝地帶。"
                else -> visualFeature
            }
            AppLanguage.JA -> when (id) {
                "tianzhan" -> "二棟の高層ビルの隙間が極端に狭く、斧で空を割ったように正面に対峙する。"
                "luchong"  -> "直線道路や廊下が玄関や窓に槍のように直撃し、交通流が迫る。"
                "fangong"  -> "高架道路や川が引き絞った弓のように曲がり、凸面が住宅に向く。"
                "tantou"   -> "正面の建物の背後から屋根角やドームが頭を覗かせている。"
                "chuanxin" -> "建物の直下を地下鉄、トンネル、車道が貫通している。"
                "huoxing"  -> "建物の鋭角な角、三角形の屋根、変電所や給油所が直面する。"
                "baihu"    -> "右側の建物が左側（青龍側）よりも明らかに高く威圧している。"
                "gejiao"   -> "高速道路や激しい水流が建物の足元に密着し緩衝帯がない。"
                else -> visualFeature
            }
            AppLanguage.KO -> when (id) {
                "tianzhan" -> "두 고층 빌딩 사이의 틈새가 칼날처럼 좁아 주택 정면을 갈라놓듯 마주함."
                "luchong"  -> "곧게 뻗은 도로가 주택의 현관이나 창문을 향해 창처럼 직진함."
                "fangong"  -> "고가도로나 강줄기가 활시위처럼 굽어 볼록한 면이 주택을 겨냥함."
                "tantou"   -> "앞 건물 뒤로 지붕 모서리나 구조물이 머리를 내밀어 엿보는 형상."
                "chuanxin" -> "건물 바로 아래로 지하철, 터널 또는 도로가 관통함."
                "huoxing"  -> "맞은편 건물의 뾰족한 모서리, 삼각 지붕, 주유소, 변전소가 직면함."
                "baihu"    -> "우측 건물(백호방)이 좌측 청룡방보다 월등히 높아 위압함."
                "gejiao"   -> "고속도로나 급류가 건물 밑동에 바짝 붙어 흘러 완충지가 없음."
                else -> visualFeature
            }
            AppLanguage.VI -> when (id) {
                "tianzhan" -> "Khoảng hở giữa hai tòa nhà cao tầng cực hẹp, như lưỡi rìu bổ thẳng vào nhà."
                "luchong"  -> "Con đường thẳng tắp hoặc hành lang dài đâm thẳng vào cửa chính hoặc cửa sổ."
                "fangong"  -> "Cầu vượt, sông ngòi hoặc đường cong uốn lượn quay mặt lồi cung tên về phía nhà."
                "tantou"   -> "Phía sau tòa nhà phía trước nhô lên một góc mái hoặc mái vòm như kẻ thò đầu dòm ngó."
                "chuanxin" -> "Phía dưới tòa nhà có tàu điện ngầm, đường hầm hoặc lòng đường xuyên qua."
                "huoxing"  -> "Góc nhọn mái nhà, tháp nhọn hình tam giác, trạm biến áp hoặc cây xăng chĩa thẳng vào."
                "baihu"    -> "Công trình bên phải nhà cao vượt trội so với bên trái (Thanh Long)."
                "gejiao"   -> "Đường cao tốc hoặc dòng nước chảy xiết sát ngay chân tường tòa nhà."
                else -> visualFeature
            }
            AppLanguage.TH -> when (id) {
                "tianzhan" -> "ช่องแคบระหว่างตึกสูงสองหลังตรงข้าม ผ่าลงมาตรงกับตัวอาคารอย่างรุนแรง"
                "luchong"  -> "ถนนสายตรงหรือทางเดินยาวพุ่งชนประตูใหญ่หรือหน้าต่างโดยตรง"
                "fangong"  -> "ทางด่วน แม่น้ำ หรือถนนโค้งเป็นคันศรหันด้านนูนพุ่งใส่ตัวบ้าน"
                "tantou"   -> "มีมุมหลังคาหรือส่วนยอดของตึกด้านหลังโผล่ขึ้นมาคล้ายมีผู้แอบมอง"
                "chuanxin" -> "ใต้อาคารมีรถไฟใต้ดิน อุโมงค์ หรือถนนลอดผ่านทะลุตัวตึก"
                "huoxing"  -> "มุมตึกแหลมคม หลังคาทรงสามเหลี่ยม ปั๊มน้ำมัน หรือเสาไฟฟ้ายื่นทิ่มแทง"
                "baihu"    -> "อาคารฝั่งขวา (เสือขาว) สูงตระหง่านกว่าฝั่งซ้าย (มังกรเขียว) อย่างเห็นได้ชัด"
                "gejiao"   -> "ทางด่วนหรือสายน้ำเชี่ยวกรากอยู่ประชิดฐานตึกโดยไร้ลานหน้าบ้านรองรับ"
                else -> visualFeature
            }
            AppLanguage.ID -> when (id) {
                "tianzhan" -> "Celah sangat sempit antara dua gedung tinggi yang tepat menghadap ke properti."
                "luchong"  -> "Jalan lurus menusuk langsung ke arah pintu utama atau jendela rumah."
                "fangong"  -> "Jalan layang, sungai, atau jalan melengkung membusur dengan bagian cembung menghadap rumah."
                "tantou"   -> "Sudut atap atau struktur bangunan di belakang bangunan depan tampak seperti mengintip."
                "chuanxin" -> "Gedung dilintasi subway, terowongan, atau jalur kendaraan langsung di bawahnya."
                "huoxing"  -> "Sudut atap tajam, struktur segitiga, SPBU, atau gardu listrik menghadap rumah."
                "baihu"    -> "Bangunan di sebelah kanan jauh lebih tinggi dibanding sisi kiri (Naga Hijau)."
                "gejiao"   -> "Jalan raya berkecepatan tinggi atau aliran air deras langsung menyapu kaki gedung."
                else -> visualFeature
            }
            else -> visualFeature
        }

    val localizedRemedySolution: String
        get() = baseLocalizedRemedySolution + "\n\n" + localizedMetaphysicsHarm

    private val baseLocalizedRemedySolution: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (id) {
                    "tianzhan" -> "① Shield (do first · free): Place a row of tall broad-leaf plants (monstera, money tree) taller than the sill, or add thick sheer curtains, on the window/balcony facing the gap.\n② Block (low cost): If the front door lines up with the gap-facing window, put a half-height cabinet or openwork screen at the entry so the room is not seen straight through.\n③ Anchor (optional): For a stronger remedy, hang a convex bagua mirror or Mountain-Sea mirror facing the gap, tilted down 3-5°, never aimed at a neighbor's windows."
                    "luchong"  -> "① Shield (do first · free): Place a door mat with threshold stone at the door and a curtain inside; put a tall leafy plant on any window facing the road.\n② Block (low cost): Add a half-height hedge or screen outside the entry to create an angled approach.\n③ Anchor (optional): Mount a Mountain-Sea mirror or convex bagua mirror above the entrance tilted slightly down toward the road, never at neighbors."
                    "fangong"  -> "① Shield (do first · free): Keep curtains drawn on the arc-facing windows; arrange a row of green plants on the sill or balcony to soften the visual line.\n② Block (low cost): Install frosted window film up to eye level, or set a screen opposite the window.\n③ Anchor (optional): Hang a Mountain-Sea mirror or pure brass bagua mirror above the window/balcony tilted downward, not reflecting into neighbors."
                    "tantou"   -> "① Shield (do first · free): Close sheer curtains on the side facing the peering peak, or place a leafy plant on the sill to block the direct sight line.\n② Block (low cost): Place a frosted sticker or decorative painting where the peak is seen.\n③ Anchor (optional): Hang a small convex mirror or brass bagua mirror tilted downward toward the structure."
                    "chuanxin" -> "① Shield (do first · free): Place a threshold strip or thick carpet over the main line through the floor to slow draft and ground vibration.\n② Block (low cost): Set a cabinet, screen or bookshelf between the entrance and rear window so qi does not blow straight out.\n③ Anchor (optional): Place heavy natural stone ornaments or ceramic vessels on the floor to steady the home qi."
                    "huoxing"  -> "① Shield (do first · free): Close blinds or thick curtains on windows facing the corner; place potted plants on the sill to block the sharp angle.\n② Block (low cost): Use frosted window film on the exposed glass panes.\n③ Anchor (optional): Hang a convex bagua mirror or brass gourd outside the window angled toward the point."
                    "baihu"    -> "① Shield (do first · free): Enhance the left (Azure Dragon) side by keeping it brightly lit, tidy and active, while keeping the right side calm.\n② Block (low cost): Place tall plants or a tall cabinet on the left wall to visually raise the Dragon side.\n③ Anchor (optional): Place a brass Kylin or Dragon ornament on the left side facing outward to balance momentum."
                    "gejiao"   -> "① Shield (do first · free): Keep lower windows closed and use double-glazed glass with thick drapes to reduce road noise and wind draft.\n② Block (low cost): Arrange dense hedges, potted shrubs, or a solid fence between the road and wall.\n③ Anchor (optional): Place a row of round heavy stones or an earth planter along the base."
                    else -> remedySolution
                }
                AppLanguage.ZH_HANT -> when (id) {
                    "tianzhan" -> "① 擋（先做·免費）：正對樓縫的窗前或陽台，擺一排高過窗台的闊葉綠植（龜背竹、發財樹），或加厚紗簾。\n② 隔（低成本）：若大門與對縫窗成一直線，玄關放半高鞋櫃或鏤空屏風，進門不一眼望穿。\n③ 鎮（可選）：正對縫口掛凸面八卦鏡或山海鎮，鏡面朝外、略下傾3-5度，勿照鄰家門窗。"
                    "luchong"  -> "① 擋（先做·免費）：門口放門檻石或門墊，門內掛門簾；正對路的窗台放一盆高綠植。\n② 隔（低成本）：門外加半高綠籬或屏風，讓進門動線拐個彎。\n③ 鎮（可選）：大門上方掛山海鎮或八卦鏡，朝路方向微下傾，勿照鄰居。"
                    "fangong"  -> "① 擋（先做·免費）：正對弧線的窗戶常拉紗簾，窗台或陽台擺一排綠植以柔化衝勢。\n② 隔（低成本）：貼半高磨砂玻璃膜，或在窗前立屏風。\n③ 鎮（可選）：窗外或陽台上方掛山海鎮或純銅八卦鏡，微下傾，勿照鄰居。"
                    "tantou"   -> "① 擋（先做·免費）：常閉正對窺視峰的紗簾，窗台擺放闊葉盆栽遮蔽視線。\n② 隔（低成本）：在視線所及處貼磨砂貼紙或懸掛字畫。\n③ 鎮（可选）：懸掛凸面八卦鏡或純銅葫蘆微下傾朝向窺視物。"
                    "chuanxin" -> "① 擋（先做·免費）：門口加設門檻條或厚重地毯，減緩穿流氣流與地面震動。\n② 隔（低成本）：玄關與後窗之間設立隔斷櫃、屏風或書架，防穿堂直泄。\n③ 鎮（可選）：地面安放厚重天然石材或陶瓷大甕以穩聚地氣。"
                    "huoxing"  -> "① 擋（先做·免費）：正對尖角窗戶常閉百葉窗，窗台擺放厚葉植物阻擋銳角射線。\n② 隔（低成本）：安裝磨砂玻璃貼膜遮擋尖鋒視線。\n③ 鎮（可選）：窗外懸掛凸面八卦鏡或開光銅葫蘆化洩火煞。"
                    "baihu"    -> "① 擋（先做·免費）：加強左側青龍方照明，保持整潔明亮，右側白虎方宜靜。\n② 隔（低成本）：左側擺放高大綠植或高櫃，視覺上拉高青龍位氣勢。\n③ 鎮（可選）：左側青龍方安放純銅龍形或麒麟法器，面向外側平衡氣場。"
                    "gejiao"   -> "① 擋（先做·免費）：低樓層常閉窗戶，安裝雙層隔音玻璃及厚重窗簾隔絕急流與噪音。\n② 隔（低成本）：外圍種植濃密灌木綠籬，形成緩衝屏障。\n③ 鎮（可選）：沿樓腳安放圓潤天然泰山石或厚重陶瓷花盆穩固根基。"
                    else -> remedySolution
                }
                else -> remedySolution
            }
        }

    val localizedMetaphysicsHarm: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val en = mapOf(
                "tianzhan" to "Wind funnel effect creates a harsh slicing air blade. Traditionally linked to accidental injuries, sudden career obstacles, and blood-pressure or heart strain.",
                "luchong"  to "Direct road trajectory drives fast airflow like a spear piercing the property. Traditionally linked to unexpected financial drains, accidents, and nervous restlessness.",
                "fangong"  to "Centrifugal road traffic drives outward-thrusting energy against the home. Traditionally associated with wealth leakage, legal disputes, and unstable relationships.",
                "tantou"   to "A rooftop peering from behind symbolizes a hidden spy. Traditionally associated with theft, gossip, covert backstabbing, and eye-strain issues.",
                "chuanxin" to "Subterranean tracks or roads destabilize the grounding foundation qi. Traditionally associated with restless occupants, declining vitality, and fleeting wealth.",
                "huoxing"  to "Fire element sharp edges cut across peaceful qi like flames. Traditionally linked to inflammatory illnesses, emotional temper, and sudden family disputes.",
                "baihu"    to "Overbearing right side suppresses the benevolent Azure Dragon qi. Traditionally linked to domestic dominance, unexpected obstacles, and disputes with authoritative figures.",
                "gejiao"   to "Rapid transport directly at building base erodes stable foundation energy. Traditionally linked to inability to accumulate wealth, foot/leg fatigue, and frequent shifts."
            )
            return when (lang) {
                AppLanguage.EN -> en[id] ?: metaphysicsHarm
                else -> metaphysicsHarm
            }
        }

    val localizedClassicalText: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val en = mapOf(
                "tianzhan" to "“Snow Heart Verses”: Two buildings pinch a razor gap, like a giant sword slicing down into the qi.",
                "luchong"  to "“Kanyu Essentials”: A direct rush at the door is hardest to endure, like a hidden arrow striking unseen.",
                "fangong"  to "“Five Geographies Formula”: Reverse bow water curves mercilessly, washing away household prosperity.",
                "tantou"   to "“Shaking Dragon Verses”: A head poking from behind brings petty gossip; even great wealth must guard against scheming.",
                "chuanxin" to "“Qing Nang Classic”: Earth veins fail to condense, dispersing indoor qi into empty poverty.",
                "huoxing"  to "“Doubting Dragon Verses”: Sharp roof corners shoot sparks of fire star, bringing sudden calamity to the door.",
                "baihu"    to "“Water Dragon Classic”: Better let the Azure Dragon rise ten thousand cubits than allow the White Tiger to lift its head half an inch.",
                "gejiao"   to "“Geographic Orthodoxy”: Water rushing tight against the foundation leaves shallow roots unable to withstand the wind."
            )
            val hant = mapOf(
                "tianzhan" to "《雪心賦》云：天斬迎面立，屋裂氣難聚。兩樓夾一罅，形同劍下劈。",
                "luchong"  to "《堪輿指要》云：直衝門前最難當，暗箭傷人人莫詳。",
                "fangong"  to "《地理五訣》云：反弓無情如彎刀，財帛付與急流漂。",
                "tantou"   to "《撼龍經》云：探頭窺面背後起，小人暗中生是非。縱有萬貫財，亦防暗中算。",
                "chuanxin" to "《青囊經》云：地脈不凝，宅氣空騰。穿心走氣，貧困無依。",
                "huoxing"  to "《疑龍經》云：尖角衝克火星飛，災殃臨門人不歸。",
                "baihu"    to "《水龍經》云：寧叫青龍高萬丈，莫教白虎抬半寸。",
                "gejiao"   to "《地理正宗》云：水逼樓腳急，根淺風難立。"
            )
            return when (lang) {
                AppLanguage.EN -> en[id] ?: classicalText
                AppLanguage.ZH_HANT -> hant[id] ?: classicalText
                else -> classicalText
            }
        }
}

class ExteriorShaEngine private constructor() {
    companion object {
        val instance: ExteriorShaEngine by lazy { ExteriorShaEngine() }
        val shared: ExteriorShaEngine get() = instance
    }

    val database: List<ExteriorShaItem> = listOf(
        ExteriorShaItem(
            id = "tianzhan",
            name = "天斩煞",
            aliases = "天堑煞 · 穿心风",
            visualFeature = "两栋高楼间隙极度狭窄，犹如巨斧凌空劈裂，正对向首或坐山",
            metaphysicsHarm = "气流受文丘里效应加速形成高速风刃，主血光之灾、官非破财、心脑血管突发疾厄",
            severity = ShaSeverity.CRITICAL,
            classicalText = "《雪心赋》云：天斩迎面立，屋裂气难聚。两楼夹一罅，形同剑下劈。",
            remedySolution = "① 挡（先做·免费）：正对楼缝的窗前或阳台，摆一排高过窗台的阔叶绿植（龟背竹、发财树），或加厚纱帘。\n② 隔（低成本）：若大门与对缝窗成一直线，玄关放半高鞋柜或镂空屏风，进门不一眼望穿。\n③ 镇（可选）：正对缝口挂凸面八卦镜或山海镇，镜面朝外、略下倾3-5度，勿照邻家门窗。"
        ),
        ExteriorShaItem(
            id = "luchong",
            name = "路冲煞",
            aliases = "枪煞 · 箭煞",
            visualFeature = "笔直道路或长廊直刺明堂大门、阳台或主卧窗户，车流直逼",
            metaphysicsHarm = "一条直路一条枪，车流动能化作无形猛兽直冲宅气，主破耗连连、意外伤灾、人丁不安",
            severity = ShaSeverity.CRITICAL,
            classicalText = "《堪舆指要》云：直冲门前最难当，暗箭伤人人莫详。",
            remedySolution = "① 挡（先做·免费）：门口放门槛石或门垫，门内挂门帘；正对路的窗台放一盆高绿植。\n② 隔（低成本）：门外加半高绿篱或屏风，让进门动线拐个弯。\n③ 镇（可选）：大门上方挂山海镇或八卦镜，朝路方向微下倾，勿照邻居。"
        ),
        ExteriorShaItem(
            id = "fangong",
            name = "反弓煞",
            aliases = "镰刀煞 · 割脚水",
            visualFeature = "高架桥、河流或弧形道路如拉满之弓箭，弧顶凸面正对房屋",
            metaphysicsHarm = "离心力将污浊气流与煞气持续甩向建筑，主财帛难聚、突发官司是非、家宅不安",
            severity = ShaSeverity.CRITICAL,
            classicalText = "《地理五诀》云：反弓无情如弯刀，财帛付与急流漂。",
            remedySolution = "① 挡（先做·免费）：正对反弓凸面的窗户长拉纱帘，窗台或阳台摆一排绿植以柔克刚。\n② 隔（低成本）：贴半高磨砂玻璃膜，或在窗前立屏风。\n③ 镇（可选）：正对反弓顶点的窗台或阳台安放山海镇或纯铜八卦镜，微下倾，勿照邻家。"
        ),
        ExteriorShaItem(
            id = "tantou",
            name = "探头煞",
            aliases = "窥视煞 · 偷窥小人",
            visualFeature = "前方建筑物后方隐隐露出一角或圆顶，如有人探首窥视宅内",
            metaphysicsHarm = "形如盗贼窥视，主宅内频遭小人暗算陷害、财物盗失、家中男女多生异心",
            severity = ShaSeverity.WARNING,
            classicalText = "《撼龙经》云：探头窥面背后起，小人暗中生是非。纵有万贯财，亦防暗中算。",
            remedySolution = "① 挡（先做·免费）：正对窥视建筑的窗前常拉纱帘，窗台摆一盆阔叶植物遮蔽视线。\n② 隔（低成本）：视线正对处贴磨砂贴纸或挂字画，不与探头部直直对视。\n③ 镇（可选）：窗台安放凸面八卦镜或纯铜葫芦微下倾，化解窥探视线。"
        ),
        ExteriorShaItem(
            id = "chuanxin",
            name = "穿心煞",
            aliases = "悬针煞 · 地底贯通",
            visualFeature = "楼宇下方有地铁、地下隧道、车道贯穿，或正门正对直通后窗",
            metaphysicsHarm = "地气被掏空无法聚气，主家运起伏剧烈、财来财去一场空、居者精神萎靡",
            severity = ShaSeverity.WARNING,
            classicalText = "《青囊经》云：地脉不凝，宅气空腾。穿心走气，贫困无依。",
            remedySolution = "① 挡（先做·免费）：大门口加装高门槛条或厚重门垫，减缓气流穿心与震动。\n② 隔（低成本）：玄关与后窗间设隔断柜、屏风或书架，形成S形聚气动线。\n③ 镇（可选）：室内地面或玄关安放重型天然泰山石或陶瓷大坛，稳固地气。"
        ),
        ExteriorShaItem(
            id = "huoxing",
            name = "火形煞",
            aliases = "尖角煞 · 尖峰冲煞",
            visualFeature = "对面大厦屋角、三角形顶棚、加油站、变电站或红色尖塔直刺窗口",
            metaphysicsHarm = "火形燥烈伤金木，主家人性情暴躁、心脑眼目疾厄、官讼是非甚至回禄之灾",
            severity = ShaSeverity.WARNING,
            classicalText = "《疑龙经》云：尖角冲克火星飞，灾殃临门人不归。",
            remedySolution = "① 挡（先做·免费）：正对尖角的窗户长挂百叶窗或厚布帘，窗台摆茂密绿植挡住尖角。\n② 隔（低成本）：安装磨砂贴膜，阻隔尖角直射视线。\n③ 镇（可选）：窗外悬挂凸面八卦镜或开光铜葫芦，以土泄火、以金制煞。"
        ),
        ExteriorShaItem(
            id = "baihu",
            name = "白虎煞",
            aliases = "白虎抬头 · 虎强龙弱",
            visualFeature = "住宅右侧建筑物明显高过左侧青龙方，或右侧有大型动土施工",
            metaphysicsHarm = "白虎猖狂欺主，主女人掌权是非多、男主人事业受压抑、血光官灾",
            severity = ShaSeverity.WARNING,
            classicalText = "《水龙经》云：宁叫青龙高万丈，莫教白虎抬半寸。",
            remedySolution = "① 挡（先做·免费）：加亮左侧青龙方照明，保持左侧整洁有序，右侧宜静不宜动。\n② 隔（低成本）：左侧青龙位摆放高大家具、高绿植，视觉上拉高青龙位气势。\n③ 镇（可选）：左侧青龙方摆放纯铜龙形饰物或麒麟，昂首向外平衡气场。"
        ),
        ExteriorShaItem(
            id = "gejiao",
            name = "割脚煞",
            aliases = "割脚水 · 贴足急流",
            visualFeature = "高架桥、贴身快速车道或汹涌急流紧挨楼脚，没有明堂缓冲地带",
            metaphysicsHarm = "气场受急流飞速带走无法聚财，主财源不稳、根基动摇、下肢疾厄",
            severity = ShaSeverity.MINOR,
            classicalText = "《地理正宗》云：水逼楼脚急，根浅风难立。",
            remedySolution = "① 挡（先做·免费）：低楼层窗户常闭，加装双层中空隔音玻璃与厚窗帘阻隔急流气浪。\n② 隔（低成本）：外围阳台种植浓密灌木或绿篱，形成贴身缓冲屏障。\n③ 镇（可选）：沿楼脚或阳台地面安放厚重天然泰山石或陶瓷花盆，稳固宅基。"
        )
    )

    fun find(id: String): ExteriorShaItem? = database.firstOrNull { it.id == id }

    fun shaItem(id: String): ExteriorShaItem? {
        return database.firstOrNull { it.id == id }
    }
}
