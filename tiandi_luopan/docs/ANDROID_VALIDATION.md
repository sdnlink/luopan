# Android 原生移植验证记录

验证日期：2026-11-14（Asia/Shanghai）。iOS 基准：`b8428b46384e1eed9c17eb1135e176c30e471905`。Android 版本：`1.3.4` / `134`。

## 自动化结果

| 检查 | 结果 |
| --- | --- |
| `:app:assembleDebug` | 成功 |
| `:app:testDebugUnitTest` | 68 项，0 失败，0 错误 |
| `:app:lintDebug` | 0 错误；79 条警告，包括绘制时对象分配、文本拼接、旧 API 与既有资源问题 |
| iOS 规范翻译 | 827 键 × 8 语言逐值一致 |
| 全部 Android 翻译 | 1086 键 × 8 语言，键集一致 |
| Swift 源码对照 | 56 个文件，对应 Android 文件均存在 |
| `git diff --check` | 通过 |
| iOS 文件修改 | 无 |

测试集：

- `IOSParityTests`：20 项，比例与方位、多边形、DST/立春、子初、稳定 ID、家庭分配、来源、投影、测绘映射与物业切换。
- `NativeWorkflowTests`：9 项，五个首页与分析菜单原生启动、购买签名防篡改、消费去重、单案授权、导入校验、图片轮廓候选、冻结快照、泰语日历。
- `SpatialAndStateParityTests`：21 项，签名账本、密钥不可用、预留/提交/退回、iOS 备份互通、多实例档案、三点定位、曝光姿态/深度、锁盘与物理朝向分离、几何判定、订阅周期、深链接、相机互斥、语言快照与米制 DXF。
- `DeepAnalysisParityTests`：17 项，81 星对关系、按所选方位生成来源、季节与现场条件优先级、卧室/厨卫用途约束、真实房间覆盖、旋转不变性、门向推导、模型权限、家庭隐私、长报告实际排版。
- `NativeRenderingTests`：1 项，使用原生字体渲染罗盘/户型/分析页面，并检查 Activity 重建。

原生渲染输出在 `app/build/native-screenshots/tab-0.png`、`tab-2.png`、`tab-3.png`。测试 HTML 在 `app/build/reports/tests/testDebugUnitTest/index.html`；Lint 在 `app/build/reports/lint-results-debug.html`。这些是构建产物，不加入源码。

## 构建环境与命令

实际使用 JDK 17.0.12、Gradle 8.2、Android SDK 34 / Build Tools 34.0.0、Robolectric 4.12.2。测试执行 API 28；Robolectric 另读取 API 34 的目标资源。两个测试运行环境均通过 Maven 官方 SHA512 校验。

```sh
./gradlew :app:testDebugUnitTest :app:assembleDebug :app:lintDebug
python3 tools/sync_android_ios_resources.py --revision b8428b46384e1eed9c17eb1135e176c30e471905 --check
```

离线测试可增加 `-PROBOLECTRIC_DEPENDENCY_DIR=/absolute/path/to/runtime-jars`。本次工具链临时放在 `/tmp/tiandi-android-tools`，不写入仓库或 APK。

## 安装包

文件：`app/build/outputs/apk/debug/yanxiang-v1.3.4-debug.apk`，为调试签名包。

SHA256：`f5eac8187e5572a201bd23ebb3a08480ab94fc66774e04bc5585e75b36abf01e`。

## 未完成的真机与平台等价验收

本机没有连接 Android 真机，也没有 Play Console 商品配置/公开许可密钥/测试购买账号，因此不能声称以下流程已实测：

- 相机取景变换、ARCore 安装/恢复、平面/Depth、多房间移动、实际测距与传感器精度。
- 门内视角、地图三点恢复、现场候选识别准确率、双窗口相机竞争。
- Android 13+ 通知权限、重启/时区变化后的提醒、小组件桌面尺寸与后台实际刷新、相册权限。
- Google Play 成交、订阅到期/退款/恢复、待处理交易与消耗品重试。客户端恢复无法查询已经消耗后被退款的订单；完整跨设备消耗余额及退款撤回需要服务端 Play Developer API / RTDN 账本。

Apple **RoomPlan 自动建筑语义、USDZ 导出、ARWorldMap 自动重定位、iCloud KV 和 WidgetKit 锁屏呈现**未达到原平台的等价效果。Android 已提供对应操作流程，具体替代方式见 [移植说明](ANDROID_IOS_PORT.md)。上述事项保留在交付范围中，不将源码映射或自动化测试通过当作“全部能力已无差异完成”的证明。
