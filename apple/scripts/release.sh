#!/usr/bin/env bash
# 发一个版本：构建 Release → 签名（可选公证）→ 打 zip → 生成带 EdDSA 签名的 appcast.xml → （--publish）发到 GitHub Releases。
#
#   scripts/release.sh 0.2.0                          # 只在本地生成 dist/0.2.0/，不上传（先看一眼）
#   scripts/release.sh 0.2.0 --notes notes.md         # 带更新说明（Markdown，Sparkle 更新窗口里显示）
#   scripts/release.sh 0.2.0 --notes notes.md --publish   # 生成并发布：gh release create v0.2.0
#
# 已装的 app 每天读 https://github.com/gaoziman/Switchboard/releases/latest/download/appcast.xml，
# 所以 appcast.xml 要作为附件挂在「最新的那个 Release」上（本脚本会挂）。
#
# 签名：
#   APP_SIGN_IDENTITY="Developer ID Application: …"   默认用钥匙串里的 Apple Development（别人电脑上首次打开要去「系统设置 › 隐私与安全性」点「仍要打开」）
#   NOTARY_PROFILE=<notarytool 钥匙串配置名>            设了就开 hardened runtime、加时间戳、送公证并装订（需要 Developer ID）
# 更新签名私钥在登录钥匙串（账户 switchboard），备份在 ~/.config/switchboard/sparkle_ed25519_private.key。丢了就再也发不出已装用户能收的更新
set -euo pipefail

VERSION="${1:-}"; shift || true
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { sed -n '2,16p' "$0"; exit 2; }
NOTES=""; PUBLISH=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes) NOTES="$2"; shift 2 ;;
        --publish) PUBLISH=1; shift ;;
        *) echo "未知参数 $1"; exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=Switchboard
REPO=gaoziman/Switchboard
DERIVED="$ROOT/.build/release"
APP="$DERIVED/Build/Products/Release/$NAME.app"
OUT="$ROOT/dist/$VERSION"
LOGS="$ROOT/.build/logs"
SPARKLE_BIN="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin"
mkdir -p "$LOGS"
cd "$ROOT"

step() { printf '\n▸ %s\n' "$1"; }
fail() { echo "❌ $1"; exit 1; }

if [[ $PUBLISH -eq 1 ]]; then
    gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1 && fail "v$VERSION 已经发过了"
fi

# ── 签名身份 ──
IDENTITY="${APP_SIGN_IDENTITY:-Apple Development}"
LINE="$(security find-identity -v -p codesigning | grep -F "\"${IDENTITY}" | head -1 || true)"
[[ -n "$LINE" ]] || fail "钥匙串里没有「${IDENTITY}」证书"
SIGN_HASH="$(awk '{print $2}' <<<"$LINE")"
IDENTITY="$(sed -n 's/.*"\(.*\)".*/\1/p' <<<"$LINE")"
SIGN_OPTS=(--force --sign "$SIGN_HASH")
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    [[ "$IDENTITY" == "Developer ID Application"* ]] || fail "公证要用 Developer ID Application 证书"
    SIGN_OPTS+=(--options runtime --timestamp)
else
    SIGN_OPTS+=(--timestamp=none)
fi

# ── 单测：没过不发 ──
step "运行单测"
(cd "$ROOT/BarlyKit" && swift test) >"$LOGS/release-test.log" 2>&1 \
    || { grep -E "error:|✘" "$LOGS/release-test.log" | sort -u | head -20; fail "单测没过：$LOGS/release-test.log"; }
grep -E "Test run with" "$LOGS/release-test.log" | tail -1 | sed 's/^/  /'

# ── 构建 ──
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
step "构建 $NAME ${VERSION}（build ${BUILD_NUMBER}）"
xcodegen generate --quiet || fail "xcodegen 失败"
xcodebuild -skipPackagePluginValidation -skipMacroValidation -project "$NAME.xcodeproj" -scheme "$NAME-macOS" -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED" \
    "MARKETING_VERSION=$VERSION" "CURRENT_PROJECT_VERSION=$BUILD_NUMBER" CODE_SIGN_IDENTITY=- \
    build >"$LOGS/release-dist.log" 2>&1 || { grep -E "error:" "$LOGS/release-dist.log" | sort -u | head; fail "构建失败：$LOGS/release-dist.log"; }

# ── 签名：由内到外 ──
step "签名：$IDENTITY"
sign() { codesign "${SIGN_OPTS[@]}" "$@" >>"$LOGS/release-sign.log" 2>&1 || fail "签名失败：$* （$LOGS/release-sign.log）"; }
: >"$LOGS/release-sign.log"
# 包里必须有 tmux，而且架构和 app 一样（只有 arm64 的 tmux 在 Intel Mac 上起不来）
TMUX_BIN="$APP/Contents/Resources/Tmux/bin/tmux"
[[ -x "$TMUX_BIN" ]] || fail "包里没有 tmux"
archs() { lipo -archs "$1" | tr ' ' '\n' | sort | tr '\n' ' '; }
[[ "$(archs "$APP/Contents/MacOS/$NAME")" == "$(archs "$TMUX_BIN")" ]] \
    || fail "tmux 的架构（$(archs "$TMUX_BIN")）和 app（$(archs "$APP/Contents/MacOS/$NAME")）不一样"
sign "$TMUX_BIN"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for item in "$SPARKLE"/Versions/B/XPCServices/*.xpc "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
    [[ -e "$item" ]] && sign --preserve-metadata=entitlements "$item"
done
sign "$APP"
codesign --verify --deep --strict "$APP" || fail "签名校验失败"
# 构建目录里的这份别留在 LaunchServices 里（同一个 bundle ID 登记多份，程序坞会显示空白图标）
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true

# ── 打包 ──
step "打包到 dist/$VERSION"
rm -rf "$OUT" && mkdir -p "$OUT"
ZIP="$OUT/$NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    step "公证（几分钟）"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait >"$LOGS/notary.log" 2>&1 || { tail -5 "$LOGS/notary.log"; fail "公证失败"; }
    xcrun stapler staple "$APP" >/dev/null || fail "装订失败"
    rm "$ZIP" && ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
fi

# 更新说明：和 zip 同名的 .md，generate_appcast 会嵌进 appcast
[[ -n "$NOTES" ]] && cp "$NOTES" "$OUT/$NAME-$VERSION.md"

# ── appcast：只放这一个版本；用钥匙串里的私钥签 ──
step "生成 appcast.xml"
"$SPARKLE_BIN/generate_appcast" --account switchboard --maximum-deltas 0 --embed-release-notes \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$REPO" "$OUT" >"$LOGS/appcast.log" 2>&1 || { cat "$LOGS/appcast.log"; fail "generate_appcast 失败"; }
grep -q 'sparkle:edSignature' "$OUT/appcast.xml" || fail "appcast 里没有 EdDSA 签名"
grep -q "sparkle:shortVersionString>$VERSION<\|sparkle:shortVersionString=\"$VERSION\"" "$OUT/appcast.xml" || fail "appcast 版本号不对"
ls -lh "$OUT" | tail -n +2 | sed 's/^/  /'

if [[ $PUBLISH -eq 0 ]]; then
    echo
    echo "✅ 本地生成完毕（没有上传）。确认无误后加 --publish 再跑一次。"
    exit 0
fi

# ── 发布 ──
step "发布到 GitHub：v$VERSION"
NOTES_ARGS=(--notes "Switchboard $VERSION")
[[ -n "$NOTES" ]] && NOTES_ARGS=(--notes-file "$NOTES")
gh release create "v$VERSION" --repo "$REPO" --title "Switchboard $VERSION" "${NOTES_ARGS[@]}" "$ZIP" "$OUT/appcast.xml"
echo
echo "✅ 已发布：https://github.com/$REPO/releases/tag/v$VERSION"
