**iOS 第三轮逻辑审查 · 2026-11-08**

审查基线：`f6a57dc`，即本次已提交的第二轮修复。继续检查扫描坐标、二维／三维回流、异步识别、报告快照和多窗口持久化，确认 9 项问题：4 项 P1、5 项 P2。本轮记录发现及修复方向，尚未实施这些新增问题的修复。

结论来自调用链、状态转移和临时 Python 数值复核。当前环境为 Linux，没有 Swift/Xcode；未执行原生编译、35 个 XCTest、AR/LiDAR 或多窗口真机验收。下面的复现步骤是待执行的原生验收路径，不代表已在设备上复现。

1. **[P1] 多窗口保存宅谱，会覆盖另一窗口刚新增的档案**

   位置：[FloorplanView.swift:960](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:960)，关联 [FloorplanView.swift:590](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:590)、[Info.plist:69](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Info.plist:69)。

   应用明确开启多场景，但 `savedCases` 是每个 `FloorplanView` 各自的 `@State`，仅首次恢复时读取共享存储。新增、导入、删除均把本窗口的整个数组覆盖到同一个 UserDefaults 键；没有共享的档案存储对象、版本校验或增量合并。

   复现：两个窗口都载入 `[A]`；窗口一新增 B，持久化为 `[B, A]`；窗口二仍持有 `[A]`，新增 C 后持久化为 `[C, A]`。B 从档案列表丢失。删除操作也可能让另一窗口此前删除的条目重新出现。上述数组写入顺序已做控制流模拟。

   修复方向：档案库采用进程内共享存储，按档案 ID 执行增删改并发布更新；持久化由该存储统一完成。活动户型的共享键和背景图片也应使用同一份状态或明确按场景隔离，避免旧窗口回写覆盖新窗口。

2. **[P1] 锁盘后启动 AR／RoomPlan，仍把锁定宅向当成相机当前方向**

   位置：[ARSpatialSurveyView.swift:463](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:463)、[ARRoomPlanCaptureView.swift:177](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:177)。

   两条采集入口都从 `motion.headingState.facingAngle` 初始化测绘方向基准。这个值在锁盘／手动选山后表示住宅锁定角，而非相机此刻的真实方向。航向管理器已经独立维护 `liveSensorHeading`，实景页面也通过 `arCameraFacingAngle` 使用它；空间扫描入口没有采用相同区分。

   验收：先锁宅向 90°，转向 180°，再启动扫描。真实传感器已更新为 180°，模型仍保存基准 90°，后续房间归宫、导入蓝图和地图存档均沿用该错误基准。地面八卦投影在 [ARSpatialSurveyView.swift:540](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:540) 也读取锁定值，存在相同偏转。

   修复方向：测绘坐标基准从同一时刻的真实相机姿态和有效实时航向建立，独立于住宅锁定角；缺少有效测量时先完成校准，而不是拿锁盘值替代物理方向。

3. **[P1] RoomPlan → 二维 → 当前 3D／VR，会再次把坐标基准写成住宅向首**

   位置：[FloorplanView.swift:424](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:424)、[FloorplanView.swift:2134](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:2134)，关联 [ARRoomPlanCaptureView.swift:478](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:478)。

   上轮在空间模型中拆分了 `compassHeading` 和 `houseFacingDegrees`，但二维回流入口仍向两个参数传相同的 `effectiveHeading`。RoomPlan 同步给二维的值明确是蓝图上方的坐标基准；二维布局没有另存住宅向首，重新生成时也没有采用已保存 survey 的住宅向首。

   对照输入：原始测绘基准 0°、大门朝东 90°，实测 survey 已正确得到住宅向首 90°。同步二维后，`effectiveHeading` 为 0°；打开“当前户型 3D”或进入 VR，则显式传入住宅向首 0°。引擎优先使用显式参数，门法线无法纠正它，导致同一户型两条路径的宅卦／飞星不同。

   这是上一轮方向拆分尚未覆盖的回流路径，也涉及上一轮新增的 VR 参数传递。修复方向：二维布局也分别持久化坐标基准和住宅向首，导入及重建全程保留二者；对没有明确向首的布局，可从门几何推导，不能直接复制坐标基准。

4. **[P1] 扫描坐标旋转后，RoomPlan 可能把室内门识别成入户门**

   位置：[ARRoomPlanCaptureView.swift:859](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:859)，同样的选择规则还用于 [ARRoomPlanCaptureView.swift:703](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARRoomPlanCaptureView.swift:703)。

   入户门按“距离世界坐标轴对齐包围盒最近”选择。轴对齐包围盒会随扫描坐标方向改变，距离排序不具备旋转不变性。上轮引擎改为用入户门法线推导住宅向首后，这个前置识别错误会直接改变住宅向首及其全部宅卦／飞星分析。

   数值复核：10×6 米矩形房，外墙角点为 `(±5, ±3)`，入户门位于 `(5, 0)`，室内门位于 `(4.5, 2)`。未旋转时两门距包围盒分别为 0 米和 0.5 米，选中入户门；将所有几何旋转 45° 后，距离分别变成约 2.121 米和 1.061 米，改选室内门。两次差异都大于源码的 0.05 米平局阈值，门宽排序无法修正。

   修复方向：使用真实外轮廓或保持物理方向的边界判断，保留用户确认入户门的能力；增加任意角度旋转的入口识别回归，不能只覆盖 90° 旋转和已标好入口的引擎输入。

5. **[P2] AI 识别完成后，使用回调时的朝向和深度保存旧图像目标**

   位置：[ARVisionView.swift:1816](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:1816)，关联 [ARSpatialSurveyView.swift:271](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARSpatialSurveyView.swift:271)。

   三帧先采集再串行运行 Vision，返回值只保留图像内的二维目标坐标；`ARCapturedFrame` 没有采集时的航向／相机姿态。最终自动入档时，`targetCalculatedHeading` 读取最新实时航向，距离又从当前帧重新采样。三帧共识检查仅比较类型、图像坐标和置信度，无法检查分析期间的转身。

   验收：朝东采完三帧，分析返回前转向南。识别结果仍对应东面的旧图像，却按南向和新画面的深度写入档案。这是自动持久化结果，用户无需再点一次“标记”。

   修复方向：每帧携带同一曝光时刻的相机姿态、方向和目标深度证据，先把检测点转换成可比较的物理方位再形成共识；或检测到足够大的位姿变化时使该次识别失效。

6. **[P2] 上下拖动 AR 目标框后，保存的测距位置与屏幕显示不一致**

   位置：[ARVisionView.swift:1835](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:1835)，关联 [ARVisionView.swift:1097](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:1097)、[ARVisionView.swift:1177](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:1177)。

   框体位置及框内显示的 LiDAR 距离使用包含 `targetOffset.height` 的屏幕采样点；持久化所用 `currentTargetSamplePoint.y` 只取原始 `targetNormalizedPoint.y`，完全忽略垂直拖动。存证快照的深度采样也使用原始 y。

   验收：画面中心是近处物体，向下拖框对准更远的地面。框内距离按地面采样，点击标记后存档却采样原来的画面中心；存证图片上的测距也可能与拖动后的框内读数不同。

   修复方向：用一个完整的、经过相同限位的二维目标坐标同时驱动框体、方位／仰角、测距、标记和存证，垂直拖动与水平拖动使用一致的转换规则。

7. **[P2] 图像上方目标被记为负仰角，下方目标被记为正仰角**

   位置：[ARVisionView.swift:558](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/ARVision/ARVisionView.swift:558)，关联 [OnDeviceShaAnalyzer.swift:366](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/OnDeviceShaAnalyzer.swift:366)。

   识别结果已把 Vision 坐标转换为屏幕坐标：顶部 y=0、底部 y=1。仰角却以 `(y - 0.5)` 产生偏移后直接加到相机仰角，因此方向反了，与该属性注释中的“俯为负、仰为正”相矛盾。

   数值复核：横向视场 50°、相机水平、目标 y=0.25，按源码得到约 -7.139°；该目标位于画面上方，应为正偏移。y=0.75 时则相反。该值写入 `ExteriorShaRecord.elevationDegrees` 并显示在全景记录中。

   修复方向：统一屏幕坐标和相机坐标的 y 轴方向后计算仰角，同时采用真实取景区的视场和宽高比例，并覆盖上方、下方及垂直拖动场景。

8. **[P2] 户型长图导出没有冻结中宫，仍可出现旧结论配新立极点**

   位置：[FloorplanView.swift:3262](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:3262)，关联 [FloorplanView.swift:3114](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:3114)。

   导出前冻结了房间、朝向、底图和报告数组，却没有冻结 `centroid`。后台渲染闭包直接读取 SwiftUI 当前的中宫状态；导出期间没有阻止继续编辑，语言及宅主资料也仍在后台读取。

   验收：中宫为 `(0.5, 0.5)`、房间中心为 `(0.7, 0.5)` 时开始导出，后台绘制完成前把中宫移到 `(0.8, 0.5)`。报告仍保留按旧中宫得到的东侧判断，图片上的中宫却可能已经位于房间右侧，房间落成西侧。切换档案时也可能把不同档案的中宫混入同一张图。

   修复方向：在主线程构造包含中宫、语言、宅主资料的完整导出快照；后台只读取值类型输入，并在档案切换／页面退出时处理过期结果。

9. **[P2] 户型体检跨立春后仍可能保留上一年的流年结论**

   位置：[FloorplanView.swift:1397](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Views/Floorplan/FloorplanView.swift:1397)，关联 [FloorplanEngine.swift:451](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:451)、[FloorplanEngine.swift:821](/home/skn/code/luopan/tiandi_luopan/ios/TiandiLuopan/Models/FloorplanEngine.swift:821)。

   户型审核会读取当前紫白盘，把流年星、太岁、岁破、三煞写入房间说明。但页面的审核缓存仅依据朝向及中宫变化，没有定时刷新、交节订阅或回前台刷新；锁定朝向、停留当前标签时，时间变化不会重建已经保存的 `auditedRooms` 和 `auditReport`。

   验收：立春前打开户型页并固定坐向、中宫，跨过立春，或保持该标签从后台回到前台。即便实时紫白页已经更新，户型说明和直接导出的审核列表仍可使用上一年结果，直到调整户型或切换标签触发强制重算。

   修复方向：审核缓存纳入有效流年／节气状态，在时间边界与回前台时检查失效；引擎显式接收审核时间，使页面、缓存和导出使用同一时间快照。

本轮复核：

- 提交前 `git diff --check`、53 个 Swift 文件的括号／结构扫描和 Identifiable 检查通过；这些检查不包含 Swift 类型检查。
- 临时脚本复算了入口选择在 0°／45° 坐标下的距离排序、锁盘与实时方向的 90° 差、二维回流的向首覆盖、图像 y 轴的仰角符号、多窗口数组覆盖和导出中宫前后的方位变化。
- 现有回归测试没有覆盖本轮这些完整 UI 调用链；尤其“引擎收到正确入口”的旋转测试不能验证 RoomPlan 是否选对入口，“传入独立方向参数”的测试也不能验证二维调用方是否真的传入了两个不同参数。
