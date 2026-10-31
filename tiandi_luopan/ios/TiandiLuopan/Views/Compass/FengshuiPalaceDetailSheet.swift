import SwiftUI

// MARK: - 居家风水八方详勘与空间布局全鉴弹窗 (Fengshui Palace Detail Sheet)

public struct FengshuiPalaceDetailSheet: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    private var palaces: [(gua: String, dir: String, elem: String, member: String, body: String, bestRoom: String, taboo: String, desc: String)] {
        let l = LocalizationManager.shared
        return [
            (l.t("gua_qian"), l.t("dir_nw"), l.t("elem_metal"), l.t("member_father"), l.t("body_head"), l.t("best_room_qian"), l.t("taboo_qian"), l.t("desc_qian")),
            (l.t("gua_kan"), l.t("dir_n"), l.t("elem_water"), l.t("member_middle_son"), l.t("body_kidney"), l.t("best_room_kan"), l.t("taboo_kan"), l.t("desc_kan")),
            (l.t("gua_gen"), l.t("dir_ne"), l.t("elem_earth"), l.t("member_youngest_son"), l.t("body_spleen"), l.t("best_room_gen"), l.t("taboo_gen"), l.t("desc_gen")),
            (l.t("gua_zhen"), l.t("dir_e"), l.t("elem_wood"), l.t("member_eldest_son"), l.t("body_liver"), l.t("best_room_zhen"), l.t("taboo_zhen"), l.t("desc_zhen")),
            (l.t("gua_xun"), l.t("dir_se"), l.t("elem_wood"), l.t("member_eldest_daughter"), l.t("body_nerve"), l.t("best_room_xun"), l.t("taboo_xun"), l.t("desc_xun")),
            (l.t("gua_li"), l.t("dir_s"), l.t("elem_fire"), l.t("member_middle_daughter"), l.t("body_heart"), l.t("best_room_li"), l.t("taboo_li"), l.t("desc_li")),
            (l.t("gua_kun"), l.t("dir_sw"), l.t("elem_earth"), l.t("member_mother"), l.t("body_belly"), l.t("best_room_kun"), l.t("taboo_kun"), l.t("desc_kun")),
            (l.t("gua_dui"), l.t("dir_w"), l.t("elem_metal"), l.t("member_youngest_daughter"), l.t("body_mouth"), l.t("best_room_dui"), l.t("taboo_dui"), l.t("desc_dui"))
        ]
    }
    
    public var body: some View {
        return NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<palaces.count, id: \.self) { idx in
                        let p = palaces[idx]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("【\(p.gua)\(lang.t("gua_suffix")) · \(p.dir)】")
                                        .font(.adaptive(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Text(p.elem)
                                        .font(.adaptive(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.12))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Spacer()
                                Text("\(lang.t("family_member_corresp"))\(p.member)")
                                    .font(.adaptive(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(p.desc)
                                .font(.adaptive(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.t("suitable_spaces"))
                                        .font(.adaptive(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                    Text(p.bestRoom)
                                        .font(.adaptive(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.t("forbidden_layouts"))
                                        .font(.adaptive(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                    Text(p.taboo)
                                        .font(.adaptive(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
            .navigationBarTitle(lang.t("palace_sheet_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
