# 冗余内容复核与清理

本次按文件引用、构建入口、Swift 调用和资源读取方式复核，只删除已确认的冗余内容。

## 删除文件

- 已入库 Python 字节码 `tiandi_luopan/tools/__pycache__/audit_unlocalized_strings.cpython-313.pyc`。
- 可由 `analyze_html_features.py` 重新生成的 `html_features_summary.txt`。
- 无代码、构建或文档引用的 `tiandi_luopan/screen.png`。
- 八种语言的 `Localizable.strings`：原生运行时使用 `LocalizationManager.swift` 中的字典，未发现 Foundation 本地化 API 或 SwiftUI 字面量键读取这些副本。同步移除工程资源及分组引用，保留全部八语言 `InfoPlist.strings` 权限描述。
- 以下 20 个一次性源码修改脚本：不在 CI、构建或保留工具的调用链中，内容为历史源码替换、模板注入或迁移，部分仍使用固定 Windows 路径。清理 README 中已失效的脚本引用。

```text
append_prd_sections.py
apply_layer_and_motion_i18n.py
apply_view_localizations.py
deepen_refactoring.py
generate_full_prd.py
implement_advanced_metaphysics.py
implement_apple_iap.py
implement_ar_vision.py
implement_i18n.py
implement_ios_fixes.py
implement_multichannel_cashier.py
implement_tianjishu_engine.py
localize_all_remaining.py
localize_all_views.py
refactor_app.py
register_new_swift_files.py
update_batch2_localization.py
update_iap_localization.py
update_localization_manager.py
update_pbxproj.py
```

以上共删除 31 个文件、1,504,168 字节（约 1.43 MiB），不包含 Git 历史。Python 缓存和生成结果已加入忽略规则。

## 删除代码及构建引用

- `ARSpatialSurveyView.makeMarkerNode`、`ARVisionView.targetElevationDegrees`、`BaZhaiView.birthYearSectionTitle`：只有定义，没有调用。
- `LegalLinks.subscriptionInfo`：未引用的协议 URL 别名。
- `LegalDocument.terms/privacy`：关于页已使用官网链接，枚举仅保留实际使用的合规说明。后续按用户要求移除家庭资料管理底部的隐私说明区块；关于页和购买页继续提供官网隐私入口。声明字典保留，仅按后续要求移除联系电话和 App 备案字段，其余条款未删改。
- 原生代码没有 WebKit 调用，移除 Xcode 中未使用的 `WebKit.framework` 显式链接。
- 原生 App 不读取 `www/`，移除 Xcode 资源复制项。资源验证打包工具也停止复制 `www/` 和根目录 `index.html`；README 同步注明独立 PWA 与原生包的关系。

## 复核后保留

- `www/` 及其图标：`serve_ios_web.py`、`prepare_ios_web.py` 和 `generate_icons.py` 仍服务于独立 PWA，属于实际用途，不删除源码。
- `build_ios.ps1`、`package_ipa.py` 和 `generate_pbxproj.py`：仍是文档化的资源验证入口，保留；正式可安装 IPA 继续使用 macOS/Xcode 或现有 CI。
- 八语言官网页面、根地址兼容入口、各端图标与 Android/小程序代码：存在独立发布或配置引用。
- 完整协议、隐私声明和 `InfoPlist.strings`：属于正在使用的内容，不能因相似而删除。
- 本机 `.auto-moniter/` 等工作目录不纳入此次清理。

## 验证结果

- 13 项项目结构、隐私清单及网页政策检查通过，主 App 和 Widget 共 63 个编译条目的本地类型依赖检查通过。
- 6 项官网发布检查通过，重新生成包含 62 个站点文件的发布包。
- 修改后的 Swift 文件括号与结构检查通过；八语言字典键集合一致，无重复键，八份权限描述和六份 PWA 资源逐字节保持不变。
- 在隔离临时目录实际运行资源验证打包工具，确认无 `www/` 输入仍可组装，包内无 PWA 或冗余翻译文件，保留八语言权限描述。复制目标为每次新建目录，不需要 `dirs_exist_ok`，同时兼容当前 Python 3.7 检查环境。
- 浏览器检查覆盖八语言联系、隐私及条款页面 × 320/768/1440 像素共 72 组，确认联系渠道仅有邮箱、没有电话链接、官网备案仍展示，且没有横向溢出或丢失图片。
- 对比删除前文本，原生声明仅移除用户指定的电话及备案字段，网页声明仅移除电话字段，其余协议正文保持不变。
- 当前 Linux 环境不能执行 Xcode 编译或 StoreKit 真机恢复测试；正式构建仍需现有 macOS CI 验证。
