#!/usr/bin/env bash
set -euo pipefail

target="${1:-debug}"
case "$target" in
  debug|release) ;;
  *) echo "用法: $0 [debug|release]" >&2; exit 2 ;;
esac

if ! command -v java >/dev/null 2>&1; then
  echo "缺少 Java。请安装 JDK 17，并设置 JAVA_HOME。" >&2
  exit 1
fi
if ! command -v javac >/dev/null 2>&1; then
  echo "当前只有 Java Runtime，缺少 javac。请安装 JDK 17（不是 JRE）。" >&2
  exit 1
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo "缺少 Android SDK。请设置 ANDROID_SDK_ROOT 或 ANDROID_HOME。" >&2
  exit 1
fi

sdkmanager=""
for candidate in \
  "$sdk_root/cmdline-tools/latest/bin/sdkmanager" \
  "$sdk_root/cmdline-tools/bin/sdkmanager"; do
  if [[ -x "$candidate" ]]; then sdkmanager="$candidate"; break; fi
done
if [[ -z "$sdkmanager" ]]; then
  echo "未找到 sdkmanager；请安装 Android SDK Command-line Tools。" >&2
  exit 1
fi

if [[ ! -d "$sdk_root/platforms/android-34" || ! -d "$sdk_root/build-tools/34.0.0" ]]; then
  echo "正在检查 Android API 34 与 Build-Tools 34.0.0..."
  yes | "$sdkmanager" --sdk_root="$sdk_root" \
    "platforms;android-34" "build-tools;34.0.0"
fi

cd "$(dirname "$0")"
if [[ "$target" == "release" ]]; then
  ./gradlew assembleRelease
else
  ./gradlew assembleDebug
fi
