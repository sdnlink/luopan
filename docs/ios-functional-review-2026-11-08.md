**iOS 功能审查记录 · 2026-11-08**

修复状态：11 项问题均已完成代码修改，并新增 12 个 XCTest 回归用例及独立模拟器测试 workflow。当前机器无法运行 Xcode，原生编译、回归用例和硬件验收仍待 macOS 执行。以下问题描述保留为修复前的审查记录。

审查基线：`36a0779`。范围为 `tiandi_luopan/ios` 原生工程，重点沿罗盘、真太阳时与排盘、AR/RoomPlan、户型档案、报告导出和内购权益的调用链检查。

发现 11 项功能缺陷：4 项 P1、7 项 P2。P1 表示应优先修复的核心计算、档案混用或付费权益问题；P2 表示特定操作或环境下的功能错误。下面的结论来自代码与数值复核，复现步骤是后续原生验收用例，尚未在 iOS 设备执行。

1. **[P1] 非正方形户型图的房间方位计算失真**

   位置：[FloorplanEngine.swift:646](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:646)，关联 [FloorplanView.swift:2475](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:2475)。

   `palaceForPoint` 直接对两个归一化坐标差使用 `atan2`，没有恢复图纸的宽高比例。画布却按原图片比例展示，罗盘扇区也使用屏幕上的真实角度，因此房间显示位置和体检所判宫位会不同；缺角归宫同样调用此函数，也受到影响。

   数值复核：图纸宽高比为 3:1、中宫 `(0.5, 0.5)`、房间中心 `(0.7, 0.3)`、朝向 0° 时，代码得到 45°（东北）；真实显示向量为 `(0.6, -0.2)`，方位为 71.565°（正东）。这会改变整间房的判断结果。

   修复方向：向引擎传入图纸或实际户型的宽高尺度，先把归一化位移换算成同一尺度，再计算方位；2D 叠图和 3D 投影使用同一个坐标变换。

2. **[P1] 切换宅谱后会继续使用上一套房的 3D 与室内分析**

   位置：[FloorplanView.swift:756](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:756)，关联 [TianJiShuView.swift:455](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/TianJiShuView.swift:455)。

   `loadCaseFromArchive` 只在新档案含有 `spatialSurvey` 时更新 3D 状态，没有在新档案为空时清除旧状态。即使新档案有模型，也只替换 measured/virtual 其中一个槽位，另一个槽位仍指向上一套房。`ShaSurveyStore.latestInterior` 同样在新档案无模型时保留旧数据，长卷又直接读取该全局档案。

   复现：先保存一份没有 3D 数据的 B 宅谱；再加载或扫描有 3D 数据的 A；然后加载 B。B 的二维户型已切换，但“最近实测/VR 3D”和长卷室内内容仍可能来自 A。重新保存 B 时，旧模型还会被归入 B 的档案。

   修复方向：切换宅谱时完整替换两个空间槽位和室内档案，包括显式写入空值；用 case ID 关联二维、三维、室内外记录及报告。

3. **[P1] 真太阳时修正错误地移动了八字的交节时刻**

   位置：[SolarTimeCalculator.swift:103](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/SolarTimeCalculator.swift:103)。

   `trueSolarDate` 是为了取得地方太阳钟面读数而平移的时间值，但代码再次用它计算太阳黄经、节气桶和是否立春。太阳交节是同一绝对时刻的天文事件；把经度修正再次送入天文计算，会使不同经度的用户在同一时刻得到不同的年柱、月柱。页面显示的当前节气却使用原始 `date`，还会与四柱相矛盾。

   数值复核：以源码自己的太阳位置模型求出 2026 年立春边界，再取其后 30 分钟、设备时区 UTC+8。同一时刻，经度 80° 的四柱仍按节气桶 1、2025 干支年处理，经度 120° 已按桶 2、2026 干支年处理。此示例只验证内部一致性，没有把源码模型的交节时间当作权威历书时间。

   修复方向：以原始绝对时间计算节气及年/月柱边界；地方太阳时只用于所采用规则下的地方日、时辰计算。

4. **[P1] 终身购买退款后可能一直保留专业版权益**

   位置：[StoreKitIAPManager.swift:1231](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/StoreKitIAPManager.swift:1231)，关联 [StoreKitIAPManager.swift:995](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/StoreKitIAPManager.swift:995)。

   收到明确的终身商品撤销交易时，处理器没有直接收回终身状态，而是重新扫描权益。扫描结果为空且旧镜像有效时，又调用“年度订阅”的状态来决定是否保留旧镜像。仅购买过终身商品、没有年度订阅记录的用户，订阅状态为空会得到 `.unknown`，随后直接 `return`，旧的 `isLifetime` 留在镜像中。

   原生验收：只购买终身版、不购买年度订阅；确认解锁后在 StoreKit 测试中撤销终身交易；触发交易更新和恢复购买。应检查所有 VIP 门控是否立即锁定。现有分支在年度订阅状态为空时不会清理旧终身权益。

   修复方向：明确撤销事件必须按被撤销商品立即更新镜像；订阅缓存保护和非消耗品保护分开处理，不能用另一类商品的 unknown 状态覆盖撤销事实。

5. **[P2] 夏令时地区的真太阳时多出一小时**

   位置：[SolarTimeCalculator.swift:79](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/SolarTimeCalculator.swift:79)。

   代码从时区 UTC 偏移中扣掉夏令时，再按标准经线求偏移；但输出仍通过包含夏令时的当前时区格式化，没有扣除钟面上的夏令时一小时。最终值会多出夏令时偏移，时柱和跨日附近的日柱也可能受到影响。

   数值复核：纽约 2026-07-01 当地 12:00、经度 -74.006°，按代码公式得到约 12:00:31；按 UTC、经度及相同均时差换算为太阳钟面时间约 11:00:31，差值恰为 60 分钟。

   修复方向：使用包含夏令时的完整民用 UTC 偏移计算钟面修正，或从 UTC 直接求太阳钟面时间，避免重复应用当前时区。

6. **[P2] RoomPlan 手动校准朝向没有传给二维户型**

   位置：[ARRoomPlanCaptureView.swift:507](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:507)，关联 [ARRoomPlanCaptureView.swift:1119](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:1119)。

   结算页的 ±1°/±5° 按钮更新 `headingOffsetDegrees`，并用它重算三维报告；同步二维户型时调用的 `resolvedDoorCompassHeading` 却只加 `initialCompassHeading`，遗漏校准量。

   复现：完成一次有门的 RoomPlan 扫描，在结算页累计修正 +30°，再同步户型。二维户型保存的角度与未校准时相同，三维报告已经按修正值计算。

   修复方向：使用统一的已校准世界坐标朝向生成二维导入和三维报告，并验证同一门在两种表示下的方向一致。

7. **[P2] AR 平面导入使用导入瞬间的手机方向，导致户型随最后一次转身偏转**

   位置：[ARSpatialSurveyView.swift:1080](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1080)，关联 [ARSpatialSurveyView.swift:432](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:432)。

   扫描开始时保存了 `surveyHeadingDegrees`，`buildSpatialSurvey` 也使用这个基准。但二维蓝图由固定的世界坐标 X/Z 生成，导入角度却读取当时最新的 `motion.headingState.facingAngle`。扫描时转动手机不会旋转已建立的世界坐标，导入角度却跟着转了。

   复现：未锁盘时朝东启动扫描，转向南后点击同步户型。三维 survey 保留开始时的约 90° 基准，二维户型却保存约 180°，同一组几何数据产生不同的宫位。

   修复方向：导入使用与蓝图坐标轴一致的扫描基准及变换，不能把按钮点击时的手机朝向当作图纸朝向；重定位恢复也需保留对应的朝向元数据。

8. **[P2] 新航向回调会清掉仍然有效的离线 WMM 真北补偿**

   位置：[CompassMotionManager.swift:823](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/CompassMotionManager.swift:823)，关联 [CompassMotionManager.swift:910](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/CompassMotionManager.swift:910)。

   有效定位会计算 WMM 磁偏角并设置 `hasDeclination = true`；随后只要一个航向样本的系统 `trueHeading < 0`，即使经纬度仍有效，也会把偏角清零并退回磁北。WMM 只在下次定位回调重算，而定位配置的距离门限是 10 米，原地测量时可能长时间收不到新的定位。

   验收输入：先交付有效位置、计算非零 WMM 偏角，再连续交付磁航向有效而系统真航向为 -1 的样本。选择真北的罗盘会使用磁北，真北针也会消失。

   修复方向：独立保存 WMM 补偿的有效性和系统真航向的有效性；系统样本缺少真航向时，仍用有效位置的 WMM 偏角修正磁航向。

9. **[P2] 选择佛历等系统日历会算错紫白和奇门**

   位置：[PurpleWhiteEngine.swift:194](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/PurpleWhiteEngine.swift:194)、[QimenEngine.swift:373](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/QimenEngine.swift:373)。

   两个引擎用 `Calendar.current` 取得年/月/日，随后送入要求公历年月日的年星或儒略日公式。系统日历为佛历时，同一物理日期的 2026 会被读取成 2569；日本历等以年号计年的日历也不适用这些公式。应用提供泰语界面，此环境具有实际相关性。

   数值复核：源码年星公式对公历 2026 得到 1，对佛历 2569 得到 7。奇门的儒略日和日干支也会随错误年份改变。

   修复方向：算法内部统一使用 `Calendar(identifier: .gregorian)` 并保留用户时区；展示格式再按用户地区和日历处理。

10. **[P2] 紫白页面跨交节后仍显示旧流年、流月盘**

    位置：[PurpleWhiteView.swift:303](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/PurpleWhiteView.swift:303)。

    缓存键只包含民用日期和当前八方宫位，没有节气桶。页面没有用于交节的定时刷新或 `currentSolarTermName` 订阅。用户在同一天交节前后保持页面和朝向不变，缓存不会重建；即使航向轻微变化触发 `refreshChart()`，同一天、同一宫位的早退条件仍挡住更新。

    复现：交节前打开实时紫白页，并保持前台至交节后。立春会影响年盘和月盘，其余换月节会影响月盘；切走再回来才强制刷新。

    修复方向：缓存键包含实际年/月交节状态，并增加低频边界检查或订阅统一的节气变化事件；自选日期模式按所选时刻计算。

11. **[P2] 宅谱 JSON 导入产生共享底图，删除副本会删掉原档案图片**

    位置：[FloorplanView.swift:811](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:811)，关联 [FloorplanView.swift:836](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:836)。

    重复导入同一宅谱 JSON 时，只生成新的 record ID，保留同一个 `imageFileName`。删除任一档案会直接删除该文件，其他引用此图的档案无法重新载入底图。此外，所谓 JSON 备份只包含图片文件名，没有图片内容，迁移到另一台设备或重装后也无法恢复底图。

    复现：保存带底图的 A → 复制 A 的 JSON → 导入为副本 B → 删除 B → 再载入 A。A 的底图文件已被删除。

    修复方向：导入副本时复制图片到独立文件，或对共享资源做引用计数；完整备份应携带图片资源，导入时重建文件名与资源关联。

验证记录：

- `validate_swift_syntax.py`：扫描 52 个 Swift 文件，未发现括号配对错误。这不是 Swift 编译检查。
- `audit_swift_symbols.py`：未发现脚本检查范围内缺失的罗盘成员。
- plist XML 解析通过，52 个 Swift 文件均有工程文件引用。
- `check_localization_keys.py`：8 种语言、每种 558 个键，缺失和重复键均为 0；因 17 个未使用键返回非零状态。这些未使用键未列作功能缺陷。
- 使用临时 Python 数值计算复核图纸宽高比、夏令时偏移、源码模型的交节一致性和佛历年份输入，结果见对应条目。
- 工程没有 XCTest/UI Test target。当前机器为 Linux，未安装 Swift/Xcode，未执行原生编译、模拟器、相机/LiDAR、StoreKit 或真实照片写入测试。以上检查不证明这些运行路径已经验收通过。

修复记录：

| 编号 | 当前实现 | 验证覆盖 |
| --- | --- | --- |
| 1 | 按图纸或标定尺寸还原坐标比例；画布、体检、房源比较、导出和 3D 投影使用一致的比例，AR/RoomPlan 蓝图也保留比例 | XCTest：屏幕向量与归一化向量一致、3:1 户型房间判为正东 |
| 2 | 切换宅谱时完整替换实测、VR、室内和室外记录，包括空档案；新增字段保持旧存档可读，换底图和重置时清除旧空间数据 | XCTest：空档案切换、实测替换 VR、重新读取持久化结果 |
| 3 | 年/月柱使用原始绝对时刻判断交节；太阳钟面只决定日、时柱，跨公历新年也保留正确的干支年 | XCTest：立春前后多经度一致、太阳钟面跨新年 |
| 4 | 明确撤销立即写入权益镜像；扫描版本号阻止旧扫描覆盖撤销；年度订阅缓存保护不再保留终身权益 | XCTest：撤销终身/订阅不影响其他付费商品和消耗额度；完整交易流仍需 StoreKit 验收 |
| 5 | 由 UTC 生成太阳钟面日期，按完整民用时区偏移计算展示时差 | XCTest：纽约夏令时、夏令时跳变的连续性 |
| 6 | RoomPlan 二维导入采用已校准的世界坐标朝向，与三维分析一致，不再混用门法线和图纸上方 | 待 LiDAR 真机验证 +30° 校准同步 |
| 7 | AR 二维导入使用扫描开始时的方向基准，不读取导入时手机的新方向 | 待真机验证扫描后转身再导入 |
| 8 | 单独缓存离线 WMM 偏角；系统真航向失效时继续使用有效定位的离线补偿，失去定位时清除 | 待 Core Location 航向输入及真机验证 |
| 9 | 紫白、奇门算法内部固定使用公历并保留当前时区 | 待佛历、日本历系统设置下原生验收 |
| 10 | 紫白缓存键包含节气桶，监听节气变化并每 30 秒检查实时盘 | 待前台跨节气、静止和自选日期模式验收 |
| 11 | JSON 备份内嵌底图；每次导入生成独立图片；删除旧共享图片时检查剩余引用，写入失败不创建伪成功档案 | XCTest：跨目录恢复、旧版 JSON 副本导入、删除副本保留原图、旧字段兼容 |

原生回归入口：[FunctionalRegressionTests.swift](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopanTests/FunctionalRegressionTests.swift)。测试目标为 `TiandiLuopanTests`，已加入共享的 `TiandiLuopan` scheme。新增 workflow 为 [ios-regression-tests.yml](/home/skn/code/luopan/.github/workflows/ios-regression-tests.yml)，使用仓库现有的 `xcode-27` runner；本次未触发远程任务。

macOS 可在 Xcode 选择 iPhone 模拟器后运行 Product → Test，或使用已有模拟器名称执行：

```sh
xcodebuild test \
  -project tiandi_luopan/ios/TiandiLuopan.xcodeproj \
  -scheme TiandiLuopan \
  -destination 'platform=iOS Simulator,name=<已安装的 iPhone 模拟器名称>' \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

本次本地验证：53 个 Swift 文件的括号检查和罗盘成员检查通过；工程文件结构、引用、共享 scheme、plist、workflow YAML 与 shell 语法检查通过；`git diff --check` 通过。本地化检查仍有修复前相同的 17 个未使用键，缺失/重复键均为 0。上述验证不包含 Swift 类型检查、Xcode 编译和 XCTest 执行。
