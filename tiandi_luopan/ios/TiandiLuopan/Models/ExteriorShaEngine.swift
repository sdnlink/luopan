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
            case "tianzhan": return "① Shield (do first · free): Place a row of tall broad-leaf plants (monstera, money tree) taller than the sill, or add thick sheer curtains, on the window/balcony facing the gap. → Effect: Softens the wind and visual pressure from the gap; covers the affected window/balcony.\n② Block (low cost): If the front door lines up with the gap-facing window, put a half-height cabinet or openwork screen at the entry so the room is not seen straight through. → Effect: Stops the through-draft and stabilizes airflow across the home.\n③ Anchor (optional): For a stronger remedy, hang a convex bagua mirror or Mountain-Sea mirror facing the gap, tilted down 3-5°, never aimed at a neighbor's windows. → Effect: Acts only on that facing direction; keep neighborly harmony.\n→ Family impact: Mostly the health of elders and members who come and go often (head & bone discomfort, accident risk) plus loss of steady income; affects the direction facing the gap and family active there."
            case "luchong":  return "① Shield (do first · free): Place a threshold stone or mat at the door and a curtain inside; put a tall plant on a window facing the road. → Effect: Eases the pressure of the straight road pointing at the door; covers the main door and the facing window.\n② Block (low cost): Add a low hedge or screen outside so the entry path turns a corner. → Effect: Turns the direct rush into a gentler flow; benefits the whole home.\n③ Anchor (optional): Hang a Mountain-Sea or bagua mirror above the door, slightly tilted down toward the road, not aimed at neighbors. → Effect: Acts only on the facing direction.\n→ Family impact: Accidents, injury and money loss for members who travel in and out often (daily commuters); unsettled family fortune; affects the direction the road points at and those passing through."
            case "fangong":  return "① Shield (do first · free): Arrange curved greenery or potted plants on the window/balcony on the bow side. → Effect: Eases the pressure of the bow facing the home; covers the affected window/balcony.\n② Block (low cost): Place a round table, rug or curved sofa on the bow side instead of sharp-edged furniture. → Effect: Softens the outward-pulling energy and stabilizes that area.\n③ Anchor (optional): Put obsidian, a Shi Gandang stone or Five-Emperor coins on the bow side, facing outward. → Effect: Acts only on that direction; optional reinforcement.\n→ Family impact: Cooler marital bond, quarrels and money drain (most noticeable for the lady of the house and the couple); the home struggles to hold Qi; affects the outward-bow direction and family living there."
            case "tantou":   return "① Shield (do first · free): Keep sheer curtains or blinds drawn during the day on windows facing the peering corner. → Effect: Blocks the line of sight; covers that window.\n② Block (low cost): Place tall plants (ivy, pothos) on the sill to screen the corner. → Effect: Visual isolation; reduces the feeling of being watched.\n③ Anchor (optional): Hang a convex bagua mirror toward the peering building, not aimed at neighbor windows. → Effect: Acts only on that direction.\n→ Family impact: Secret scheming, theft concerns and official disputes (privacy and sense of security affected); affects the direction of the peering structure and family active there."
            case "chuanxin": return "① Block (do first · free): If the door lines up with a back window, place a cabinet, screen or thick curtain across the path. → Effect: Stops the straight through-draft and stabilizes airflow.\n② Shield (low cost): Add rugs, plants on sills and heavy furniture against walls to slow the airflow. → Effect: Slows the rushing air; improves comfort and stability.\n③ Anchor (optional): Put Five-Emperor coins or a small Shi Gandang inside the threshold. → Effect: Entry area; optional reinforcement.\n→ Family impact: Health disturbance and restless sleep for residents (worst for anyone sleeping on the through-line); pierced house energy; affects the through-path direction and family there."
            case "huoxing":  return "① Shield (do first · free): Hang sheer curtains or blinds on windows facing the sharp corner. → Effect: Visual buffer; covers that window.\n② Block (low cost): Place water-grown plants (pothos, ivy) on the sill to ease dryness. → Effect: Harmonizes fire dryness in that area.\n③ Anchor (optional): Use obsidian, crystal or blue decor to suppress fire; avoid red in this direction. → Effect: Acts only on that direction; avoid red.\n→ Family impact: Short temper, quarrels and fire risk (temperament, heart/brain and eye health); affects the direction the sharp corner/chimney points at and family there."
            case "baihu":    return "① Balance (do first · free): Add a floor lamp, tall furniture or tall plants on the left (Azure Dragon) side to even out the visual height. → Effect: Balances the room's energy and eases the right-side pressure.\n② Shield (low cost): If there is construction or a tall building on the right, hang heavy curtains on that side. → Effect: Blocks noise and visual disturbance.\n③ Anchor (optional): Place a Taishan stone or Qilin ornament on the left. → Effect: Symbolic reinforcement only.\n→ Family impact: Underhanded scheming, disputes among the women of the house and accidental injury (felt most by the women at home); affects the right-side White Tiger direction and family there."
            case "gejiao":   return "① Shield (do first · free): Put tall potted plants or planters on the balcony/windows beside the road. → Effect: Buffers the fast flow; covers the road-side.\n② Block (low cost): Use thicker glass or double curtains on the road-side windows to reduce noise. → Effect: Reduces sound and visual disturbance.\n③ Anchor (optional): Place a Pixiu or Shi Gandang facing the road/water. → Effect: Acts on that direction; optional reinforcement.\n→ Family impact: Wealth leakage and health issues (dampness discomfort, money flowing out); affects the direction of the sweeping water/road and family living there."
            default: return remedySolution
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "① 擋（先做·免費）：正對樓縫的窗前或陽台，擺一排高過窗台的闊葉綠植（龜背竹、發財樹），或加厚紗簾。→ 影響：減輕夾縫直衝的氣流與視覺壓迫，覆蓋對縫的窗和陽台。\n② 隔（低成本）：若大門與對縫窗成一直線，玄關放半高鞋櫃或鏤空屏風，進門不一目望穿。→ 影響：阻斷穿堂直通，穩定全屋氣流。\n③ 鎮（可選）：正對縫口掛凸面八卦鏡或山海鎮，鏡面朝外、略下傾3-5度，勿照鄰家門窗。→ 影響：僅作用該沖射方位；注意鄰里關係。\n→ 家人影響：主家中長輩與經常出入者健康（頭部、骨骼不適與血光之虞）及正財破耗；影響正對樓縫的方位及該處常活動的家人。"
            case "luchong": return "① 擋（先做·免費）：門口放門檻石或門墊，門內掛門簾；正對路的窗台放一盆高綠植。→ 影響：弱化直路沖門的壓迫感，覆蓋大門與正沖窗。\n② 隔（低成本）：門外加半高綠籬或屏風，讓進門動線拐個彎。→ 影響：直沖氣流轉為緩行，全宅受益。\n③ 鎮（可選）：大門上方掛山海鎮或八卦鏡，朝路方向微下傾，勿照鄰居。→ 影響：僅針對沖射方位。\n→ 家人影響：主經常出入的家人（早晚通勤者）意外、血光與破財，家運不穩；影響直沖來路方向及出入之人。"
            case "fangong": return "① 擋（先做·免費）：反弓一側窗外擺弧形綠植或盆栽，形成半圓緩衝。→ 影響：緩解弧頂正對的壓迫感，覆蓋反弓側窗/陽台。\n② 隔（低成本）：室內反弓方向放圓形茶几、地毯或弧形沙發，避免直角家具直沖。→ 影響：柔化離心氣流，穩定該區域氣場。\n③ 鎮（可選）：反弓方位放黑曜石、石敢當或五帝錢，面朝弧外。→ 影響：僅針對該方位；可選強化。\n→ 家人影響：主夫妻感情淡薄、是非退財（女主人與夫妻關係感受最明顯），家宅難聚氣；影響反弓弧外方向及常在此起居的家人。"
            case "tantou": return "① 擋（先做·免費）：對探頭方向的窗，白天拉上紗簾或百葉。→ 影響：阻斷視線交叉，覆蓋該窗。\n② 隔（低成本）：窗台擺高綠植（長春藤、綠蘿），遮擋探頭角。→ 影響：視覺隔離，緩解被窺感。\n③ 鎮（可選）：凸面八卦鏡朝探頭方掛，勿照鄰家門窗。→ 影響：僅針對該方位。\n→ 家人影響：主小人窺視、防盜與官非口舌，家人隱私與安全感受擾；影響探頭方向及該處活動的家人。"
            case "chuanxin": return "① 隔（先做·免費）：門與後窗成直線時，在動線正中放玄關櫃、屏風或掛厚門簾。→ 影響：阻斷穿堂直通，穩定全屋氣流。\n② 擋（低成本）：地面鋪地毯、窗台放綠植、重家具靠牆，減緩氣流速度。→ 影響：降低直穿氣流速度，改善室溫與安穩感。\n③ 鎮（可選）：入戶門檻內放五帝錢或小號石敢當。→ 影響：入戶區域；可選強化。\n→ 家人影響：主居住者健康不安、睡眠受擾（睡在穿心線上的人影響最大），家宅氣場被穿破；影響穿心路徑方向及該處家人。"
            case "huoxing": return "① 擋（先做·免費）：正對尖角的窗掛紗簾或百葉。→ 影響：視覺緩衝，覆蓋該窗。\n② 隔（低成本）：窗台擺水養植物（水培綠蘿、常春藤），緩解乾燥。→ 影響：調和火燥，覆蓋該區域。\n③ 鎮（可選）：放黑曜石、水晶或藍色裝飾物壓火氣；此方位忌紅色。→ 影響：僅針對該方位；忌紅色。\n→ 家人影響：主家人急躁口舌、火災之虞（脾氣、心腦血管與眼目健康）；影響尖角/煙囪所指方向及該處家人。"
            case "baihu": return "① 補（先做·免費）：左側（青龍方）加落地燈、高大家具或高大綠植，平衡左右視覺高度。→ 影響：平衡客廳/書房氣場，緩解右側壓迫。\n② 擋（低成本）：右側若臨施工或高樓，靠右窗掛厚窗簾遮擋。→ 影響：遮擋噪音與視線干擾。\n③ 鎮（可選）：左側放泰山石或麒麟擺件。→ 影響：僅象徵性補強。\n→ 家人影響：主小人暗算、女眷是非與意外傷災（家中女性感受較明顯）；影響右側白虎方位及該處家人。"
            case "gejiao": return "① 擋（先做·免費）：臨路一側陽台或窗前擺高盆綠植或花壇。→ 影響：緩衝急流，覆蓋臨路側。\n② 隔（低成本）：臨路窗換厚玻璃或加雙層窗簾，降低噪音。→ 影響：減少聲煞與視覺干擾。\n③ 鎮（可選）：近路/水方向放貔貅或石敢當。→ 影響：該方位；可選強化。\n→ 家人影響：主退財與健康（居住者濕氣不適、財運外流）；影響近水/高架割腳方向及該處家人。"
            default: return remedySolution
            }
        case .ja:
            switch id {
            case "tianzhan": return "① 遮る（先にやる・無料）：ビルの隙間に向いた窓やベランダに、窓台より高い広葉の観葉植物（モンステラ、パキラ）を並べるか、厚手のレースカーテンを付ける。→ 効果：隙間からの風と視覚的圧迫を和らげ、向かい合う窓・ベランダに効果。\n② 区切る（低コスト）：玄関ドアと隙間側の窓が一直線なら、玄関にハーフカウンターや透かし屏風を置き、入ってすぐ見通せないようにする。→ 効果：貫通気流を遮断し、家全体の空気の流れを安定。\n③ 鎮める（任意）：隙間の正面に凸面八卦鏡や山海鎮を掛け、鏡面を外に向けて3-5度下向きにし、隣家の窓に向けない。→ 効果：その対面方向のみに作用。近隣への配慮を忘れずに。\n→ 家族への影響：主に年長者や出入りの多い家族の健康（頭部・骨の不調、けがのリスク）と収入面での出費。隙間に面した方位とそこで過ごす家族に影響。"
            case "luchong": return "① 遮る（先にやる・無料）：玄関に敷居石かマットを置き、内側にカーテンを掛ける。道路に向いた窓には背の高い植物を置く。→ 効果：直線道路が門に突き刺さる圧迫感を和らげ、玄関と正面の窓に効果。\n② 区切る（低コスト）：門の外に低い生垣や屏風を置き、入り口の動線を曲げる。→ 効果：直進する気を緩やかな流れに変え、家全体に良い影響。\n③ 鎮める（任意）：門の上に山海鎮や八卦鏡を掛け、道路方向へ少し下向きに。隣家に向けない。→ 効果：正面の方向のみに作用。\n→ 家族への影響：頻繁に出入りする家族（通勤者など）の事故・けがと金銭面のトラブル。家運が揺らぎ、直線道路が向く方位と出入りする人に影響。"
            case "fangong": return "① 遮る（先にやる・無料）：反弓側の窓やベランダに弓なりに緑や鉢植えを並べ、半円の緩衝帯を作る。→ 効果：弧の頂点が家に面する圧迫感を和らげ、反弓側の窓・ベランダに効果。\n② 区切る（低コスト）：室内の反弓方向に丸テーブルや円形ラグ、曲線のソファを置き、角のある家具を避ける。→ 効果：外へ引く気を柔らげ、その場所の気を安定。\n③ 鎮める（任意）：反弓方位に黒曜石、石敢当、五帝銭を弧の外側に向けて置く。→ 効果：その方向のみに作用。任意の補強。\n→ 家族への影響：夫婦の気持ちがすれ違い、言い争いや出費が増える（妻や夫婦関係に最も現れやすい）。家に気が留まりにくく、反弓の外側の方位とそこで暮らす家族に影響。"
            case "tantou": return "① 遮る（先にやる・無料）：覗き込んでくる建物の角に向いた窓は、日中レースカーテンやブラインドを閉じる。→ 効果：視線の交差を遮断し、その窓に効果。\n② 区切る（低コスト）：窓台に背の高い植物（アイビー、ポトス）を置き、角を隠す。→ 効果：視覚的に隔離し、見られている感覚を緩和。\n③ 鎮める（任意）：凸面八卦鏡を覗き込み方向に掛ける。隣家の窓に向けない。→ 効果：その方向のみに作用。\n→ 家族への影響：のぞき・盗難・役所や対人トラブル（プライバシーと安心感が損なわれる）。覗き込む方向とそこで過ごす家族に影響。"
            case "chuanxin": return "① 区切る（先にやる・無料）：玄関ドアと裏窓が一直線なら、動線の中央に玄関収納、屏風、厚手のカーテンを置く。→ 効果：貫通気流を遮断し、家全体の空気の流れを安定。\n② 遮る（低コスト）：床にカーペット、窓台に植物、重い家具を壁際に置き、気流を遅くする。→ 効果：直進する空気の速度を下げ、室温と安定感が改善。\n③ 鎮める（任意）：玄関の敷居内に五帝銭か小型の石敢当を置く。→ 効果：玄関エリア。任意の補強。\n→ 家族への影響：住む人の体調不良や睡眠の乱れ（貫通線上で眠る人が最も影響）。家の気が貫かれてしまい、貫通する方向とそこにいる家族に影響。"
            case "huoxing": return "① 遮る（先にやる・無料）：尖った角に向いた窓にレースカーテンやブラインドを掛ける。→ 効果：視覚的な緩衝となり、その窓に効果。\n② 区切る（低コスト）：窓台に水耕の植物（ポトス、アイビー）を置き、乾燥を和らげる。→ 効果：火気の乾燥を調和し、その場所に効果。\n③ 鎮める（任意）：黒曜石、水晶、青系の装飾で火気を抑える。この方位は赤を避ける。→ 効果：その方向のみに作用。赤色は避ける。\n→ 家族への影響：苛立ちや口論、火の用心（気性、心臓・頭、目の健康）。尖った角や煙突が向く方位とそこにいる家族に影響。"
            case "baihu": return "① 補う（先にやる・無料）：左側（青龍側）にフロアランプ、背の高い家具、大きな観葉植物を置き、左右の視覚的高さを揃える。→ 効果：リビング・書斎の気を均衡させ、右側の圧迫を緩和。\n② 遮る（低コスト）：右側に工事や高層ビルがある場合、右側の窓に厚手のカーテンを掛ける。→ 効果：騒音と視覚的干渉を遮断。\n③ 鎮める（任意）：左側に泰山石や麒麟の置物を置く。→ 効果：象徴的な補強のみ。\n→ 家族への影響：陰口や女性同士の言い争い、思わぬけが（家の女性に表れやすい）。右側・白虎の方位とそこにいる家族に影響。"
            case "gejiao": return "① 遮る（先にやる・無料）：道路側のベランダや窓の前に背の高い鉢植えやプランターを置く。→ 効果：急流の気を緩衝し、道路側に効果。\n② 区切る（低コスト）：道路側の窓を厚いガラスにするか二重カーテンにし、騒音を下げる。→ 効果：音と視覚的干渉を軽減。\n③ 鎮める（任意）：道路・水の方向に貔貅か石敢当を置く。→ 効果：その方向のみに作用。任意の補強。\n→ 家族への影響：金運の流出と健康面（湿気による不調、出費が増える）。水や道路が迫る方位とそこで暮らす家族に影響。"
            default: return remedySolution
            }
        case .ko:
            switch id {
            case "tianzhan": return "① 막기(먼저 하세요·무료): 건물 틈을 향한 창문이나 베란다에 창틀보다 높은 넓은 잎 식물(몬스테라, 파키라)을 늘어놓거나 두꺼운 커튼을 답니다. → 효과: 틈새에서 오는 바람과 시각적 압박을 줄이며, 틈을 마주한 창문·베란다에 효과.\n② 구분(저비용): 현관문과 틈 쪽 창문이 일직선이면 현관에 반 높이 수납장이나 칸막이를 두어 들어와서 바로 보이지 않게 합니다. → 효과: 관통 기류를 차단하고 집 전체의 기운 흐름을 안정시킵니다.\n③ 진정(선택): 틈 정면에 볼록 팔괘경이나 산해진을 걸되, 경면을 바깥으로 3-5도 아래로 기울이고 이웃집 창문을 향하지 않게 합니다. → 효과: 해당 방향에만 작용. 이웃 관계에 주의.\n→ 가족 영향: 주로 어르신과 출입이 잦은 가족의 건강(머리·뼈 불편, 사고 위험)과 재물 손실. 건물 틈을 마주한 방위와 그곳에서 지내는 가족에게 영향."
            case "luchong": return "① 막기(먼저 하세요·무료): 현관에 문턱석이나 매트를 두고 안쪽에 커튼을 답니다. 길을 향한 창가에는 키 큰 화분을 둡니다. → 효과: 직선 도로가 문을 겨누는 압박감을 줄이며 현관과 정면 창에 효과.\n② 구분(저비용): 문 밖에 낮은 울타리나 칸막이를 두어 진입 동선이 꺾이게 합니다. → 효과: 직진하던 기운을 완만하게 바꿔 집 전체에 이롭습니다.\n③ 진정(선택): 대문 위에 산해진이나 팔괘경을 걸고 도로 쪽으로 약간 아래를 향하게 합니다. 이웃을 향하지 마세요. → 효과: 정면 방향에만 작용.\n→ 가족 영향: 자주 드나드는 가족(출퇴근자 등)의 사고·부상과 재물 손실. 집의 기운이 흔들리며, 도로가 곧게 향한 방위와 출입하는 사람에게 영향."
            case "fangong": return "① 막기(먼저 하세요·무료): 반궁(활처럼 휜) 쪽 창문이나 베란다에 곡선으로 화분을 배치해 반원 완충대를 만듭니다. → 효과: 활 끝이 집을 향하는 압박감을 줄이며 반궁 쪽 창·베란다에 효과.\n② 구분(저비용): 실내 반궁 방향에 원형 테이블·원형 러그·곡선 소파를 두고 각진 가구를 피합니다. → 효과: 밖으로 빨아내는 기운을 부드럽게 하고 그 공간의 기를 안정시킵니다.\n③ 진정(선택): 반궁 방위에 흑요석, 석감당, 오제전을 활 바깥쪽으로 향해 둡니다. → 효과: 해당 방향에만 작용. 선택 보강.\n→ 가족 영향: 부부 사이가 서먹해지고 다툼·지출이 늘어남(아내와 부부관계에 가장 잘 드러남). 집에 기운이 머물지 못하며, 반궁 바깥 방위와 그곳에서 사는 가족에게 영향."
            case "tantou": return "① 막기(먼저 하세요·무료): 엿보는 건물 모서리를 향한 창은 낮에 커튼이나 블라인드를 내립니다. → 효과: 시선 교차를 차단하며 해당 창에 효과.\n② 구분(저비용): 창틀에 키 큰 식물(담쟁이, 포토스)을 두어 모서리를 가립니다. → 효과: 시각적으로 격리되어 엿보임을 덜 느끼게 합니다.\n③ 진정(선택): 볼록 팔괘경을 엿보는 방향으로 겁니다. 이웃 창문을 향하지 마세요. → 효과: 해당 방향에만 작용.\n→ 가족 영향: 엿보는 시선·도난·관청 및 대인 마찰(사생활과 안심이 침해됨). 엿보는 방향과 그곳에서 지내는 가족에게 영향."
            case "chuanxin": return "① 구분(먼저 하세요·무료): 현관문과 뒷창문이 일직선이면 동선 한가운데 현관 수납장, 칸막이, 두꺼운 커튼을 둡니다. → 효과: 관통 기류를 차단하고 집 전체의 공기 흐름을 안정시킵니다.\n② 막기(저비용): 바닥에 카펫, 창틀에 화분, 무거운 가구는 벽 쪽에 두어 기류 속도를 늦춥니다. → 효과: 직통 기류 속도를 낮춰 온도와 안정감을 개선합니다.\n③ 진정(선택): 현관 문턱 안쪽에 오제전이나 소형 석감당을 둡니다. → 효과: 현관 영역. 선택 보강.\n→ 가족 영향: 거주자의 건강 불안과 수면 방해(관통선 위에서 자는 사람이 가장 크게 영향). 집 기운이 뚫리며, 관통 경로 방위와 그곳의 가족에게 영향."
            case "huoxing": return "① 막기(먼저 하세요·무료): 뾰족한 모서리를 향한 창에 커튼이나 블라인드를 답니다. → 효과: 시각적 완충, 해당 창에 효과.\n② 구분(저비용): 창틀에 수경 식물(포토스, 담쟁이)을 두어 건조함을 줄입니다. → 효과: 화기의 건조함을 조화시키며 해당 공간에 효과.\n③ 진정(선택): 흑요석·수정·파란색 장식품으로 화기를 누릅니다. 이 방위에서는 빨간색을 피하세요. → 효과: 해당 방향에만 작용. 빨간색 금지.\n→ 가족 영향: 조급함·말다툼·화재 우려(기질, 심혈관·머리, 눈 건강). 뾰족한 모서리나 굴뚝이 향한 방위와 그곳의 가족에게 영향."
            case "baihu": return "① 보완(먼저 하세요·무료): 왼쪽(청룡방)에 스탠드 조명, 키 큰 가구, 큰 화분을 두어 좌우 시각 높이를 맞춥니다. → 효과: 거실·서재의 기운 균형을 잡고 오른쪽 압박을 완화합니다.\n② 막기(저비용): 오른쪽에 공사장이나 고층 건물이 있으면 오른쪽 창에 두꺼운 커튼을 답니다. → 효과: 소음과 시선 간섭을 차단합니다.\n③ 진정(선택): 왼쪽에 태산석이나 기린 장식품을 둡니다. → 효과: 상징적 보강일 뿐입니다.\n→ 가족 영향: 뒷말·여성 간 시비·뜻밖의 부상(집 안 여성에게 잘 나타남). 오른쪽 백호 방위와 그곳의 가족에게 영향."
            case "gejiao": return "① 막기(먼저 하세요·무료): 도로 쪽 베란다나 창 앞에 키 큰 화분이나 화단을 둡니다. → 효과: 빠른 기류를 완충하며 도로 쪽에 효과.\n② 구분(저비용): 도로 쪽 창을 두꺼운 유리로 바꾸거나 이중 커튼을 달아 소음을 낮춥니다. → 효과: 소음과 시각적 간섭을 줄입니다.\n③ 진정(선택): 도로·물 방향에 비휴나 석감당을 둡니다. → 효과: 해당 방향에만 작용. 선택 보강.\n→ 가족 영향: 재물 유출과 건강(습기 불편, 지출 증가). 물이나 도로가 다가오는 방위와 그곳에서 사는 가족에게 영향."
            default: return remedySolution
            }
        case .vi:
            switch id {
            case "tianzhan": return "① Chắn (làm trước·miễn phí): Đặt hàng cây lá rộng cao hơn bậu cửa (cây monstera, kim tiền) hoặc rèm vải dày ở cửa sổ/ban công đối diện khe nhà. → Ảnh hưởng: Giảm luồng gió và áp lực thị giác từ khe hở; phủ cửa sổ/ban công đối diện.\n② Chặn (chi phí thấp): Nếu cửa chính thẳng hàng với cửa sổ đối diện khe, đặt tủ nửa cao hoặc vách ngăn ở huyền quan để không nhìn thông thẳng. → Ảnh hưởng: Chặn luồng gió xuyên phòng, ổn định khí lưu toàn nhà.\n③ Trấn (tùy chọn): Treo gương Bát Quái lồi hoặc Sơn Hải Trấn đối diện khe, mặt gương hướng ra ngoài nghiêng xuống 3-5 độ, không chiếu vào cửa sổ nhà hàng xóm. → Ảnh hưởng: Chỉ tác động vào hướng xung đó; giữ hòa khí láng giềng.\n→ Ảnh hưởng gia đình: Chủ yếu sức khỏe người lớn tuổi và người hay ra vào (đầu, xương khó chịu, nguy cơ tai nạn) cùng hao tài lộc; ảnh hưởng hướng đối diện khe và người nhà sinh hoạt ở đó."
            case "luchong": return "① Chắn (làm trước·miễn phí): Đặt bậc cửa hoặc thảm ở cửa chính và rèm bên trong; đặt chậu cây cao trên cửa sổ hướng ra đường. → Ảnh hưởng: Giảm áp lực đường thẳng đâm vào cửa; phủ cửa chính và cửa sổ đối diện.\n② Chặn (chi phí thấp): Thêm hàng rào thấp hoặc vách ngăn ngoài cửa để lối vào rẽ góc. → Ảnh hưởng: Biến luồng xung thẳng thành dòng chảy nhẹ; toàn nhà được lợi.\n③ Trấn (tùy chọn): Treo Sơn Hải Trấn hoặc gương Bát Quái trên cửa, hơi nghiêng xuống về phía đường, không hướng vào nhà hàng xóm. → Ảnh hưởng: Chỉ tác động vào hướng xung.\n→ Ảnh hưởng gia đình: Người hay ra vào (đi làm mỗi ngày) dễ gặp sự cố, thương tích và hao tài; vận nhà không ổn, ảnh hưởng hướng đường đâm thẳng và người qua lại."
            case "fangong": return "① Chắn (làm trước·miễn phí): Xếp cây xanh hoặc chậu cảnh cong theo phía cung ôm để tạo đệm bán nguyệt. → Ảnh hưởng: Giảm áp lực đỉnh cung đối diện; phủ cửa sổ/ban công phía cung ôm.\n② Chặn (chi phí thấp): Đặt bàn tròn, thảm tròn hoặc sofa cong ở phía cung ôm thay cho đồ nội thất góc cạnh. → Ảnh hưởng: Làm mềm luồng khí ly tâm, ổn định khí trường khu vực đó.\n③ Trấn (tùy chọn): Đặt thạch anh đen, Thạch Cảm Đương hoặc tiền Ngũ Đế ở phía cung ôm, hướng ra ngoài. → Ảnh hưởng: Chỉ tác động hướng đó; gia cố tùy chọn.\n→ Ảnh hưởng gia đình: Tình cảm vợ chồng nhạt dần, thị phi và tiêu tán tiền bạc (nữ chủ nhà và quan hệ vợ chồng thấy rõ nhất); nhà khó tụ khí, ảnh hưởng hướng cung ôm hướng ra và người nhà ở đó."
            case "tantou": return "① Chắn (làm trước·miễn phí): Kéo rèm mỏng hoặc mành vào ban ngày ở cửa sổ hướng về góc thò ra. → Ảnh hưởng: Chặn giao thoa ánh nhìn; phủ cửa sổ đó.\n② Chặn (chi phí thấp): Đặt cây cao (trường xuân, trầu bà) trên bậu cửa để che góc nhìn. → Ảnh hưởng: Cách ly thị giác, giảm cảm giác bị nhìn.\n③ Trấn (tùy chọn): Treo gương Bát Quái lồi về phía tòa nhà thò ra, không chiếu vào cửa sổ hàng xóm. → Ảnh hưởng: Chỉ tác động hướng đó.\n→ Ảnh hưởng gia đình: Tiểu nhân dòm ngó, trộm cắp và thị phi quan phi (riêng tư và cảm giác an toàn bị ảnh hưởng); ảnh hưởng hướng có vật nhô ra và người nhà sinh hoạt ở đó."
            case "chuanxin": return "① Chặn (làm trước·miễn phí): Nếu cửa chính thẳng hàng với cửa sổ sau, đặt tủ, vách ngăn hoặc rèm dày giữa luồng đi. → Ảnh hưởng: Chặn luồng gió xuyên thẳng, ổn định khí lưu.\n② Chắn (chi phí thấp): Trải thảm, đặt cây trên bậu cửa và đồ nội thất nặng sát tường để làm chậm khí lưu. → Ảnh hưởng: Giảm tốc luồng khí, cải thiện nhiệt độ và cảm giác an ổn.\n③ Trấn (tùy chọn): Đặt tiền Ngũ Đế hoặc Thạch Cảm Đương nhỏ trong ngạch cửa. → Ảnh hưởng: Khu vực cửa vào; gia cố tùy chọn.\n→ Ảnh hưởng gia đình: Sức khỏe người ở bất an, ngủ không ngon (người nằm trên đường xuyên tâm ảnh hưởng nhất); khí nhà bị xuyên phá, ảnh hưởng hướng đường xuyên và người nhà ở đó."
            case "huoxing": return "① Chắn (làm trước·miễn phí): Treo rèm mỏng hoặc mành ở cửa sổ hướng về góc nhọn. → Ảnh hưởng: Đệm thị giác; phủ cửa sổ đó.\n② Chặn (chi phí thấp): Đặt cây thủy sinh (trầu bà, trường xuân) trên bậu cửa để giảm khô. → Ảnh hưởng: Điều hòa hỏa khí khô nóng tại khu vực đó.\n③ Trấn (tùy chọn): Dùng thạch anh đen, pha lê hoặc vật trang trí màu xanh để dập hỏa; hướng này tránh màu đỏ. → Ảnh hưởng: Chỉ tác động hướng đó; tránh màu đỏ.\n→ Ảnh hưởng gia đình: Người nhà nóng nảy, cãi vã, nguy cơ hỏa hoạn (tính khí, tim mạch và mắt); ảnh hưởng hướng góc nhọn/ống khói chỉ tới và người nhà ở đó."
            case "baihu": return "① Cân bằng (làm trước·miễn phí): Thêm đèn sàn, đồ nội thất cao hoặc cây cao ở phía trái (Thanh Long) để cân bằng chiều cao thị giác. → Ảnh hưởng: Cân bằng khí trường phòng khách/phòng sách, giảm áp lực phía phải.\n② Chắn (chi phí thấp): Nếu phía phải có công trường hoặc tòa nhà cao, treo rèm dày ở cửa sổ bên phải. → Ảnh hưởng: Chặn tiếng ồn và nhiễu thị giác.\n③ Trấn (tùy chọn): Đặt Thạch Cảm Đương hoặc tượng Kỳ Lân ở phía trái. → Ảnh hưởng: Chỉ mang ý nghĩa biểu trưng.\n→ Ảnh hưởng gia đình: Tiểu nhân hãm hại, thị phi phụ nữ và tai nạn thương tích (phụ nữ trong nhà cảm nhận rõ hơn); ảnh hưởng hướng Bạch Hổ bên phải và người nhà ở đó."
            case "gejiao": return "① Chắn (làm trước·miễn phí): Đặt chậu cây cao hoặc bồn hoa ở ban công/cửa sổ phía sát đường. → Ảnh hưởng: Đệm dòng khí nhanh; phủ phía sát đường.\n② Chặn (chi phí thấp): Thay kính dày hoặc treo rèm đôi ở cửa sổ sát đường để giảm tiếng ồn. → Ảnh hưởng: Giảm tạp âm và nhiễu thị giác.\n③ Trấn (tùy chọn): Đặt Tỳ Hưu hoặc Thạch Cảm Đương hướng ra đường/nước. → Ảnh hưởng: Tác động hướng đó; gia cố tùy chọn.\n→ Ảnh hưởng gia đình: Hao tài và sức khỏe (ẩm thấp khó chịu, tiền bạc thất thoát); ảnh hưởng hướng nước/đường cao tốc áp sát và người nhà ở đó."
            default: return remedySolution
            }
        case .th:
            switch id {
            case "tianzhan": return "① บัง (ทำก่อน·ฟรี): วางต้นไม้ใบกว้างสูงกว่าขอบหน้าต่าง (มอนสเตอรา ต้นเงิน) หรือติดม่านทึบที่หน้าต่าง/ระเบียงที่หันเข้าช่องตึก → ผล: ลดลมและแรงกดทางสายตาจากช่องว่าง ครอบคลุมหน้าต่าง/ระเบียงที่หันเข้าช่อง\n② กั้น (ต้นทุนต่ำ): ถ้าประตูหน้าตรงกับหน้าต่างที่หันเข้าช่อง วางตู้ครึ่งสูงหรือฉากโปร่งที่โถงทางเข้า อย่าให้มองทะลุถึงสุด → ผล: ตัดลมทะลุตรง ทำลมในบ้านให้คงที่\n③ สะกด (ทางเลือก): แขวนกระจกนูนแปดทิศหรือซานไห่เจิ้นหันเข้าช่อง เอียงลง 3-5 องศา อย่าชี้ไปที่หน้าต่างเพื่อนบ้าน → ผล: มีผลเฉพาะทิศที่ปะทะนั้น ดูแลไมตรีกับเพื่อนบ้าน\n→ ผลต่อครอบครัว: หลักคือสุขภาพผู้ใหญ่และคนที่เข้าออกบ่อย (ศรีษะ กระดูกไม่สบาย เสี่ยงอุบัติเหตุ) กับเสียทรัพย์ กระทบทิศที่หันเข้าช่องและคนในบ้านที่อยู่ตรงนั้น"
            case "luchong": return "① บัง (ทำก่อน·ฟรี): วางหินธรณีประตูหรือพรมที่ประตูและม่านด้านใน วางต้นไม้สูงที่หน้าต่างหันทางถนน → ผล: ลดแรงกดของถนนตรงที่พุ่งเข้าประตู ครอบคลุมประตูหลักและหน้าต่างที่หันตรง\n② กั้น (ต้นทุนต่ำ): วางรั้วเตี้ยหรือฉากนอกประตูให้ทางเข้าอ้อมมุม → ผล: เปลี่ยนกระแสตรงเป็นทางอ้อม เจริญทั้งบ้าน\n③ สะกด (ทางเลือก): แขวนซานไห่เจิ้นหรือกระจกแปดทิศเหนือประตู เอียงลงทางถนนเล็กน้อย อย่าชี้เพื่อนบ้าน → ผล: มีผลเฉพาะทิศที่ปะทะ\n→ ผลต่อครอบครัว: คนที่เข้าออกบ่อย (ผู้เดินทางทุกวัน) เสี่ยงอุบัติเหตุ บาดเจ็บและเสียเงิน วาสนาบ้านสั่นคลอน กระทบทิศที่ถนนพุ่งตรงและคนที่ผ่านไปมา"
            case "fangong": return "① บัง (ทำก่อน·ฟรี): จัดต้นไม้หรือกระถางโค้งตามทิศโค้งน้ำ/ถนนเพื่อเป็นเกราะครึ่งวงกลม → ผล: ลดแรงกดของส่วนโค้งที่หันเข้าบ้าน ครอบคลุมหน้าต่าง/ระเบียงด้านโค้ง\n② กั้น (ต้นทุนต่ำ): วางโต๊ะกลม พรมกลม หรือโซฟาโค้งในทิศโค้งแทนเฟอร์นิเจอร์มุมแหลม → ผล: ทำให้นิวเคลียสแรงเหวี่ยงนุ่มลง ทำให้พื้นที่นั้นคงที่\n③ สะกด (ทางเลือก): วางหินออบซิเดียน ศิลากั้นตัง หรือเหรียญห้าจักรพรรดิที่ทิศโค้ง หันออกนอก → ผล: มีผลเฉพาะทิศนั้น เสริมได้ตามต้องการ\n→ ผลต่อครอบครัว: ความสัมพันธ์คู่สามีภรรยาเย็นลง ทะเลาะและเสียทรัพย์ (ภรรยาและความสัมพันธ์คู่เห็นชัดที่สุด) บ้านยากที่จะเก็บพลัง กระทบทิศโค้งที่ยื่นออกและคนในบ้านที่อยู่ตรงนั้น"
            case "tantou": return "① บัง (ทำก่อน·ฟรี): ปิดม่านบางหรือมู่ลี่ตอนกลางวันที่หน้าต่างหันมุมตึกที่โผล่ → ผล: กั้นสายตา ครอบคลุมหน้าต่างนั้น\n② กั้น (ต้นทุนต่ำ): วางต้นไม้สูง (ไม้เลื้อย โพทอส) บนขอบหน้าต่างบังมุม → ผล: แยกสายตา ลดความรู้สึกถูกจ้อง\n③ สะกด (ทางเลือก): แขวนกระจกนูนแปดทิศไปทางตึกที่โผล่ อย่าชี้หน้าต่างเพื่อนบ้าน → ผล: มีผลเฉพาะทิศนั้น\n→ ผลต่อครอบครัว: คนมองจ้อง ขโมย และเรื่องทะเลาะกับหน่วยงาน (ความเป็นส่วนตัวและความปลอดภัยถูกรบกวน) กระทบทิศที่สิ่งก่อสร้างโผล่และคนในบ้านที่อยู่ตรงนั้น"
            case "chuanxin": return "① กั้น (ทำก่อน·ฟรี): ถ้าประตูหน้าตรงกับหน้าต่างหลัง วางตู้ ฉาก หรือม่านหนากลางทางเดิน → ผล: ตัดลมทะลุตรง ทำให้กระแสลมคงที่\n② บัง (ต้นทุนต่ำ): ปูพรม วางต้นไม้ที่ขอบหน้าต่าง และเฟอร์นิเจอร์หนักชิดผนังเพื่อชะลอกระแสลม → ผล: ชะลอความเร็วลม ปรับอุณหภูมิและความมั่นคงในบ้าน\n③ สะกด (ทางเลือก): วางเหรียญห้าจักรพรรดิหรือศิลากั้นตังเล็กในธรณีประตู → ผล: บริเวณประตูเข้า เสริมได้ตามต้องการ\n→ ผลต่อครอบครัว: คนในบ้านสุขภาพไม่สบาย นอนไม่หลับ (คนที่นอนอยู่บนแนวทะลุได้รับผลมากที่สุด) พลังบ้านถูกทะลุ กระทบทิศทางเดินทะลุและคนในบ้านที่อยู่ตรงนั้น"
            case "huoxing": return "① บัง (ทำก่อน·ฟรี): ติดม่านบางหรือมู่ลี่ที่หน้าต่างหันมุมแหลม → ผล: เกราะทางสายตา ครอบคลุมหน้าต่างนั้น\n② กั้น (ต้นทุนต่ำ): วางต้นไม้น้ำ (โพทอส ไม้เลื้อย) บนขอบหน้าต่างลดความแห้ง → ผล: ลดความร้อนแห้งของธาตุไฟในบริเวณนั้น\n③ สะกด (ทางเลือก): ใช้หินออบซิเดียน ผลึก หรือของตกแต่งสีน้ำเงินสะกดไฟ ทิศนี้ห้ามสีแดง → ผล: มีผลเฉพาะทิศนั้น ห้ามใช้สีแดง\n→ ผลต่อครอบครัว: คนในบ้านหงุดหงิด ทะเลาะ กลัวอัคคีภัย (อารมณ์ สมองและหัวใจ สายตา) กระทบทิศที่มุมแหลม/ปล่องไฟชี้และคนในบ้านที่อยู่ตรงนั้น"
            case "baihu": return "① ถ่วง (ทำก่อน·ฟรี): เพิ่มโคมไฟตั้งพื้น เฟอร์นิเจอร์สูง หรือต้นไม้สูงทางซ้าย (มังกรเขียว) ให้สมดุลความสูงสายตา → ผล: ถ่วงสมดุลพลังห้องนั่งเล่น/ห้องหนังสือ ลดแรงกดด้านขวา\n② บัง (ต้นทุนต่ำ): ถ้าด้านขวามีงานก่อสร้างหรือตึกสูง ม่านหนาที่หน้าต่างขวา → ผล: บังเสียงและการรบกวนทางสายตา\n③ สะกด (ทางเลือก): วางศิลาไท่ซานหรือกิเลนทางซ้าย → ผล: เสริมเชิงสัญลักษณ์เท่านั้น\n→ ผลต่อครอบครัว: คนคิดร้ายลับหลัง สตรีในบ้านทะเลาะและบาดเจ็บ (ผู้หญิงในบ้านรับรู้ชัดกว่า) กระทบทิศเสือขาวทางขวาและคนในบ้านที่อยู่ตรงนั้น"
            case "gejiao": return "① บัง (ทำก่อน·ฟรี): วางกระถางสูงหรือสวนกระถางที่ระเบียง/หน้าต่างด้านติดถนน → ผล: กันกระแสเร็ว ครอบคลุมด้านติดถนน\n② กั้น (ต้นทุนต่ำ): เปลี่ยนกระจกหนาหรือม่านสองชั้นที่หน้าต่างติดถนนลดเสียง → ผล: ลดเสียงและสายตารบกวน\n③ สะกด (ทางเลือก): วางปี่เซียะหรือศิลากั้นตังหันทางถนน/น้ำ → ผล: มีผลเฉพาะทิศนั้น เสริมได้ตามต้องการ\n→ ผลต่อครอบครัว: เงินไหลออกและสุขภาพ (ความชื้นไม่สบาย ค่าใช้จ่ายเพิ่ม) กระทบทิศที่น้ำ/ถนนประชิดและคนในบ้านที่อยู่ตรงนั้น"
            default: return remedySolution
            }
        case .id:
            switch id {
            case "tianzhan": return "① Halau (lakukan dulu·gratis): Taruh deretan tanaman berdaun lebar lebih tinggi dari kusen (monstera, pohon uang) atau tirai tebal di jendela/balkon yang menghadap celah gedung. → Efek: Meredam angin dan tekanan visual dari celah; mencakup jendela/balkon yang menghadap celah.\n② Sekat (biaya rendah): Jika pintu depan segaris dengan jendela menghadap celah, taruh kabinet setengah tinggi atau skrin tembus pandang di pintu masuk agar tidak tembus pandang. → Efek: Menghentikan aliran tembus, menstabilkan sirkulasi udara rumah.\n③ Tanam (opsional): Gantung cermin Bagua cembung atau Shan Hai Zhen menghadap celah, miring ke bawah 3-5°, jangan arahkan ke jendela tetangga. → Efek: Hanya bekerja pada arah yang menghadap itu; jaga kerukunan tetangga.\n→ Dampak keluarga: Terutama kesehatan orang tua dan anggota yang sering keluar-masuk (kepala, tulang tidak nyaman, risiko kecelakaan) serta kehilangan uang; memengaruhi arah menghadap celah dan anggota keluarga di sana."
            case "luchong": return "① Halau (lakukan dulu·gratis): Taruh batu ambang atau keset di pintu dan tirai di dalam; taruh tanaman tinggi di jendela menghadap jalan. → Efek: Meredam tekanan jalan lurus yang mengarah ke pintu; mencakup pintu utama dan jendela menghadap.\n② Sekat (biaya rendah): Tambahkan pagar rendah atau skrin di luar agar jalur masuk berbelok. → Efek: Mengubah aliran langsung menjadi pelan; menguntungkan seluruh rumah.\n③ Tanam (opsional): Gantung Shan Hai Zhen atau cermin Bagua di atas pintu, agak miring ke bawah ke arah jalan, jangan arahkan ke tetangga. → Efek: Hanya bekerja pada arah hadap.\n→ Dampak keluarga: Anggota yang sering bepergian (komuter) rentan kecelakaan, cedera dan kehilangan uang; rezeki rumah goyah; memengaruhi arah jalan lurus dan mereka yang lalu-lalang."
            case "fangong": return "① Halau (lakukan dulu·gratis): Susun tanaman atau pot melengkung di jendela/balkon sisi busur untuk membuat penyangga setengah lingkaran. → Efek: Meredam tekanan lengkung yang menghadap rumah; mencakup jendela/balkon sisi busur.\n② Sekat (biaya rendah): Taruh meja bundar, karpet bundar atau sofa melengkung di sisi busur, hindari furnitur bersudut tajam. → Efek: Melunakkan energi yang menarik keluar, menstabilkan area itu.\n③ Tanam (opsional): Taruh obsidian, batu Shi Gandang atau Koin Lima Kaisar di sisi busur, menghadap keluar. → Efek: Hanya bekerja pada arah itu; penguatan opsional.\n→ Dampak keluarga: Hubungan suami-istri mendingin, pertengkaran dan pengeluaran (paling terasa pada istri dan pasangan); rumah sulit menahan energi; memengaruhi arah lengkung ke luar dan anggota keluarga di sana."
            case "tantou": return "① Halau (lakukan dulu·gratis): Tutup tirai tipis atau kerai pada siang hari di jendela menghadap sudut bangunan yang mengintip. → Efek: Memblokir pertemuan pandangan; mencakup jendela itu.\n② Sekat (biaya rendah): Taruh tanaman tinggi (ivy, pothos) di kusen untuk menutupi sudut. → Efek: Isolasi visual, mengurangi rasa diawasi.\n③ Tanam (opsional): Gantung cermin Bagua cembung ke arah bangunan pengintip, jangan ke jendela tetangga. → Efek: Hanya bekerja pada arah itu.\n→ Dampak keluarga: Orang yang mengintip, pencurian dan masalah hukum (privasi dan rasa aman terganggu); memengaruhi arah bangunan menonjol dan anggota keluarga di sana."
            case "chuanxin": return "① Sekat (lakukan dulu·gratis): Jika pintu depan segaris dengan jendela belakang, taruh kabinet, skrin atau tirai tebal di tengah jalur. → Efek: Menghentikan aliran tembus, menstabilkan sirkulasi udara.\n② Halau (biaya rendah): Tambahkan karpet, tanaman di kusen dan furnitur berat di dekat dinding untuk memperlambat aliran udara. → Efek: Memperlambat udara, memperbaiki kenyamanan dan stabilitas.\n③ Tanam (opsional): Taruh Koin Lima Kaisar atau Shi Gandang kecil di dalam ambang pintu. → Efek: Area masuk; penguatan opsional.\n→ Dampak keluarga: Kesehatan penghuni terganggu, tidur tidak nyenyak (paling terasa bagi yang tidur di jalur tembus); energi rumah tertembus; memengaruhi arah jalur tembus dan keluarga di sana."
            case "huoxing": return "① Halau (lakukan dulu·gratis): Pasang tirai tipis atau kerai di jendela menghadap sudut tajam. → Efek: Penyangga visual; mencakup jendela itu.\n② Sekat (biaya rendah): Taruh tanaman air (pothos, ivy) di kusen untuk mengurangi kekeringan. → Efek: Menyelaraskan kekeringan api di area itu.\n③ Tanam (opsional): Gunakan obsidian, kristal atau dekorasi biru untuk menekan api; hindari merah di arah ini. → Efek: Hanya bekerja pada arah itu; hindari merah.\n→ Dampak keluarga: Anggota mudah marah, bertengkar, risiko kebakaran (temperamen, kesehatan jantung/kepala dan mata); memengaruhi arah yang ditunjuk sudut tajam/cerobong dan keluarga di sana."
            case "baihu": return "① Seimbang (lakukan dulu·gratis): Tambahkan lampu lantai, furnitur tinggi atau tanaman tinggi di sisi kiri (Naga Hijau) untuk meratakan tinggi visual. → Efek: Menyeimbangkan energi ruang tamu/ruang kerja, meredakan tekanan sisi kanan.\n② Halau (biaya rendah): Jika ada konstruksi atau gedung tinggi di kanan, gantung tirai tebal di jendela kanan. → Efek: Memblokir kebisingan dan gangguan visual.\n③ Tanam (opsional): Taruh batu Taishan atau ornamen Qilin di kiri. → Efek: Hanya penguatan simbolis.\n→ Dampak keluarga: Fitnah, pertikaian perempuan rumah dan cedera tak terduga (paling terasa pada wanita di rumah); memengaruhi arah Harimau Putih di kanan dan keluarga di sana."
            case "gejiao": return "① Halau (lakukan dulu·gratis): Taruh pot tanaman tinggi atau taman pot di balkon/jendela sisi jalan. → Efek: Menyangga aliran cepat; mencakup sisi jalan.\n② Sekat (biaya rendah): Gunakan kaca lebih tebal atau tirai ganda di jendela sisi jalan untuk mengurangi kebisingan. → Efek: Mengurangi suara dan gangguan visual.\n③ Tanam (opsional): Taruh Pixiu atau Shi Gandang menghadap jalan/air. → Efek: Bekerja pada arah itu; penguatan opsional.\n→ Dampak keluarga: Kebocoran keuangan dan kesehatan (ketidaknyamanan lembap, uang keluar); memengaruhi arah air/jalan yang menyapu dan keluarga di sana."
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
            remedySolution: "① 挡（先做·免费）：正对楼缝的窗前或阳台，摆一排高过窗台的阔叶绿植（龟背竹、发财树），或加厚纱帘。→ 影响：减轻夹缝直冲的气流与视觉压迫，覆盖对缝的窗和阳台。\n② 隔（低成本）：若大门与对缝窗成一直线，玄关放半高鞋柜或镂空屏风，进门不一眼望穿。→ 影响：阻断穿堂直通，稳定全屋气流。\n③ 镇（可选）：正对缝口挂凸面八卦镜或山海镇，镜面朝外、略下倾3-5度，勿照邻家门窗。→ 影响：仅作用该冲射方位；注意邻里关系。\n→ 家人影响：主家中长辈与经常出入者健康（头部、骨骼不适与血光之虞）及正财破耗；影响正对楼缝的方位及该处常活动的家人。"
        ),
        ExteriorShaItem(
            id: "luchong",
            name: "路冲煞",
            aliases: "枪煞 · 箭煞",
            visualFeature: "笔直道路或长廊直刺明堂大门、阳台或主卧窗户，车流直逼",
            metaphysicsHarm: "一条直路一条枪，车流动能化作无形猛兽直冲宅气，主破耗连连、意外伤灾、人丁不安",
            severity: .critical,
            classicalText: "《堪舆指要》云：直冲门前最难当，暗箭伤人人莫详。",
            remedySolution: "① 挡（先做·免费）：门口放门槛石或门垫，门内挂门帘；正对路的窗台放一盆高绿植。→ 影响：弱化直路冲门的压迫感，覆盖大门与正冲窗。\n② 隔（低成本）：门外加半高绿篱或屏风，让进门动线拐个弯。→ 影响：直冲气流转为缓行，全宅受益。\n③ 镇（可选）：大门上方挂山海镇或八卦镜，朝路方向微下倾，勿照邻居。→ 影响：仅针对冲射方位。\n→ 家人影响：主经常出入的家人（早晚通勤者）意外、血光与破财，家运不稳；影响直冲来路方向及出入之人。"
        ),
        ExteriorShaItem(
            id: "fangong",
            name: "反弓水 / 反弓路",
            aliases: "割脚镰 · 弯刀煞",
            visualFeature: "高架桥、河流或弧形道路如拉满之弓箭，弧顶凸面正对房屋",
            metaphysicsHarm: "离心力将财气与贵人运向外甩离，形成无情冲撞，主子孙叛逆、破大财、官讼缠身",
            severity: .warning,
            classicalText: "《地理五诀》云：反弓无情水，犹如弯刀割。居者难安泰，钱财随水折。",
            remedySolution: "① 挡（先做·免费）：反弓一侧窗外摆弧形绿植或盆栽，形成半圆缓冲。→ 影响：缓解弧顶正对的压迫感，覆盖反弓侧窗/阳台。\n② 隔（低成本）：室内反弓方向放圆形茶几、地毯或弧形沙发，避免直角家具直冲。→ 影响：柔化离心气流，稳定该区域气场。\n③ 镇（可选）：反弓方位放黑曜石、石敢当或五帝钱，面朝弧外。→ 影响：仅针对该方位；可选强化。\n→ 家人影响：主夫妻感情淡薄、是非退财（女主人与夫妻关系感受最明显），家宅难聚气；影响反弓弧外方向及常在此起居的家人。"
        ),
        ExteriorShaItem(
            id: "tantou",
            name: "探头煞",
            aliases: "窥视煞 · 偷窥小人",
            visualFeature: "前方建筑物后方隐隐露出一角或圆顶，犹如有人探首窥视宅内",
            metaphysicsHarm: "暗中窥测，主招引暗室小人、遭盗窃欺诈、婚外暗昧之情或突发名誉受损",
            severity: .warning,
            classicalText: "《撼龙经》云：头低偷窥探，小人暗中乱。纵有万贯财，亦防暗中算。",
            remedySolution: "① 挡（先做·免费）：对探头方向的窗，白天拉上纱帘或百叶。→ 影响：阻断视线交叉，覆盖该窗。\n② 隔（低成本）：窗台摆高绿植（长春藤、绿萝），遮挡探头角。→ 影响：视觉隔离，缓解被窥感。\n③ 镇（可选）：凸面八卦镜朝探头方挂，勿照邻家门窗。→ 影响：仅针对该方位。\n→ 家人影响：主小人窥视、防盗与官非口舌，家人隐私与安全感受扰；影响探头方向及该处活动的家人。"
        ),
        ExteriorShaItem(
            id: "chuanxin",
            name: "穿心煞",
            aliases: "悬针煞 · 地底贯通",
            visualFeature: "楼宇下方有地铁、隧道、车道贯穿，或正门正对直通后窗",
            metaphysicsHarm: "地气空洞不稳定，泄气极速，主财气不聚、肠胃脾胃虚寒、居者缺乏安全感",
            severity: .warning,
            classicalText: "《青囊经》云：地脉不凝，宅气空腾。穿心走气，贫困无依。",
            remedySolution: "① 隔（先做·免费）：门与后窗成直线时，在动线正中放玄关柜、屏风或挂厚门帘。→ 影响：阻断穿堂直通，稳定全屋气流。\n② 挡（低成本）：地面铺地毯、窗台放绿植、重家具靠墙，减缓气流速度。→ 影响：降低直穿气流速度，改善室温与安稳感。\n③ 镇（可选）：入户门槛内放五帝钱或小号石敢当。→ 影响：入户区域；可选强化。\n→ 家人影响：主居住者健康不安、睡眠受扰（睡在穿心线上的人影响最大），家宅气场被穿破；影响穿心路径方向及该处家人。"
        ),
        ExteriorShaItem(
            id: "huoxing",
            name: "火形煞",
            aliases: "尖角煞 · 尖峰冲煞",
            visualFeature: "对面大厦屋角、三角形顶棚、加油站、变电站或红色高耸尖塔直刺",
            metaphysicsHarm: "火金相克，火燥生煞，主口舌官非、视力疾厄、皮肤炎肿、脾气暴躁易燃",
            severity: .warning,
            classicalText: "《疑龙经》云：尖角冲克火星飞，灾殃临门人不归。",
            remedySolution: "① 挡（先做·免费）：正对尖角的窗挂纱帘或百叶。→ 影响：视觉缓冲，覆盖该窗。\n② 隔（低成本）：窗台摆水养植物（水培绿萝、常春藤），缓解干燥。→ 影响：调和火燥，覆盖该区域。\n③ 镇（可选）：放黑曜石、水晶或蓝色装饰物压火气；此方位忌红色。→ 影响：仅针对该方位；忌红色。\n→ 家人影响：主家人急躁口舌、火灾之虞（脾气、心脑血管与眼目健康）；影响尖角/烟囱所指方向及该处家人。"
        ),
        ExteriorShaItem(
            id: "baihu",
            name: "白虎煞",
            aliases: "虎强龙弱 · 白虎抬头",
            visualFeature: "住宅右侧建筑物明显高过左侧（青龙方），或右侧有大型动土施工",
            metaphysicsHarm: "青龙委靡，白虎张狂，主阴盛阳衰、妇人专权暴烈、男丁运势受压抑阻滞",
            severity: .minor,
            classicalText: "《水龙经》云：宁叫青龙高万丈，莫教白虎昂半寸。",
            remedySolution: "① 补（先做·免费）：左侧（青龙方）加落地灯、高大家具或高大绿植，平衡左右视觉高度。→ 影响：平衡客厅/书房气场，缓解右侧压迫。\n② 挡（低成本）：右侧若临施工或高楼，靠右窗挂厚窗帘遮挡。→ 影响：遮挡噪音与视线干扰。\n③ 镇（可选）：左侧放泰山石或麒麟摆件。→ 影响：仅象征性补强。\n→ 家人影响：主小人暗算、女眷是非与意外伤灾（家中女性感受较明显）；影响右侧白虎方位及该处家人。"
        ),
        ExteriorShaItem(
            id: "gejiao",
            name: "割脚煞",
            aliases: "割脚水 · 贴足急流",
            visualFeature: "高架桥、贴身快速车道或汹涌急流紧挨楼脚，无明堂缓冲地带",
            metaphysicsHarm: "气流疾走拔除地气，财运大起大落，根基虚浮，青年得志但晚运易倾颓",
            severity: .minor,
            classicalText: "《地理正宗》云：水逼楼脚急，根浅风难立。",
            remedySolution: "① 挡（先做·免费）：临路一侧阳台或窗前摆高盆绿植或花坛。→ 影响：缓冲急流，覆盖临路侧。\n② 隔（低成本）：临路窗换厚玻璃或加双层窗帘，降低噪音。→ 影响：减少声煞与视觉干扰。\n③ 镇（可选）：近路/水方向放貔貅或石敢当。→ 影响：该方位；可选强化。\n→ 家人影响：主退财与健康（居住者湿气不适、财运外流）；影响近水/高架割脚方向及该处家人。"
        )
    ]
}
