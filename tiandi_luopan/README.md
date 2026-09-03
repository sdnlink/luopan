# 易学时空罗盘 - Android 应用

基于 WebView 打包的 Android 应用，完整保留 HTML 版本的所有功能。

## 功能特性

- 先天/后天八卦双模式切换
- 二十四山方位
- 二十四节气（定气法精确计算）
- 十二消息卦 + 六爻
- 先天六十四卦圆图（含卦图）
- 24小时制时间刻度 + 实时时间指针
- 指南针（设备方向传感器，手机端自动显示）
- 今日当令节气自动定位
- 触摸悬停查看详细信息
- 沉浸式全屏显示

## 系统要求

- Android 8.0 (API 26) 及以上
- 手机设备（指南针功能需要方向传感器）

## 构建方法

### 方法一：Android Studio（推荐）

1. 下载安装 [Android Studio](https://developer.android.com/studio)
2. 打开 Android Studio，选择 `Open an existing project`
3. 选择本目录（`android-app`）
4. 等待 Gradle 同步完成（首次需要下载依赖）
5. 连接 Android 手机（开启 USB 调试）或启动模拟器
6. 点击 Run 按钮（▶）或菜单 `Run > Run 'app'`

### 方法二：命令行构建

```bash
# 生成 APK（Debug 版本）
./gradlew assembleDebug

# APK 输出位置
# app/build/outputs/apk/debug/app-debug.apk

# 安装到连接的设备
./gradlew installDebug
```

Windows 系统使用 `gradlew.bat` 代替 `./gradlew`。

### 生成 Release APK

1. 生成签名密钥（keystore）
2. 在 `app/build.gradle` 中配置 signingConfigs
3. 运行 `./gradlew assembleRelease`

## 项目结构

```
android-app/
├── settings.gradle              # 项目设置
├── build.gradle                 # 根构建脚本
├── gradle.properties            # Gradle 属性
├── gradle/wrapper/              # Gradle Wrapper
└── app/
    ├── build.gradle             # 模块构建脚本
    ├── proguard-rules.pro       # 混淆规则
    └── src/main/
        ├── AndroidManifest.xml  # 应用清单
        ├── assets/
        │   └── yiijing_map.html # 罗盘页面（核心）
        ├── java/com/example/yiijingcompass/
        │   └── MainActivity.kt  # 主 Activity（WebView）
        └── res/
            ├── layout/           # 布局
            ├── values/           # 字符串/颜色/主题
            ├── drawable/         # 图标矢量图
            └── mipmap-anydpi-v26/ # 自适应图标
```

## 技术说明

- **WebView 方案**：将完整的 HTML/CSS/JS 打包到 assets，WebView 加载本地文件
- **无需重写**：所有 Canvas 绘制、触摸交互、节气计算完全复用
- **指南针**：通过 WebView 的 DeviceOrientationEvent 访问设备方向传感器
- **全屏**：沉浸式全屏模式，隐藏系统状态栏和导航栏
- **竖屏锁定**：固定竖屏显示，适配罗盘布局

## 更新罗盘内容

修改 `app/src/main/assets/yiijing_map.html` 后重新构建即可。
