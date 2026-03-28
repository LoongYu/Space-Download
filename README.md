<div align="center">

# 🚀 Space Download

**基于 yt-dlp 的图形界面视频下载工具**

[![License: Unlicense](https://img.shields.io/badge/-Unlicense-blue.svg?style=for-the-badge)](LICENSE)

</div>

## 简介

Space Download 是一个基于 yt-dlp 的桌面视频下载工具，提供简洁美观的图形界面，支持多种视频网站的视频下载。

## 功能特性

- 🎬 支持多平台视频下载
- 🎨 现代化深色主题界面
- 📊 实时下载进度显示
- 🖼️ 自动下载视频封面
- 🌐 支持代理设置
- 📝 自定义文件命名模板
- 🎯 多种视频质量选择
- 📦 支持多种输出格式 (mp4, mkv, webm, flv)
- 🚀 分片并发下载 (8线程)

## 下载

从 [Releases](https://github.com/LoongYu/Space-Download/releases) 下载最新版本：

| 平台 | 下载 |
|------|------|
| macOS | SpaceDownload-YYYYMMDDNN.dmg |
| Windows | SpaceDownload-YYYYMMDDNN.zip |

## 从源码运行

```bash
# 克隆仓库
git clone https://github.com/LoongYu/Space-Download.git
cd Space-Download

# 安装依赖
pip install streamlit pywebview deep-translator

# 运行
python main.py
```

## 构建

### macOS DMG

```bash
# 构建 dmg 并创建 Release
python3.11 build_release.py YYYYMMDDNN

# 仅构建 dmg
python3.11 build_app.py dmg
```

### Windows EXE

在 GitHub Actions 手动触发 `Build Windows` workflow，输入 release 名称。

## 使用方法

1. 启动应用程序
2. 在左侧设置面板配置下载选项
3. 粘贴视频链接
4. 点击"开始下载"

## 技术栈

- **yt-dlp**: 视频下载核心
- **Streamlit**: Web UI 框架
- **pywebview**: 桌面窗口
- **PyInstaller**: 应用打包

## 许可证

[Unlicense](LICENSE) - 自由使用
