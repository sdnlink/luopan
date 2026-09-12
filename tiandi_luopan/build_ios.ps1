# ==========================================================
# 演象 · 时空罗盘 (YanXiang Compass) - iOS 编译与打包脚本
# ==========================================================
$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  正在构建 演象·时空罗盘 iPhone (iOS) 应用程序与安装包" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. 生成 iOS 全套高清图标
Write-Host "`n[1/4] 提取并生成 iOS AppIcon 与 PWA 图标资源..." -ForegroundColor Yellow
python tools/generate_icons.py
if ($LASTEXITCODE -ne 0) { throw "图标生成失败" }

# 2. 准备 iOS 优化的 Web 核心引擎
Write-Host "`n[2/4] 编译与适配 iOS 专用 Web 核心与桥接通道..." -ForegroundColor Yellow
python tools/prepare_ios_web.py
if ($LASTEXITCODE -ne 0) { throw "Web 核心适配失败" }

# 3. 生成 Xcode 工程配置
Write-Host "`n[3/4] 生成标准 Xcode 工程文件 (project.pbxproj)..." -ForegroundColor Yellow
python tools/generate_pbxproj.py
if ($LASTEXITCODE -ne 0) { throw "Xcode 工程生成失败" }

# 4. 打包生成 iOS IPA 安装包
Write-Host "`n[4/4] 组装并压缩生成 iOS IPA 安装包..." -ForegroundColor Yellow
python tools/package_ipa.py
if ($LASTEXITCODE -ne 0) { throw "IPA 打包失败" }

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  ✅ iOS 移植与打包成功！" -ForegroundColor Green
Write-Host "  产物目录: dist-ios/YanXiangCompass-v1.2.3.ipa" -ForegroundColor Green
Write-Host "  Xcode 工程: ios/TiandiLuopan.xcodeproj" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
