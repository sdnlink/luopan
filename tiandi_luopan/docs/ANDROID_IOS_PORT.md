# main 分支 iOS → 原生 Android

基准为 `b8428b46384e1eed9c17eb1135e176c30e471905`，使用 main 的原生罗盘应用，不包含临时 AR 装修分支。iOS 源码保持不变。Android 启动入口已改为 Kotlin 原生 Activity、View 和 Canvas；历史 WebView 页面不参与主界面。

完整的 **56 个 Swift 源文件对应入口**见 [源码对照表](ANDROID_IOS_SOURCE_MAP.md)，机器可读清单见 [android_port_inventory.json](android_port_inventory.json)。清单覆盖意味着实现入口存在；不等同于所有设备上的效果已通过验收。

## 原生能力

| 能力 | Android 实现 |
| --- | --- |
| 罗盘与传感器 | 二十四山、120 分金、64 卦、节气、双北、倾角/水准、磁场告警、校准、锁盘、手选坐向、图层预设、财神喜神方位。物理相机姿态不受锁盘影响。 |
| 核心计算 | WMM2025、真太阳时、立春换年、子初换日、夏令时、玄空/八宅/紫白/奇门/三合/择日，独立日期与时辰、元运和自动/手动替卦。 |
| 住宅分析 | 罗盘和当前住宅两种来源；真实房间采样、床灶门窗位置、流年流月与现场条件、来源注记、优先建议和住宅待办。 |
| 户型 | 图片导入、本地轮廓候选确认、矩形/多边形房间移动缩放、尺寸与坐标校准、房屋朝向与坐标北分离、立极点、撤销、重置、并发写入检查。 |
| 家庭 | 宅主与多个家庭成员的完整生日/年、性别、角色、稳定 ID，个人配卦、卧室/书房分别推荐、共享房间、手动分配、清空、导出人物隐私开关、个人资料删除。 |
| 测绘 | ARCore 平面与可选 Depth、多房间角点、平面候选人工确认、层高采样、两点鲁班尺、地面方位、现场取证、带方位与深度的冻结画面、三帧识别一致性、可拖动取样点。 |
| 手工与 3D | 从校准户型生成独立手工模型，手工补录门窗、家具、横梁，房间用途修正；透视/俯视/门内视角、旋转、八宅/玄空叠加、尺寸/警示开关、构件探查。 |
| 档案与互通 | 多住宅档案、改名/删除、测量与手工槽位、外景与现场条件、便携 JSON 内嵌底图，读取 main iOS JSONEncoder 的日期/几何/枚举格式。JSON 不导入购买授权。 |
| 导出 | 户型图文长报告、3D 报告 PDF、米制多边形 DXF、完整 JSON、宣纸长卷与日签/现场图片；原生预览缩放、分享、保存到相册，长文按真实排版扩展高度，署名/堂号/印章定制。 |
| 支付 | Google Play 商品实际价格及订阅阶段/周期，RSA 签名校验、Keystore 签名本地账本、购买去重、恢复/撤销重新核对、户型单档案次数、长卷导出预留/提交/退款。 |
| 系统集成 | 八种语言、三步引导、动态快捷方式、iOS 兼容深链接、日签、小组件、节气/择日通知、逐条/全部取消、跨住宅与年份提醒隔离、系统评分、法律与支持入口。 |
| 生命周期 | 横竖屏重建、宽屏罗盘/户型分栏、工作区旧写入拒绝、独立档案存储锁、双窗口相机互斥、后台停止传感器与相机。 |

## 平台专属能力的对应方式

这些差异有明确处理，不能理解成 Apple API 可以在 Android 运行：

- **RoomPlan / LiDAR 建筑语义**：Android 实现了实测平面、Depth、角点采集与手工校正流程。ARCore 不直接提供 RoomPlan 等价的自动门窗/家具语义；自动完整室内语义识别尚未达到 RoomPlan 的效果。
- **ARWorldMap**：Android 保存房间、标记和方位基准，重新进入时通过原顺序的三个实物点进行人工刚性校准。不会自动重定位，也不能直接加载 Apple 的 ARWorldMap 二进制文件。拟合误差超过 15 cm 时拒绝恢复。
- **SceneKit / USDZ**：3D 查看采用原生 Canvas 投影；导出 DXF、JSON、PNG、PDF。Apple USDZ 资产导出没有直接迁移。
- **Vision**：使用 Android 本地连通区域/轮廓几何与同类判定规则，双阈值及三帧一致性、可选深度证据。不是同一个视觉检测器，识别精度需要实景验证。
- **StoreKit / Keychain / iCloud**：使用 Google Play Billing、Android Keystore、Android 系统备份和便携档案。Apple 的购买、消耗余额及 iCloud KV 不会转成 Google Play 权益；设备 Keystore 密钥及付费余额不参加系统备份，会员在新设备经 Google Play 恢复。
- **WidgetKit / Spotlight**：使用可调尺寸的桌面 App Widget 与 Android 快捷方式。刷新在换日、子初、节气边界及系统周期安排；Android 可能延迟后台闹钟。Android 分享回调只能确认用户选择了目标应用，无法确认目标应用最终发送成功。

## 构建

环境：JDK 17、Android SDK 34 / Build Tools 34.0.0、项目 Gradle Wrapper 8.2。无需提交本机 SDK、缓存、签名文件或凭据。

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
python3 tools/sync_android_ios_resources.py --revision b8428b46384e1eed9c17eb1135e176c30e471905 --check
```

首次运行 Robolectric 需要从 Maven 下载测试用 Android 运行环境。离线环境可事先下载并校验官方 `android-all-instrumented` 运行包，再通过 `-PROBOLECTRIC_DEPENDENCY_DIR=/absolute/path/to/runtime-jars` 指定目录。该参数不影响 APK。

Google Play **公开 RSA 许可密钥**通过 Gradle 属性或同名环境变量 `GOOGLE_PLAY_LICENSE_KEY` 配置，不是私钥。缺少时禁止发起购买。还需在 Play Console 创建匹配 `InAppProductId` 的商品/订阅，并配置测试账号和商店版本。正式签名继续使用现有 `YANXIANG_*` 参数。

## 验证与交付边界

自动化覆盖计算边界、空间坐标、备份转换、并发档案、签名及账本、消费预留/取消、深度取样、来源隔离、家庭隐私、五个原生首页及分析菜单启动、原生字体排版、超长报告和页面重建。原生渲染截图由测试生成在 `app/build/native-screenshots/`。

尚需 Android 真机完成：磁场/姿态精度、相机方向与取景一致性、ARCore 支持/不支持设备、Depth 可用/不可用设备、多房间与地图人工恢复、门内视角、相册拒绝权限、通知权限/重启恢复、双窗口相机竞争，以及 Play 测试购买/退款/到期/恢复。当前工作区没有连接这些设备或 Play 测试账号，不能把自动化通过称为这些流程已实测。

最终验证的具体命令、测试数和报告见 [验证记录](ANDROID_VALIDATION.md)。
