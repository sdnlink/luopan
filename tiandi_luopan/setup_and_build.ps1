param(
    [string]$Target = "release"
)

$ErrorActionPreference = "Continue"

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = "E:\code\android\tiandi_luopan" }
$toolsDir = Join-Path $baseDir ".tools"
$jdkDir = Join-Path $toolsDir "jdk-17"
$sdkDir = Join-Path $toolsDir "android-sdk"

# 1. 查找 JDK
$foundJava = Get-ChildItem -Path $jdkDir -Filter "java.exe" -Recurse | Select-Object -First 1
if (-not $foundJava) {
    Write-Error "JDK java.exe not found!"
    exit 1
}
$env:JAVA_HOME = $foundJava.Directory.Parent.FullName
$env:PATH = "$($env:JAVA_HOME)\bin;" + $env:PATH
Write-Host "Using JAVA_HOME: $($env:JAVA_HOME)"

# 2. 查找 sdkmanager
$sdkManagerBat = Join-Path $sdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkManagerBat)) {
    Write-Error "sdkmanager.bat not found at $sdkManagerBat"
    exit 1
}

# 3. 预置 License 许可
$licensesDir = Join-Path $sdkDir "licenses"
if (-not (Test-Path $licensesDir)) {
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null
}

$licContent = @"
24333f8a63b6825ea9c5514f83c2829b004d1fee
84831b9409646a3e80447306f0366e6539ebca84
d56f5187479451eabf01fb78af6dfcb131a6481e
"@
[System.IO.File]::WriteAllText((Join-Path $licensesDir "android-sdk-license"), $licContent.Trim())
[System.IO.File]::WriteAllText((Join-Path $licensesDir "android-sdk-arm-dbt-license"), "859f317696f67ef3d7f30a50a5560e7834b433fb")
[System.IO.File]::WriteAllText((Join-Path $licensesDir "android-sdk-preview-license"), "84831b9409646a3e80447306f0366e6539ebca84")
Write-Host "Android SDK licenses accepted."

# 4. 安装 SDK Platforms 与 Build-Tools
$platformDir = Join-Path $sdkDir "platforms\android-34"
$buildToolsDir = Join-Path $sdkDir "build-tools\34.0.0"

if (-not (Test-Path $platformDir) -or -not (Test-Path $buildToolsDir)) {
    Write-Host "Installing Android SDK Platform 34 and Build-Tools 34.0.0 via sdkmanager..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c `"$sdkManagerBat`" --sdk_root=`"$sdkDir`" `"platforms;android-34`" `"build-tools;34.0.0`""
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.WriteLine("y")
    $p.StandardInput.WriteLine("y")
    $p.WaitForExit()
    Write-Host "sdkmanager completed with exit code: $($p.ExitCode)"
}

# 5. 生成 local.properties
$localProperties = Join-Path $baseDir "local.properties"
$escapedSdkDir = $sdkDir.Replace("\", "\\").Replace(":", "\:")
[System.IO.File]::WriteAllText($localProperties, "sdk.dir=$escapedSdkDir`n")
Write-Host "Configured local.properties: sdk.dir=$escapedSdkDir"

# 6. 设置环境变量并编译
$env:ANDROID_HOME = $sdkDir
$env:ANDROID_SDK_ROOT = $sdkDir

Set-Location $baseDir
if ($Target -eq "release") {
    Write-Host "Running Gradle assembleRelease..."
    & ".\gradlew.bat" assembleRelease
    $apkPath = Join-Path $baseDir "app\build\outputs\apk\release\yanxiang.apk"
} else {
    Write-Host "Running Gradle assembleDebug..."
    & ".\gradlew.bat" assembleDebug
    $apkPath = Join-Path $baseDir "app\build\outputs\apk\debug\app-debug.apk"
}

if (Test-Path $apkPath) {
    $apkItem = Get-Item $apkPath
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ">>> APK 编译成功: $($apkItem.FullName)" -ForegroundColor Green
    Write-Host ">>> 文件大小: $([math]::Round($apkItem.Length / 1MB, 2)) MB ($($apkItem.Length) 字节)" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Error "APK file not found at: $apkPath"
}
