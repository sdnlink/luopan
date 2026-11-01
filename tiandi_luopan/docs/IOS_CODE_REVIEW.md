# iOS 源码审查与功能完整性报告

审查基准：2026-11-01。范围为 `ios/TiandiLuopan` 下已加入 Xcode target 的 Swift 源码，并以源码实际调用关系为准。本文补充 `docs/IOS_ANALYSIS.md`，重点回答四个问题：模块做什么、结果是否可信、锦囊是否覆盖、福宅天机长卷是否包含全部当前结果。

## 结论

页面和基础能力基本齐全：罗盘、AR 形煞、户型审计、ARKit/LiDAR/RoomPlan、玄空/八宅/三合/奇门/紫白/择日、长卷导出、StoreKit 会员和本地化均有入口和实现。但当前不能把结果描述为“全模块准确排盘”或“当前全屋全案长卷”：

1. **P0：奇门核心飞布顺序错误。** `QimenEngine.swift:288-312` 用数字升序作为洛书路径，九星、八门、八神和天干会落错宫，最佳方向也可能错。
2. **P1：天机长卷不是当前状态的全量汇总。** `TianJiShuView` 只传航向、坐标、真太阳时和语言；户型、AR 现场记录、RoomPlan、3D 空间审计没有进入渲染器。
3. **P1：多个导出路径主动丢数据。** 三合只取前三项，紫白只取重点宫位，户型报告只绘制前六项，八宅长卷只写四个凶位。
4. **P1/P2：定位失败、形煞归宫、择日“三煞”、多语言和会员兼容仍有边界问题。** 这些问题会造成陈旧数据、标签错误、文案误导或历史交易无法记账。

传统堪舆算法存在流派差异。以下将“可由代码直接证明的错误/遗漏”和“实现为启发式、需要业务确认的简化”分开描述，避免把启发式结果宣传成物理测量或绝对吉凶。

## 模块覆盖矩阵

| 模块 | 主要源码和入口 | 实际功能/输出 | 锦囊覆盖 | 准确性与限制 | 是否进入福宅天机长卷 |
| --- | --- | --- | --- | --- | --- |
| 罗盘与传感器 | `CompassMotionManager.swift`、`CompassMainView.swift` | Core Location 航向/定位、Core Motion 姿态/磁场、滤波、真北/磁北、二十四山、水平仪、真太阳时 | 罗盘详勘、分金、空亡、宫位建议存在 | 真机磁场、权限、姿态生命周期未实测；定位失败可能留下旧状态 | 只写角度、坐山/向山、坐标和真太阳时摘要 |
| 地磁与历法 | `WorldMagneticModel.swift`、`SolarTimeCalculator.swift`、`SolarTermsData.swift` | WMM 偏角后备、经度校正真太阳时、节气、四柱 | 作为各引擎输入，无独立完整方案 | WMM/节气边界需真机和历法基准回归；各引擎仍可能使用不同时间快照 | 只有摘要和重新计算结果 |
| 定向数据 | `Mountain24.swift`、`Fenjin120Data.swift`、`Hexagram64.swift` | 二十四山、120 分金、六十四卦、兼向/替卦字段 | 分金等级、卦名和基础解释存在 | 长卷没有分金秘诀、空亡/兼向完整详情 | 只写第一卷摘要 |
| 玄空飞星 | `FlyingStarsEngine.swift`、`XuanKongGridView.swift` | 三元九运、山/向星、旺山旺向、二五/三七/七九判断和财/健康/调理建议 | 九宫格每宫有评价，财富/健康/调理建议存在 | 中宫卦名生成错误；五黄/二黑可能先被当运星判断覆盖，财位建议未排除凶星 | 写格局和三段建议，不写九宫全盘 |
| 八宅与三合 | `BaZhaiEngine.swift`、`SanHeWaterEngine.swift`、`BaZhaiView.swift` | 宅卦八宫游年、八路黄泉、八煞、十二长生水法 | 八宅各宫 suggestion、黄泉/八煞 remedy、24 山长生 lore 存在 | 三合是项目规则化映射，未覆盖完整阴阳龙、顺逆、水口和来去水证据 | 八宅只写四凶位；三合只写前三项 |
| 奇门遁甲 | `QimenEngine.swift`、`QimenDunjiaView.swift` | 节气阴阳遁、局数、九宫、八门、九星、八神、天干和出行方 | 页面可看九宫、门星神 lore、避忌方 | 洛书飞布顺序错误；`zhiFuPalace` 强制解包有崩溃风险；实现为离线简化排盘 | 只写标题、最佳方和八宅生气方 |
| 紫白与择日 | `PurpleWhiteEngine.swift`、`ZeRiEngine.swift`、`PurpleWhiteView.swift` | 流年/流月客星、太岁/岁破/三煞方、四柱、少量冲克警告 | 紫白每宫 advice、择日宜忌和详情存在 | 紫白建议主要按年星，月星参与有限；择日没有完整神煞、三煞方，且把“冲山”放入 `sanShaWarning` | 紫白只写 notable；择日只写四柱/状态摘要 |
| 户型立极 | `FloorplanEngine.swift`、`FloorplanView.swift` | 图片/示例户型、房间编辑、面积质心、八宫分配、房间审计、缺角检查 | 非“平”房间和缺角有 lore/solution；正常房间有字段但不进报告 | 缺角只查四角；审计主要使用矩形中心，真实多边形支持未贯穿；导出最多六条 | **不进入长卷**；独立户型图也会截断 |
| AR 形煞 | `ARVisionView.swift`、`OnDeviceShaAnalyzer.swift`、`ExteriorShaEngine.swift`、`ShaSurveyModels.swift` | Vision 矩形/轮廓几何候选、三帧共识、LiDAR 距离、手动/AI 标注、八宫聚合、化解页 | 八大静态形煞有通用 remedy；当前记录有距离/置信度/严重度 | 不是训练好的建筑语义模型；当前记录只存内存；八宫索引未使用报告采集朝向 | **不进入长卷**；长卷使用静态八大形煞列表 |
| 空间测绘 | `ARSpatialSurveyView.swift`、`ARRoomPlanCaptureView.swift`、`HouseSpatialSurveyModel.swift`、`House3DSpaceViewer.swift`、`VRSpatialSurveyView.swift` | ARKit/LiDAR/RoomPlan/虚拟回退，墙门窗家具、测距、九宫、空间形煞、JSON/ARWorldMap/DXF/USdz | 每个 `shaItem` 有 detail/lore/solution，3D 查看器可看结果 | 规则和阈值是启发式；多处中文硬编码；未在长卷消费 `HouseSpatialSurvey` | **不进入长卷** |
| 长卷导出 | `TianJiShuEngine.swift`、`TianJiShuView.swift` | 1080×6000 宣纸图、预览、相册保存、系统分享、成功后扣天机额度 | 只覆盖已接入的摘要/通用列表 | 固定画布无动态测量/分页；`isPro` 参数未使用；输入不是全量快照 | 当前是“理气摘要长卷”，不是全模块当前状态报告 |
| 权益与本地化 | `StoreKitIAPManager.swift`、`VIPPaywallSheet.swift`、`LocalizationManager.swift` | StoreKit 2 交易/权益、会员和消耗额度、本地化字典 | 付费入口有门控；8 种语言字典无重复/缺失 | 消耗型余额只在本地记账，重装/换机恢复依赖未实现的服务端账本；旧商品 ID 在交易监听入口被过滤 | 不属于长卷内容，但决定导出是否可用 |

## 按严重程度的问题

### P0：奇门洛书飞布路径错误

`QimenEngine.swift:288-312` 定义：

```swift
luoOrderFull = [1, 2, 3, 4, 5, 6, 7, 8, 9]
luoOrderSkip = [1, 2, 3, 4, 6, 7, 8, 9]
```

代码注释称这是“洛书飞布顺序”，但常用洛书九宫路径应是 `1 → 8 → 3 → 4 → 9 → 2 → 7 → 6`，逆局反向，中宫单独处理。当前 `flightFull`、`flightSkip` 的顺序会同时影响地盘、天盘九星、八门和八神，随后影响页面九宫、最佳动身方、避忌方和长卷奇门摘要。应先确认项目采用的流派，再把路径作为明确常量，并增加固定日期、顺逆局、8 个非中宫唯一覆盖和中宫不重复的回归测试。

### P1：长卷不能代表当前所有模块

`TianJiShuView.swift:248-269` 只传入 `heading`、`coordsDesc`、`solarTimeDesc`、`language` 和 `reportDate`。`TianJiShuEngine.generateScrollImage` 没有接收户型审计、AR 记录、RoomPlan、3D 空间调查或用户选中条目。因此它会用单例重新计算部分基础引擎，却不会读取用户在其他页面实际完成的结果。

当前长卷包含：

- 坐向、坐山、120 分金和六十四卦的摘要；
- 玄空格局、当前运星和三段财/健康/调理建议；
- 八路黄泉、坐山八煞和前三项十二长生水法；
- 奇门标题/最佳动身方、八宅宅卦和生气方；
- 紫白重点宫位、择日四柱/状态、八宅四个凶位；
- `ExteriorShaEngine.database` 中的静态八类形煞通用锦囊。

明确缺失：

- 当前 `FloorplanEngine` 的房间、立极点、缺角、穿堂煞和房间锦囊；
- ARVision 的当前 AI/手动记录、目标角度、仰角、距离、置信度和存证照片；
- `HouseSpatialSurveyEngine` 的墙、门窗、家具、空间评分和 `shaItems`；
- RoomPlan 语义统计、JSON/USdz 和 ARWorldMap 结果；
- 玄空九宫全盘、奇门九宫全字段、分金秘诀、空亡/兼向详情；
- 用户当前选中的房间、宫位或形煞上下文。

`drawShaSelfCheck`（`TianJiShuEngine.swift:642-668`）遍历的是静态知识库，不是 `ShaSurveyStore` 的当前记录。产品应称其为“罗盘与理气摘要”，或者改为接收一次性冻结的 `TianJiReportSnapshot`，并对未扫描/未提供模块显式显示状态。

### P1：导出链路存在明确截断

- `TianJiShuEngine.swift:346` 使用 `sanHeItems.prefix(3)`，只输出前三条长生水法。
- `TianJiShuEngine.swift:596-609` 只输出紫白 `notable` 宫位，普通宫位的建议被省略。
- `TianJiShuEngine.swift:629-637` 只输出八宅四个凶位，四个吉位的完整 suggestion 不进入长卷。
- `FloorplanView.swift:1948-1974` 只绘制 `report.prefix(6)`；第七条之后的审计和锦囊丢失。
- `FloorplanEngine.swift:485-494` 只把 `inspectionLevel != "平"` 的房间加入报告；正常房间的解释和建议只能在房间卡片中看到。

如果需求是“全部分析结果和锦囊”，应保存完整数组，提供“全量/重点”模式，并按内容动态分页或导出 PDF。

### P1：形煞、择日和传感器状态会造成错误上下文

- `ExteriorShaRecord.palaceIndex`（`ShaSurveyModels.swift:49-54`）按绝对 `bearingDegrees` 分宫，`ShaPanoramaReport.headingDegrees` 只被保存，没有参与分宫。若产品语义是“以采集时罗盘为基准随罗盘旋转”，当前记录会落错宫；应明确绝对地理方位还是相对采集朝向，并统一计算。
- `ShaSurveyStore.archive`（`ShaSurveyModels.swift:207-214`）使用生成档案时的当前 `headingState`，而不是记录采集时的 heading；用户转动设备后再导出，档案元数据可能漂移。
- `ShaSurveyStore` 的 `records`/`latestInterior` 只有 `@Published` 内存状态，Codable 结构没有落盘。杀进程、重启或切换设备会丢失尚未另行导出的现场档案。
- `CompassMotionManager.locationManager(_:didFailWithError:)`（`CompassMotionManager.swift:682-695`）非瞬态失败只设置 `hasLocationFix = false`，没有清空经纬度、海拔、旧磁偏角、真北标志和太阳时。之后页面或导出仍可能使用陈旧定位。定位失败时应清除整个定位快照并回退磁北/WMM。
- `ZeRiEngine.swift:198-232` 将“日支冲坐山”写入 `sanShaWarning`，文案却是“冲山大忌”；真正年/月/日三煞方和完整择日神煞没有计算。`isAuspicious = warnings.isEmpty` 也不足以支持“宜动土/安门”的强结论。

### P1/P2：算法输出需要降级为启发式或补齐安全边界

- `FlyingStarsEngine.swift:554,774-776` 将中宫命名为“天心五 (中宫)”，再用 `prefix(1)` 生成卦名，结果为“天”，应为独立的“中/太极”。
- `FlyingStarsEngine.swift:86-102` 先判断当运山/向星，再判断五黄/二黑；五黄或二黑同时为当运星时可能先显示吉象。`wealthAdvice`（约 263-297）也可能对凶星所在宫继续建议动水，应排除或覆盖五黄、二黑和二五交加。
- `QimenEngine.swift:428` 对 `stemToPalace[xunHeadSixYi]` 强制解包；数据表变更、异常日期或新旬首规则可能直接崩溃，应返回可诊断错误或中性盘。
- `GeometryUtils.polygonRectIOU`（`GeometryUtils.swift:66-76`）用多边形包围盒交集代替真实多边形交集；凹多边形和三角形会高估 IoU。若用于识别/房间重叠，应改用真实裁剪或明确标注为近似值。
- `SanHeWaterEngine.resolveWaterMethod`（`SanHeWaterEngine.swift:741-797`）是固定四大局和 24 山映射，未表达阴阳龙顺逆、来水/去水、水口和现场水形证据，只能称规则化辅助结果。
- `HouseSpatialSurveyEngine` 的大量阈值（距离、角度、面积、重叠率）是工程启发式，`HouseSpatialShaItem` 不等同于建筑检测或医学/安全结论。`HouseSpatialSurveyModel.swift:522-604` 和 `ARSpatialSurveyView.swift:866-889` 仍有中文硬编码，非中文页面/快照会混入中文。
- `OnDeviceShaAnalyzer.swift:79-149` 使用 Vision 矩形/轮廓、比例和深度加权，不是训练好的建筑语义模型；置信度是规则分数，不能当作经过验证的识别概率。
- 长卷固定 1080×6000，多个 `draw(in:)` 使用固定高度且没有基于 `curY` 的边界检查或分页；长文本、多语言或新增锦囊可能裁切、重叠或把落款画到画布外。`isPro` 参数当前未使用。

### P2：本地化和历史权益兼容

- `ARSpatialSurveyView.swift:866-889` 的标题、标签和低梁提示硬编码简体中文；形煞锦囊页 `ARVisionView.swift:1863`、`1940`、`1974-2084` 也有同类文案。语言字典无缺失不代表动态结果已全部本地化。
- `StoreKitIAPManager.swift:346-357` 对少量旧户型商品 ID 有兼容判断，但 `handleTransactionUpdate` 在 `582-585` 先要求 `IAPProductID(rawValue: pid) != nil`；旧 ID 会在兼容记账前直接返回。若这些商品仍需迁移，旧交易无法记账。
- 消耗型商品余额仅在本地镜像记账；`Transaction.currentEntitlements` 不会恢复已完成的消耗型交易。生产环境应以服务端交易 ID 幂等账本同步未用余额，否则重装/换机或写入前崩溃可能丢额度。
- `check_localization_keys.py` 报告 8 种语言各 469 个 key，重复/缺失均为 0，但有 13 个未使用 key；属于资源清理项，不是运行阻断。

## 锦囊覆盖结论

锦囊字段大多存在，但“存在于页面模型”不等于“进入当前导出”：

- 户型：异常房间/缺角有 solution，普通“平”房间不进报告，独立图最多 6 项。
- 3D 空间：每个 `shaItem` 有 detail/lore/solution，但硬编码中文，且天机长卷完全不读取。
- AR 外部形煞：静态八类知识库有通用 remedy；用户当前 AI/手动记录有严重度和距离，但长卷仍只遍历静态八类。
- 玄空：wealth/health/remedy 存在，但凶星覆盖优先级不足，长卷只写三段文字。
- 八宅：8 宫 suggestion 存在，长卷只输出四凶位。
- 三合：24 山阶段和 lore 存在，长卷只取前三项，且缺少完整水形输入。
- 奇门：门、星、神、趋避和 lore 存在，但飞布顺序错误，长卷只写最佳方。
- 紫白：每宫 advice 存在，长卷只输出 notable，未覆盖普通宫和流月完整建议。
- 择日：有宜/忌/详情字段，但实际神煞覆盖有限，`sanShaWarning` 命名不准确。
- 罗盘：分金、六十四卦、空亡和兼向有页面详情，长卷只放第一卷摘要。

因此当前只能称“部分模块的通用锦囊集合”，不能称“当前所有诊断的完整锦囊”。

## 福宅天机长卷的改造建议

建议在导出前由主页面创建不可变快照，例如：

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
    let floorplan: FloorplanSnapshot?
    let panorama: PanoramaFengShuiArchive?
    let spatialSurvey: HouseSpatialSurvey?
}
```

渲染器只消费这份快照，不再在后台读取单例；每个模块输出完整数组，并显示“已扫描/未扫描/不可用/仅通用知识库”。长卷应采用动态分页或 PDF，分离“当前测量结果”和“无当前记录时的通用锦囊”，避免用户误以为静态知识库就是现场检测结论。

## 建议修复顺序

1. 修正奇门洛书路径，加入固定日期和宫位覆盖回归测试。
2. 建立 `TianJiReportSnapshot`，接入户型、AR、RoomPlan、3D 空间和全部引擎结果。
3. 移除 `prefix(3)`、`prefix(6)` 和紫白/八宅筛选，改为全量分页或 PDF。
4. 修正形煞相对/绝对方位定义、采集时间快照和定位失败清理。
5. 修正中宫 trigram、五黄/二黑优先级、`sanShaWarning` 语义和 Qimen 强制解包。
6. 将空间测绘、AR 锦囊和长卷动态字段迁移到本地化资源，并做 8 语言快照测试。
7. 为消耗型商品建立服务端交易账本，兼容历史商品 ID 后再进行生产发布。

## 验证记录与限制

已运行：

- `python tools/validate_swift_syntax.py`：49 个 Swift 文件，括号/语法模式错误 0；
- `python tools/check_identifiable.py`：93 个结构体，Identifiable 检查通过；
- `python tools/check_localization_keys.py`：8 种语言，469 keys/language，重复 0、缺失 0，13 个未使用 key；
- `python tools/check_ios14_compat.py`：3 个 iOS 15+ API/颜色提示。工程最低版本为 iOS 16，属于兼容性提示而非当前构建阻断。

当前容器没有 Xcode/iOS SDK，不能替代 macOS 真机执行 `xcodebuild`、Core Location/磁场、AVCapture/Vision、ARKit/LiDAR、RoomPlan、Photos 授权或 StoreKit 沙盒验证。因此本报告中的功能链路来自静态源码审查，算法准确性仍需固定样例、真机和领域规则回归测试。
