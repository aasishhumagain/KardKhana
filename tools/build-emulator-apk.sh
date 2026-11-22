#!/usr/bin/env bash
set -euo pipefail

repo=$1
target=$2
tool_cache="${KARDKHANA_ANDROID_TOOL_CACHE:-$HOME/.cache/kardkhana-android-build}"
flutter="$tool_cache/flutter/bin/flutter"

if [[ ! -x "$flutter" || ! -x "$tool_cache/jdk/bin/java" || ! -d "$tool_cache/android-sdk" ]]; then
  echo "The KardKhana Flutter, Java, and Android build tools are missing from $tool_cache." >&2
  exit 1
fi

export JAVA_HOME="$tool_cache/jdk"
export ANDROID_HOME="$tool_cache/android-sdk"
export ANDROID_USER_HOME="$tool_cache/android-user"
export GRADLE_USER_HOME="$tool_cache/gradle"
export PUB_CACHE="$tool_cache/pub"
export PATH="$tool_cache/tools/usr/bin:$JAVA_HOME/bin:$PATH"
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=2 -Dorg.gradle.jvmargs=-Xmx3g"

build_dir=$(mktemp -d "$tool_cache/emulator-build.XXXXXXXX")
staged_apk=
cleanup() {
  if [[ -n "$staged_apk" ]]; then
    rm -f -- "$staged_apk"
  fi
  rm -rf -- "$build_dir"
}
trap cleanup EXIT

# Build a copy inside Linux so generated SDK paths never enter the Windows checkout.
tar -C "$repo/app" --exclude='./build' --exclude='./.dart_tool' \
  --exclude='./.idea' --exclude='./android/.gradle' --exclude='./android/.kotlin' \
  --exclude='./android/local.properties' --exclude='./android/app/build' \
  --exclude='./android/app/.cxx' -cf - . | tar -xf - -C "$build_dir"

cd "$build_dir"
"$flutter" --suppress-analytics build apk --debug --target-platform "$target"

out="$repo/app/build/emulator"
mkdir -p "$out"
staged_apk=$(mktemp "$out/.app-debug.XXXXXXXX")
cp build/app/outputs/flutter-apk/app-debug.apk "$staged_apk"
mv -f -- "$staged_apk" "$out/app-debug.apk"
