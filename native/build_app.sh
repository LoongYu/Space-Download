#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
BUILD_DIR="$SCRIPT_DIR/.build"
APP_DIR="$SCRIPT_DIR/dist/SpaceDownloadNative.app"
CONTENTS_DIR="$APP_DIR/Contents"

mkdir -p "$BUILD_DIR/cache" "$BUILD_DIR/config" "$BUILD_DIR/security" "$BUILD_DIR/module-cache"

CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache" swift build \
    --configuration release \
    --disable-sandbox \
    --build-path "$BUILD_DIR" \
    --cache-path "$BUILD_DIR/cache" \
    --config-path "$BUILD_DIR/config" \
    --security-path "$BUILD_DIR/security"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_DIR/release/SpaceDownloadNative" "$CONTENTS_DIR/MacOS/SpaceDownloadNative"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/Resources/SpaceDownload.icns" "$CONTENTS_DIR/Resources/SpaceDownload.icns"
if [[ -x "$SCRIPT_DIR/.tools/yt-dlp" ]]; then
    cp "$SCRIPT_DIR/.tools/yt-dlp" "$CONTENTS_DIR/Resources/yt-dlp"
    chmod +x "$CONTENTS_DIR/Resources/yt-dlp"
else
    echo "WARN: 未打包独立 yt-dlp；运行 ./prepare_tools.sh 后重新构建可生成自带下载引擎的 app"
fi
if [[ -n "${SPACEDOWNLOAD_FFMPEG_PATH:-}" && -x "$SPACEDOWNLOAD_FFMPEG_PATH" ]]; then
    cp "$SPACEDOWNLOAD_FFMPEG_PATH" "$CONTENTS_DIR/Resources/ffmpeg"
    chmod +x "$CONTENTS_DIR/Resources/ffmpeg"
fi
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
