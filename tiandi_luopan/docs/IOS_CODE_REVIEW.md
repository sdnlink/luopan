# iOS 源码审查与功能完整性报告

审查基准：2026-11-01。范围为 `ios/TiandiLuopan` 下已加入 Xcode target 的 Swift 源码，并以源码实际调用关系为准。本文补充 `docs/IOS_ANALYSIS.md`，重点回答四个问题：模块做什么、结果是否可信、锦囊是否覆盖、福宅天机长卷是否包含全部当前结果。

## 结论

页面和基础能力基本齐全：罗盘、AR 形煞、户型审计、ARKit/LiDAR/RoomPlan、玄空/八宅/三合/奇门/紫白/择日、长卷导出、StoreKit 会员和本地化均有入口和实现。本轮已修复源码与文档中发现的主要工程缺陷，长卷现在会消费一次性冻结的当前户型审计和室内外现场档案，并输出已接入模块的完整数组与锦囊。

仍不能把结果描述为“传统流派绝对准确”或“原始测绘文件已嵌入长图”：三合、空间形煞和 AR 识别仍是规则化/启发式结果，完整年/月/日三煞算法尚未实现，原始 RoomPlan/ARWorldMap/USDZ 需要单独导出。真机传感器、ARKit、Photos、StoreKit 沙盒和大数据量长图压力测试也需要在 macOS/Xcode 环境补做。

传统堪舆算法存在流派差异。以下将“可由代码直接证明的错误/遗漏”和“实现为启发式、需要业务确认的简化”分开描述，避免把启发式结果宣传成物理测量或绝对吉凶。

## 本轮已修复

本轮代码修复已覆盖此前报告中的主要工程缺陷：

- 奇门洛书飞布改为 `1→8→3→4→9→2→7→6` 外围路径，中宫独立处理，值符宫改为安全回退；
- 定位失败和无效真北会清空坐标、磁偏角、真北和真太阳时旧状态；
- 户型缺角检查扩展为 3×3 外圈 8 个区域，户型导出按完整报告动态扩展，不再 `prefix(6)`；
- 天机长卷接收当前户型审计、AR/室内空间档案，三合、紫白、八宅改为全量输出；现场档案存在时使用当前记录，不再用静态形煞列表冒充现场结果；
- 长卷改为动态文本测量和更大画布，冻结报告输入后再后台渲染；
- 玄空中宫 trigram、五黄/二黑优先级和财富动水建议已修正；
- AR 形煞记录保存采集时朝向，八宫按报告基准朝向分组，室内外档案支持本地恢复；
- 择日将坐山冲克移到 `sittingClashWarning`，不再错误填入 `sanShaWarning`；旧户型商品 ID 在交易监听中保留兼容记账。

以下“问题”部分仍描述实现边界和待补能力；已修复条目不应再按原严重程度重复计入发布阻断。

## 模块覆盖矩阵

| 模块 | 主要源码和入口 | 实际功能/输出 | 锦囊覆盖 | 准确性与限制 | 是否进入福宅天机长卷 |
| --- | --- | --- | --- | --- | --- |
| 罗盘与传感器 | `CompassMotionManager.swift`、`CompassMainView.swift` | Core Location 航向/定位、Core Motion 姿态/磁场、滤波、真北/磁北、二十四山、水平仪、真太阳时 | 罗盘详勘、分金、空亡、宫位建议存在 | 真机磁场、权限、姿态生命周期未实测；定位失败现在会清除定位快照并回退磁北 | 长卷写角度、坐山/向山、坐标和真太阳时摘要；完整罗盘详情仍在罗盘页 |
| 地磁与历法 | `WorldMagneticModel.swift`、`SolarTimeCalculator.swift`、`SolarTermsData.swift` | WMM 偏角后备、经度校正真太阳时、节气、四柱 | 作为各引擎输入，无独立完整方案 | WMM/节气边界需真机和历法基准回归；各引擎仍可能使用不同时间快照 | 只有摘要和重新计算结果 |
| 定向数据 | `Mountain24.swift`、`Fenjin120Data.swift`、`Hexagram64.swift` | 二十四山、120 分金、六十四卦、兼向/替卦字段 | 分金等级、卦名和基础解释存在 | 兼向/空亡的完整流派解释仍需领域回归 | 长卷写第一卷摘要；完整明细仍在定向页 |
| 玄空飞星 | `FlyingStarsEngine.swift`、`XuanKongGridView.swift` | 三元九运、山/向星、旺山旺向、二五/三七/七九判断和财/健康/调理建议 | 九宫格每宫有评价，财富/健康/调理建议存在；五黄/二黑优先提示 | 传统流派参数仍需固定样例回归 | 长卷写格局、三段建议和九宫逐宫结果 |
| 八宅与三合 | `BaZhaiEngine.swift`、`SanHeWaterEngine.swift`、`BaZhaiView.swift` | 宅卦八宫游年、八路黄泉、八煞、十二长生水法 | 八宅各宫 suggestion、黄泉/八煞 remedy、24 山长生 lore 存在 | 三合是项目规则化映射，未覆盖完整阴阳龙、顺逆、水口和来去水证据 | 长卷全量写八宅八宫和 24 山水法 |
| 奇门遁甲 | `QimenEngine.swift`、`QimenDunjiaView.swift` | 节气阴阳遁、局数、九宫、八门、九星、八神、天干和出行方 | 页面可看九宫、门星神 lore、避忌方 | 洛书路径已修正；仍是离线简化排盘，需固定日期/流派回归 | 长卷写标题、最佳/避忌方和九宫全字段 |
| 紫白与择日 | `PurpleWhiteEngine.swift`、`ZeRiEngine.swift`、`PurpleWhiteView.swift` | 流年/流月客星、太岁/岁破/三煞方、四柱、冲克警告 | 紫白每宫 advice、择日宜忌和详情存在；坐山冲克单独标注 | 紫白建议主要按年星，月星参与有限；完整年/月/日神煞仍未实现 | 长卷全量写紫白九宫和择日警告/宜忌 |
| 户型立极 | `FloorplanEngine.swift`、`FloorplanView.swift` | 图片/示例户型、房间编辑、面积质心、八宫分配、房间审计、缺角检查 | 房间与缺角有 lore/solution，正常房间也保留审计结果 | 缺角现查 3×3 外圈 8 区；审计主要使用矩形中心，真实多边形支持未贯穿 | 当前审计写入长卷；独立户型图按完整报告动态扩展 |
| AR 形煞 | `ARVisionView.swift`、`OnDeviceShaAnalyzer.swift`、`ExteriorShaEngine.swift`、`ShaSurveyModels.swift` | Vision 矩形/轮廓几何候选、三帧共识、LiDAR 距离、手动/AI 标注、八宫聚合、化解页 | 八大静态形煞有通用 remedy；现场记录有距离/置信度/严重度并落盘 | 不是训练好的建筑语义模型；置信度是规则分数；八宫按报告基准朝向分组 | 当前现场记录进入长卷；无现场记录时才显示通用知识库 |
| 空间测绘 | `ARSpatialSurveyView.swift`、`ARRoomPlanCaptureView.swift`、`HouseSpatialSurveyModel.swift`、`House3DSpaceViewer.swift`、`VRSpatialSurveyView.swift` | ARKit/LiDAR/RoomPlan/VR 仿真，墙门窗家具、测距、九宫、空间形煞、JSON/ARWorldMap/DXF/USDZ；户型页另有“当前户型3D”推演入口 | 每个 `shaItem` 有 detail/lore/solution，3D 查看器显示来源、实测构件和 VR 房间隔墙 | 规则和阈值是启发式；VR 依赖用户输入的比例尺寸，不能当现场实测；部分动态文案仍有中文硬编码 | 最近一次 `HouseSpatialSurvey`（AR/RoomPlan/VR，按 `scanMethod` 区分）的统计、评分和条目进入长卷 |
| 长卷导出 | `TianJiShuEngine.swift`、`TianJiShuView.swift` | 宣纸长图、预览、相册保存、系统分享、成功后扣天机额度 | 当前接入模块输出完整数组并动态测量文本 | 仍为单张长图而非分页 PDF；`isPro` 参数保留兼容但由视图门控；真机内存/图像限制未实测 | 包含当前罗盘摘要、玄空/奇门/八宅/三合/紫白/择日、户型、AR 和室内测绘结果 |
| 权益与本地化 | `StoreKitIAPManager.swift`、`VIPPaywallSheet.swift`、`LocalizationManager.swift` | StoreKit 2 交易/权益、会员和消耗额度、本地化字典 | 付费入口有门控；8 种语言字典无重复/缺失 | 消耗型余额仍只在本地记账，生产环境需服务端交易账本 | 不属于长卷内容，但决定导出是否可用 |

## 按严重程度的问题

本轮已修复此前可直接证明的工程问题：奇门飞布路径、长卷数据接入与截断、定位失败清理、现场档案持久化与朝向快照、玄空中宫/土煞优先级、择日冲山字段语义，以及旧户型商品交易兼容。下面只保留仍然存在的限制和发布前需要确认的事项。

### P1：算法和现场证据仍需领域回归

- `SanHeWaterEngine.resolveWaterMethod` 是固定四大局和 24 山映射，未表达阴阳龙顺逆、水口、来去水和现场水形证据，只能称规则化辅助结果。
- `HouseSpatialSurveyEngine` 的距离、角度、面积和重叠率均为工程启发式；`HouseSpatialShaItem` 不等同于建筑检测或医学/安全结论。
- `OnDeviceShaAnalyzer` 使用 Vision 几何、比例和深度加权，不是经过验证的建筑语义模型；置信度是规则分数，不能当作统计概率。
- `ZeRiEngine` 已把坐山冲克放入 `sittingClashWarning`，但真正年/月/日三煞方和完整择日神煞仍未实现；`isAuspicious` 只能表示当前轻量检查器没有发现已编码警告。
- WMM、节气边界、真太阳时和各传统流派参数需要固定样例、真机传感器和领域规则回归，当前容器不能替代这些验证。

### P1：长卷是单张长图，仍有工程边界

- 当前长卷接收一次性冻结的户型审计和 `ShaSurveyStore` 档案，输出玄空/奇门九宫、三合全量、紫白九宫、八宅八宫、择日宜忌、AR 外部记录和室内 `HouseSpatialSurvey` 条目。
- 单张图片仍可能受到设备内存、系统图片尺寸和极端长文本影响；虽然画布按记录数量扩展、正文按文本测量，尚未在真机对最大数据集做压力测试。
- RoomPlan 的 JSON、USDZ、ARWorldMap 文件本身不嵌入 PNG；长卷输出其结构统计、评分和形煞条目，原始文件仍需从空间测绘页面导出。

### P2：本地化、数据账本和产品边界

- `ARSpatialSurveyView`、`HouseSpatialSurveyModel` 和部分 AR 形煞页面仍有动态中文硬编码，非中文页面可能混入中文结果。
- 消耗型余额仍只在本地镜像记账；`Transaction.currentEntitlements` 不会恢复已完成消耗型交易，生产环境应增加服务端交易 ID 幂等账本。
- 传统堪舆结果属于文化/娱乐参考，不能作为医疗、法律、建筑安全或投资结论；导出免责声明仍需保留。
- `check_localization_keys.py` 报告 8 种语言各 469 个 key，重复/缺失均为 0，13 个未使用 key 属于清理项。

## 锦囊覆盖结论

当前页面模型和长卷都保留了各模块的完整锦囊数组；没有现场数据时，长卷会明确显示静态知识库的通用建议，避免把知识库冒充成现场检测结果。

- 户型：房间审计和 3×3 外圈缺角均输出 lore/solution；独立户型图与长卷按完整条数扩展。
- 空间测绘：最近一次 `HouseSpatialSurvey` 的房间、墙体、门窗、评分和 `shaItems` 摘要及 solution 进入长卷，并保留 `scanMethod` 来源标记；户型图 3D 推演不会覆盖当前户型编辑状态，原始 JSON/USDZ/ARWorldMap 仍单独导出。
- AR 外部形煞：保存采集朝向、距离、置信度、来源和备注；长卷按当前记录输出对应 remedy，无记录时才输出通用知识库。
- 玄空：九宫逐宫评价、五黄/二黑提示及财富/健康/调理建议均输出。
- 八宅：八宫 suggestion 全量输出；三合 24 山阶段和 lore 全量输出，但缺少现场水形证据。
- 奇门：九宫门、星、神、天干、趋避方向及最佳方锦囊全量输出；仍需传统流派样例回归。
- 紫白与择日：紫白九宫 advice、太岁/岁破/三煞摘要、四柱、冲克警告、宜忌和详情均输出。
- 罗盘：第一卷包含坐向、坐山、分金、六十四卦、坐标和真太阳时；页面仍保留更细的空亡/兼向交互详情。

因此当前可以称为“基于当前输入快照的全模块长卷”；对没有采集或未接入的数据，会显示为空/未提供，而不是生成虚假的现场结论。

## 福宅天机长卷的后续改进建议

当前实现已经在导出前冻结 `heading`、语言、时间、户型审计和室内外档案，并将这些值传给后台渲染器。后续可继续把各引擎结果也封装为不可变快照，进一步减少后台重新计算与语言状态变化的耦合：

```swift
struct TianJiReportSnapshot {
    let capturedAt: Date
    let language: AppLanguage
    let heading: Double
    let location: LocationSnapshot?
    let compass: CompassAnalysisSnapshot
    let flyingStars: XuanKongChart
    let baZhai: BaZhaiAnalysis
    let sanHe: [SanHeWaterItem]
    let qiMen: QimenChart
    let purpleWhite: PurpleWhiteChart
    let zeRi: ZeRiAnalysis
    let floorplan: [FloorplanAuditItem]
    let panorama: PanoramaFengShuiArchive?
}
```

单张长图已经按内容测量并扩展高度；若需要极端大数据集或打印输出，建议增加分页 PDF，并将“当前现场结果”和“未采集时的通用锦囊”明确分栏。

## 后续修复顺序

1. 为奇门、玄空、紫白和择日加入固定日期、顺逆局、跨节气边界的回归样例，并在真机验证传感器权限与磁场异常。
2. 将各引擎结果纳入统一的 `TianJiReportSnapshot`，让后台渲染器完全消费快照，避免任何单例状态漂移。
3. 将空间测绘和 AR 动态文案迁移到本地化资源，补充 8 语言长卷快照测试。
4. 为消耗型商品建立服务端交易账本，按交易 ID 幂等同步未用额度。
5. 若需要印刷级输出，再增加分页 PDF、原始 RoomPlan/ARWorldMap 文件附件和最大数据集压力测试。

## 验证记录与限制

已运行：

- `python tools/validate_swift_syntax.py`：49 个 Swift 文件，括号/语法模式错误 0；
- `python tools/check_identifiable.py`：94 个结构体，Identifiable 检查通过；
- `python tools/check_localization_keys.py`：8 种语言，469 keys/language，重复 0、缺失 0，13 个未使用 key；
- `python tools/check_ios14_compat.py`：3 个 iOS 15+ API/颜色提示。工程最低版本为 iOS 16，属于兼容性提示而非当前构建阻断。

当前容器没有 Xcode/iOS SDK，不能替代 macOS 真机执行 `xcodebuild`、Core Location/磁场、AVCapture/Vision、ARKit/LiDAR、RoomPlan、Photos 授权或 StoreKit 沙盒验证。因此本报告中的功能链路来自静态源码审查，算法准确性仍需固定样例、真机和领域规则回归测试。
