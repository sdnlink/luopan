# Android / iOS 自动编译与产物留存

GitHub Actions 入口：**Android & iOS Build**，配置在仓库根目录 `.github/workflows/build-mobile.yml`。

## 触发与结果

- 推送到 `main` / `master`、向这两个分支提交 Pull Request，且修改本项目或该 workflow 时自动运行。
- 也可在 Actions 页面选择该流程，点击 **Run workflow** 手动编译所选分支。
- Android 和 iOS 使用独立 job，可以并行执行。一端失败不会取消另一端的构建和上传。
- 在运行详情页的 **Artifacts** 下载产物；每个 job 的 Summary 也有下载链接。
- 产物及诊断资料均保留 **30 天**，受仓库／组织保留策略约束。删除工作流运行记录也会删除关联产物。
- 每份产物附有提交 SHA、运行编号及 SHA256 校验文件，可追溯到具体代码。

## 可下载内容

| Artifact | 内容 | 使用方式 |
| --- | --- | --- |
| `Android-Packages-<run_id>-<attempt>` | Debug APK、Release APK、Release AAB、构建信息及 SHA256 | Debug APK 可安装；Release 产物未签名，分发前需配置正式签名。CI 不注入 Google Play 验证公钥，购买功能不可用。 |
| `Android-Diagnostics-<run_id>-<attempt>` | 编译日志、单元测试结果、Lint 报告、原生渲染截图 | 即使测试或 Lint 失败，已生成的安装包仍会上传。 |
| `iOS-Builds-<run_id>-<attempt>` | 设备 `.xcarchive.tar.gz`、模拟器 `.app.tar.gz`、构建信息及 SHA256 | 设备归档未签名，不是可安装 IPA；模拟器应用只能在兼容的 iOS Simulator 上运行。使用 tar 保留包内权限和符号链接。 |
| `iOS-Diagnostics-<run_id>-<attempt>` | Xcode 环境／编译日志、`.xcresult` | 构建失败时仍上传已有诊断资料；设备构建失败后仍尝试模拟器构建。 |

iOS Runner 沿用 `IOS_RUNNER_LABEL` 仓库变量，默认 `xcode-27`，并检查设备和模拟器 SDK 均不低于 27.1，保持项目现有 CI 的 SDK 要求。普通双端编译不需要 Apple 证书或商店密钥。

## 正式签名 iOS IPA

已有 **iOS Multi-Mode Build & Deploy**（`.github/workflows/build-ios.yml`）继续负责开发签名 IPA、App Store IPA 和可选的 TestFlight 上传，仍使用原有签名 Secrets。该流程的 IPA 和构建日志也统一保留 30 天。

新增的双端流程只编译和留存产物，不执行商店发布。iOS 功能回归测试仍由独立的 **iOS Functional Regression Tests** 流程运行。
