#!/usr/bin/env bash
# barly-design Mac 工程：改完代码后一条命令：单测 → 构建 Release → 签名 → 替换 /Applications/Switchboard.app → 重新启动。
# （由 new-apple.sh 拷进 <工程>/scripts/install.sh；scheme = Switchboard-macOS，单测 target = Switchboard-macOSTests）
#
#   scripts/install.sh                  # 完整流程
#   scripts/install.sh --skip-tests     # 只改了界面文案之类，跳过单测
#   scripts/install.sh --no-launch      # 装好但不启动
#   scripts/install.sh --refresh-dock   # 换了 app 图标时用：重启 Dock，免得一直显示旧图标的缓存
#
# 签名：默认找钥匙串里的「Apple Development」证书。用固定证书签名后，app 的身份在每次构建间保持不变：
# 辅助功能、屏幕录制这类权限只需授权一次，钥匙串里存的密码也不会每次重装都弹「允许访问」。
# 找不到证书时退回 ad-hoc 签名，那样每次安装后都要重新授权。
# 想指定证书：APP_SIGN_IDENTITY="Apple Development: xxx" scripts/install.sh
set -euo pipefail

SKIP_TESTS=0; LAUNCH=1; REFRESH_DOCK=0
for arg in "$@"; do
    case "$arg" in
        --skip-tests) SKIP_TESTS=1 ;;
        --no-launch) LAUNCH=0 ;;
        --refresh-dock) REFRESH_DOCK=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "未知参数 ${arg}（--skip-tests / --no-launch / --refresh-dock）"; exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=Switchboard
BUNDLE_ID="design.barly.switchboard.mac"
DEST="/Applications/$NAME.app"
LOGS="$ROOT/.build/logs"
DERIVED="$ROOT/.build/release"
APP="$DERIVED/Build/Products/Release/$NAME.app"
DESTINATION="platform=macOS,arch=$(uname -m)"
mkdir -p "$LOGS"
cd "$ROOT"

step() { printf '\n▸ %s\n' "$1"; }
fail() { echo "❌ $1"; exit 1; }

# ── 0. 签名身份 ────────────────────────────────────────────────
# Xcode 统一用 ad-hoc 构建，构建完再用 codesign 按证书的 SHA-1 重签：绕开 Xcode 的 team / provisioning 匹配
IDENTITY="${APP_SIGN_IDENTITY:-Apple Development}"
IDENTITY_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep -F "\"${IDENTITY}" | head -1 || true)"
if [[ -n "$IDENTITY_LINE" ]]; then
    SIGN_HASH="$(awk '{print $2}' <<<"$IDENTITY_LINE")"
    IDENTITY="$(sed -n 's/.*"\(.*\)".*/\1/p' <<<"$IDENTITY_LINE")"
else
    SIGN_HASH=""
    IDENTITY="-（ad-hoc）"
fi

# ── 1. 生成工程 ────────────────────────────────────────────────
step "生成 Xcode 工程"
xcodegen generate --quiet || fail "xcodegen 失败"

# ── 2. 单测 ────────────────────────────────────────────────────
if [[ $SKIP_TESTS -eq 0 ]]; then
    step "运行单测"
    # 业务逻辑的单测在 BarlyKit 包里（ScreensTests），Xcode scheme 里的只有外壳的
    if ! (cd "$ROOT/BarlyKit" && swift test) >"$LOGS/screens-test.log" 2>&1; then
        grep -E "error:|✘" "$LOGS/screens-test.log" | sort -u | head -20
        fail "单测没过，没有安装。完整日志：${LOGS}/screens-test.log"
    fi
    grep -E "Test run with" "$LOGS/screens-test.log" | tail -1 | sed 's/^/  /'
    if ! xcodebuild -skipPackagePluginValidation -skipMacroValidation -project "$NAME.xcodeproj" -scheme "$NAME-macOS" -destination "$DESTINATION" \
            -derivedDataPath "$ROOT/.build/xcode" test >"$LOGS/test.log" 2>&1; then
        grep -E "error:|✘" "$LOGS/test.log" | sort -u | head -20
        fail "单测没过，没有安装。完整日志：${LOGS}/test.log"
    fi
    grep -E "Test run with" "$LOGS/test.log" | tail -1 | sed 's/^/  /'
fi

# ── 3. 构建 Release ───────────────────────────────────────────
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
step "构建 Release（build ${BUILD_NUMBER}，签名：${IDENTITY}）"
if ! xcodebuild -skipPackagePluginValidation -skipMacroValidation -project "$NAME.xcodeproj" -scheme "$NAME-macOS" -configuration Release -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED" "CURRENT_PROJECT_VERSION=$BUILD_NUMBER" CODE_SIGN_IDENTITY=- \
        build >"$LOGS/release.log" 2>&1; then
    grep -E "error:" "$LOGS/release.log" | sort -u | head -20
    fail "构建失败，没有安装。完整日志：${LOGS}/release.log"
fi
WARNINGS="$(grep -E "^/.*\.swift:[0-9]+:[0-9]+: warning:" "$LOGS/release.log" | sort -u || true)"
if [[ -n "$WARNINGS" ]]; then
    echo "  ⚠️  编译警告："
    echo "$WARNINGS" | head -10 | sed 's/^/     /'
fi
if [[ -n "$SIGN_HASH" ]]; then
    # 包里的 tmux 先单独签，再签整个 app；都带 hardened runtime（重签不带会把 Xcode 设的标记丢掉）
    if [[ -x "$APP/Contents/Resources/Tmux/bin/tmux" ]]; then
        codesign --force --sign "$SIGN_HASH" --options runtime --timestamp=none "$APP/Contents/Resources/Tmux/bin/tmux" >"$LOGS/codesign.log" 2>&1 \
            || fail "tmux 签名失败：${LOGS}/codesign.log"
    fi
    # Sparkle 里的 XPC 服务、Autoupdate、Updater.app、框架本身：由内到外逐个签（不用 --deep）
    SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
    if [[ -d "$SPARKLE" ]]; then
        for item in "$SPARKLE"/Versions/B/XPCServices/*.xpc "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
            [[ -e "$item" ]] || continue
            codesign --force --sign "$SIGN_HASH" --options runtime --timestamp=none --preserve-metadata=entitlements "$item" >>"$LOGS/codesign.log" 2>&1 \
                || fail "Sparkle 签名失败：${LOGS}/codesign.log"
        done
    fi
    codesign --force --sign "$SIGN_HASH" --options runtime --timestamp=none "$APP" >>"$LOGS/codesign.log" 2>&1 \
        || fail "证书签名失败：${LOGS}/codesign.log"
fi
codesign --verify --strict "$APP" 2>>"$LOGS/codesign.log" || fail "签名校验失败：${LOGS}/codesign.log"
# 构建目录里的这份别留在 LaunchServices 里：同一个 bundle ID 登记多份时，程序坞可能拿错的那份找图标，显示成空白模板
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -u "$APP" 2>/dev/null || true
for debug_app in "$ROOT/.build/xcode/Build/Products/Debug/$NAME.app" "$ROOT/.build/loc/Build/Products/Debug/$NAME.app"; do
    [[ -d "$debug_app" ]] && "$LSREGISTER" -u "$debug_app" 2>/dev/null || true
done

# ── 4. 替换 /Applications 里的旧版 ─────────────────────────────
step "安装到 ${DEST}"
if pgrep -xq "$NAME"; then
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in {1..20}; do pgrep -xq "$NAME" || break; sleep 0.2; done
    pkill -x "$NAME" 2>/dev/null || true
    sleep 0.3
fi
rm -rf "$DEST"
ditto "$APP" "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
if [[ $REFRESH_DOCK -eq 1 ]]; then
    touch "$DEST"; killall Dock 2>/dev/null || true
fi

VERSION="$(defaults read "$DEST/Contents/Info" CFBundleShortVersionString)"
echo "  ${NAME} ${VERSION}（build ${BUILD_NUMBER}）"

# ── 5. 启动 ────────────────────────────────────────────────────
if [[ $LAUNCH -eq 1 ]]; then
    step "启动"
    open "$DEST"
fi

echo
echo "✅ 完成"
if [[ "$IDENTITY" == -* ]]; then
    echo "   ad-hoc 签名：用到辅助功能 / 屏幕录制权限的，要去「系统设置 › 隐私与安全性」把 ${NAME} 关掉再打开一次；"
    echo "   读钥匙串的，重装后第一次会弹授权框，点「始终允许」。"
else
    echo "   固定证书签名：权限和钥匙串授权过一次后，以后重装不用再管。"
fi
