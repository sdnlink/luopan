import Foundation

// MARK: - 八大经典外环境形煞知识库与智能诊断引擎 (Exterior Sha Engine)

public enum ShaSeverity: String, Codable {
    case critical = "极凶 (大煞破局)"
    case warning  = "中凶 (损丁耗财)"
    case minor    = "轻微 (气场受扰)"
    case notice   = "吉象 (明堂清秀)"
    
    public var badgeColorHex: String {
        switch self {
        case .critical: return "#ef4444"
        case .warning:  return "#f59e0b"
        case .minor:    return "#eab308"
        case .notice:   return "#10b981"
        }
    }
    
    public var localizedTitle: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch self {
        case .critical:
            switch lang {
            case .en: return "Critical (Major Harm)"
            case .zhHant, .ja: return "極凶 (大煞破局)"
            case .ko: return "극흉 (대살파국)"
            case .vi: return "Cực Hung (Đại Sát Phá Cục)"
            case .th: return "อัปมงคลยิ่ง (เคราะห์ใหญ่ทำลายล้าง)"
            case .id: return "Sangat Buruk (Bencana Besar)"
            case .auto, .zhHans: return "极凶 (大煞破局)"
            }
        case .warning:
            switch lang {
            case .en: return "Warning (Severe Harm)"
            case .zhHant, .ja: return "中凶 (損丁耗財)"
            case .ko: return "중흉 (손재패가)"
            case .vi: return "Trung Hung (Tổn Đinh Hao Tài)"
            case .th: return "อัปมงคลปานกลาง (สูญเสียทรัพย์และคน)"
            case .id: return "Cukup Buruk (Kerugian Finansial & Keluarga)"
            case .auto, .zhHans: return "中凶 (损丁耗财)"
            }
        case .minor:
            switch lang {
            case .en: return "Minor (Disturbed Qi)"
            case .zhHant: return "輕微 (氣場受擾)"
            case .ja: return "軽微 (気場受乱)"
            case .ko: return "경미 (기장교란)"
            case .vi: return "Khinh Vi (Khí Trường Nhiễu)"
            case .th: return "เล็กน้อย (พลังงานแปรปรวน)"
            case .id: return "Ringan (Gangguan Energi)"
            case .auto, .zhHans: return "轻微 (气场受扰)"
            }
        case .notice:
            switch lang {
            case .en: return "Auspicious (Bright Hall)"
            case .zhHant, .ja: return "吉象 (明堂清秀)"
            case .ko: return "길상 (명당청수)"
            case .vi: return "Cát Tượng (Minh Đường Thanh Tú)"
            case .th: return "มงคล (ลานหน้างดงามบริสุทธิ์)"
            case .id: return "Pertanda Baik (Halaman Cerah & Seimbang)"
            case .auto, .zhHans: return "吉象 (明堂清秀)"
            }
        }
    }
}

public struct ExteriorShaItem: Identifiable, Codable {
    public let id: String
    public let name: String              // 形煞名称 (天斩煞、路冲煞、反弓水...)
    public let aliases: String           // 别名/古名
    public let visualFeature: String     // 视觉特征
    public let metaphysicsHarm: String   // 风水危害原理
    public let severity: ShaSeverity     // 严重等级
    public let classicalText: String     // 古籍赋文
    public let remedySolution: String    // 大师化解方案与开光法器建议
    
    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch id {
            case "tianzhan": return "Sky Severing Sha"
            case "luchong":  return "Road Rush Sha"
            case "fangong":  return "Reverse Bow Water"
            case "tantou":   return "Peeking Sha"
            case "chuanxin": return "Heart Piercing Sha"
            case "huoxing":  return "Fire Shape Sha"
            case "baihu":    return "White Tiger Sha"
            case "gejiao":   return "Feet Cutting Sha"
            default: return name
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "天斬煞"
            case "luchong":  return "路衝煞"
            case "fangong":  return "反弓水"
            case "tantou":   return "探頭煞"
            case "chuanxin": return "穿心煞"
            case "huoxing":  return "火形煞"
            case "baihu":    return "白虎煞"
            case "gejiao":   return "割腳煞"
            default: return name
            }
        case .ja:
            switch id {
            case "tianzhan": return "天斬煞"
            case "luchong":  return "路衝煞"
            case "fangong":  return "反弓水"
            case "tantou":   return "探頭煞"
            case "chuanxin": return "穿心煞"
            case "huoxing":  return "火形煞"
            case "baihu":    return "白虎煞"
            case "gejiao":   return "割脚煞"
            default: return name
            }
        case .ko:
            switch id {
            case "tianzhan": return "천참살"
            case "luchong":  return "노충살"
            case "fangong":  return "반궁수"
            case "tantou":   return "탐두살"
            case "chuanxin": return "천심살"
            case "huoxing":  return "화형살"
            case "baihu":    return "백호살"
            case "gejiao":   return "할각살"
            default: return name
            }
        case .vi:
            switch id {
            case "tianzhan": return "Thiên Trảm Sát"
            case "luchong":  return "Lộ Xung Sát"
            case "fangong":  return "Phản Cung Thủy"
            case "tantou":   return "Thám Đầu Sát"
            case "chuanxin": return "Xuyên Tâm Sát"
            case "huoxing":  return "Hỏa Hình Sát"
            case "baihu":    return "Bạch Hổ Sát"
            case "gejiao":   return "Cát Cước Sát"
            default: return name
            }
        case .th:
            switch id {
            case "tianzhan": return "เคราะห์ผ่าสวรรค์ (เทียนจั่นซา)"
            case "luchong":  return "เคราะห์ทางพุ่งชน (ลู่ชงซา)"
            case "fangong":  return "เคราะห์คันศรย้อนกลับ (ฝ่านกงซา)"
            case "tantou":   return "เคราะห์แอบมอง (ท่านโถวซา)"
            case "chuanxin": return "เคราะห์ทะลวงหัวใจ (ชวนซินซา)"
            case "huoxing":  return "เคราะห์รูปไฟ (หั่วสิงซา)"
            case "baihu":    return "เคราะห์เสือขาว (ไป๋หู่ซา)"
            case "gejiao":   return "เคราะห์ตัดข้อเท้า (เกอเจี่ยวซา)"
            default: return name
            }
        case .id:
            switch id {
            case "tianzhan": return "Sha Pemotong Langit"
            case "luchong":  return "Sha Jalan Menusuk"
            case "fangong":  return "Sha Busur Terbalik"
            case "tantou":   return "Sha Mengintip"
            case "chuanxin": return "Sha Menembus Jantung"
            case "huoxing":  return "Sha Bentuk Api"
            case "baihu":    return "Sha Harimau Putih"
            case "gejiao":   return "Sha Pemotong Kaki"
            default: return name
            }
        case .auto, .zhHans:
            return name
        }
    }
    
    public var localizedAliases: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch id {
            case "tianzhan": return "Wind Blade Gap · Split House"
            case "luchong":  return "Spear Sha · Arrow Sha"
            case "fangong":  return "Sickle Sha · Curved Knife"
            case "tantou":   return "Peeping Tom Sha · Hidden Observer"
            case "chuanxin": return "Hanging Needle · Hollow Qi"
            case "huoxing":  return "Sharp Angle · Transformer Sha"
            case "baihu":    return "Dominant Right · Tiger Head"
            case "gejiao":   return "Foot Scraper · Rapid Stream"
            default: return aliases
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "天塹煞 · 穿心風"
            case "luchong":  return "槍煞 · 箭煞"
            case "fangong":  return "割腳鐮 · 彎刀煞"
            case "tantou":   return "窺視煞 · 偷窺小人"
            case "chuanxin": return "懸針煞 · 地底貫通"
            case "huoxing":  return "尖角煞 · 尖峰衝煞"
            case "baihu":    return "虎強龍弱 · 白虎抬頭"
            case "gejiao":   return "割腳水 · 貼足急流"
            default: return aliases
            }
        case .ja:
            switch id {
            case "tianzhan": return "天塹殺・穿心風"
            case "luchong":  return "槍殺・矢殺"
            case "fangong":  return "反弓殺・鎌刀殺"
            case "tantou":   return "覗き見殺・小人殺"
            case "chuanxin": return "懸針殺・貫通風"
            case "huoxing":  return "尖角殺・鋭角衝煞"
            case "baihu":    return "白虎台頭・虎強龍弱"
            case "gejiao":   return "割脚水・貼足急流"
            default: return aliases
            }
        case .ko:
            switch id {
            case "tianzhan": return "천참살 · 관심풍"
            case "luchong":  return "창살 · 전살"
            case "fangong":  return "반궁살 · 낫살"
            case "tantou":   return "엿보기살 · 규시살"
            case "chuanxin": return "현침살 · 지하관통살"
            case "huoxing":  return "첨각살 · 화형충살"
            case "baihu":    return "백호대두 · 호강용약"
            case "gejiao":   return "할각수 · 첩족급류"
            default: return aliases
            }
        case .vi:
            switch id {
            case "tianzhan": return "Thiên Tiệm Sát · Xuyên Tâm Phong"
            case "luchong":  return "Thương Sát · Tiễn Sát"
            case "fangong":  return "Phản Cung Thủy · Đoản Đao Sát"
            case "tantou":   return "Khuy Thị Sát · Tiểu Nhân Dòm Ngó"
            case "chuanxin": return "Huyền Châm Sát · Địa Đạo Xuyên Tâm"
            case "huoxing":  return "Tiêm Giác Sát · Tiêm Phong Xung"
            case "baihu":    return "Bạch Hổ Ngẩng Đầu · Hổ Vượng Long Suy"
            case "gejiao":   return "Cát Cước Thủy · Cấp Lưu Sát Chân"
            default: return aliases
            }
        case .th:
            switch id {
            case "tianzhan": return "เคราะห์ลมกรีดแทง · อาคารผ่าซีก"
            case "luchong":  return "เคราะห์หอกทิ่มแทง · ศรพิฆาต"
            case "fangong":  return "เคราะห์เคียวกรีด · ธนูตัดโชค"
            case "tantou":   return "เคราะห์แอบมอง · เหลี่ยมเร้นลับ"
            case "chuanxin": return "เคราะห์เข็มเสียบทะลุ · ลมกลวงใต้ดิน"
            case "huoxing":  return "เคราะห์มุมแหลม · สามเหลี่ยมทิ่มแทง"
            case "baihu":    return "เคราะห์ข่มมังกรเขียว · เสือขาวผงาด"
            case "gejiao":   return "เคราะห์น้ำตัดเท้า · กระแสน้ำประชิด"
            default: return aliases
            }
        case .id:
            switch id {
            case "tianzhan": return "Celah Pisau Angin · Rumah Terbelah"
            case "luchong":  return "Sha Tombak · Sha Panah Lurus"
            case "fangong":  return "Sha Sabit · Sha Belati Lengkung"
            case "tantou":   return "Sha Mengintip Tersembunyi"
            case "chuanxin": return "Sha Jarum Menembus Tanah"
            case "huoxing":  return "Sha Sudut Tajam · Sha Menara Segitiga"
            case "baihu":    return "Harimau Putih Menindih Naga Hijau"
            case "gejiao":   return "Air Pemotong Pondasi"
            default: return aliases
            }
        case .auto, .zhHans:
            return aliases
        }
    }
    
    public var localizedVisualFeature: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch id {
            case "tianzhan": return "Extremely narrow gap between two high-rise buildings directly facing the property."
            case "luchong":  return "A straight road, alley, or corridor pointing directly at the main entrance or window."
            case "fangong":  return "An elevated bridge, highway, or curved road bending outward like an arched bow."
            case "tantou":   return "A roof corner, dome, or structure peering from behind a frontal building."
            case "chuanxin": return "Subway, tunnel, or busy roadway passing directly underneath the building."
            case "huoxing":  return "Sharp roof corners, triangular towers, gas stations, or electrical substations."
            case "baihu":    return "Right-side building is noticeably taller than the left (Azure Dragon) side."
            case "gejiao":   return "High-speed road or turbulent waterway running directly against building foundations."
            default: return visualFeature
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "兩棟高樓間隙極度狹窄，如巨斧凌空劈裂，正對向首或坐山。"
            case "luchong": return "筆直道路或長廊直刺明堂大門、陽台或主臥窗戶，車流直逼。"
            case "fangong": return "高架橋、河流或弧形道路如拉滿之弓箭，弧頂凸面正對房屋。"
            case "tantou": return "前方建築物後方隱隱露出一角或圓頂，如有人探首窺視宅內。"
            case "chuanxin": return "樓宇下方有地鐵、隧道、車道貫穿，或正門正對直通後窗。"
            case "huoxing": return "對面大廈屋角、三角形頂棚、加油站、變電站或紅色尖塔直刺。"
            case "baihu": return "住宅右側建築物明顯高過左側青龍方，或右側有大型動土施工。"
            case "gejiao": return "高架橋、貼身快速車道或洶湧急流緊挨樓腳，沒有明堂緩衝地帶。"
            default: return visualFeature
            }
        case .ja:
            switch id {
            case "tianzhan": return "二棟の高層ビルの隙間が極端に狭く、斧で空を割ったように正面に対峙する。"
            case "luchong":  return "直線道路や廊下が玄関や窓に槍のように直撃し、交通流が迫る。"
            case "fangong":  return "高架道路や川が引き絞った弓のように曲がり、凸面が住宅に向く。"
            case "tantou":   return "正面の建物の背後から屋根角やドームが頭を覗かせている。"
            case "chuanxin": return "建物の直下を地下鉄、トンネル、車道が貫通している。"
            case "huoxing":  return "建物の鋭角な角、三角形の屋根、変電所や給油所が直面する。"
            case "baihu":    return "右側の建物が左側（青龍側）よりも明らかに高く威圧している。"
            case "gejiao":   return "高速道路や激しい水流が建物の足元に密着し緩衝帯がない。"
            default: return visualFeature
            }
        case .ko:
            switch id {
            case "tianzhan": return "두 고층 빌딩 사이의 틈새가 칼날처럼 좁아 주택 정면을 갈라놓듯 마주함."
            case "luchong":  return "곧게 뻗은 도로가 주택의 현관이나 창문을 향해 창처럼 직진함."
            case "fangong":  return "고가도로나 강줄기가 활시위처럼 굽어 볼록한 면이 주택을 겨냥함."
            case "tantou":   return "앞 건물 뒤로 지붕 모서리나 구조물이 머리를 내밀어 엿보는 형상."
            case "chuanxin": return "건물 바로 아래로 지하철, 터널 또는 도로가 관통함."
            case "huoxing":  return "맞은편 건물의 뾰족한 모서리, 삼각 지붕, 주유소, 변전소가 직면함."
            case "baihu":    return "우측 건물(백호방)이 좌측 청룡방보다 월등히 높아 위압함."
            case "gejiao":   return "고속도로나 급류가 건물 밑동에 바짝 붙어 흘러 완충지가 없음."
            default: return visualFeature
            }
        case .vi:
            switch id {
            case "tianzhan": return "Khoảng hở giữa hai tòa nhà cao tầng cực hẹp, như lưỡi rìu bổ thẳng vào nhà."
            case "luchong":  return "Con đường thẳng tắp hoặc hành lang dài đâm thẳng vào cửa chính hoặc cửa sổ."
            case "fangong":  return "Cầu vượt, sông ngòi hoặc đường cong uốn lượn quay mặt lồi cung tên về phía nhà."
            case "tantou":   return "Phía sau tòa nhà phía trước nhô lên một góc mái hoặc mái vòm như kẻ thò đầu dòm ngó."
            case "chuanxin": return "Phía dưới tòa nhà có tàu điện ngầm, đường hầm hoặc lòng đường xuyên qua."
            case "huoxing":  return "Góc nhọn mái nhà, tháp nhọn hình tam giác, trạm biến áp hoặc cây xăng chĩa thẳng vào."
            case "baihu":    return "Công trình bên phải nhà cao vượt trội so với bên trái (Thanh Long)."
            case "gejiao":   return "Đường cao tốc hoặc dòng nước chảy xiết sát ngay chân tường tòa nhà."
            default: return visualFeature
            }
        case .th:
            switch id {
            case "tianzhan": return "ช่องแคบระหว่างตึกสูงสองหลังตรงข้าม ผ่าลงมาตรงกับตัวอาคารอย่างรุนแรง"
            case "luchong":  return "ถนนสายตรงหรือทางเดินยาวพุ่งชนประตูใหญ่หรือหน้าต่างโดยตรง"
            case "fangong":  return "ทางด่วน แม่น้ำ หรือถนนโค้งเป็นคันศรหันด้านนูนพุ่งใส่ตัวบ้าน"
            case "tantou":   return "มีมุมหลังคาหรือส่วนยอดของตึกด้านหลังโผล่ขึ้นมาคล้ายมีผู้แอบมอง"
            case "chuanxin": return "ใต้อาคารมีรถไฟใต้ดิน อุโมงค์ หรือถนนลอดผ่านทะลุตัวตึก"
            case "huoxing":  return "มุมตึกแหลมคม หลังคาทรงสามเหลี่ยม ปั๊มน้ำมัน หรือเสาไฟฟ้ายื่นทิ่มแทง"
            case "baihu":    return "อาคารฝั่งขวา (เสือขาว) สูงตระหง่านกว่าฝั่งซ้าย (มังกรเขียว) อย่างเห็นได้ชัด"
            case "gejiao":   return "ทางด่วนหรือสายน้ำเชี่ยวกรากอยู่ประชิดฐานตึกโดยไร้ลานหน้าบ้านรองรับ"
            default: return visualFeature
            }
        case .id:
            switch id {
            case "tianzhan": return "Celah sangat sempit antara dua gedung tinggi yang tepat menghadap ke properti."
            case "luchong":  return "Jalan lurus menusuk langsung ke arah pintu utama atau jendela rumah."
            case "fangong":  return "Jalan layang, sungai, atau jalan melengkung membusur dengan bagian cembung menghadap rumah."
            case "tantou":   return "Sudut atap atau struktur bangunan di belakang bangunan depan tampak seperti mengintip."
            case "chuanxin": return "Gedung dilintasi subway, terowongan, atau jalur kendaraan langsung di bawahnya."
            case "huoxing":  return "Sudut atap tajam, struktur segitiga, SPBU, atau gardu listrik menghadap rumah."
            case "baihu":    return "Bangunan di sebelah kanan jauh lebih tinggi dibanding sisi kiri (Naga Hijau)."
            case "gejiao":   return "Jalan raya berkecepatan tinggi atau aliran air deras langsung menyapu kaki gedung."
            default: return visualFeature
            }
        case .auto, .zhHans:
            return visualFeature
        }
    }
    
    public var localizedRemedySolution: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch id {
            case "tianzhan": return "1. Hang an authentic Mountain-Sea Mirror or convex Bagua mirror;\n2. Plant broad-leaved evergreen plants on the balcony as a wind buffer;\n3. Install an opaque porch screen to break direct incoming wind."
            case "luchong":  return "1. Place a Taishan Stone Shi Gandang monument at the entrance;\n2. Design a winding entryway to slow and harmonize incoming qi flow;\n3. Position a pair of consecrated pure brass Qilin facing the road."
            case "fangong":  return "1. Position an Obsidian Dragon Turtle facing outward;\n2. Place curved lush greenery along window ledges as an energetic buffer;\n3. Hang Five Emperor Coins with Vajra pestle indoors."
            case "tantou":   return "1. Hang a convex brass Bagua mirror to reflect peering energy;\n2. Place a pure brass rooster facing the corner to dispel stealth disturbance;\n3. Keep translucent venetian blinds closed during daylight."
            case "chuanxin": return "1. Lay yellow jade Seven-Star array on the floor to ground Earth qi;\n2. Install a sunken solid brass threshold at the entrance;\n3. Place a heavy solid-wood cabinet at the foyer to retain qi."
            case "huoxing":  return "1. Place natural white quartz crystal sphere or obsidian array to counter Fire;\n2. Hang two strings of Six Emperor brass coins near the window;\n3. Integrate ocean blue decorative textiles to balance Five Elements."
            case "baihu":    return "1. Place a consecrated pure brass Dragon holding a pearl on the left side;\n2. Position a heavy green jade Taishan stone on the right to subdue the Tiger;\n3. Increase lighting intensity and tall furniture placement on the left."
            case "gejiao":   return "1. Build tall planter boxes and shrubs on the balcony as a buffer;\n2. Place a pair of brass Pixiu facing the waterway to guard wealth;\n3. Install thick soundproofing laminated Low-E double glazing."
            default: return remedySolution
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "1. 懸掛正品開光純銅山海鎮或九宮八卦凸鏡；\n2. 陽台密植闊葉盆栽形成擋風屏障；\n3. 玄關設山水屏風阻隔直衝煞氣。"
            case "luchong": return "1. 門前安置泰山石敢當；\n2. 設曲折玄關使直氣轉緩；\n3. 窗內安放開光麒麟朝向路衝。"
            case "fangong": return "1. 擺放黑曜石八卦龍龜；\n2. 窗台以弧形綠植緩衝；\n3. 室內懸掛五帝錢金剛杵。"
            case "tantou": return "1. 掛凸面銅八卦鏡反彈窺視；\n2. 擺放昂首純銅公雞；\n3. 白天關閉百葉窗簾。"
            case "chuanxin": return "1. 地面鋪黃玉七星陣聚土氣；\n2. 大門設真銅門檻；\n3. 玄關擺厚重實木櫃藏風聚氣。"
            case "huoxing": return "1. 安放白水晶球或黑曜石陣；\n2. 窗邊懸掛六帝古錢；\n3. 以藍色水波紋織物調和五行。"
            case "baihu": return "1. 左側擺純銅祥龍吐珠；\n2. 右方白虎位安置青玉泰山石；\n3. 增強左側燈光與家具高度。"
            case "gejiao": return "1. 陽台築高盆花壇與灌木；\n2. 向急流方供放銅貔貅；\n3. 安裝厚質隔音 Low-E 玻璃。"
            default: return remedySolution
            }
        case .ja:
            switch id {
            case "tianzhan": return "1. 純銅の山海鎮または凸面八卦鏡を設置する；\n2. ベランダに広葉樹の観葉植物を密に配置して風を遮る；\n3. 玄関に間仕切りスクリーンを置いて直射風を和らげる。"
            case "luchong":  return "1. 玄関前に泰山石敢当を配置する；\n2. 玄関を屈折構造にして気の流れを緩やかにする；\n3. 道路に向かって開光麒麟の置物を一対配置する。"
            case "fangong":  return "1. 外側に向けて黒曜石の龍亀を置く；\n2. 窓辺に緑の観葉植物を半円状に配置して緩衝する；\n3. 室内に五帝銭を吊るす。"
            case "tantou":   return "1. 凸面銅八卦鏡で視線エネルギーを反射する；\n2. 銅製の雄鶏の置物を角に向けて配置する；\n3. 日中はブラインドカーテンを下ろしておく。"
            case "chuanxin": return "1. 床に黄玉七星陣を配置して地の気を安定させる；\n2. 玄関に真鍮製敷居を設置する；\n3. 重厚な木製キャビネットを置いて気を留める。"
            case "huoxing":  return "1. 天然白水晶球または黒曜石を置いて火気を鎮める；\n2. 窓辺に六帝銭を吊るす；\n3. 青色系の布製品を取り入れて五行の調和を図る。"
            case "baihu":    return "1. 左側（青龍側）に真鍮製の龍の置物を配置する；\n2. 右側（白虎側）に重量感のある石を配置して鎮める；\n3. 左側の照明を明るくし背の高い家具を配置する。"
            case "gejiao":   return "1. ベランダに背の高いプランターや低木を配置する；\n2. 急流に向けて銅製貔貅を一対配置する；\n3. 遮音性の高い二重サッシガラスを設置する。"
            default: return remedySolution
            }
        case .ko:
            switch id {
            case "tianzhan": return "1. 산해진 또는 볼록 팔괘경 설치;\n2. 발코니에 넓은 잎 식물을 빽빽이 배치하여 방풍벽 형성;\n3. 현관에 파티션을 두어 강한 바람 완화."
            case "luchong":  return "1. 출입구에 태산석감당 설치;\n2. 굴절형 현관을 조성하여 직진하는 기운 완화;\n3. 도로를 향해 기린상 한 쌍 배치."
            case "fangong":  return "1. 바깥을 향해 흑요석 용귀 배치;\n2. 창가에 반원형 화분을 두어 완충작용 조성;\n3. 실내에 오제전 걸기."
            case "tantou":   return "1. 볼록 팔괘경으로 시선 반사;\n2. 구리 닭 조형물을 모서리를 향해 배치;\n3. 주간에는 블라인드를 내려 시선 차단."
            case "chuanxin": return "1. 바닥에 황옥 칠성진을 두어 지기 안정화;\n2. 현관에 황동 문턱 설치;\n3. 묵직한 원목 수납장 배치로 기운 보존."
            case "huoxing":  return "1. 백수정구나 흑요석을 배치하여 화기 제어;\n2. 창가에 육제전 걸기;\n3. 푸른색 계열 패브릭으로 오행 조화 도모."
            case "baihu":    return "1. 좌측 청룡방에 황동 용 조형물 배치;\n2. 우측 백호방에 무거운 태산석을 놓아 진압;\n3. 좌측 조명을 밝히고 높은 가구 배치."
            case "gejiao":   return "1. 발코니에 키 큰 화단과 관목 배치;\n2. 급류를 향해 황동 비휴 한 쌍 배치;\n3. 차음 성능이 우수한 복층 유리 설치."
            default: return remedySolution
            }
        case .vi:
            switch id {
            case "tianzhan": return "1. Treo Sơn Hải Trấn hoặc gương Bát Quái lồi bằng đồng;\n2. Đặt chậu cây lá rộng ở ban công tạo tấm chắn gió;\n3. Bố trí bình phong ở huyền quan để cản luồng khí xung trực diện."
            case "luchong":  return "1. Đặt đá Thái Sơn Thạch Cảm Đương trước cửa;\n2. Thiết kế huyền quan uốn lượn để giảm tốc luồng khí xộc thẳng;\n3. Đặt một đôi Kỳ Lân bằng đồng quay đầu hướng ra đường."
            case "fangong":  return "1. Đặt Long Quy thạch anh đen quay đầu hướng ra ngoài;\n2. Xếp hàng cây xanh dạng vòng cung trên bậu cửa sổ;\n3. Treo chuỗi tiền Ngũ Đế gia hộ trong nhà."
            case "tantou":   return "1. Treo gương Bát Quái lồi bằng đồng phản xạ ánh nhìn;\n2. Đặt tượng Gà trống bằng đồng hướng về góc nhọn;\n3. Thường xuyên kéo rèm lá sách vào ban ngày."
            case "chuanxin": return "1. Rải thất tinh trận hoàng ngọc để tụ địa khí;\n2. Làm ngạch cửa bằng đồng thau kiên cố;\n3. Đặt tủ gỗ nặng ở huyền quan để giữ khí."
            case "huoxing":  return "1. Đặt quả cầu thạch anh trắng hoặc thạch anh đen giải trừ hỏa khí;\n2. Treo hai chuỗi tiền Lục Đế cạnh cửa sổ;\n3. Bổ sung vật dụng màu xanh lam để cân bằng Ngũ Hành."
            case "baihu":    return "1. Đặt tượng Rồng ngậm ngọc bằng đồng bên Thanh Long (trái);\n2. Đặt đá phong thủy trấn áp bên Bạch Hổ (phải);\n3. Tăng cường ánh sáng và bố trí kệ tủ cao bên trái."
            case "gejiao":   return "1. Trồng bồn cây cao và cây bụi ở ban công làm đệm cản;\n2. Đặt một đôi Tỳ Hưu bằng đồng hướng về dòng nước chảy xiết;\n3. Dùng cửa kính cách âm dày Low-E hai lớp."
            default: return remedySolution
            }
        case .th:
            switch id {
            case "tianzhan": return "1. แขวนกระจกซานไห่เจิ้นหรือกระจกนูนแปดทิศทองเหลือง;\n2. ปลูกไม้ใบกว้างริมระเบียงเป็นแนวกั้นลม;\n3. ตั้งฉากกั้นบริเวณโถงทางเข้าชะลอแรงลมปะทะ"
            case "luchong":  return "1. วางหินไท่ซานกันตังหน้าทางเข้า;\n2. ออกแบบโถงทางเข้าให้คดเคี้ยวเพื่อชะลอกระแสชี่;\n3. ตั้งกิเลนทองเหลืองคู่หันหน้าสู่ทิศทางถนนพุ่งชน"
            case "fangong":  return "1. วางเต่ามังกรหินออบซิเดียนหันหน้าออกด้านนอก;\n2. จัดวางไม้กระถางโค้งตามขอบหน้าต่างเป็นกันชน;\n3. แขวนเหรียญห้าจักรพรรดิคุ้มครองภายในห้อง"
            case "tantou":   return "1. แขวนกระจกนูนแปดทิศสะท้อนพลังแอบมอง;\n2. ตั้งไก่ทองเหลืองหันไปทางมุมตึกแหลม;\n3. ปิดมู่ลี่กรองแสงในเวลากลางวัน"
            case "chuanxin": return "1. วางค่ายเจ็ดดาวหินหยกเหลืองเพื่อดูดซับพลังดิน;\n2. ติดตั้งธรณีประตูทองเหลืองแท้ที่ทางเข้า;\n3. วางตู้ไม้เนื้อแข็งที่โถงทางเข้าเพื่อกักเก็บพลังชี่"
            case "huoxing":  return "1. วางลูกแก้วควอตซ์ขาวหรือหินออบซิเดียนสยบธาตุไฟ;\n2. แขวนเหรียญหกจักรพรรดิริมหน้าต่าง;\n3. ใช้ของตกแต่งโทนสีน้ำเงินครามเพื่อปรับสมดุลธาตุทั้งห้า"
            case "baihu":    return "1. วางมังกรทองเหลืองคาบแก้วทางฝั่งซ้าย (มังกรเขียว);\n2. วางหินไท่ซานหยกเขียวกดทับฝั่งขวา (เสือขาว);\n3. เพิ่มความสว่างและจัดวางเฟอร์นิเจอร์ทรงสูงไว้ฝั่งซ้าย"
            case "gejiao":   return "1. จัดสวนกระถางทรงสูงและไม้พุ่มริมระเบียงเป็นกันชน;\n2. วางปี่เซียะทองเหลืองคู่หันรับกระแสน้ำเพื่อเรียกทรัพย์;\n3. ติดตั้งหน้าต่างกระจกสองชั้น Low-E ป้องกันเสียงรบกวน"
            default: return remedySolution
            }
        case .id:
            switch id {
            case "tianzhan": return "1. Gantung cermin Shan Hai Zhen atau cermin cembung Bagua kuningan;\n2. Tanam tanaman berdaun lebar di balkon sebagai penahan angin;\n3. Pasang penyekat di teras masuk untuk memecah angin kencang."
            case "luchong":  return "1. Letakkan batu Taishan Shi Gandang di pintu masuk;\n2. Rancang lorong masuk berliku untuk memperlambat aliran qi;\n3. Posisikan sepasang Qilin kuningan menghadap ke arah jalan."
            case "fangong":  return "1. Tempatkan Kura-kura Naga Obsidian menghadap ke luar;\n2. Susun tanaman hijau melengkung di tepi jendela sebagai penyangga energi;\n3. Gantung Koin Lima Kaisar di dalam ruangan."
            case "tantou":   return "1. Gantung cermin cembung Bagua untuk memantulkan energi intipan;\n2. Pasang patung ayam jago kuningan menghadap sudut tajam;\n3. Tutup tirai venetian pada siang hari."
            case "chuanxin": return "1. Letakkan formasi Tujuh Bintang giok kuning di lantai untuk menstabilkan qi bumi;\n2. Pasang ambang pintu kuningan kokoh di pintu masuk;\n3. Tempatkan lemari kayu solid di ruang depan untuk menahan qi."
            case "huoxing":  return "1. Letakkan bola kristal kuarsa putih atau obsidian untuk meredam api;\n2. Gantung dua untai Koin Enam Kaisar di dekat jendela;\n3. Gunakan kain bernuansa biru laut untuk menyeimbangkan Lima Elemen."
            case "baihu":    return "1. Letakkan patung Naga kuningan memegang mutiara di sisi kiri (Naga Hijau);\n2. Letakkan batu Taishan berat di sisi kanan untuk menundukkan Harimau;\n3. Tingkatkan pencahayaan dan tata perabot tinggi di sisi kiri."
            case "gejiao":   return "1. Buat kotak tanaman tinggi dan semak di balkon sebagai penyangga;\n2. Tempatkan sepasang Pixiu kuningan menghadap aliran air untuk menjaga rezeki;\n3. Pasang jendela kaca ganda Low-E kedap suara."
            default: return remedySolution
            }
        case .auto, .zhHans:
            return remedySolution
        }
    }

    /// Localized explanation shown in the AR result card.
    public var localizedMetaphysicsHarm: String {
        guard LocalizationManager.shared.effectiveLanguage != .zhHans else { return metaphysicsHarm }
        let en: [String: String] = [
            "tianzhan": "Venturi acceleration turns the gap into a high-speed wind blade, associated with accidents, disputes, financial loss and sudden cardiovascular strain.",
            "luchong": "A straight road behaves like a spear: traffic momentum rushes into the home, bringing repeated loss, accidents and family unrest.",
            "fangong": "Centrifugal force pulls wealth and support outward, creating an unfeeling collision associated with rebellion, major loss and litigation.",
            "tantou": "A hidden gaze invites back-room trouble, theft, deceit, secret affairs and sudden damage to reputation.",
            "chuanxin": "Unstable ground qi leaks rapidly, weakening wealth retention, digestion and the occupants' sense of security.",
            "huoxing": "Fire clashes with Metal, bringing arguments, legal trouble, eye and skin complaints, and an irritable temper.",
            "baihu": "A weakened Azure Dragon and dominant White Tiger can suppress yang energy, authority and the family's progress.",
            "gejiao": "Fast moving qi strips the foundation, causing volatile finances, a weak base and a tendency for later decline."
        ]
        let hant: [String: String] = [
            "tianzhan": "氣流受文丘裏效應加速形成高速風刃，主血光之災、官非破財及心腦血管突發疾厄。",
            "luchong": "直路如槍，車流動能直衝宅氣，主破耗連連、意外傷災及人丁不安。",
            "fangong": "離心力將財氣與貴人運向外甩離，形成無情衝撞，主子孫叛逆、破大財及官訟纏身。",
            "tantou": "暗中窺測，主招引暗室小人、盜竊欺詐、婚外暗昧或突發名譽受損。",
            "chuanxin": "地氣空洞不穩定，洩氣極速，主財氣不聚、脾胃虛寒及居者缺乏安全感。",
            "huoxing": "火金相克、火燥生煞，主口舌官非、視力疾厄、皮膚炎腫及脾氣暴躁。",
            "baihu": "青龍委靡、白虎張狂，主陰盛陽衰、男丁運勢受壓抑阻滯。",
            "gejiao": "氣流疾走拔除地氣，財運大起大落、根基虛浮，青年得志而晚運易傾頹。"
        ]
        let ja: [String: String] = [
            "tianzhan": "ベンチュリ効果により気流が風の刃となり、血光の災い、財の損失、循環器系の急患を招くとされます。",
            "luchong": "直線道路が槍のように直撃し、車流のエネルギーが宅気を乱して散財や事故、不和を招きます。",
            "fangong": "遠心力によって財気や貴人の運気が振り落とされ、大きな損失や訴訟沙汰を招きます。",
            "tantou": "隠れた覗き見の気が小人を引き寄せ、盗難や詐欺、名誉毀損などの暗雲を招きます。",
            "chuanxin": "地下の空洞により地気が不安定で漏れやすく、財の散逸や消化器の不調、不安感を生じさせます。",
            "huoxing": "火と金が相克し、口論や法的トラブル、視力低下や皮膚炎、短気をもたらします。",
            "baihu": "青龍が衰え白虎が盛んになり、陰盛陽衰、男性の運勢が抑圧され停滞します。",
            "gejiao": "激しい気流が建物の根底を削り、財運の乱高下や基礎の不安定さを招きます。"
        ]
        let ko: [String: String] = [
            "tianzhan": "좁은 틈새로 가속된 바람이 칼날처럼 내리쳐 혈광지재, 관재파재, 심혈관 질환을 유발함.",
            "luchong": "직선 도로는 창과 같아 차량의 에너지가 택기를 직격하여 연이은 손실과 사고를 부름.",
            "fangong": "원심력으로 재물운과 귀인운이 밖으로 튕겨나가 가족 간 불화와 큰 파재, 소송을 야기함.",
            "tantou": "은밀한 엿보기가 소인배, 도난, 사기, 불륜 및 갑작스러운 명예 훼손을 초래함.",
            "chuanxin": "지기가 허공으로 빠져나가 재물이 모이지 않고 위장 질환과 불안감을 조성함.",
            "huoxing": "화극금의 기운으로 구설수, 관재, 시력 및 피부 질환, 조급한 성격을 유발함.",
            "baihu": "청룡이 쇠하고 백호가 득세하여 음성양쇠, 남성의 운세가 억압되고 정체됨.",
            "gejiao": "급류가 지기를 쓸어가 재운이 불안정해지고 기초가 흔들려 말년운이 쇠락하기 쉬움."
        ]
        let vi: [String: String] = [
            "tianzhan": "Luồng khí bị nén qua khe hẹp tạo thành lưỡi dao gió, chủ tai họa huyết quang, phá tài kiện tụng và bệnh tim mạch.",
            "luchong": "Đường thẳng tựa ngọn giáo, động năng xe cộ đâm thẳng làm tổn hại sinh khí, chủ hao tài, tai nạn và gia đạo bất an.",
            "fangong": "Lực ly tâm hất văng tài khí và quý nhân, tạo xung đột vô tình, chủ con cháu bất phục, hao tổn tài sản lớn.",
            "tantou": "Ngấm ngầm nhòm ngó, chủ dẫn dụ tiểu nhân ám hại, trộm cắp lừa gạt hoặc tổn hại thanh danh.",
            "chuanxin": "Địa khí rỗng tuếch không tụ, thoát khí cực nhanh, chủ khó tích tụ tài lộc, tỳ vị hư hàn và thiếu an tâm.",
            "huoxing": "Hỏa Kim tương khắc, hỏa táo sinh sát khí, chủ thị phi khẩu thiệt, bệnh về mắt da và tính tình nóng nảy.",
            "baihu": "Thanh Long suy vi, Bạch Hổ hoành hành, chủ âm thịnh dương suy, vận thế nam nhân bị áp chế trắc trở.",
            "gejiao": "Dòng khí chảy xiết bứng mất địa khí, tài vận thăng trầm thất thường, căn cơ suy kiệt, hậu vận bất lợi."
        ]
        let th: [String: String] = [
            "tianzhan": "กระแสลมบีบอัดผ่านซอกตึกกลายเป็นใบมีดลม ส่งผลให้เกิดอุบัติเหตุ เสียทรัพย์ และปัญหาสุขภาพหัวใจฉับพลัน",
            "luchong": "ถนนสายตรงดั่งหอกพุ่งชน แรงจราจรปะทะชี่บ้าน นำมาซึ่งความสูญเสียซ้ำซ้อนและครอบครัวไร้ความสงบ",
            "fangong": "แรงเหวี่ยงหนีศูนย์พัดพาโชคลาภและผู้อุปถัมภ์หลุดลอย ส่งผลให้ลูกหลานดื้อรั้น เสียทรัพย์ก้อนโต และมีคดีความ",
            "tantou": "การแอบมองในเงามืด ดึงดูดคนพาล การลักขโมย คดีความหลอกลวง และเสื่อมเสียชื่อเสียงอย่างไม่คาดคิด",
            "chuanxin": "ชี่ใต้ดินกลวงและไม่มั่นคง รั่วไหลอย่างรวดเร็ว ส่งผลให้เก็บเงินไม่อยู่ ระบบย่อยอาหารอ่อนแอ และขาดความมั่นคง",
            "huoxing": "ธาตุไฟพิฆาตธาตุทอง ก่อให้เกิดการทะเลาะวิวาท ปัญหาทางกฎหมาย โรคตาและผิวหนัง รวมทั้งอารมณ์ฉุนเฉียว",
            "baihu": "มังกรเขียวอ่อนแรง เสือขาวมีอำนาจ ส่งผลให้หยินข่มหยาง บารมีผู้นำครอบครัวถูกกดขี่และติดขัด",
            "gejiao": "กระแสลมและสายน้ำเชี่ยวกรากพัดพาชี่พื้นดินไป โชคลาภผันผวน รากฐานไม่มั่นคง และช่วงบั้นปลายชีวิตถดถอย"
        ]
        let indo: [String: String] = [
            "tianzhan": "Akselerasi Venturi mengubah celah menjadi bilah angin kencang, memicu kecelakaan, sengketa, kerugian finansial, dan serangan kardiovaskular mendadak.",
            "luchong": "Jalan lurus bagaikan tombak: arus kendaraan menyerang qi rumah, membawa kerugian berulang, kecelakaan, dan keresahan keluarga.",
            "fangong": "Gaya sentrifugal membuang rezeki dan dukungan luar, memicu pembangkangan anak cucu, kerugian besar, dan masalah hukum.",
            "tantou": "Pandangan tersembunyi mengundang intrik orang licik, pencurian, penipuan, dan pencemaran nama baik secara mendadak.",
            "chuanxin": "Qi tanah berongga dan bocor cepat, melemahkan penumpukan kekayaan, pencernaan, dan rasa aman penghuni.",
            "huoxing": "Api berbenturan dengan Logam, memicu pertengkaran, masalah hukum, keluhan mata dan kulit, serta emosi meledak-ledak.",
            "baihu": "Naga Hijau melemah dan Harimau Putih mendominasi, menekan energi yang, otoritas, dan kemajuan pria dalam rumah tangga.",
            "gejiao": "Aliran cepat mengikis fondasi tanah, menyebabkan keuangan bergejolak, dasar lemah, dan penurunan di masa tua."
        ]
        let langCode = LocalizationManager.shared.effectiveLanguage
        switch langCode {
        case .zhHant: return hant[id] ?? metaphysicsHarm
        case .ja: return ja[id] ?? en[id] ?? metaphysicsHarm
        case .ko: return ko[id] ?? en[id] ?? metaphysicsHarm
        case .vi: return vi[id] ?? en[id] ?? metaphysicsHarm
        case .th: return th[id] ?? en[id] ?? metaphysicsHarm
        case .id: return indo[id] ?? en[id] ?? metaphysicsHarm
        case .auto, .zhHans, .en: return en[id] ?? metaphysicsHarm
        }
    }

    public var localizedClassicalText: String {
        guard LocalizationManager.shared.effectiveLanguage != .zhHans else { return classicalText }
        let en: [String: String] = [
            "tianzhan": "The Snow Heart Ode says: A sky-cleaving gap before the house splits the qi; two towers leave a cleft like a sword descending.",
            "luchong": "The Essentials of Form says: A direct road before the gate is hardest to withstand; a hidden arrow wounds without warning.",
            "fangong": "The Five Geographic Secrets says: An unfeeling reverse-bow stream cuts like a curved blade; wealth follows the water away.",
            "tantou": "The Dragon Classic says: A lowered head peering from behind stirs hidden trouble; even great wealth must guard against secret schemes.",
            "chuanxin": "The Green Satchel Classic says: When the earth vein is not gathered, house qi rises and escapes through the heart, leaving poverty and insecurity.",
            "huoxing": "The Doubting Dragon Classic says: A sharp corner strikes like a flying fire star; calamity reaches the door and people fail to return.",
            "baihu": "The Water Dragon Classic says: Let the Azure Dragon rise ten thousand yards; never let the White Tiger lift its head even half an inch.",
            "gejiao": "The Orthodox Geography says: When water presses urgently at the building's feet, shallow roots cannot stand against the wind."
        ]
        let hant: [String: String] = [
            "tianzhan": "《雪心賦》云：天斬迎面立，屋裂氣難聚。兩樓夾一罅，形同劍下劈。",
            "luchong": "《堪輿指要》云：直衝門前最難當，暗箭傷人人莫詳。",
            "fangong": "《地理五訣》云：反弓無情水，猶如彎刀割。居者難安泰，錢財隨水折。",
            "tantou": "《撼龍經》云：頭低窺視探，小人暗中亂。縱有萬貫財，亦防暗中算。",
            "chuanxin": "《青囊經》云：地脈不凝，宅氣空騰。穿心走氣，貧困無依。",
            "huoxing": "《疑龍經》云：尖角衝克火星飛，災殃臨門人不歸。",
            "baihu": "《水龍經》云：寧叫青龍高萬丈，莫教白虎昂半寸。",
            "gejiao": "《地理正宗》云：水逼樓腳急，根淺風難立。"
        ]
        let ja: [String: String] = [
            "tianzhan": "『雪心賦』に云う：天斬迎面にして立ち、屋裂けて気集まり難し。両楼一罅を挟み、形は剣の下劈に同じ。",
            "luchong": "『堪輿指要』に云う：門前への直衝は最も当り難く、暗箭の人を傷つけるや人詳らかならず。",
            "fangong": "『地理五訣』に云う：反弓は無情の水、猶お湾刀の割くがごとし。銭財水に従いて折る。",
            "tantou": "『撼竜経』に云う：頭を低くして窺い視探り、小人暗中に乱す。縦い万貫の財有るも、暗中の算を防ぐべし。",
            "chuanxin": "『青嚢経』に云う：地脈凝らず、宅気空騰す。穿心して気を走らせ、貧困にして依る無し。",
            "huoxing": "『疑竜経』に云う：尖角衝克して火星飛び、災殃門に臨みて人帰らず。",
            "baihu": "『水竜経』に云う：寧ろ青龍を高き万丈に叫ばしむとも、白虎をして半寸も昂らしむるなかれ。",
            "gejiao": "『地理正宗』に云う：水は楼脚に逼りて急なり、根浅く風立ち難し。"
        ]
        let ko: [String: String] = [
            "tianzhan": "《설심부》: 천참이 면전에 서면 집이 갈라져 기가 모이지 못한다. 두 건물의 틈새는 칼날이 내려치는 것과 같다.",
            "luchong": "《감여지요》: 대문 앞 곧은 도로는 막기 어려우니, 암살의 화살처럼 사람을 해친다.",
            "fangong": "《지리오결》: 반궁수는 무정한 물이라 굽은 칼날과 같으니 재물이 물길 따라 흩어진다.",
            "tantou": "《감룡경》: 머리를 숙여 엿보는 형상은 소인이 암투를 벌임이니, 만관의 재물이 있어도 음모를 경계하라.",
            "chuanxin": "《청낭경》: 지맥이 뭉치지 못하면 택기가 공중으로 날아가니 심장을 뚫고 기가 새어나가 빈곤을 부른다.",
            "huoxing": "《의룡경》: 뾰족한 모서리가 충극하여 화성이 날아드니 재앙이 문에 닥쳐 사람이 돌아오지 못한다.",
            "baihu": "《수룡경》: 차라리 청룡이 만 장 높을지언정 백호는 반 치도 고개를 들게 하지 말라.",
            "gejiao": "《지리정종》: 물길이 건물 밑동을 급하게 압박하니 뿌리가 얕아 바람을 견디기 어렵다."
        ]
        let vi: [String: String] = [
            "tianzhan": "«Tuyết Tâm Phú» vân: Thiên trảm nghênh diện lập, ốc liệt khí nan tụ. Lưỡng lâu hiệp nhất há, hình đồng kiếm hạ phách.",
            "luchong": "«Khám Dư Chỉ Yếu» vân: Trực xung môn tiền tối nan đương, ám tiễn thương nhân nhân mạc tường.",
            "fangong": "«Địa Lý Ngũ Quyết» vân: Phản cung vô tình thủy, do như loan đao cát. Tiền tài tùy thủy chiết.",
            "tantou": "«Hám Long Kinh» vân: Đầu đê khuy thị thám, tiểu nhân ám trung loạn. Tung hữu vạn quán tài, diệc phòng ám trung toán.",
            "chuanxin": "«Thanh Nang Kinh» vân: Địa mạch bất ngưng, trạch khí không đằng. Xuyên tâm tẩu khí, bần khốn vô y.",
            "huoxing": "«Nghi Long Kinh» vân: Tiêm giác xung khắc hỏa tinh phi, tai ương lâm môn nhân bất quy.",
            "baihu": "«Thủy Long Kinh» vân: Ninh khiếu Thanh Long cao vạn trượng, mạc giáo Bạch Hổ ngẩng bán thốn.",
            "gejiao": "«Địa Lý Chính Tông» vân: Thủy bức lâu cước cấp, căn thiển phong nan lập."
        ]
        let th: [String: String] = [
            "tianzhan": "คัมภีร์เสวี่ยซินกล่าวว่า: สวรรค์ผ่าประชิดหน้า ชี่บ้านแตกรวมตัวยาก สองตึกประกบดั่งดาบฟันลงมา",
            "luchong": "คัมภีร์คั่นอวี๋กล่าวว่า: ทางพุ่งชนหน้าประตูยากต้านทาน ดั่งศรลอบทำร้ายไร้สุ้มเสียง",
            "fangong": "คัมภีร์ภูมิศาสตร์ห้าเคล็ดกล่าวว่า: คันศรย้อนกลับดั่งมีดกรีดเฉือน ทรัพย์สินไหลไปตามกระแสน้ำ",
            "tantou": "คัมภีร์เขย่ามังกรกล่าวว่า: ชะเง้อแอบมอง คนพาลก่อกวนในเงามืด แม้มีทรัพย์หมื่นตำลึงก็ต้องระวังเล่ห์กล",
            "chuanxin": "คัมภีร์ชิงหนางกล่าวว่า: ชีพจรดินไม่เกาะกลุ่ม ชี่บ้านลอยเคว้ง เสียบทะลุชี่กระจายนำสู่ความยากไร้",
            "huoxing": "คัมภีร์อี๋หลงกล่าวว่า: มุมแหลมพิฆาตดั่งสะเก็ดดาวไฟ เภทภัยเยือนเรือนคนมิอาจหวนคืน",
            "baihu": "คัมภีร์มังกรน้ำกล่าวว่า: ยอมให้มังกรเขียวสูงหมื่นวา อย่าให้เสือขาวผงาดแม้ครึ่งนิ้ว",
            "gejiao": "คัมภีร์ภูมิศาสตร์แท้กล่าวว่า: สายน้ำประชิดรากตึกเชี่ยวกราก รากตื้นมิอาจต้านทานลมพัด"
        ]
        let indoClassical: [String: String] = [
            "tianzhan": "Kitab Xue Xin berkata: Celah langit berdiri di depan, rumah terbelah qi sulit berkumpul; dua gedung menyisakan celah bagai pedang menebas.",
            "luchong": "Kitab Intisari Kanyu berkata: Jalan lurus di depan pintu paling sulit dihadapi; panah tersembunyi melukai tanpa peringatan.",
            "fangong": "Kitab Lima Rahasia Geografi berkata: Air busur terbalik tanpa perasaan memotong seperti belati lengkung; harta lenyap terbawa air.",
            "tantou": "Kitab Mengguncang Naga berkata: Kepala menunduk mengintip di belakang memicu intrik rahasia; meski kaya raya tetap harus waspada tipu muslihat.",
            "chuanxin": "Kitab Qing Nang berkata: Urat bumi tak mengental, qi rumah menguap hampa; menembus jantung membuang energi, berujung kemiskinan.",
            "huoxing": "Kitab Meragukan Naga berkata: Sudut tajam menyerang bagai percikan bintang api; malapetaka tiba di pintu penghuni tak kembali.",
            "baihu": "Kitab Naga Air berkata: Lebih baik Naga Hijau menjulang sepuluh ribu depa, jangan biarkan Harimau Putih mengangkat kepala walau setengah inci.",
            "gejiao": "Kitab Geografi Ortodoks berkata: Air mendesak deras di kaki bangunan, akar yang dangkal tak mampu berdiri melawan angin."
        ]
        let langCode = LocalizationManager.shared.effectiveLanguage
        switch langCode {
        case .zhHant: return hant[id] ?? classicalText
        case .ja: return ja[id] ?? en[id] ?? classicalText
        case .ko: return ko[id] ?? en[id] ?? classicalText
        case .vi: return vi[id] ?? en[id] ?? classicalText
        case .th: return th[id] ?? en[id] ?? classicalText
        case .id: return indoClassical[id] ?? en[id] ?? classicalText
        case .auto, .zhHans, .en: return en[id] ?? classicalText
        }
    }
}

public final class ExteriorShaEngine {
    public static let shared = ExteriorShaEngine()
    
    public let database: [ExteriorShaItem] = [
        ExteriorShaItem(
            id: "tianzhan",
            name: "天斩煞",
            aliases: "天堑煞 · 穿心风",
            visualFeature: "两栋高楼间隙极度狭窄，犹如巨斧凌空劈裂，正对向首或坐山",
            metaphysicsHarm: "气流受文丘里效应加速形成高速风刃，主血光之灾、官非破财、心脑血管突发疾厄",
            severity: .critical,
            classicalText: "《雪心赋》云：天斩迎面立，屋裂气难聚。两楼夹一罅，形同剑下劈。",
            remedySolution: "1. 悬挂正品开光纯铜【山海镇】或【九宫八卦凸镜】化解罡风；\n2. 阳台窗前密植阔叶盆栽形成绿色生态挡风屏障；\n3. 室内玄关设双面山水透光屏风阻隔直冲煞气。"
        ),
        ExteriorShaItem(
            id: "luchong",
            name: "路冲煞",
            aliases: "枪煞 · 箭煞",
            visualFeature: "笔直道路或长廊直刺明堂大门、阳台或主卧窗户，车流直逼",
            metaphysicsHarm: "一条直路一条枪，车流动能化作无形猛兽直冲宅气，主破耗连连、意外伤灾、人丁不安",
            severity: .critical,
            classicalText: "《堪舆指要》云：直冲门前最难当，暗箭伤人人莫详。",
            remedySolution: "1. 门前立【泰山石敢当】重器镇宅，稳固地基气场；\n2. 设玄关形成九曲水回流之局，使气直则缓、曲则有情；\n3. 窗内安放一对纯铜【开光麒麟】，头朝路冲方向纳气化煞。"
        ),
        ExteriorShaItem(
            id: "fangong",
            name: "反弓水 / 反弓路",
            aliases: "割脚镰 · 弯刀煞",
            visualFeature: "高架桥、河流或弧形道路如拉满之弓箭，弧顶凸面正对房屋",
            metaphysicsHarm: "离心力将财气与贵人运向外甩离，形成无情冲撞，主子孙叛逆、破大财、官讼缠身",
            severity: .warning,
            classicalText: "《地理五诀》云：反弓无情水，犹如弯刀割。居者难安泰，钱财随水折。",
            remedySolution: "1. 摆放【黑曜石八卦龙龟】背向化解冲煞；\n2. 窗台安置半圆型绿色植被弧阵缓冲离心煞气；\n3. 室内向反弓方挂置【五帝钱金刚杵】镇摄金木交战之刑。"
        ),
        ExteriorShaItem(
            id: "tantou",
            name: "探头煞",
            aliases: "窥视煞 · 偷窥小人",
            visualFeature: "前方建筑物后方隐隐露出一角或圆顶，犹如有人探首窥视宅内",
            metaphysicsHarm: "暗中窥测，主招引暗室小人、遭盗窃欺诈、婚外暗昧之情或突发名誉受损",
            severity: .warning,
            classicalText: "《撼龙经》云：头低偷窥探，小人暗中乱。纵有万贯财，亦防暗中算。",
            remedySolution: "1. 挂置【凸面铜八卦镜】反弹窥测气场；\n2. 室内面向探头方摆放一只昂首纯铜【大号神公鸡】破除阴邪暗窥；\n3. 长期拉上微透光百叶窗帘，阻绝视线交锋。"
        ),
        ExteriorShaItem(
            id: "chuanxin",
            name: "穿心煞",
            aliases: "悬针煞 · 地底贯通",
            visualFeature: "楼宇下方有地铁、隧道、车道贯穿，或正门正对直通后窗",
            metaphysicsHarm: "地气空洞不稳定，泄气极速，主财气不聚、肠胃脾胃虚寒、居者缺乏安全感",
            severity: .warning,
            classicalText: "《青囊经》云：地脉不凝，宅气空腾。穿心走气，贫困无依。",
            remedySolution: "1. 室内地面铺设【黄玉七星阵】聚引大地土气；\n2. 大门入户处设下沉式真铜条门槛压胜稳气；\n3. 摆放厚重实木玄关柜以藏风聚气。"
        ),
        ExteriorShaItem(
            id: "huoxing",
            name: "火形煞",
            aliases: "尖角煞 · 尖峰冲煞",
            visualFeature: "对面大厦屋角、三角形顶棚、加油站、变电站或红色高耸尖塔直刺",
            metaphysicsHarm: "火金相克，火燥生煞，主口舌官非、视力疾厄、皮肤炎肿、脾气暴躁易燃",
            severity: .warning,
            classicalText: "《疑龙经》云：尖角冲克火星飞，灾殃临门人不归。",
            remedySolution: "1. 安放【天然白水晶球】或【黑曜石阵】以水克火化燥气；\n2. 窗边悬挂【特制两串六帝古钱】泄化燥火；\n3. 增加蓝色/水波纹装饰织物调和五行平衡。"
        ),
        ExteriorShaItem(
            id: "baihu",
            name: "白虎煞",
            aliases: "虎强龙弱 · 白虎抬头",
            visualFeature: "住宅右侧建筑物明显高过左侧（青龙方），或右侧有大型动土施工",
            metaphysicsHarm: "青龙委靡，白虎张狂，主阴盛阳衰、妇人专权暴烈、男丁运势受压抑阻滞",
            severity: .minor,
            classicalText: "《水龙经》云：宁叫青龙高万丈，莫教白虎昂半寸。",
            remedySolution: "1. 在左侧（青龙方）高处摆放一尊纯铜【祥龙吐珠】助旺龙气；\n2. 在右方白虎位安置【青玉泰山石】稳稳压伏；\n3. 提升左侧室内灯光照度与高大家具布局。"
        ),
        ExteriorShaItem(
            id: "gejiao",
            name: "割脚煞",
            aliases: "割脚水 · 贴足急流",
            visualFeature: "高架桥、贴身快速车道或汹涌急流紧挨楼脚，无明堂缓冲地带",
            metaphysicsHarm: "气流疾走拔除地气，财运大起大落，根基虚浮，青年得志但晚运易倾颓",
            severity: .minor,
            classicalText: "《地理正宗》云：水逼楼脚急，根浅风难立。",
            remedySolution: "1. 阳台处筑造高盆花坛灌木，构筑人工台座阻滞泄气；\n2. 屋内向急流方供放一对【生肖铜貔貅】咬财纳吉；\n3. 运用厚质隔音挡气Low-E玻璃窗增强气密性。"
        )
    ]
}
