# 住宅空间测绘版

当前 iOS 版本面向量房记录、户型方案整理和装修前用量估算。旧风水功能不属于当前用户流程。产品差异由真实可用的空间工作流体现；不承诺 App Store 审核结果。

## 本次新增能力

| 能力 | 入口 | 计算和使用边界 |
| --- | --- | --- |
| 面积与周长统计 | 户型编辑 → 空间用量与报告；住宅项目 → 对应项目同名按钮 | 使用输入的物理尺寸与房间多边形。门标记不作为地面；合计不等同于产权面积、建筑面积或法定套内面积。 |
| 轮廓检查 | 空间用量与报告 | 识别无效轮廓、越界及房间重叠。多边形按轮廓判断，接触墙边不算面积重叠。存在问题时停用材料估算和方案比较。 |
| 装修材料估算 | 空间用量与报告 → 选择房间 | 可输入墙高、门窗及不涂刷面积、地材每包面积、涂料单遍覆盖率、遍数与损耗。参数与房间选择可单独保存至对应项目，随备份恢复；关闭时提示未保存的修改。多窗口保存会检查项目和参数是否已被修改。 |
| 已保存户型对比 | 住宅项目，至少保存两个项目 | 比较面积、内周长、房间数、卧室数及厨卫面积。显示 B − A，不生成优劣或房屋品质评分。 |
| PDF 空间报告 | 空间用量与报告 → 导出 PDF | A4 分页，包含纵横同一比例的轮廓示意、编号、面积和周长；估算有效时附所选房间与全部计算参数。图不是按纸张比例校准的施工图。报告不附底图照片或个人资料。 |
| CSV 材料清单 | 空间用量与报告 → 导出 CSV | UTF-8 编码，包含房间面积、周长、参与估算状态、有效参数及材料用量，可在表格软件中核算。尚不包含材料价格、人工费或施工报价。 |
| 几何项目备份 v2 | 住宅项目 → 导出备份 | 支持新设备恢复底图、房间多边形和三维几何。对外不包含旧吉凶分析、家人命理、购买凭证或旧勘测结论。仍支持导入旧格式，并清理旧分析字段。 |

### 材料计算

- 地材面积 = 所选房间面积合计 × (1 + 损耗率)。
- 包数 = 地材面积 ÷ 每包覆盖面积，向上取整。
- 单遍墙面积 = 所选房间内周长合计 × 墙高 − 输入扣除面积。
- 涂料升数 = 单遍墙面积 × 涂刷遍数 ÷ 每升单遍覆盖面积 × (1 + 损耗率)。

不含天花板。共用墙两侧分别算各房间的内墙面；门窗扣除值应根据选择的房间及实际施工面填写。不得将估算代替现场复核、施工清单或结构安全判断。

## 提交材料草案

以下内容需与最终真机验收结果一致后使用。保持现有 Bundle ID 和购买 ID，更新商品对外名称和描述。

### 中文商店文案

副标题：住宅测量、户型编辑与材料估算

描述：

记录房间尺寸，整理住宅户型，并把现场记录转成可分享的空间成果。

- 使用兼容设备进行 AR 测量或 LiDAR RoomPlan 扫描，也可导入户型底图并手工输入尺寸。
- 编辑房间用途、位置和大小，查看三维空间模型，保存多套住宅项目。
- 统计房间面积和内周长，检查房间轮廓重叠与越界。
- 按选择的房间估算地材整包数量与涂料用量，自行调整损耗、覆盖率和门窗扣除面积。
- 保存每个项目的估算参数，导出 CSV 材料清单用于后续核算。
- 对比两个已保存方案的面积与空间构成。
- 导出 PDF 空间报告及项目备份；会员可使用 CAD / DXF 导出等高级空间工具。

尺寸和面积为估算，受设备、环境及操作影响。手工模型基于输入尺寸；请现场复核重要尺寸。LiDAR 扫描需要支持的设备。

### English store copy

Subtitle: Measure, plan and estimate

Description:

Record room dimensions, organise floor plans and share useful spatial records.

- Measure with AR or scan with RoomPlan on compatible LiDAR devices. Import a floor-plan image and enter dimensions manually when needed.
- Edit room types, positions and sizes; inspect a 3D model and save multiple home projects.
- Calculate room areas and perimeters, with checks for overlapping and out-of-bounds outlines.
- Estimate flooring packs and paint volume for selected rooms using adjustable waste, coverage and opening deductions.
- Save estimate settings with each project and export CSV material lists for spreadsheet use.
- Compare the geometry and room composition of two saved plans.
- Share paginated PDF space reports and portable project backups. Membership provides CAD / DXF export and other advanced spatial tools.

Dimensions and material quantities are estimates. Manual models use entered dimensions. Verify important measurements on site. LiDAR scanning requires compatible hardware.

### 审核备注草案

本构建将产品核心用途调整为住宅空间测量、户型编辑、三维记录、材料估算和成果分享。此前的占卜与吉凶分析不再出现在用户流程中。

请使用最终版本号与构建号替换提交说明，并附演示视频：

1. 无 LiDAR 路径：户型编辑 → 输入画布尺寸 → 添加两个不重叠的房间 → 保存 → 空间用量与报告 → 调整参数 → 导出 PDF。
2. 项目路径：住宅项目 → 保存项目快照 → 编辑并保存另一套方案 → 已保存户型对比。
3. 支持设备路径：空间测量 → RoomPlan 扫描 → 完成扫描 → 查看模型与导入户型 → 检查实际导出结果。

不能将未验证功能、模拟场景或手工模型描述为真实硬件测量。

## 提交前必须在 Mac / 真机完成

- 编译主 App 与 XCTest target；执行 `FunctionalRegressionTests`。本次新增测试覆盖矩形比例、多边形面积与周长、接触边和重叠、异常尺寸、用量计算、备份去除旧字段、重复 ID 和 PDF 分页。
- 简体中文、繁体中文、English 及其余五种语言下检查新增页面、长标签和数字输入；逗号小数分隔符设备也需检查。
- 检查 PDF 的中文、英文、泰文等字形和分页；将 20 × 5 m 户型与方形户型对照，确认图形未被拉伸。
- 新安装与旧版本升级分别检查首页、深链、通知、历史档案、报告、备份和购买恢复。旧通知不再展示。
- 备份到 Files，再从另一安装环境导入，核对底图、多边形和三维几何。新格式不转移购买授权，购买恢复继续由 StoreKit 校验。
- 分别修改两个项目的估算参数，重新打开与备份恢复后核对数值；在两个窗口同时编辑同一项目，确认旧窗口不能覆盖新保存的参数。
- 导出包含中文、逗号、换行或引号的房间名称至 CSV，在 Numbers / Excel 中打开核对；核实清单内的选择状态、单位和参数。不要把无效轮廓或无效输入当作完整材料清单。
- 同一住宅同时保留实测原模型和手工修改模型，保存、导出备份、导入后分别核对，确保两份模型都存在。
- 更新 App Store Connect 中现有年度及终身商品的本地化名称与说明，停用旧单次商品销售；不以修改本地字符串代替更新商店商品元数据。
- 替换商店截图和描述；在 Safari 验证应用内链接的隐私、条款和支持页面与住宅测绘版一致且可访问。

## 本地验证说明

当前 Linux 环境可运行工程结构、Swift 括号检查、本地化完整性和 Python 工程检查测试；没有 Xcode 或 Swift 编译器，不能替代 iOS 编译、XCTest 和硬件测量验收。

本次已通过：46 个 App Swift 文件的括号检查、两个编译源阶段共 53 个条目的结构与本地类型依赖检查、八种语言每种 459 个键的完整性检查，以及 12 项不依赖外部网站的 Python 测试。两轮共新增 15 项 XCTest，尚未在此环境执行。

`tools/test_check_swift_target_dependencies.py` 中的 `test_public_terms_are_complete_in_all_supported_languages` 依赖仓库外的 `../website/i18n`。该外部网站不在本次可写工作区内；其内容或失败不能当作本仓库 iOS 代码的编译结论。
