**iOS 第二轮逻辑审查 · 2026-11-08**

审查对象：当前工作区，包括上一轮尚未提交的修复。此次继续检查跨页面参数、日期边界、导出结算、提醒排程和 AR 恢复流程，发现 12 处问题：4 项 P1、8 项 P2。

这些结论基于调用链与状态转移检查；生日递减、节气名称错位、子时局数变化和导出预留超时已做数值/控制流复核。当前机器是 Linux，没有执行原生编译、XCTest、StoreKit 分享流程和 AR 真机测试。地图恢复问题尤其需要真机确认实际偏差。本轮仅新增审查记录。

1. **[P1] 打开并保存生辰编辑页，会逐次减小立春前出生用户的生日年份**

   位置：[BaZhaiView.swift:2397](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/BaZhaiView.swift:2397)，关联 [BaZhaiEngine.swift:926](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/BaZhaiEngine.swift:926)。

   `kua.birthYear` 保存的是计算命卦使用的风水年。编辑页却把它当成生日的公历年：初始化时发现 `birthDate` 年份不同，就直接改写 `selectedDate.year`，保存时再减一次立春前的年差。

   复现：录入 `1990-01-10`，风水年为 1989；关闭后重新打开编辑页，不改内容直接保存，生日变为 `1989-01-10`，风水年变为 1988。再次打开并保存，生日继续变为 `1988-01-10`。这会持久化错误生日，并改变命卦、生肖和人宅配卦。

   修复方向：生日年月日和计算得到的风水年分开保存；精确日期模式以原始 `birthDate` 初始化，不能用派生年回写原始日期。

2. **[P1] 3D 分析把世界坐标朝向基准当成了住宅向首**

   位置：[HouseSpatialSurveyModel.swift:1859](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/HouseSpatialSurveyModel.swift:1859)，关联 [HouseSpatialSurveyModel.swift:1982](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/HouseSpatialSurveyModel.swift:1982)。

   房间归宫时使用 `房间在世界坐标中的局部角度 + compassHeading`，说明 `compassHeading` 是坐标轴转成地理方向的基准。但八宅与玄空同时直接用 `compassHeading` 排住宅的坐山、向首，没有使用用户确认的住宅朝向或大门方向。上轮二维/三维同步采用同一坐标基准后，这个概念混用仍然存在。

   等价输入：同一物理住宅的大门都朝东，可以表示为“坐标基准 0°、门局部方向 90°”，也可以表示为“坐标基准 90°、门局部方向 0°”。两者的真实门向都是 90°，引擎却分别按 0° 和 90° 排宅卦。换一个扫描启动方向，可能改变同一套房的八宅、山向星和吉凶结果。

   修复方向：模型分别保存世界坐标方向基准和住宅向首；房间归宫使用前者，八宅/玄空立宅使用后者，并做坐标旋转前后结果不变的回归测试。

3. **[P1] 天机长卷没有导出用户正在查看的元运与手动替卦设置**

   位置：[XuanKongGridView.swift:109](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/XuanKongGridView.swift:109)、[TianJiShuEngine.swift:361](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/TianJiShuEngine.swift:361)。

   玄空页保存了 `selectedPeriod` 和用户指定的 `useTiGua`，打开长卷时只构造无参数的 `TianJiShuView()`。导出引擎没有接收这些值：元运使用报告当天的默认元运，替卦则在 [TianJiShuEngine.swift:212](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/TianJiShuEngine.swift:212) 按角度重新推导。

   复现：专业版选择八运并手动切换下卦/替卦，然后从该页生成长卷。当前日期属于九运时，长卷会重新生成九运盘；手动模式也可能被覆盖。付费导出的星盘和正在查看的分析不一致。

   修复方向：构造不可变的分析快照，把所选元运、排盘模式和坐向传入预览及导出，避免在渲染器内重新选择业务参数。

4. **[P1] 分享面板停留超过五分钟，成功导出可能不扣次数**

   位置：[StoreKitIAPManager.swift:665](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/StoreKitIAPManager.swift:665)，关联 [StoreKitIAPManager.swift:694](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/StoreKitIAPManager.swift:694)。

   单次导出先预留 token，余额仍保留，分享成功后才扣次数。但 `commitTianjiCreditReservation` 会先清理超过 300 秒的 token，再尝试移除当前 token；已过期就直接返回，没有扣款。长时间停留在分享、打印面板是正常操作，不等于取消导出。

   复现：非会员有 1 次长卷额度，打开分享面板，停留超过 5 分钟后完成分享。控制流复核结果为：干净图片已交付、余额仍为 1。重复该操作可反复绕过单次扣费，完整分享回调仍需原生环境验证。

   修复方向：区分仍在执行、已取消和失联的导出；成功回调不能仅因预留超时就免扣。若释放了预留，应阻止旧操作继续交付，或保留可结算的操作记录。

5. **[P2] 户型进入 VR 编辑时丢失手动朝向和立极点**

   位置：[FloorplanView.swift:419](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:419)，关联 [VRSpatialSurveyView.swift:615](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/VRSpatialSurveyView.swift:615)。

   户型页只传房间和宽深，没有传 `effectiveHeading` 或用户移动过的 `centroid`。VR 只有从 `initialSurvey` 打开时才保留朝向；当前入口未传 survey，因此生成时改用手机实时罗盘角度，立极点也由引擎重新计算。

   复现：关闭户型与罗盘同步，手动设置朝向 90°，把中宫移动到指定位置；手机朝向 0° 时进入 VR 并生成。同一套布局会按 0° 及重新推算的中宫分析，可能改变房间宫位和结论。

   修复方向：VR 初始化接收完整的户型坐标、朝向和立极点快照，生成时保留这些参数。

6. **[P2] 奇门局数和时柱使用不同的子时换日边界**

   位置：[QimenEngine.swift:409](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/QimenEngine.swift:409)，关联 [QimenEngine.swift:455](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/QimenEngine.swift:455)。

   拆补元局使用原始公历日干支，午夜换日；时柱却明确按 23:00 归次日。同一子时内，时柱保持相同，元局仍会在午夜突变。

   数值复核：UTC+8 下 `2026-11-10 23:30` 使用原始日干支序号 24 定局，但时柱使用次日序号 25。按源码立冬局数表，此时为二局，过午夜后变成八局，时柱对应的日和时支没有改变。

   修复方向：先确定统一的有效干支日，再同时用于符头、三元、局数和时柱；年/月和节气仍按各自的天文边界处理。

7. **[P2] 奇门页面仍会漏掉同一小时内的交节换局**

   位置：[QimenDunjiaView.swift:282](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/QimenDunjiaView.swift:282)。

   缓存键只有民用年月日和小时；一分钟定时器调用 `refreshChart()`，却会在同小时、朝向变化不足 1° 时直接返回。缓存没有节气桶，也没有订阅节气名称变化。上轮紫白页面加入的交节刷新没有覆盖奇门。

   复现：在某节气交接前保持奇门页面前台、罗盘锁定，跨过交节。阳遁/阴遁、局数等可能继续使用旧盘，直至下一整点或足够大的方向变化。

   修复方向：缓存包含实际节气/元局状态，并在定时边界检查或统一节气事件到来时失效。

8. **[P2] 换山后清除了手动标记，却没有恢复正确的下卦/替卦模式**

   位置：[XuanKongGridView.swift:138](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Analysis/XuanKongGridView.swift:138)。

   更换坐/向山只把 `manualTiGuaOverride` 置为 nil，没有把 `useTiGua` 更新为当前的 `isJianXiang`。如果换山前后 `isJianXiang` 相同，它的 `onChange` 不会触发，旧手动值会继续用于排盘。

   复现：在一个山的正中线手动开启替卦，再手选另一个山的正中线。两次 `isJianXiang` 都为 false；虽然代码已进入自动跟随状态，星盘仍保持替卦。

   修复方向：恢复自动模式时同步设置实际模式值，或由“手动覆盖值 ?? 当前自动判定”直接计算排盘模式。

9. **[P2] 节气通知名称永远错一位**

   位置：[BaZhaiEngine.swift:1509](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/BaZhaiEngine.swift:1509)，关联 [SolarTermsData.swift:84](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/SolarTermsData.swift:84)。

   天文计算器的索引 0 是小寒，罗盘展示数组的索引 0 却是冬至。通知把计算器的“下一节气索引”直接用于展示数组，结果取回当前节气的名字。

   对照源码两份数组：立春后本应提醒雨水，实际标题是立春；夏至后本应提醒小暑，实际是夏至；立冬后本应提醒小雪，实际是立冬。

   修复方向：使用稳定的节气标识/名称进行映射，避免共享起点不同的数组索引。

10. **[P2] 节气提醒只排一次，触发后不会续排**

    位置：[BaZhaiEngine.swift:1542](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/BaZhaiEngine.swift:1542)，关联 [BaZhaiEngine.swift:1475](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/BaZhaiEngine.swift:1475)。

    只添加一个 `repeats: false` 请求。通知触发后，没有消费/补排逻辑；回前台仅在“保存的偏好为开、内存状态为关”时排程。正常启用状态和下次启动恢复的状态都是开，因此也不会补排。

    复现：开启提醒，等待首个通知触发，再回到 App 或重新启动。开关仍显示开启，但没有后续节气通知。重新关闭并开启才能再排一个。

    修复方向：按真实节气时刻批量排程合理窗口，并在启动、回前台、通知消费后检查及补充请求。

11. **[P2] AR 地图保存/恢复没有携带坐标系对应的罗盘基准**

    位置：[ARSpatialSurveyView.swift:1694](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1694)，关联 [ARSpatialSurveyView.swift:1572](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1572)。

    保存文件只编码 `ARWorldMap`，没有编码 `surveyHeadingDegrees`；恢复地图时也没有恢复该变量。它仍来自本次启动扫描时的手机方向，而恢复后的几何使用旧地图的坐标体系。

    验收路径：第一次朝东启动并保存地图，重新进入页面时朝南，再恢复旧地图并导出户型。几何恢复了，但用于地理归宫的方向基准没有随地图恢复，存在整体方向错位风险。上轮修复仅处理了同一次扫描内“转身后同步”的路径。

    修复方向：地图与朝向元数据作为同一存档保存/恢复；旧格式缺少元数据时，应要求重新校准或进行可验证的重新定向，不能直接沿用新会话方向。

12. **[P2] 宅主及家属命卦仍会被佛历等系统日历算错**

    位置：[BaZhaiEngine.swift:913](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/BaZhaiEngine.swift:913)。

    上轮固定公历的修改覆盖了紫白、奇门；`UserKuaProfileManager.fengShuiYear` 仍用 `Calendar.current` 取年，随后把它当公历年并限制到 1920...2035。家属命卦也调用此函数。

    输入对照：真实 `1990-06-15` 在佛历下年份为 2533，这个函数会把它钳制成 2035。不同人的真实生日可能被算成同一个 2035 年命卦；相关日期编辑器也用系统日历构造公历年份，错误会继续进入存档。

    修复方向：命卦与生日存储转换统一使用公历和明确的时区，地区日历只用于展示；同时统一此处固定 2 月 4 日的立春近似与其他引擎的天文边界策略。

本轮验证范围：检查了上述实际调用链和所有节气通知排程入口；以临时脚本复核生日年份状态转移、源码两套节气数组、2026-11-10 子时干支/局数及导出 token 超时分支。临时计算用于说明触发条件，没有替代原生功能测试。现有 12 个 XCTest 用例尚未覆盖这些新增场景，也尚未在本机执行。
