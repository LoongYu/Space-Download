#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
TOOLS_DIR="$SCRIPT_DIR/.tools"
YTDLP_PATH="$TOOLS_DIR/yt-dlp"

mkdir -p "$TOOLS_DIR"

if [[ ! -x "$YTDLP_PATH" ]]; then
    TEMP_DIR=$(mktemp -d /private/tmp/spacedownload-tools.XXXXXX)
    gh release download \
        --repo yt-dlp/yt-dlp \
        --pattern yt-dlp_macos \
        --dir "$TEMP_DIR"
    mv "$TEMP_DIR/yt-dlp_macos" "$YTDLP_PATH"
    chmod +x "$YTDLP_PATH"
fi

"$YTDLP_PATH" --version
