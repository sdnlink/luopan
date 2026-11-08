**iOS 第四轮逻辑审查 · 2026-11-08**

审查基线：`3db67ed`，即本次提交的第三轮修复。继续检查地图恢复、嵌套相机会话、多窗口下的扫描与修正、非矩形房间以及报告日历，确认 8 项问题：2 项 P1、6 项 P2。本轮只记录发现，尚未修改下述业务逻辑。

结论来自源码调用链和临时 Python 数值／状态转移复核。当前环境没有 Swift、Xcode，未执行原生编译、现有 53 个 XCTest、相机／RoomPlan 或多窗口真机验收。以下复现步骤为待执行的原生验收路径；简化状态模拟不代表已执行 Swift 实现。

1. **[P1] 切换宅谱后，仍打开的扫描／VR／3D 修正可以把旧住宅结果写进当前住宅**

   位置：[VRSpatialSurveyView.swift:670](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/VRSpatialSurveyView.swift:670)，关联 [FloorplanView.swift:734](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:734)、[ARRoomPlanCaptureView.swift:1084](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:1084)、[House3DSpaceViewer.swift:461](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/House3DSpaceViewer.swift:461)。

   上轮给二维布局写入增加了版本校验，但采集和修正页面没有保存所属宅谱 ID／活动住宅代次。VR 生成、RoomPlan 完成及 3D 改房间类型仍直接覆盖全局实测／VR 键；扫描同步二维还会在未传 `expectedRevision` 的情况下调用共享工作区保存，并沿用回调时当前住宅的授权与外部记录。另一窗口切换宅谱时，已有的扫描／VR 页面也没有被失效或关闭。

   验收：窗口一从住宅 A 进入 VR，保留编辑页；窗口二加载住宅 B；窗口一点击生成。B 的当前二维布局仍是 B，但“最近 VR”已变为 A。此时保存宅谱会把 A 的模型与 B 的布局一起归档。若窗口一在 RoomPlan 中执行“同步户型”，还会直接把 B 的当前布局和底图替换为 A 的扫描结果。已有宅谱文件在再次保存之前不一定改变，污染首先发生在共享活动工作区。

   修复方向：为活动住宅设独立身份／切换代次，扫描、VR、3D 查看器和异步完成回调均携带同一身份；切换住宅使旧操作失效，所有布局及空间存档写入统一校验身份。普通编辑版本与住宅切换身份应区分，避免仅因同一住宅的正常编辑就误拒绝扫描。

2. **[P1] AR 地图没有保存已完成的手动打点房间，恢复后重新生成会丢失这些修正**

   位置：[ARSpatialSurveyView.swift:1704](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1704)，关联 [ARSpatialSurveyView.swift:1532](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1532)、[ARSpatialSurveyView.swift:1856](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1856)。

   完成打点时，房间只加入模型内的 `cornerRooms`，随后 `clearCornerPins()` 移除全部打点 ARAnchor。`SpatialWorldMapArchive` 仅保存地图数据、版本和方向，未编码这些房间；加载地图又明确调用 `clearCornerRooms()`，没有重建房间的路径。因此仅恢复地图无法恢复用户已完成的精细房间定义。

   验收：扫描并手动打点完成两个房间，保存地图；重新进入或在当前会话加载该地图，房间计数变为 0；重新生成报告仅采用恢复的自动平面，丢失手动房间。此前单独保存的实测报告可能暂时还含有这些房间，但生成新报告会覆盖该共享快照，不能把它视为地图恢复成功。

   修复方向：地图存档原子保存手动房间及必要标注，并在同一世界坐标系恢复；兼容旧版本的缺失字段。增加“打点完成 → 保存地图 → 新会话加载 → 再生成报告”的完整回归。

3. **[P2] 从 RoomPlan 返回 AR 时，父页面保留已获准状态，却没有重新持有相机租约**

   位置：[RootContentView.swift:994](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/RootContentView.swift:994)，关联 [RootContentView.swift:967](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/RootContentView.swift:967)、[ARSpatialSurveyView.swift:2732](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:2732)。

   同窗口的子闸门会接管相机租约，父闸门被覆盖时释放租约但不把 `phase` 从 `.granted` 重置。子页面退出后，父闸门的 `tryAcquire()` 又因 `.granted` 直接返回。AR 页同时在 `showRoomPlan` 变为 false 时无条件恢复会话，实际租约可能为空，或已被另一个等待窗口取得。

   验收：窗口一打开 AR 测绘，再进入其全屏 RoomPlan；窗口二打开相机并等待；关闭窗口一的 RoomPlan。子租约释放后，窗口二可以获准启动，窗口一也恢复 AR，但其父闸门没有重新申请。这会重新形成跨窗口相机会话争用，可能出现黑屏或会话中断。

   修复方向：授权状态绑定实际租约所有权及页面可见性；支持同场景嵌套会话的明确转交／恢复，父页面重新持有租约后才能恢复采集。需覆盖嵌套页面返回及另一个窗口等待的组合。

4. **[P2] 识别出的多边形房间拖动／缩放时，只更新矩形，真实轮廓仍留在原处**

   位置：[FloorplanView.swift:2883](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:2883)，关联 [FloorplanView.swift:2930](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:2930)、[FloorplanEngine.swift:390](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:390)。

   轮廓识别会写入全图归一化的 `polygonPoints`。拖动和缩放只改变 `room.rect`，包含实时 `auditedRooms` 更新也只复制矩形。显示轮廓及“按房间重新立极”优先读取旧多边形，而宫位审核、3D 投影读取修改后的矩形，二者随编辑产生分歧，并一起持久化。

   数值复核：矩形及多边形均为 `(0.1, 0.1)…(0.3, 0.3)`，向右移动 0.4 后矩形中心变为 `(0.6, 0.2)`，多边形质心仍是 `(0.2, 0.2)`。点击按房间重新立极会采用旧位置；把宽高放大两倍，实际轮廓面积也仍不变。

   修复方向：以手势开始时的原始矩形及轮廓为输入，对所有多边形顶点施加同一平移／缩放变换，限位后保持二者一致；审核、绘制、立极和导出统一使用更新后的几何。

5. **[P2] 凹形房间的包围盒可能抢占中宫，审核没有判断立极点是否在真实房间内**

   位置：[FloorplanEngine.swift:458](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:458)，关联 [FloorplanEngine.swift:483](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:483)。

   房间已支持真实多边形，但中宫房间仍只筛选 `rect.contains(centroid)`，并按包围盒面积取最小者。凹形房间空缺区域中的点也会被认为在该房间内，随后整个房间进入中宫专用判断；其余房间归宫也仍取包围盒中心，而非已有的真实质心函数。

   数值复核：L 形房间顶点为 `(0.1,0.1)、(0.6,0.1)、(0.6,0.3)、(0.3,0.3)、(0.3,0.6)、(0.1,0.6)`，包围盒面积 0.25；相邻矩形房间从 `(0.3,0.3)` 延伸至 `(0.95,0.95)`，面积 0.4225。立极点 `(0.5,0.5)` 位于矩形房间内、L 形之外，但两个包围盒都包含它，代码会选面积较小的 L 形房间作为中宫，影响显示及诊断分支。

   修复方向：存在轮廓时使用点在多边形内的判断，真实面积和质心驱动相关排序／归宫；仅无轮廓房间退化为矩形。此问题在完全不拖动房间时也会发生，需要独立覆盖。

6. **[P2] VR 纠正自动识别的入户门后，住宅向首仍冻结为纠正前的方向**

   位置：[VRSpatialSurveyView.swift:100](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/VRSpatialSurveyView.swift:100)，关联 [VRSpatialSurveyView.swift:664](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/VRSpatialSurveyView.swift:664)、[HouseSpatialSurveyModel.swift:721](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/HouseSpatialSurveyModel.swift:721)。

   从实测结果初始化 VR 时，无条件把 `resolvedHouseFacing` 保存为显式 `houseFacingDegrees`，没有区分人工确定的宅向和从入口法线自动推导的宅向。拖动／替换入口会改变生成的门位置与法线，却不更新该显式值；引擎又明确让显式值优先于入口几何，因此纠正入口不会纠正此前由错误入口推导的宅向。

   验收：实测入口误识别在东侧，自动得到向首 90°；进入 VR 把门移到真实南侧，再生成。生成的入口法线已指向南，但住宅向首仍为 90°，宅卦和飞星继续沿用旧方向。

   修复方向：保存向首来源，人工确定的宅向可继续锁定；自动来源在入口改变后重新推导，或提供明确的“随入口重算／固定宅向”选择。只保留方向值无法正确决定两种行为。

7. **[P2] AR 离轴目标的方向计算忽略手机横滚，倾斜持机会写错方位与仰角**

   位置：[GeometryUtils.swift:49](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/GeometryUtils.swift:49)，关联 [GeometryUtils.swift:67](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/GeometryUtils.swift:67)、[ARSpatialSurveyView.swift:1787](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:1787)、[ARVisionView.swift:1865](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:1865)。

   当前投影将屏幕 x 偏移独立加到航向、y 偏移独立加到仰角，曝光姿态只保存航向和仰角，没有完整相机基向量或横滚。手机绕光轴倾斜时，屏幕竖直方向同时具有世界水平分量，该分量在存档中被忽略；姿态兼容性检查也无法识别仅有横滚的变化。

   数值复核：光轴水平朝北，横向视场 50°、取景宽高比 0.5，目标在屏幕 `(0.5,0.25)`。当前算法始终给出方位 0°、仰角 25°；相对直立状态横滚 45° 后，完整三维射线的水平偏角绝对值约 18.249°、仰角约 17.388°。横滚方向决定水平偏角正负。曝光快照冻结了时间，但没有补齐这部分几何信息。

   修复方向：曝光时保存完整相机姿态及与取景坐标对应的投影，把目标像素反投影为相机射线，再转换到统一世界／地理坐标后求方位、仰角；共识检查也使用完整旋转。需覆盖横滚及同时俯仰的离轴目标。

8. **[P2] 长卷落款仍使用系统日历年份，佛历设置下干支年错误**

   位置：[TianJiShuEngine.swift:721](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/TianJiShuEngine.swift:721)。

   上轮已修复宅主／家属出生年的系统日历问题，但导出落款仍从 `Calendar.current` 提取年份，再直接套用公历干支年公式；立春判断却来自实际日期的节气计算。系统使用佛历时，这两部分使用不同的纪年。

   数值复核：2026 年立春后的报告应落款丙午；佛历读出的年份为 2569，当前公式得到己酉，且所有语言的签名文本都复用这个结果。

   修复方向：干支推导显式采用公历和与报告一致的时区，尽量复用现有节气年函数；系统日历只用于本地化显示。增加相同绝对日期在公历／佛历系统设置下结果相同的回归。

本轮验证与优先级：

- 临时 Python 复核了旧编辑页写入当前宅谱、地图恢复缺少手动房间、嵌套相机返回、房间平移后几何分歧、L 形中宫误判、VR 显式宅向优先级、横滚射线及佛历干支年，共 8 组数值／状态场景。状态模拟只用于检查推导，不替代原生测试。
- `polygonRectIOU` 的计算也有边界问题，但未发现调用方，未把未触达的辅助函数计入本轮功能缺陷。
- 本轮新增内容只有审查文档。第三轮修复已先提交为 `3db67ed`；其测试及静态检查范围见第三轮记录，现有 53 个 XCTest 仍需在 macOS 上运行。
- 建议先处理活动住宅身份校验和地图中手动房间的持久化，再处理相机会话转交、统一多边形编辑／审核几何，以及 VR 方向来源、完整相机投影和报告日历。
