import SwiftUI

// MARK: - 罗盘顶部数据仪表盘与天心十道状态视图 (Compass Header View)

public struct CompassHeaderView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    
    public init() {}
    
    public var body: some View {
        let state = motion.headingState
        let sitFacingText = "\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix"))"
        let palaceText = state.facingMountain.localizedPalace + lang.t("palace_suffix")

        VStack(spacing: 8) {
            // 顶栏 1 (最顶部): 真太阳时与双轴倾角 (俯仰 / 横滚)
            ViewThatFits(in: .horizontal) {
                HStack {
                    solarTimeLabel
                    Spacer(minLength: 8)
                    pitchRollLabel
                }
                VStack(alignment: .leading, spacing: 3) {
                    solarTimeLabel
                    pitchRollLabel
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)
            .padding(.horizontal, 12)

            // 顶栏 2: 核心度数与坐向徽章
            // 窄屏 (iPhone / Duo 外屏)：英/印尼/泰/越译文字比中文长很多，
            // 尤其泰语词间无空格不会主动断行，度数行、坐向标题、宫位徽章和
            // 两个圆按钮挤在同一 HStack 里会互相穿插重叠。改为两行堆叠：
            // 第一行只放度数 + 按钮，第二行整行放坐向标题 + 宫位徽章。
            // 宽屏 (iPad / Duo 内屏分栏) 仍保持原来的一行横排。
            Group {
                if horizontalSizeClass == .compact {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            degreeBlock(state: state)
                            Spacer()
                            lockButtons
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(sitFacingText)
                                .adaptiveFont(size: 18, weight: .bold, design: .serif)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            palaceBadge(text: palaceText)
                        }
                        fenjinDescLine(state: state)
                    }
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        degreeBlock(state: state)

                        // 坐向与二十四山
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(sitFacingText)
                                    .adaptiveFont(size: 18, weight: .bold, design: .serif)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.6)
                                    .fixedSize(horizontal: false, vertical: true)

                                palaceBadge(text: palaceText)
                            }
                            fenjinDescLine(state: state)
                        }

                        Spacer()
                        lockButtons
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        // iPad 宽屏单列下顶部仪表会被拉得很宽，度数在左、按钮在右，中间一片空白；
        // 限宽 720pt 居中，保持与内容区同一视觉宽度。
        // 分栏时铺满左栏；单列宽屏仍保留 720 上限保证长行文字可读性。
        .frame(maxWidth: AdaptiveLayout.isTwoPane(
            horizontal: horizontalSizeClass, vertical: verticalSizeClass,
            form: layoutForm) ? .infinity : 720)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: - 顶栏复用块（窄屏两行堆叠 / 宽屏一行横排共用）
    private func degreeBlock(state: CompassHeadingState) -> some View {
        HStack(alignment: .top, spacing: 2) {
            Text(String(format: "%.1f", state.facingAngle))
                .adaptiveFont(size: 34, weight: .black, design: .rounded)
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: true, vertical: false)
            Text("°")
                .adaptiveFont(size: 17, weight: .bold)
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.8))
        }
    }

    private var lockButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                motion.resetManualOffset()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Button(action: {
                motion.toggleLock()
            }) {
                Image(systemName: motion.isLocked ? "lock.fill" : "lock.open")
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(motion.isLocked ? Color.yellow : Color.white)
                    .frame(width: 32, height: 32)
                    .background(motion.isLocked ? Color.yellow.opacity(0.25) : Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }

    private func palaceBadge(text: String) -> some View {
        Text(text)
            .adaptiveFont(size: 11, weight: .semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.25))
            .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
            .cornerRadius(4)
    }

    private func fenjinDescLine(state: CompassHeadingState) -> some View {
        Text(state.fenJinDesc)
            .adaptiveFont(size: 12, weight: .medium)
            .foregroundColor(state.isJianXiang ? Color.orange : Color(red: 0.8, green: 0.8, blue: 0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var solarTimeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .adaptiveFont(size: 11)
                .foregroundColor(Color.orange)
            Text("\(lang.t("true_solar_time_prefix")) \(motion.trueSolarTimeStr)")
                .adaptiveFont(size: 11, weight: .medium)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var pitchRollLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(motion.isLevel ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text("\(lang.t("pitch_label")) \(String(format: "%.1f", motion.pitch))° / \(lang.t("roll_label")) \(String(format: "%.1f", motion.roll))°")
                .adaptiveFont(size: 11, weight: .regular, design: .monospaced)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
