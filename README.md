<div align="center">

# 🚀 Space Download

**基于 yt-dlp 的图形界面视频下载工具**

[![License: Unlicense](https://img.shields.io/badge/-Unlicense-blue.svg?style=for-the-badge)](LICENSE)

</div>

## 简介

Space Download 是一个基于 yt-dlp 的桌面视频下载工具，提供简洁美观的图形界面，支持多种视频网站的视频下载。

## 功能特性

- 🎬 支持多平台视频下载
- ▶️ 原生 macOS 版支持 YouTube 单视频、播放列表和频道下载
- 🔓 YouTube 公开内容默认无需 Cookies，登录限制内容可单独选择 Cookies 文件
- 🧩 原生 macOS 版使用独立站点适配器，站点设置互不混用并可继续扩展
- 𝕏 原生 macOS 版支持 X 单条 status 的视频、animated GIF 与单帖多视频资源；X Cookies 独立且仅手动选择
- 🎵 原生 macOS 版支持公开 TikTok 单视频与安全短链入口；TikTok 设置和手动 Cookies 文件完全独立
- 🎶 原生 macOS 版支持抖音公开单视频标准链接和安全短链入口；抖音与 TikTok 的设置、图标和手动 Cookies 完全隔离
- 📸 原生 macOS 版支持公开 Instagram Reel、单帖视频和 carousel 中的视频资源；仅使用独立手动 Cookies 文件，图片暂不下载
- ✈️ 原生 macOS 版支持 Telegram 公开频道单条消息中的单视频和多视频资源；匿名公开内容无需 Cookies，图片暂不下载
- 🎨 现代化深色主题界面
- 📊 实时下载进度显示
- ⚠️ 成功/失败数量统计与失败清单日志
- 🖼️ 自动下载视频封面
- 🌐 支持代理设置
- 💾 左侧设置支持本地记忆上次选择
- 📂 保存目录浏览按钮
- 📝 内置命名模板默认附带 `(id)`
- 🔗 支持多个单视频链接输入
- 📄 批量下载支持页码筛选
- ⚙️ 标准 macOS 设置菜单与独立的全局/站点设置窗口
- 📐 主页核心下载区与运行日志区比例已针对桌面窗口重新优化
- 🎯 多种视频质量选择
- 📦 支持多种输出格式 (mp4, mkv, webm, flv)
- 🚀 可配置下载限速和 1–16 分片并发数

## 下载

从 [Releases](https://github.com/LoongYu/Space-Download/releases) 下载最新版本：

| 平台 | 下载 |
|------|------|
| macOS | SpaceDownload-YYYYMMDDNN.dmg |
| Windows x64 | SpaceDownload-YYYYMMDDNN-windows-x64.zip |

## 从源码运行

```bash
# 克隆仓库
git clone https://github.com/LoongYu/Space-Download.git
cd Space-Download

# 安装依赖
pip install -e ".[default]"
pip install streamlit pywebview deep-translator pyinstaller requests

# 可选：安装 ffmpeg（视频转换/合并需要）
# brew install ffmpeg

# 运行
python main.py
```

## 构建

### macOS DMG

```bash
# 构建本地 .app
python build_app.py

# 构建本地 dmg
python build_app.py dmg

# 构建 dmg 并创建 GitHub Release
python build_release.py YYYYMMDDNN
```

### Windows EXE

在 GitHub Actions 手动触发 `Build Windows` workflow，输入 release 名称。

## 使用方法

1. 启动应用程序
2. 在左侧设置面板配置下载选项
3. 粘贴一个或多个视频链接
4. 如需批量下载，可填写页码范围，例如 `1-3,5`
5. 页码筛选按 Pornhub 网页分页处理，不是按第 N 个视频处理；适用于频道/用户/模特等视频列表页
6. 点击"开始下载"

## 本地记录

开发过程中的本地对话/调试记录默认建议放在 `local_notes/` 目录。
该目录已加入 Git 忽略，默认不会推送到 GitHub。

## 技术栈

- **yt-dlp**: 视频下载核心
- **Streamlit**: Web UI 框架
- **pywebview**: 桌面窗口
- **PyInstaller**: 应用打包

## 原生 macOS 重构

`native/` 目录包含独立的 SwiftUI 重构工程。原生版已接入真实 `yt-dlp` 下载引擎，并完成独立设置窗口、设置持久化、目录选择、多链接、Pornhub 网页分页、YouTube 单视频/播放列表/频道、X 多媒体帖子、TikTok 与抖音公开单视频、Instagram 公开 Reel/帖子/carousel 视频、Telegram 公开单条消息视频、实时进度、失败统计、站点独立翻译与最高像素封面、代理和手动 Cookies 认证；现有 Python 客户端保持不变。

```bash
cd native
swift test --disable-sandbox --build-path .build \
  --cache-path .build/cache \
  --config-path .build/config \
  --security-path .build/security
./prepare_tools.sh
./build_app.sh
```

原生 `.app` 会打包官方独立版 `yt-dlp_macos`；格式合并和转换仍需要系统安装 `ffmpeg`，或在构建时通过 `SPACEDOWNLOAD_FFMPEG_PATH` 指定可分发版本。详细说明见 [native/README.md](native/README.md)。

## 许可证

[Unlicense](LICENSE) - 自由使用
